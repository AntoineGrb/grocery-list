import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/quantity_tag.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/core/ui/confirm_dialog.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/ingredient_sheet.dart';
import 'package:kadi/features/recettes/ui/recipe_row.dart';
import 'package:kadi/features/recettes/ui/revue_row.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
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

/// La ligne de la recette [name] (Recettes).
Finder recipeCard(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(RecipeRow));

/// Le bouton de sélection « Ajouter » / « Ajoutée » de la ligne de [name].
Finder recipeSelectButton(String name) =>
    find.descendant(of: recipeCard(name), matching: find.byType(SelectButton));

/// La recette [name] est sélectionnée (« Ajoutée »).
bool recipeSelected(WidgetTester tester, String name) =>
    tester.widget<SelectButton>(recipeSelectButton(name)).selected;

/// Amène la ligne de [name] à l'écran : la liste de Recettes est
/// paresseuse, une ligne loin de l'écran n'est pas bâtie.
Future<void> showRecipe(WidgetTester tester, String name) async {
  if (recipeCard(name).evaluate().isEmpty) {
    final list = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    // Vers le haut d'abord (Recettes est triée par nom), puis vers le bas.
    for (final delta in [-200.0, 200.0]) {
      if (recipeCard(name).evaluate().isNotEmpty) break;
      try {
        await tester.scrollUntilVisible(
          recipeCard(name),
          delta,
          scrollable: list.first,
          maxScrolls: 20,
        );
      } on StateError {
        // Pas dans ce sens.
      }
    }
  }
  await tester.ensureVisible(recipeCard(name));
  await tester.pumpAndSettle();
}

/// Touche le bouton de sélection de [name] (sélection ou désélection).
Future<void> tapRecipeCard(WidgetTester tester, String name) async {
  await showRecipe(tester, name);
  await tester.ensureVisible(recipeSelectButton(name));
  await tester.pumpAndSettle();
  await tester.tap(recipeSelectButton(name));
  await tester.pumpAndSettle();
}

/// Ouvre la fiche de [name] par un tap sur sa ligne.
Future<void> editRecipe(WidgetTester tester, String name) async {
  await showRecipe(tester, name);
  await tester.tap(
    find.descendant(of: recipeCard(name), matching: find.text(name)),
  );
  await tester.pumpAndSettle();
  expect(find.byType(FicheRecetteScreen), findsOneWidget);
}

/// Quitte une Fiche recette non modifiée par le bouton retour : elle se
/// ferme sans question.
Future<void> backFromFiche(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(find.byType(FicheRecetteScreen), findsNothing);
}

/// Le bouton « Enregistrer » de la fiche.
Finder get saveButton =>
    find.widgetWithText(FilledButton, StringsFr.enregistrer);

/// « Enregistrer » est actif.
bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(saveButton).onPressed != null;

/// Touche « Enregistrer » : la fiche s'écrit et se ferme.
Future<void> saveFiche(WidgetTester tester) async {
  expect(saveEnabled(tester), isTrue);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
  expect(find.byType(FicheRecetteScreen), findsNothing);
}

/// Dialogue « Quitter sans enregistrer ? ».
Finder get quitDialog => find.byType(ConfirmDialog);

/// Quitte une fiche modifiée par le retour, puis « Quitter » dans le
/// dialogue : elle se ferme sans rien écrire.
Future<void> quitFiche(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(find.text(StringsFr.quitterSansEnregistrerTitre), findsOneWidget);
  await tester.tap(find.widgetWithText(TextButton, StringsFr.quitter));
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

/// Le champ en pilule « Ajouter un ingrédient… » de la fiche.
Finder get addIngredientButton =>
    find.text(StringsFr.ajouterUnIngredientEllipse);

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

/// Le bouton « Valider n recettes » de Recettes.
Finder validerButton(int n) =>
    find.widgetWithText(FilledButton, StringsFr.validerN(n));

/// Ouvre la Revue par « Valider n recettes ».
Future<void> openRevue(WidgetTester tester, int n) async {
  await tester.tap(validerButton(n));
  await tester.pumpAndSettle();
}

/// Ouvre le menu ⋮ de Recettes et touche son action [label] (« Nouvelle
/// liste », « Paramètres »).
Future<void> recettesMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(StringsFr.plusDOptions));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Le Bouton d'action de la Revue : « Ajouter N articles à la liste ».
Finder get revueAddButton => find.descendant(
  of: find.byType(RevueScreen),
  matching: find.byType(FilledButton),
);

