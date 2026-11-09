import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/ingredient_sheet.dart';
import 'package:kadi/features/recettes/ui/recipe_row.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e_harness.dart';

Finder _ingredientRow(String name) => find.byWidgetPredicate(
  (w) => w is IngredientRow && w.ingredient.name == name,
);

Finder _quantity(String name) =>
    find.descendant(of: _ingredientRow(name), matching: find.byType(TextField));

String _sheetText(WidgetTester tester) =>
    tester.widget<TextField>(ingredientSheetField).controller!.text;

/// État de départ : Kadi sur Recettes ; « Haricots rouges » (Épicerie
/// salée, g) est au catalogue d'Antoine.
Future<AppDatabase> _pumpRecettes(WidgetTester tester) async {
  phone(tester, size: const Size(412, 1400));
  final db = await pumpE2e(tester);
  await db.transaction(
    () => CatalogueRepository(db, Clock()).createArticle(
      'Haricots rouges',
      rayon: Rayon.epicerieSalee,
      unit: Unit.g,
    ),
  );
  await openTab(tester, StringsFr.tabRecettes);
  return db;
}

/// Ouvre une fiche vide par le FAB + de Recettes.
Future<void> _nouvelleFiche(WidgetTester tester) async {
  await tapAndSettle(tester, find.byTooltip(StringsFr.nouvelleRecette));
  expect(find.byType(FicheRecetteScreen), findsOneWidget);
  expect(find.text(StringsFr.nouvelleRecette), findsOneWidget);
}

void flux4SaisirUneRecette() {
  group('Flux 4 — Saisir une recette en moins d’une minute', () {
    testBothThemes('FAB +, « Chili », cinq ingrédients par la popup dont un '
        'créé, 500 g de haricots, Enregistrer : ★ la carte « Chili » avec '
        'le Picto des haricots rouges', (tester) async {
      final db = await _pumpRecettes(tester);

      // 1. Fiche vide, nom focalisé.
      await _nouvelleFiche(tester);
      expect(
        tester.widget<TextField>(ficheNameField).focusNode!.hasFocus,
        isTrue,
      );

      // 2. Le nom.
      await tester.enterText(ficheNameField, 'Chili');
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isFalse);

      // 3. « Ajouter un ingrédient » : « hari », Haricots rouges ; la ligne
      // apparaît derrière, le champ se vide, la popup reste ouverte.
      await openIngredientSheet(tester);
      expect(find.byType(FicheRecetteScreen), findsOneWidget);
      await tester.enterText(ingredientSheetField, 'hari');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, ingredientResult('Haricots rouges'));
      expect(_ingredientRow('Haricots rouges'), findsOneWidget);
      expect(_sheetText(tester), isEmpty);
      expect(find.byType(IngredientSheet), findsOneWidget);
      expect(saveEnabled(tester), isTrue);

      // 4. Oignons, viande hachée, tomates ; « Épices » n'est pas au
      // catalogue : « Créer « Épices » » l'y ajoute sans quitter la popup.
      for (final (query, name) in [
        ('oign', 'Oignons'),
        ('viande h', 'Viande hachée'),
        ('tomates', 'Tomates'),
      ]) {
        await tester.enterText(ingredientSheetField, query);
        await tester.pumpAndSettle();
        await tapAndSettle(tester, ingredientResult(name));
        expect(_ingredientRow(name), findsOneWidget);
        expect(_sheetText(tester), isEmpty);
      }
      await tester.enterText(ingredientSheetField, 'Épices');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text(StringsFr.creerNom('Épices')));
      expect(_ingredientRow('Épices'), findsOneWidget);
      expect(find.byType(IngredientSheet), findsOneWidget);
      await closeIngredientSheet(tester);

      // 5. 500 g de haricots rouges ; les épices restent sans quantité.
      await tester.showKeyboard(_quantity('Haricots rouges'));
      await tester.enterText(_quantity('Haricots rouges'), '500');
      await tester.pumpAndSettle();
      expect(await recipeNamed(db, 'Chili'), isNull);
      await saveFiche(tester);

      // 6. ★ La ligne « Chili » apparaît, monogramme « Ch » à la couleur
      // du rayon des haricots rouges.
      expect(recipeCard('Chili'), findsOneWidget, reason: '★');
      final card = tester.widget<RecipeRow>(recipeCard('Chili'));
      final haricots = await (db.select(
        db.articles,
      )..where((a) => a.name.equals('Haricots rouges'))).getSingle();
      expect(card.card.pictoKey, haricots.pictoKey, reason: '★');
      expect(card.card.rayon, Rayon.epicerieSalee, reason: '★');
      expect(
        find.descendant(of: recipeCard('Chili'), matching: find.text('Ch')),
        findsOneWidget,
        reason: '★',
      );
      final chili = (await recipeNamed(db, 'Chili'))!;
      final ingredients = await (db.select(
        db.recipeIngredients,
      )..where((i) => i.recipeId.equals(chili.id))).get();
      expect(ingredients, hasLength(5));
      expect(
        ingredients.singleWhere((i) => i.articleId == haricots.id).quantity,
        500,
      );
      final epices = await (db.select(
        db.articles,
      )..where((a) => a.name.equals('Épices'))).getSingle();
      expect(
        (epices.rayon, epices.unit, epices.inCatalogue),
        (Rayon.divers.code, null, true),
      );
    });

    testBothThemes('Échec : retour sans enregistrer : « Garder » ramène à la '
        'fiche, « Quitter » ne crée rien', (tester) async {
      final db = await _pumpRecettes(tester);
      await _nouvelleFiche(tester);
      await tester.enterText(ficheNameField, 'Chili');
      await tester.pumpAndSettle();
      await addIngredientBySheet(tester, 'hari', 'Haricots rouges');

      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.text(StringsFr.quitterSansEnregistrerTitre), findsOneWidget);
      await tapAndSettle(
        tester,
        find.widgetWithText(TextButton, StringsFr.garder),
      );
      expect(find.byType(FicheRecetteScreen), findsOneWidget);
      expect(_ingredientRow('Haricots rouges'), findsOneWidget);

      await quitFiche(tester);
      expect(await recipeNamed(db, 'Chili'), isNull);
      expect(recipeCard('Chili'), findsNothing);
    });

    testBothThemes('Échec : sans nom ou sans ingrédient, « Enregistrer » '
        'reste grisé', (tester) async {
      await _pumpRecettes(tester);
      await _nouvelleFiche(tester);
      expect(saveEnabled(tester), isFalse);
      await tester.enterText(ficheNameField, 'Chili');
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isFalse, reason: 'sans ingrédient');
      await tester.enterText(ficheNameField, '');
      await tester.pumpAndSettle();
      await addIngredientBySheet(tester, 'hari', 'Haricots rouges');
      expect(saveEnabled(tester), isFalse, reason: 'sans nom');
      await tester.enterText(ficheNameField, 'Chili');
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isTrue);
    });
  });
}

void main() => flux4SaisirUneRecette();
