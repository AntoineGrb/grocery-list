import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/recettes/ui/revue_row.dart';

import 'e2e_harness.dart';

const _quiche = [
  'Pâte feuilletée',
  'Lardons',
  'Œufs',
  'Crème fraîche',
  'Emmental râpé',
];

/// État de départ, par les gestes : la liste de la semaine validée
/// (Pâtes carbonara et Chili con carne), puis Recettes.
Future<void> _semaineValidee(WidgetTester tester) async {
  phone(tester);
  await pumpE2e(tester);
  await openTab(tester, StringsFr.tabRecettes);
  await tapRecipeCard(tester, 'Pâtes carbonara');
  await tapRecipeCard(tester, 'Chili con carne');
  await openRevue(tester, 2);
  await tapAndSettle(tester, ajouterALaListe);
  await letSnackBarClose(tester);
  expect(itemRowWith('Lardons', formatQuantity(200, Unit.g)), findsOneWidget);
  expect(itemRowWith('Œufs', formatQuantity(3000, Unit.piece)), findsOneWidget);
  await openTab(tester, StringsFr.tabRecettes);
}

/// Quiche lorraine sélectionnée et validée, Œufs décochés en Revue.
Future<void> _ajouterLaQuiche(WidgetTester tester) async {
  await tapRecipeCard(tester, 'Quiche lorraine');
  expect(validerButton(1), findsOneWidget);
  await openRevue(tester, 1);
  expect(
    [
      for (final r in tester.widgetList<RevueRow>(find.byType(RevueRow)))
        r.line.name,
    ]..sort(),
    [..._quiche]..sort(),
  );
  await uncheckInRevue(tester, 'Œufs');
  await tapAndSettle(tester, ajouterALaListe);
}

void flux5RecetteDuMercredi() {
  group('Flux 5 — La recette du mercredi', () {
    testBothThemes('Quiche ajoutée à une liste validée, Œufs décochés : ★ la '
        'liste est complétée, les quantités s’additionnent', (tester) async {
      await _semaineValidee(tester);
      await _ajouterLaQuiche(tester);

      // ★ La liste en cours est complétée sans repartir de zéro.
      // Carbonara et Chili : 10 lignes, que la quiche complète de 3.
      expect(find.text(StringsFr.listePrete), findsOneWidget, reason: '★');
      expect(itemRow('Pâtes'), findsOneWidget, reason: '★ gardée');
      expect(itemRow('Riz'), findsOneWidget, reason: '★ gardée');
      expect(
        itemRowWith('Lardons', formatQuantity(400, Unit.g)),
        findsOneWidget,
        reason: '★ 200 g + 200 g',
      );
      expect(
        itemRowWith('Œufs', formatQuantity(3000, Unit.piece)),
        findsOneWidget,
        reason: '★ décochés : inchangés',
      );
      for (final name in [
        'Pâte feuilletée',
        'Crème fraîche',
        'Emmental râpé',
      ]) {
        expect(itemRow(name), findsOneWidget, reason: '★ $name');
        expect(
          tester.getTopLeft(itemRow(name)).dy,
          greaterThan(
            tester.getTopLeft(rayonHeader(StringsFr.rayonCremerie)).dy,
          ),
          reason: '★ $name dans Crèmerie',
        );
        expect(
          tester.getTopLeft(itemRow(name)).dy,
          lessThan(
            tester.getTopLeft(rayonHeader(StringsFr.rayonEpicerieSalee)).dy,
          ),
          reason: '★ $name dans Crèmerie',
        );
      }
      expect(find.byType(ItemRow), findsNWidgets(10 + 3), reason: '★');
    });

    testBothThemes('Échec : pas de quiche finalement, désélectionnée : ses '
        'ingrédients quittent la liste, Annuler', (tester) async {
      await _semaineValidee(tester);
      await _ajouterLaQuiche(tester);

      await openTab(tester, StringsFr.tabRecettes);
      await tapRecipeCard(tester, 'Quiche lorraine');
      expect(
        find.text(StringsFr.ingredientsRetires('Quiche lorraine')),
        findsOneWidget,
      );
      expect(undoAction, findsOneWidget);

      await openTab(tester, StringsFr.tabListe);
      expect(
        itemRowWith('Lardons', formatQuantity(200, Unit.g)),
        findsOneWidget,
      );
      for (final name in [
        'Pâte feuilletée',
        'Crème fraîche',
        'Emmental râpé',
      ]) {
        expect(itemRow(name), findsNothing, reason: name);
      }
      expect(
        itemRowWith('Œufs', formatQuantity(3000, Unit.piece)),
        findsOneWidget,
      );
    });
  });
}

void main() => flux5RecetteDuMercredi();
