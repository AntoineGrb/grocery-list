import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/ingredient_sheet.dart';
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

/// Le bouton « Ajouter un ingrédient » de la fiche.
Finder get addIngredientButton => find.ancestor(
  of: find.text(StringsFr.ajouterUnIngredient),
  matching: find.byWidgetPredicate((w) => w is TextButton),
);

/// Ouvre la popup d'ajout d'ingrédient par le bouton de la fiche.
Future<void> openIngredientSheet(WidgetTester tester) async {
  await tester.ensureVisible(addIngredientButton);
  await tester.pumpAndSettle();
  await tester.tap(addIngredientButton);
  await tester.pumpAndSettle();
  expect(find.byType(IngredientSheet), findsOneWidget);
}

/// Champ « Ajouter un ingrédient » de la popup.
Finder get ingredientSheetField => find.descendant(
  of: find.byType(IngredientSheet),
  matching: find.byType(TextField),
);

/// Ligne de résultat de [name] dans la popup.
Finder ingredientResult(String name) => find.byWidgetPredicate(
  (w) => w is IngredientResultRow && w.article.name == name,
);

/// Ferme la popup par le retour.
Future<void> closeIngredientSheet(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byType(IngredientSheet), findsNothing);
}

/// Ouvre la popup, cherche [query], touche le résultat [name] et referme.
Future<void> addIngredientBySheet(
  WidgetTester tester,
  String query,
  String name,
) async {
  await openIngredientSheet(tester);
  await tester.enterText(ingredientSheetField, query);
  await tester.pumpAndSettle();
  await tester.tap(ingredientResult(name));
  await tester.pumpAndSettle();
  await closeIngredientSheet(tester);
}

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