/// Tag quantité de la Ligne d'ingrédient de [name] dans la Fiche recette.
Finder ingredientQuantityTag(String name) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is IngredientRow && w.ingredient.name == name,
  ),
  matching: find.byType(QuantityTag),
);

/// Quantité de [name] par son tag et le Module quantité : l'unité [unit]
/// (libellé du segment) si elle est donnée, puis [text] saisi au clavier
/// (vide : 0, sans quantité), puis OK.
Future<void> setIngredientQuantity(
  WidgetTester tester,
  String name,
  String text, {
  String? unit,
}) async {
  final tag = ingredientQuantityTag(name);
  await tester.ensureVisible(tag);
  await tester.pumpAndSettle();
  await tester.tap(tag);
  await tester.pumpAndSettle();
  if (unit != null) {
    await tester.tap(find.bySemanticsLabel(StringsFr.uniteDe(unit)));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('quantity-sheet-number')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('quantity-sheet-input')), text);
  await tester.tap(find.text(StringsFr.ok));
  await tester.pumpAndSettle();
}

/// La Ligne de Revue de [name].
Finder revueRowOf(String name) =>
    find.byWidgetPredicate((w) => w is RevueRow && w.line.name == name);

/// Touche la Ligne de Revue de [name] : gardée ↔ « J'ai ! ».
Future<void> toggleRevueRow(WidgetTester tester, String name) async {
  final text = find.descendant(of: revueRowOf(name), matching: find.text(name));
  await tester.ensureVisible(text);
  await tester.pumpAndSettle();
  await tester.tap(text);
  await tester.pumpAndSettle();
}

/// La Ligne de Revue de [name] est gardée.
bool revueKept(WidgetTester tester, String name) =>
    tester.widget<RevueRow>(revueRowOf(name)).checked;

/// Toutes les Lignes de Revue sont gardées.
bool allRevueKept(WidgetTester tester) =>
    tester.widgetList<RevueRow>(find.byType(RevueRow)).every((r) => r.checked);

/// Quantité montrée par la Ligne de Revue de [name] (`formatQuantity`).
String revueQuantity(WidgetTester tester, String name) {
  final row = tester.widget<RevueRow>(revueRowOf(name));
  return formatQuantity(row.quantity, row.unit);
}

/// Corrige la quantité de [name] en Revue par son tag et le Module
/// quantité : [unit] si donnée, puis [text] au clavier, puis OK.
Future<void> setRevueQuantity(
  WidgetTester tester,
  String name,
  String text, {
  String? unit,
}) async {
  final tag = find.descendant(
    of: revueRowOf(name),
    matching: find.byType(QuantityTag),
  );
  await tester.ensureVisible(tag);
  await tester.pumpAndSettle();
  await tester.tap(tag);
  await tester.pumpAndSettle();
  if (unit != null) {
    await tester.tap(find.bySemanticsLabel(StringsFr.uniteDe(unit)));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('quantity-sheet-number')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('quantity-sheet-input')), text);
  await tester.tap(find.text(StringsFr.ok));
  await tester.pumpAndSettle();
}

/// Rayons des cartes de la Revue, de haut en bas.
List<Rayon> revueRayons(WidgetTester tester) {
  final cards = [
    for (final e in find.byType(RevueRayonCard).evaluate())
      (
        (e.widget as RevueRayonCard).group.rayon,
        tester.getTopLeft(find.byWidget(e.widget)).dy,
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (r, _) in cards) r];
}
