import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/recettes/ui/recettes_screen.dart';
import 'package:kadi/features/recettes/ui/recipe_row.dart';

import 'e2e_harness.dart';

const _exemples = [
  'Pâtes carbonara',
  'Chili con carne',
  'Quiche lorraine',
  'Ratatouille',
];

/// Supprime [name] par sa fiche (« Supprimer la recette »).
Future<void> _supprimer(WidgetTester tester, String name) async {
  await editRecipe(tester, name);
  await deleteFromFiche(tester);
  expect(find.byType(RecettesScreen), findsOneWidget);
}

void flux6PremierLancement() {
  group('Flux 6 — Le premier lancement', () {
    testBothThemes('Recettes et ligne d’accueil, deux cartes, Valider, '
        'Ajouter : ★ une première liste triée par rayon sans rien saisir ; '
        'une recette exemple supprimée avec Annuler', (tester) async {
      phone(tester);
      await pumpE2e(tester, firstLaunch: true);

      // 1. L'app s'ouvre sur la Liste ; Recettes : 4 recettes exemples,
      // ligne d'accueil.
      expect(find.byType(ListeScreen), findsOneWidget);
      await openTab(tester, StringsFr.tabRecettes);
      expect(find.byType(RecettesScreen), findsOneWidget);
      expect(find.text(StringsFr.recettesAccueil), findsOneWidget);
      expect(find.byType(RecipeRow), findsNWidgets(4));
      for (final name in _exemples) {
        expect(recipeCard(name), findsOneWidget, reason: name);
      }

      // 2-3. Deux cartes, Valider, puis Ajouter sans rien changer.
      await tapRecipeCard(tester, 'Pâtes carbonara');
      await tapRecipeCard(tester, 'Ratatouille');
      await openRevue(tester, 2);
      await tapAndSettle(tester, ajouterALaListe);

      // 4. ★ Sa première liste, triée par rayon, sans avoir rien saisi.
      expect(find.byType(ListeScreen), findsOneWidget, reason: '★');
      expect(find.text(StringsFr.listePrete), findsOneWidget, reason: '★');
      expect(find.byType(ItemRow), findsNWidgets(12), reason: '★ 5 + 7');
      final headers = shownHeaders(tester);
      expect(headers, [
        for (final r in Rayon.values)
          if (headers.contains(r.label)) r.label,
      ], reason: '★ ordre du parcours');
      expect(headers, [
        StringsFr.rayonFruitsLegumes,
        StringsFr.rayonViandePoisson,
        StringsFr.rayonCremerie,
        StringsFr.rayonEpicerieSalee,
      ], reason: '★');

      // 5. Une recette exemple supprimée par sa fiche, Snackbar Annuler.
      await letSnackBarClose(tester);
      await openTab(tester, StringsFr.tabRecettes);
      await _supprimer(tester, 'Quiche lorraine');
      expect(recipeCard('Quiche lorraine'), findsNothing);
      expect(
        find.text(StringsFr.recetteSupprimee('Quiche lorraine')),
        findsOneWidget,
      );
      await tapAndSettle(tester, undoAction);
      expect(recipeCard('Quiche lorraine'), findsOneWidget);
    });

    testBothThemes('Échec : toutes les recettes exemples supprimées : '
        'message d’état vide et FAB +', (tester) async {
      phone(tester);
      await pumpE2e(tester, firstLaunch: true);
      await openTab(tester, StringsFr.tabRecettes);
      for (final name in _exemples) {
        await _supprimer(tester, name);
      }
      expect(find.byType(RecipeRow), findsNothing);
      expect(find.text(StringsFr.recettesVide), findsOneWidget);
      expect(
        find.byTooltip(StringsFr.nouvelleRecette).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip(StringsFr.nouvelleRecette), findsOneWidget);
    });
  });
}

void main() => flux6PremierLancement();
