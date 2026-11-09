import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';

import 'e2e_harness.dart';

const _nbsp = ' ';

const _semaine = [
  'Pâtes carbonara',
  'Chili con carne',
  'Quiche lorraine',
  'Ratatouille',
];

/// Étapes 2 à 5 : les 4 Cartes recette, « Valider (4) », la Revue (Pâtes
/// décochées, Œufs 6 → 4), « Ajouter à la liste ».
Future<void> _choisirLaSemaine(
  WidgetTester tester, {
  bool corriger = true,
}) async {
  await openTab(tester, StringsFr.tabRecettes);
  for (final recette in _semaine) {
    await tapRecipeCard(tester, recette);
  }
  expect(validerButton(4), findsOneWidget);

  await openRevue(tester, 4);
  expect(find.byType(RevueScreen), findsOneWidget);
  expect(find.text(StringsFr.revueConsigneV2), findsOneWidget);
  // Groupée par rayon, tout coché.
  expect(allRevueKept(tester), isTrue);
  expect(shownHeaders(tester), _inRouteOrder(shownHeaders(tester)));

  if (corriger) {
    // Il reste des pâtes ; six œufs suffisent (3 + 3 dans les recettes).
    await uncheckInRevue(tester, 'Pâtes');
    expect(
      revueQuantity(tester, 'Œufs'),
      '6${String.fromCharCode(0xA0)}pièces',
    );
    await setRevueQuantity(tester, 'Œufs', '4');
  }

  await tapAndSettle(tester, ajouterALaListe);
  expect(find.byType(RevueScreen), findsNothing);
}

/// [labels] triés dans l'ordre du parcours par défaut.
List<String> _inRouteOrder(List<String> labels) => [
  for (final rayon in Rayon.values)
    if (labels.contains(rayon.label)) rayon.label,
];

/// La ligne [name] est sous l'En-tête [rayon], avant le rayon suivant.
void _expectUnder(WidgetTester tester, String name, String rayon) {
  final headers = shownHeaders(tester);
  final y = tester.getTopLeft(itemRow(name)).dy;
  expect(y, greaterThan(tester.getTopLeft(rayonHeader(rayon)).dy));
  final next = headers.indexOf(rayon) + 1;
  if (next < headers.length) {
    expect(y, lessThan(tester.getTopLeft(rayonHeader(headers[next])).dy));
  }
}

void flux1DimancheSoir() {
  group('Flux 1 — Le dimanche soir', () {
    testBothThemes('Nouvelle liste, 4 recettes, Revue corrigée : ★ la Liste '
        'fusionnée et triée par rayon ; puis deux fréquents par le +', (
      tester,
    ) async {
      phone(tester);
      final db = await pumpE2e(tester);
      // État de départ : la liste de la semaine passée n'a pas été terminée.
      await ListeRepository(db, Clock()).addArticle(SeedIds.riz);
      await tester.pumpAndSettle();
      expect(itemRow('Riz'), findsOneWidget);

      // 1. Recettes, Action Nouvelle liste, confirmée.
      await openTab(tester, StringsFr.tabRecettes);
      await recettesMenu(tester, StringsFr.nouvelleListe);
      expect(find.text(StringsFr.nouvelleListeTitre), findsOneWidget);
      await tapAndSettle(tester, find.text(StringsFr.effacerEtRecommencer));
      await openTab(tester, StringsFr.tabListe);
      expect(find.text(StringsFr.listeVide), findsOneWidget);

      // 2 à 5.
      await _choisirLaSemaine(tester);

      // 6. ★ La Liste apparaît, fusionnée et triée par rayon dans l'ordre du
      // parcours, sans aucun classement manuel. « Ta liste est prête. »
      expect(find.text(StringsFr.listePrete), findsOneWidget, reason: '★');
      final headers = shownHeaders(tester);
      expect(headers, _inRouteOrder(headers), reason: '★ ordre du parcours');
      expect(headers, [
        StringsFr.rayonFruitsLegumes,
        StringsFr.rayonViandePoisson,
        StringsFr.rayonCremerie,
        StringsFr.rayonEpicerieSalee,
      ], reason: '★');
      // Les oignons et les poivrons de deux recettes, les lardons de deux
      // recettes : une seule ligne chacun, quantités additionnées.
      for (final (name, quantity, rayon) in [
        ('Oignons', '3${_nbsp}pièces', StringsFr.rayonFruitsLegumes),
        ('Poivrons', '3${_nbsp}pièces', StringsFr.rayonFruitsLegumes),
        ('Lardons', '400${_nbsp}g', StringsFr.rayonViandePoisson),
        ('Œufs', '4${_nbsp}pièces', StringsFr.rayonCremerie),
        ('Riz', '300${_nbsp}g', StringsFr.rayonEpicerieSalee),
      ]) {
        expect(itemRow(name), findsOneWidget, reason: '★ $name');
        expect(itemRowWith(name, quantity), findsOneWidget, reason: '★ $name');
        _expectUnder(tester, name, rayon);
      }
      // 18 articles distincts, sans les pâtes décochées.
      expect(find.byType(ItemRow), findsNWidgets(17), reason: '★');
      expect(itemRow('Pâtes'), findsNothing, reason: '★');

      // 7. FAB +, « Papier toilette » et « Lait » depuis les fréquents.
      await openAddSheet(tester);
      await tapFrequent(tester, 'Papier toilette');
      await tapFrequent(tester, 'Lait');
      await closeAddSheet(tester);
      _expectUnder(tester, 'Lait', StringsFr.rayonCremerie);
      _expectUnder(tester, 'Papier toilette', StringsFr.rayonHygiene);
      expect(find.byType(ItemRow), findsNWidgets(19));
    });

    testBothThemes('Échec : Ratatouille validée par erreur, désélectionnée : '
        'ses ingrédients quittent la liste, quantités réduites, Annuler', (
      tester,
    ) async {
      phone(tester);
      await pumpE2e(tester);
      await _choisirLaSemaine(tester, corriger: false);
      expect(itemRowWith('Oignons', '3${_nbsp}pièces'), findsOneWidget);

      await openTab(tester, StringsFr.tabRecettes);
      await tapRecipeCard(tester, 'Ratatouille');
      expect(
        find.text(StringsFr.ingredientsRetires('Ratatouille')),
        findsOneWidget,
      );
      expect(undoAction, findsOneWidget);
      expect(
        find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Ratatouille')),
        findsOneWidget,
      );

      await openTab(tester, StringsFr.tabListe);
      expect(itemRowWith('Oignons', '2${_nbsp}pièces'), findsOneWidget);
      expect(itemRowWith('Poivrons', '1${_nbsp}pièce'), findsOneWidget);
      for (final gone in ['Courgettes', 'Aubergines', 'Tomates']) {
        expect(itemRow(gone), findsNothing, reason: gone);
      }
      expect(itemRow('Lardons'), findsOneWidget);

      // Annuler : la liste revient telle quelle.
      await openTab(tester, StringsFr.tabRecettes);
      await tapAndSettle(tester, undoAction);
      await openTab(tester, StringsFr.tabListe);
      expect(itemRowWith('Oignons', '3${_nbsp}pièces'), findsOneWidget);
      expect(itemRow('Courgettes'), findsOneWidget);
    });
  });
}

void main() => flux1DimancheSoir();
