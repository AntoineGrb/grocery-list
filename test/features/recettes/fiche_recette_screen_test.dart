import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/ui/quantity_sheet.dart';
import 'package:kadi/core/ui/quantity_tag.dart';
import 'package:kadi/core/ui/sheet_handle.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/ingredient_sheet.dart';
import 'package:kadi/features/recettes/ui/recipe_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/recettes.dart';
import '../../helpers/test_db.dart';

const _nbsp = ' ';

/// Kadi sur un téléphone haut (toute la fiche est bâtie), onglet Recettes
/// ouvert ; « Haricots rouges » (Épicerie salée, g) ajouté au catalogue.
Future<AppDatabase> _openRecettes(
  WidgetTester tester, {
  Size size = const Size(400, 1400),
  List<Override> overrides = const [],
}) async {
  tallPhone(tester, size);
  final db = await pumpKadi(tester, overrides: overrides);
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

Finder get _fab => find.byTooltip(StringsFr.nouvelleRecette);

/// Champ « Ajouter un ingrédient » de la popup.
Finder get _sheetField => ingredientSheetField;

Finder get _sheet => find.byType(IngredientSheet);

TextField _textField(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder);

bool _focused(WidgetTester tester, Finder field) =>
    _textField(tester, field).focusNode!.hasFocus;

String _sheetText(WidgetTester tester) =>
    _textField(tester, _sheetField).controller!.text;

/// Tape [text] dans le champ de la popup ouverte.
Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(_sheetField, text);
  await tester.pumpAndSettle();
}

