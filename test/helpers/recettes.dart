import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/recipe_card.dart';
import 'package:material_ui/material_ui.dart';

/// Téléphone haut ([size]) : toute la fiche et toutes les cartes sont
/// bâties. Vue remise à zéro à la fin du test.
void tallPhone(WidgetTester tester, [Size size = const Size(400, 1400)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Ouvre l'onglet [tab] de la barre de navigation.
Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
  );
  await tester.pumpAndSettle();
}

/// La carte de la recette [name].
Finder recipeCard(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(RecipeCard));

/// Disques `surface` translucides de la carte de [name], qui gardent la
/// coche et l'icône « modifier » lisibles sur une photo.
Finder recipeCardDiscs(String name) => find.descendant(
  of: recipeCard(name),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

/// Touche la carte de [name] (sélection ou désélection).
Future<void> tapRecipeCard(WidgetTester tester, String name) async {
  await tester.ensureVisible(recipeCard(name));
  await tester.tap(recipeCard(name));
  await tester.pumpAndSettle();
}

/// Ouvre la fiche de [name] par l'icône « modifier » de sa carte.
Future<void> editRecipe(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip(StringsFr.modifierRecette(name)));
  await tester.pumpAndSettle();
  expect(find.byType(FicheRecetteScreen), findsOneWidget);
}

/// Quitte la Fiche recette par le bouton retour.
Future<void> backFromFiche(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(find.byType(FicheRecetteScreen), findsNothing);
}

/// Champ nom de la fiche.
Finder get ficheNameField => find
    .descendant(
      of: find.byType(FicheRecetteScreen),
      matching: find.byType(TextField),
    )
    .first;

/// La recette nommée [name], supprimée ou non ; `null` sans elle.
Future<Recipe?> recipeNamed(AppDatabase db, String name) => (db.select(
  db.recipes,
)..where((r) => r.name.equals(name))).getSingleOrNull();

/// Le bouton « Valider (n) » de Recettes.
Finder validerButton(int n) =>
    find.widgetWithText(FilledButton, StringsFr.validerN(n));

/// Ouvre la Revue par « Valider (n) ».
Future<void> openRevue(WidgetTester tester, int n) async {
  await tester.tap(validerButton(n));
  await tester.pumpAndSettle();
}