/// Tape [text] dans la popup puis Entrée.
Future<void> _submit(WidgetTester tester, String text) async {
  await _search(tester, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Finder _result(String name) => ingredientResult(name);

Finder _row(String name) => find.byWidgetPredicate(
  (w) => w is IngredientRow && w.ingredient.name == name,
);

/// Tag quantité de la Ligne d'ingrédient de [name].
Finder _quantity(String name) =>
    find.descendant(of: _row(name), matching: find.byType(QuantityTag));

/// Aucune saisie de quantité n'est ouverte (le Module quantité est fermé).
bool _noQuantityFocused(WidgetTester tester) =>
    find.byType(QuantitySheet).evaluate().isEmpty;

Future<void> _setQuantity(
  WidgetTester tester,
  String name,
  String text, {
  String? unit,
}) => setIngredientQuantity(tester, name, text, unit: unit);

/// Retire [name] en glissant sa ligne vers la gauche.
Future<void> _removeRow(WidgetTester tester, String name) async {
  await tester.ensureVisible(_row(name));
  await tester.pumpAndSettle();
  await tester.drag(_row(name), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

/// Valeur stockée de l'ingrédient [name] du brouillon.
StoredQuantity? _value(WidgetTester tester, String name) =>
    tester.widget<IngredientRow>(_row(name)).ingredient.value;

/// Liste défilante de la fiche (les champs ont aussi les leurs).
Finder get _ficheScrollable => find
    .descendant(
      of: find.byType(FicheRecetteScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Haut de la feuille d'ajout.
double _sheetTop(WidgetTester tester) =>
    tester.getRect(find.byType(SheetHandle)).top;

/// Ajoute [name] par la popup (cherché par [query]) et saisit [quantity].
Future<void> _addIngredient(
  WidgetTester tester,
  String query,
  String name, [
  String? quantity,
]) async {
  await addIngredientBySheet(tester, query, name);
  if (quantity != null) await _setQuantity(tester, name, quantity);
}

/// Annonces TalkBack envoyées pendant le test.
List<String> _recordAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      final map = message as Map<dynamic, dynamic>;
      if (map['type'] == 'announce') {
        announcements.add((map['data'] as Map)['message'] as String);
      }
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}

Future<List<RecipeIngredient>> _ingredients(AppDatabase db, String recipeId) =>
    (db.select(db.recipeIngredients)
          ..where((i) => i.recipeId.equals(recipeId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.asc(i.position)]))
        .get();

Future<Article> _article(AppDatabase db, String name) =>
    (db.select(db.articles)..where((a) => a.name.equals(name))).getSingle();

void main() {
  testWidgets('Flux 4 : FAB +, « Chili », popup : « hari » → Haricots '
      'rouges, quatre autres dont un créé ; quantités ensuite, « Enregistrer » '
      ': la carte « Chili » avec le picto des haricots', (tester) async {
    final db = await _openRecettes(tester);
    final recipesBefore = (await db.select(db.recipes).get()).length;

    await tester.tap(_fab);
    await tester.pumpAndSettle();

    // Plein écran, sans Barre de navigation, flèche retour ; nom focalisé.
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(_focused(tester, ficheNameField), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // « Enregistrer » en bas, plein, argile, pleine largeur, grisé.
    expect(saveButton, findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(
      tester.getRect(saveButton).bottom,
      greaterThan(1400 - KadiSpacing.s2 - KadiSpacing.touchTarget),
    );
    expect(tester.getSize(saveButton).width, 400 - 2 * KadiSpacing.margin);

    await tester.enterText(ficheNameField, 'Chili');
    await tester.pumpAndSettle();
    // Un nom sans ingrédient : grisé, rien d'écrit.
    expect(saveEnabled(tester), isFalse);
    expect(await db.select(db.recipes).get(), hasLength(recipesBefore));

    // Champ d'ajout en pilule « Ajouter un ingrédient… » sous la section.
    expect(addIngredientButton, findsOneWidget);
    final scheme = Theme.of(tester.element(addIngredientButton)).colorScheme;
    expect(
      tester
          .getSize(
            find.ancestor(
              of: addIngredientButton,
              matching: find.byType(InkWell),
            ),
          )
          .height,
      greaterThanOrEqualTo(KadiSpacing.touchTarget),
    );

    // Feuille d'ajout à ~88 % de l'écran, champ focalisé, clavier ouvert,
    // « TES INGRÉDIENTS » sans saisie.
    await openIngredientSheet(tester);
    expect(_focused(tester, _sheetField), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(_sheetTop(tester), lessThan(1400 * 0.2));
    expect(find.text(StringsFr.tesIngredients), findsOneWidget);

    await _search(tester, 'hari');
    expect(_result('Haricots rouges'), findsOneWidget);
    expect(_result('Haricots verts'), findsOneWidget);
    await tester.tap(_result('Haricots rouges'));
    await tester.pumpAndSettle();

    // La ligne apparaît derrière, dans l'unité de l'article ; le champ se
    // vide, la popup reste ouverte et garde le focus ; aucun Champ quantité
    // ne le prend.
    expect(_row('Haricots rouges'), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(_sheetText(tester), isEmpty);
    expect(_focused(tester, _sheetField), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(_noQuantityFocused(tester), isTrue);
    // Sans quantité : le tag balance.
    expect(_value(tester, 'Haricots rouges'), isNull);
    // Rien d'écrit avant « Enregistrer ».
    expect(await recipeNamed(db, 'Chili'), isNull);

    // On enchaîne sans fermer la popup.
    for (final (query, name) in [
      ('oign', 'Oignons'),
      ('viande h', 'Viande hachée'),
      ('tomates conc', 'Tomates concassées'),
    ]) {
      await _search(tester, query);
      await tester.tap(_result(name));
      await tester.pumpAndSettle();
      expect(_row(name), findsOneWidget);
      expect(_sheetText(tester), isEmpty);
    }

    // Un ingrédient inconnu : « Créer « … » », sans quitter la popup.
    await _search(tester, "piment d'Espelette");
    expect(find.byType(IngredientResultRow), findsNothing);
    expect(find.text(StringsFr.aucunIngredient), findsOneWidget);
    final create = find.text(StringsFr.ajouterNom("piment d'Espelette"));
    expect(create, findsOneWidget);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(_row("Piment d'Espelette"), findsOneWidget);
    expect(_sheetText(tester), isEmpty);
    expect(_noQuantityFocused(tester), isTrue);

    // Trouvable ensuite par la recherche, déjà ingrédient.
    await _search(tester, 'piment');
    expect(
      tester
          .widget<IngredientResultRow>(_result("Piment d'Espelette"))
          .inRecipe,
      isTrue,
    );
    await tester.tap(find.byTooltip(StringsFr.effacerLeTexte));
    await tester.pumpAndSettle();
    expect(_sheetText(tester), isEmpty);

    // Popup fermée : les cinq lignes dans l'ordre, rien de focalisé.
    await closeIngredientSheet(tester);
    expect(
      [
        for (final row in tester.widgetList<IngredientRow>(
          find.byType(IngredientRow),
        ))
          row.ingredient.name,
      ],
      [
        'Haricots rouges',
        'Oignons',
        'Viande hachée',
        'Tomates concassées',
        "Piment d'Espelette",
      ],
    );
    expect(_noQuantityFocused(tester), isTrue);

    // La quantité se règle par le tag de la ligne et le Module quantité,
    // dans l'unité de l'article.
    for (final (name, quantity) in [
      ('Haricots rouges', '500'),
      ('Oignons', '2'),
      ('Viande hachée', '400'),
    ]) {
      await _setQuantity(tester, name, quantity);
    }
    expect(await recipeNamed(db, 'Chili'), isNull);
    expect(await db.select(db.recipes).get(), hasLength(recipesBefore));
    // Actif, argile.
    expect(saveEnabled(tester), isTrue);
    expect(
      tester
          .widget<Material>(
            find
                .descendant(of: saveButton, matching: find.byType(Material))
                .first,
          )
          .color,
      scheme.primary,
    );

    // Un tap : tout est écrit, la fiche se ferme sur Recettes.
    await saveFiche(tester);

    final chili = (await recipeNamed(db, 'Chili'))!;
    final haricots = await _article(db, 'Haricots rouges');
    final piment = await _article(db, "Piment d'Espelette");
    expect(
      (piment.rayon, piment.unit, piment.inCatalogue),
      ('divers', null, true),
    );
    expect(
      [
        for (final i in await _ingredients(db, chili.id))
          (i.articleId, i.position, i.quantity, i.unit),
      ],
      [
        (haricots.id, 0, 500, 'g'),
        (SeedIds.oignons, 1, 2000, 'piece'),
        (SeedIds.viandeHachee, 2, 400, 'g'),
        ((await _article(db, 'Tomates concassées')).id, 3, null, null),
        (piment.id, 4, null, null),
      ],
    );

    // ★ La carte « Chili » avec le picto des haricots rouges.
    expect(recipeCard('Chili'), findsOneWidget);
    final card = tester.widget<RecipeRow>(recipeCard('Chili'));
    expect(card.card.pictoKey, haricots.pictoKey);
    expect(card.card.rayon, Rayon.epicerieSalee);
    expect(card.card.selected, isFalse);
  });

  testWidgets('nouvelle fiche avec un nom sans ingrédient, ou des '
      'ingrédients sans nom : « Enregistrer » grisé ; quittée, aucune '
      'recette', (tester) async {
    final db = await _openRecettes(tester);
    final before = await db.select(db.recipes).get();

    await tester.tap(_fab);
    await tester.pumpAndSettle();
    await tester.enterText(ficheNameField, 'Chili');
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
    // Grisé, un tap n'écrit rien.
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    await quitFiche(tester);

    await tester.tap(_fab);
    await tester.pumpAndSettle();
    // Le brouillon est mort avec l'écran.
    expect(_textField(tester, ficheNameField).controller!.text, isEmpty);
    await _addIngredient(tester, 'riz', 'Riz', '300');
    await _addIngredient(tester, 'lard', 'Lardons');
    expect(saveEnabled(tester), isFalse);
    await tester.enterText(ficheNameField, '   ');
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
    await tester.enterText(ficheNameField, 'Riz au lard');
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);
    await quitFiche(tester);

    expect(await db.select(db.recipes).get(), before);
    expect(find.byType(RecipeRow), findsNWidgets(4));
  });

  testWidgets('recette existante : nom effacé, ou tous ses ingrédients '
      'retirés : « Enregistrer » grisé ; quittée, elle reste telle '
      'quelle', (tester) async {
    final db = await _openRecettes(tester);
    final recipes = await db.select(db.recipes).get();
    final ingredients = await db.select(db.recipeIngredients).get();
    final picto = tester
        .widget<RecipeRow>(recipeCard('Pâtes carbonara'))
        .card
        .pictoKey;

    await editRecipe(tester, 'Pâtes carbonara');
    expect(
      _textField(tester, ficheNameField).controller!.text,
      'Pâtes carbonara',
    );
    expect(find.byType(IngredientRow), findsNWidgets(5));
    // Ouverte sans focus : pas de clavier ; valide, « Enregistrer » actif.
    expect(_focused(tester, ficheNameField), isFalse);
    expect(saveEnabled(tester), isTrue);

    await tester.enterText(ficheNameField, '');
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
    await quitFiche(tester);
    expect(await db.select(db.recipes).get(), recipes);
    expect(recipeCard('Pâtes carbonara'), findsOneWidget);

    await editRecipe(tester, 'Pâtes carbonara');
    for (final name in ['Pâtes', 'Lardons', 'Œufs', 'Parmesan', 'Poivre']) {
      await _removeRow(tester, name);
      expect(saveEnabled(tester), name != 'Poivre');
    }
    expect(find.byType(IngredientRow), findsNothing);
    await quitFiche(tester);
    expect(await db.select(db.recipeIngredients).get(), ingredients);
    expect(
      tester.widget<RecipeRow>(recipeCard('Pâtes carbonara')).card.pictoKey,
      picto,
    );
  });

  testWidgets('rien avant « Enregistrer » : frappes, ajouts, quantités, '
      'retrait, lien, puis Quitter : aucune ligne écrite, l’article créé '
      'reste au catalogue', (tester) async {
    final db = await _openRecettes(tester);
    final recipes = await db.select(db.recipes).get();
    final ingredients = await db.select(db.recipeIngredients).get();

    await tester.tap(_fab);
    await tester.pumpAndSettle();
    await tester.enterText(ficheNameField, 'Chili');
    await tester.pumpAndSettle();
    await _addIngredient(tester, 'hari', 'Haricots rouges', '500');
    await _addIngredient(tester, 'oign', 'Oignons', '2');
    await openIngredientSheet(tester);
    await _search(tester, 'Piment');
    await tester.tap(find.text(StringsFr.ajouterNom('Piment')));
    await tester.pumpAndSettle();
    await closeIngredientSheet(tester);
    await _removeRow(tester, 'Oignons');
    final link = find
        .descendant(
          of: find.byType(FicheRecetteScreen),
          matching: find.byType(TextField),
        )
        .last;
    await tester.ensureVisible(link);
    await tester.enterText(link, 'marmiton.org');
    await tester.pumpAndSettle();
    expect(await db.select(db.recipes).get(), recipes);
    expect(await db.select(db.recipeIngredients).get(), ingredients);

    await quitFiche(tester);
    expect(await db.select(db.recipes).get(), recipes);
    expect(await db.select(db.recipeIngredients).get(), ingredients);
    expect(recipeCard('Chili'), findsNothing);
    // « Piment », créé par la popup, reste au catalogue.
    final piment = await _article(db, 'Piment');
    expect(piment.inCatalogue, isTrue);

    // Quantité changée sur une recette existante, Quitter : rien.
    await editRecipe(tester, 'Chili con carne');
    await _setQuantity(tester, 'Riz', '400');
    await quitFiche(tester);
    expect(await db.select(db.recipeIngredients).get(), ingredients);
  });

  testWidgets('retour sur une fiche modifiée : « Quitter sans enregistrer ? » ;'
      ' Garder, tap dehors et retour Android laissent la fiche et son '
      'brouillon ; non modifiée, ou modifiée puis rétablie, pas de '
      'dialogue', (tester) async {
    final db = await _openRecettes(tester);
    final ingredients = await db.select(db.recipeIngredients).get();

    // Ouverte puis retour : pas de dialogue.
    await editRecipe(tester, 'Chili con carne');
    await backFromFiche(tester);
    // Quantité changée puis rétablie : pas de dialogue.
    await editRecipe(tester, 'Chili con carne');
    await _setQuantity(tester, 'Riz', '400');
    await _setQuantity(tester, 'Riz', '300');
    await backFromFiche(tester);

    await editRecipe(tester, 'Chili con carne');
    await _setQuantity(tester, 'Riz', '400');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(quitDialog, findsOneWidget);
    expect(find.text(StringsFr.quitterSansEnregistrerTitre), findsOneWidget);
    expect(
      StringsFr.quitterSansEnregistrerTitre,
      'Quitter sans enregistrer$_nbsp?',
    );
    expect(find.text(StringsFr.quitterSansEnregistrerTexte), findsOneWidget);
    expect(
      StringsFr.quitterSansEnregistrerTexte,
      'Tes modifications seront perdues.',
    );
    final garder = find.widgetWithText(TextButton, StringsFr.garder);
    final quitter = find.widgetWithText(TextButton, StringsFr.quitter);
    final scheme = Theme.of(tester.element(garder)).colorScheme;
    expect(
      tester.widget<TextButton>(garder).style!.foregroundColor!.resolve({}),
      scheme.onSurface,
    );
    expect(
      tester.widget<TextButton>(quitter).style!.foregroundColor!.resolve({}),
      scheme.error,
    );
    for (final button in [garder, quitter]) {
      expect(
        tester.getSize(button).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );
    }

    // Garder : la fiche, son brouillon.
    await tester.tap(garder);
    await tester.pumpAndSettle();
    expect(quitDialog, findsNothing);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(_value(tester, 'Riz'), (quantity: 400, unit: Unit.g));

    // Retour Android : le dialogue ; un tap dehors vaut Garder.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(quitDialog, findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(quitDialog, findsNothing);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);

    // Le retour dans le dialogue vaut Garder.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(quitDialog, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(quitDialog, findsNothing);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(_value(tester, 'Riz'), (quantity: 400, unit: Unit.g));

    // Quitter, par le retour Android : fermée, rien d'écrit.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(quitter);
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsNothing);
    expect(await db.select(db.recipeIngredients).get(), ingredients);
  });

  testWidgets('retirer un ingrédient : supprimé logiquement, la carte prend '
      'le picto du suivant', (tester) async {
    final db = await _openRecettes(tester);
    await editRecipe(tester, 'Pâtes carbonara');
    await _removeRow(tester, 'Pâtes');
    await saveFiche(tester);

    final rows = await (db.select(
      db.recipeIngredients,
    )..where((i) => i.recipeId.equals(SeedRecipeIds.carbonara))).get();
    final pates = rows.singleWhere((i) => i.articleId == SeedIds.pates);
    expect(pates.deletedAt, isNotNull);
    expect(
      tester.widget<RecipeRow>(recipeCard('Pâtes carbonara')).card.pictoKey,
      'lardons',
    );
  });

  testWidgets('article déjà ingrédient : coche dans les résultats, un tap ne '
      'l’ajoute pas de nouveau', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    await openIngredientSheet(tester);
    await _search(tester, 'riz');

    expect(tester.widget<IngredientResultRow>(_result('Riz')).inRecipe, isTrue);
    expect(
      find.descendant(
        of: _result('Riz'),
        matching: find.text(StringsFr.dejaDansLaRecette),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Riz, ${StringsFr.rayonEpicerieSalee}, ${StringsFr.dansLaRecette}',
      ),
      findsOneWidget,
    );
    await tester.tap(_result('Riz'));
    await tester.pumpAndSettle();
    expect(find.byType(IngredientRow), findsNWidgets(5));
    expect(_sheetText(tester), 'riz');
    // Entrée sur son nom exact : rien non plus.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(IngredientRow), findsNWidgets(5));
    await closeIngredientSheet(tester);
    await backFromFiche(tester);
    expect(await _ingredients(db, SeedRecipeIds.chili), hasLength(5));
    handle.dispose();
  });

  testWidgets('kg : Module quantité, segment kg, 1,5 kg stocké 1500 g ; 0 '
      'efface', (tester) async {
    final db = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    await _setQuantity(tester, 'Riz', '1,5', unit: 'kg');
    await saveFiche(tester);

    final riz = (await _ingredients(
      db,
      SeedRecipeIds.chili,
    )).singleWhere((i) => i.articleId == SeedIds.riz);
    expect((riz.quantity, riz.unit), (1500, 'g'));

    // Vide = sans quantité.
    await editRecipe(tester, 'Chili con carne');
    expect(_value(tester, 'Riz'), (quantity: 1500, unit: Unit.g));
    await _setQuantity(tester, 'Riz', '');
    await saveFiche(tester);
    final empty = (await _ingredients(
      db,
      SeedRecipeIds.chili,
    )).singleWhere((i) => i.articleId == SeedIds.riz);
    expect((empty.quantity, empty.unit), (null, null));
  });

  testWidgets('Chili validé : sa fiche par l’icône « modifier », quantité '
      'changée : Liste inchangée, carte toujours sélectionnée (R7)', (
    tester,
  ) async {
    final db = await _openRecettes(tester);
    await tapRecipeCard(tester, 'Chili con carne');
    await openRevue(tester, 1);
    await tester.tap(revueAddButton);
    await tester.pumpAndSettle();
    await openTab(tester, StringsFr.tabRecettes);
    final lines = await db.select(db.listLines).get();
    final contributions = await db.select(db.listContributions).get();
    final selections = await db.select(db.weekSelections).get();

    await editRecipe(tester, 'Chili con carne');
    await _setQuantity(tester, 'Riz', '400');
    await saveFiche(tester);

    expect(
      (await _ingredients(
        db,
        SeedRecipeIds.chili,
      )).singleWhere((i) => i.articleId == SeedIds.riz).quantity,
      400,
    );
    expect(await db.select(db.listLines).get(), lines);
    expect(await db.select(db.listContributions).get(), contributions);
    expect(await db.select(db.weekSelections).get(), selections);
    expect(
      tester.widget<RecipeRow>(recipeCard('Chili con carne')).card.selected,
      isTrue,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('nom porté par un article hors catalogue : le même article '
      'entre au catalogue et devient ingrédient', (tester) async {
    final db = await _openRecettes(tester);
    final pilou = await db.transaction(
      () => CatalogueRepository(db, Clock()).resolveTypedArticle('Pilou'),
    );
    await editRecipe(tester, 'Chili con carne');
    await openIngredientSheet(tester);
    await _search(tester, 'pilou');
    expect(find.byType(IngredientResultRow), findsNothing);
    await tester.tap(find.text(StringsFr.ajouterNom('pilou')));
    await tester.pumpAndSettle();
    expect(_row('Pilou'), findsOneWidget);
    await closeIngredientSheet(tester);
    await saveFiche(tester);

    final row = await (db.select(
      db.articles,
    )..where((a) => a.normalizedName.equals('pilou'))).get();
    expect(row, hasLength(1));
    expect((row.single.id, row.single.inCatalogue), (pilou.id, true));
    final ingredients = await _ingredients(db, SeedRecipeIds.chili);
    expect(ingredients.last.articleId, pilou.id);
  });

  testWidgets('échec de « Créer « … » » ou d’Entrée : snackbar d’erreur dans '
      'la popup, saisie gardée, rien d’écrit', (tester) async {
    final db = await _openRecettes(
      tester,
      overrides: [
        creerArticleProvider.overrideWithValue(
          (_) async => throw StateError('échec simulé'),
        ),
      ],
    );
    final articles = await db.select(db.articles).get();
    final ingredients = await db.select(db.recipeIngredients).get();
    await editRecipe(tester, 'Chili con carne');
    await openIngredientSheet(tester);
    await _search(tester, 'Piment');
    await tester.tap(find.text(StringsFr.ajouterNom('Piment')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _sheet,
        matching: find.text(StringsFr.ajoutImpossible),
      ),
      findsOneWidget,
    );
    expect(_sheetText(tester), 'Piment');
    expect(find.byType(IngredientRow), findsNWidgets(5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _sheet,
        matching: find.text(StringsFr.ajoutImpossible),
      ),
      findsOneWidget,
    );
    expect(find.byType(IngredientRow), findsNWidgets(5));
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(await db.select(db.articles).get(), articles);
    expect(await db.select(db.recipeIngredients).get(), ingredients);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Entrée : nom exact = l’article du catalogue ; nom inconnu = '
      'article créé au catalogue ; texte vide = rien', (tester) async {
    final db = await _openRecettes(tester);
    final articlesBefore = (await db.select(db.articles).get()).length;
    await tester.tap(_fab);
    await tester.pumpAndSettle();
    await tester.enterText(ficheNameField, 'Salade');
    await tester.pumpAndSettle();
    await openIngredientSheet(tester);

    // Texte vide : rien.
    await _submit(tester, '   ');
    expect(find.byType(IngredientRow), findsNothing);

    await _submit(tester, 'tomates');
    expect(_row('Tomates'), findsOneWidget);
    expect(_sheetText(tester), isEmpty);
    expect(_focused(tester, _sheetField), isTrue);
    expect(_noQuantityFocused(tester), isTrue);
    expect((await db.select(db.articles).get()).length, articlesBefore);

    await _submit(tester, "Piment d'Espelette");
    expect(_row("Piment d'Espelette"), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(_sheetText(tester), isEmpty);
    expect(_noQuantityFocused(tester), isTrue);
    final piment = await _article(db, "Piment d'Espelette");
    expect(
      (piment.rayon, piment.unit, piment.inCatalogue),
      ('divers', null, true),
    );

    await closeIngredientSheet(tester);
    await saveFiche(tester);
    final salade = (await recipeNamed(db, 'Salade'))!;
    expect(
      [for (final i in await _ingredients(db, salade.id)) i.articleId],
      [(await _article(db, 'Tomates')).id, piment.id],
    );
  });

  testWidgets('la popup se ferme par glissement, tap hors du panneau ou '
      'retour ; les ajouts restent dans la fiche', (tester) async {
    await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');

    await openIngredientSheet(tester);
    await _search(tester, 'lait');
    await tester.tap(_result('Lait'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SheetHandle), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(_row('Lait'), findsOneWidget);

    await openIngredientSheet(tester);
    await _search(tester, 'lard');
    await tester.tap(_result('Lardons'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(_row('Lardons'), findsOneWidget);

    await openIngredientSheet(tester);
    await _search(tester, 'pâtes');
    await tester.tap(_result('Pâtes'));
    await tester.pumpAndSettle();
    await closeIngredientSheet(tester);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(_row('Pâtes'), findsOneWidget);
    expect(find.byType(IngredientRow), findsNWidgets(8));
    expect(_noQuantityFocused(tester), isTrue);
  });

  testWidgets('échec d’« Enregistrer » : snackbar d’erreur, la fiche reste '
      'ouverte avec son brouillon, rien d’écrit ; réessai réussi', (
    tester,
  ) async {
    final db = await _openRecettes(tester);
    final recipes = await db.select(db.recipes).get();
    final before = await db.select(db.recipeIngredients).get();
    await db.customStatement(
      'CREATE TRIGGER no_save BEFORE UPDATE ON recipe_ingredients '
      "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
    );
    await editRecipe(tester, 'Chili con carne');
    await tester.enterText(ficheNameField, 'Chili maison');
    await tester.pumpAndSettle();
    await _setQuantity(tester, 'Riz', '400');
    // Rien écrit par la saisie : pas d'échec avant « Enregistrer ».
    expect(find.text(StringsFr.enregistrementImpossible), findsNothing);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.enregistrementImpossible), findsOneWidget);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(_value(tester, 'Riz'), (quantity: 400, unit: Unit.g));
    expect(saveEnabled(tester), isTrue);
    // Une transaction : le nom n'est pas écrit non plus.
    expect(await db.select(db.recipes).get(), recipes);
    expect(await db.select(db.recipeIngredients).get(), before);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await db.customStatement('DROP TRIGGER no_save');
    await saveFiche(tester);
    expect(recipeCard('Chili maison'), findsOneWidget);
    expect(
      (await _ingredients(
        db,
        SeedRecipeIds.chili,
      )).singleWhere((i) => i.articleId == SeedIds.riz).quantity,
      400,
    );
  });

  testWidgets('clavier ouvert : « Enregistrer » juste au-dessus du clavier, '
      'pleine largeur', (tester) async {
    const height = 700.0;
    const keyboard = 300.0;
    await _openRecettes(tester, size: const Size(400, height));
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await editRecipe(tester, 'Chili con carne');
    final rect = tester.getRect(saveButton);
    expect(rect.bottom, lessThanOrEqualTo(height - keyboard));
    expect(
      rect.bottom,
      greaterThanOrEqualTo(height - keyboard - KadiSpacing.margin),
    );
    expect(rect.width, 400 - 2 * KadiSpacing.margin);
    expect(saveButton.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TalkBack : FAB, icône « modifier », nom, bouton « Ajouter un '
      'ingrédient », champ de la popup, résultats, « Créer », ajout annoncé, '
      'ingrédients, quantités, unité et « Retirer » sont lus', (tester) async {
    final handle = tester.ensureSemantics();
    final announcements = _recordAnnouncements(tester);
    await _openRecettes(tester);

    expect(find.byTooltip(StringsFr.nouvelleRecette), findsOneWidget);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          RegExp(
            '^${RegExp.escape(StringsFr.modifierRecette('Chili con carne'))}, ',
          ),
        ),
      ),
      isSemantics(
        label:
            '${StringsFr.modifierRecette('Chili con carne')}, '
            '${StringsFr.nIngredients(5)}',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // La carte garde sa lecture et son tap.
    expect(
      find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Chili con carne')),
      findsOneWidget,
    );

    await editRecipe(tester, 'Chili con carne');
    expect(
      find.bySemanticsLabel(RegExp(StringsFr.nomDeLaRecette)),
      findsWidgets,
    );
    expect(
      tester.getSemantics(addIngredientButton),
      isSemantics(
        label: StringsFr.ajouterUnIngredient,
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.bySemanticsLabel('Quantité de Riz, 300${_nbsp}g'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          StringsFr.rayonDe('Riz', Rayon.epicerieSalee.spokenLabel),
        ),
      ),
      isSemantics(
        label: StringsFr.rayonDe('Riz', Rayon.epicerieSalee.spokenLabel),
        isButton: true,
        hasTapAction: true,
      ),
    );

    // Ouverture par TalkBack.
    tester.semantics.tap(find.semantics.byLabel(StringsFr.ajouterUnIngredient));
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(
      tester.getSemantics(_sheetField),
      isSemantics(label: StringsFr.ajouterUnIngredient, isTextField: true),
    );

    await _search(tester, 'hari');
    expect(
      find.bySemanticsLabel('Haricots rouges, ${StringsFr.rayonEpicerieSalee}'),
      findsOneWidget,
    );
    // Ajout par TalkBack, annoncé : la fiche est inaccessible sous la popup.
    tester.semantics.tap(
      find.semantics.byLabel(
        'Haricots rouges, ${StringsFr.rayonEpicerieSalee}',
      ),
    );
    await tester.pumpAndSettle();
    expect(announcements, [StringsFr.ingredientAjoute('Haricots rouges')]);
    expect(announcements.single, 'Haricots rouges ajouté');

    await _search(tester, 'riz');
    expect(
      find.bySemanticsLabel(
        'Riz, ${StringsFr.rayonEpicerieSalee}, ${StringsFr.dansLaRecette}',
      ),
      findsOneWidget,
    );

    await _search(tester, 'Piment');
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(StringsFr.ajouterNom('Piment')),
      ),
      isSemantics(
        label: StringsFr.ajouterNom('Piment'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(
      find.semantics.byLabel(StringsFr.ajouterNom('Piment')),
    );
    await tester.pumpAndSettle();
    expect(announcements.last, StringsFr.ingredientAjoute('Piment'));

    await closeIngredientSheet(tester);
    expect(
      find.bySemanticsLabel(StringsFr.ajouterUneQuantiteA('Haricots rouges')),
      findsOneWidget,
    );
    await _setQuantity(tester, 'Haricots rouges', '500');
    expect(
      find.bySemanticsLabel('Quantité de Haricots rouges, 500${_nbsp}g'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('TalkBack : « Enregistrer » lu avec son état, désactivé puis '
      'actif ; le dialogue de sortie est lu, ses actions agissent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openRecettes(tester);
    await tester.tap(_fab);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(saveButton),
      isSemantics(
        label: StringsFr.enregistrer,
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );

    await tester.enterText(ficheNameField, 'Omelette');
    await tester.pumpAndSettle();
    await _addIngredient(tester, 'œufs', 'Œufs');
    expect(
      tester.getSemantics(saveButton),
      isSemantics(
        label: StringsFr.enregistrer,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(StringsFr.quitterSansEnregistrerTitre),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(StringsFr.quitterSansEnregistrerTexte),
      findsOneWidget,
    );
    for (final label in [StringsFr.garder, StringsFr.quitter]) {
      expect(
        tester.getSemantics(find.widgetWithText(TextButton, label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    tester.semantics.tap(find.semantics.byLabel(StringsFr.garder));
    await tester.pumpAndSettle();
    expect(quitDialog, findsNothing);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);

    tester.semantics.tap(find.semantics.byLabel(StringsFr.enregistrer));
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsNothing);
    expect(recipeCard('Omelette'), findsOneWidget);
    handle.dispose();
  });

  for (final scale in [1.3, 2.0, 3.0]) {
    testWidgets('police ×$scale sur 360 dp : fiche, bouton, popup, résultats '
        'et Choix d’unité sans débordement ni troncature', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openRecettes(tester, size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      expect(_fab.hitTestable(), findsOneWidget);

      await editRecipe(tester, 'Chili con carne');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        _row('Tomates concassées'),
        100,
        scrollable: _ficheScrollable,
      );
      await tester.pumpAndSettle();
      final name = tester.widget<Text>(
        find.descendant(
          of: _row('Tomates concassées'),
          matching: find.text('Tomates concassées'),
        ),
      );
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);
      expect(
        tester.getSize(_quantity('Tomates concassées')).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );
      // Le Module quantité, en grande police.
      await tester.tap(_quantity('Tomates concassées'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(StringsFr.ok));
      await tester.pumpAndSettle();
      await _setQuantity(tester, 'Tomates concassées', '999999');
      expect(tester.takeException(), isNull);

      final label = tester.widget<Text>(addIngredientButton);
      expect(label.maxLines, isNull);
      expect(label.overflow, isNull);

      await openIngredientSheet(tester);
      expect(tester.takeException(), isNull);
      await _search(tester, 'haricots');
      expect(tester.takeException(), isNull);
      expect(_result('Haricots rouges'), findsOneWidget);
      // En grande police, les résultats défilent sous le champ.
      await tester.ensureVisible(_result('Haricots rouges'));
      await tester.pumpAndSettle();
      await tester.tap(_result('Haricots rouges'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_row('Haricots rouges'), findsOneWidget);
      await _search(tester, 'Piment d’Espelette fumé du Pays basque');
      expect(tester.takeException(), isNull);
      expect(find.byType(CreateArticleRow), findsOneWidget);
      await closeIngredientSheet(tester);

      // « Enregistrer » entier, et le dialogue de sortie.
      final save = tester.widget<Text>(
        find.descendant(
          of: saveButton,
          matching: find.text(StringsFr.enregistrer),
        ),
      );
      expect(save.maxLines, isNull);
      expect(save.overflow, isNull);
      expect(saveButton.hitTestable(), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(quitDialog, findsOneWidget);
      for (final text in [
        StringsFr.quitterSansEnregistrerTitre,
        StringsFr.quitterSansEnregistrerTexte,
        StringsFr.garder,
        StringsFr.quitter,
      ]) {
        final widget = tester.widget<Text>(find.text(text));
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
        // Au-delà de ×2, le titre et le texte défilent ; les actions
        // restent à portée.
        if (scale <= 2 ||
            text == StringsFr.garder ||
            text == StringsFr.quitter) {
          expect(find.text(text).hitTestable(), findsOneWidget);
        }
      }
    });
  }
}
