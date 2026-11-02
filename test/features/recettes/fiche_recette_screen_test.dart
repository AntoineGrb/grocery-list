import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/quantity_input.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/recipe_card.dart';
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

Finder get _fab => find.byType(FloatingActionButton);

/// Champ de recherche de la fiche.
Finder get _searchField => find.ancestor(
  of: find.text(StringsFr.ajouterUnIngredient),
  matching: find.byType(TextField),
);

TextField _textField(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder);

bool _focused(WidgetTester tester, Finder field) =>
    _textField(tester, field).focusNode!.hasFocus;

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(_searchField, text);
  await tester.pumpAndSettle();
}

Finder _result(String name) => find.byWidgetPredicate(
  (w) => w is IngredientResultRow && w.article.name == name,
);

Finder _row(String name) => find.byWidgetPredicate(
  (w) => w is IngredientRow && w.ingredient.name == name,
);

/// Champ quantité de la Ligne d'ingrédient de [name].
Finder _quantity(String name) =>
    find.descendant(of: _row(name), matching: find.byType(TextField));

/// Liste défilante de la fiche (les champs ont aussi les leurs).
Finder get _ficheScrollable => find
    .descendant(
      of: find.byType(FicheRecetteScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Suffixe tappable [unit] d'un Champ quantité (unité et flèche de choix).
Finder _unitText(String unit) =>
    find.textContaining(RegExp('^$unit￼\$'), findRichText: true);

/// Cherche [query], touche le résultat [name] et saisit [quantity].
Future<void> _addIngredient(
  WidgetTester tester,
  String query,
  String name, [
  String? quantity,
]) async {
  await _search(tester, query);
  await tester.tap(_result(name));
  await tester.pumpAndSettle();
  if (quantity != null) {
    await tester.enterText(_quantity(name), quantity);
    await tester.pumpAndSettle();
  }
}

Future<List<RecipeIngredient>> _ingredients(AppDatabase db, String recipeId) =>
    (db.select(db.recipeIngredients)
          ..where((i) => i.recipeId.equals(recipeId) & i.deletedAt.isNull())
          ..orderBy([(i) => OrderingTerm.asc(i.position)]))
        .get();

Future<Article> _article(AppDatabase db, String name) =>
    (db.select(db.articles)..where((a) => a.name.equals(name))).getSingle();

void main() {
  testWidgets('Flux 4 : FAB +, « Chili », « hari » → Haricots rouges 500, '
      'quatre autres dont un créé, retour : la carte « Chili » avec le picto '
      'des haricots', (tester) async {
    final db = await _openRecettes(tester);
    final recipesBefore = (await db.select(db.recipes).get()).length;

    await tester.tap(_fab);
    await tester.pumpAndSettle();

    // Plein écran, sans Barre de navigation, flèche retour ; nom focalisé.
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text(StringsFr.nouvelleRecette), findsOneWidget);
    expect(_focused(tester, ficheNameField), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(ficheNameField, 'Chili');
    await tester.pumpAndSettle();
    // Un nom sans ingrédient : rien d'écrit.
    expect(await db.select(db.recipes).get(), hasLength(recipesBefore));

    await _search(tester, 'hari');
    expect(_result('Haricots rouges'), findsOneWidget);
    expect(_result('Haricots verts'), findsOneWidget);
    await tester.tap(_result('Haricots rouges'));
    await tester.pumpAndSettle();

    // La recherche se vide, le Champ quantité du nouvel ingrédient a le
    // focus, dans l'unité de l'article.
    expect(_textField(tester, _searchField).controller!.text, isEmpty);
    expect(find.byType(IngredientResultRow), findsNothing);
    expect(_row('Haricots rouges'), findsOneWidget);
    expect(_focused(tester, _quantity('Haricots rouges')), isTrue);
    expect(
      find.descendant(
        of: _row('Haricots rouges'),
        matching: _unitText(StringsFr.champUniteG),
      ),
      findsOneWidget,
    );
    // Enregistrée dès le nom et le premier ingrédient.
    expect(await recipeNamed(db, 'Chili'), isNotNull);

    await tester.enterText(_quantity('Haricots rouges'), '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Entrée rend le focus à la recherche.
    expect(_focused(tester, _searchField), isTrue);

    await _addIngredient(tester, 'oign', 'Oignons', '2');
    await _addIngredient(tester, 'viande h', 'Viande hachée', '400');
    await _addIngredient(tester, 'tomates conc', 'Tomates concassées');

    // Un ingrédient inconnu : « Créer « … » », sans quitter la fiche.
    await _search(tester, "piment d'Espelette");
    expect(find.byType(IngredientResultRow), findsNothing);
    expect(
      StringsFr.creerNom("piment d'Espelette"),
      "Créer «${_nbsp}piment d'Espelette$_nbsp»",
    );
    final create = find.text(StringsFr.creerNom("piment d'Espelette"));
    expect(create, findsOneWidget);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(_row("Piment d'Espelette"), findsOneWidget);
    expect(_focused(tester, _quantity("Piment d'Espelette")), isTrue);

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

    await backFromFiche(tester);

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
    final card = tester.widget<RecipeCard>(recipeCard('Chili'));
    expect(card.card.pictoKey, haricots.pictoKey);
    expect(card.card.rayon, Rayon.epicerieSalee);
    expect(card.card.selected, isFalse);
  });

  testWidgets('nouvelle fiche avec un nom sans ingrédient, ou des '
      'ingrédients sans nom : aucune recette', (tester) async {
    final db = await _openRecettes(tester);
    final before = await db.select(db.recipes).get();

    await tester.tap(_fab);
    await tester.pumpAndSettle();
    await tester.enterText(ficheNameField, 'Chili');
    await tester.pumpAndSettle();
    await backFromFiche(tester);

    await tester.tap(_fab);
    await tester.pumpAndSettle();
    // Le brouillon est mort avec l'écran.
    expect(_textField(tester, ficheNameField).controller!.text, isEmpty);
    await _addIngredient(tester, 'riz', 'Riz', '300');
    await _addIngredient(tester, 'lard', 'Lardons');
    await tester.enterText(ficheNameField, '   ');
    await tester.pumpAndSettle();
    await backFromFiche(tester);

    expect(await db.select(db.recipes).get(), before);
    expect(find.byType(RecipeCard), findsNWidgets(4));
  });

  testWidgets('recette existante : nom effacé, puis tous ses ingrédients '
      'retirés : sa dernière version valide reste', (tester) async {
    final db = await _openRecettes(tester);
    final recipes = await db.select(db.recipes).get();
    final ingredients = await _ingredients(db, SeedRecipeIds.carbonara);

    await editRecipe(tester, 'Pâtes carbonara');
    expect(find.text(StringsFr.recette), findsOneWidget);
    expect(
      _textField(tester, ficheNameField).controller!.text,
      'Pâtes carbonara',
    );
    expect(find.byType(IngredientRow), findsNWidgets(5));
    // Ouverte sans focus : pas de clavier.
    expect(_focused(tester, ficheNameField), isFalse);

    await tester.enterText(ficheNameField, '');
    await tester.pumpAndSettle();
    await backFromFiche(tester);
    expect(await db.select(db.recipes).get(), recipes);
    expect(recipeCard('Pâtes carbonara'), findsOneWidget);

    await editRecipe(tester, 'Pâtes carbonara');
    for (final name in ['Pâtes', 'Lardons', 'Œufs', 'Parmesan', 'Poivre']) {
      await tester.tap(find.byTooltip(StringsFr.retirerIngredient(name)));
      await tester.pumpAndSettle();
    }
    expect(find.byType(IngredientRow), findsNothing);
    await backFromFiche(tester);
    // Le dernier retrait n'est pas écrit : Poivre reste, seul.
    final kept = await _ingredients(db, SeedRecipeIds.carbonara);
    expect(kept.map((i) => i.id), [ingredients.last.id]);
    expect(
      tester.widget<RecipeCard>(recipeCard('Pâtes carbonara')).card.pictoKey,
      'poivre',
    );
  });

  testWidgets('retirer un ingrédient : supprimé logiquement, la carte prend '
      'le picto du suivant', (tester) async {
    final db = await _openRecettes(tester);
    await editRecipe(tester, 'Pâtes carbonara');
    await tester.tap(find.byTooltip(StringsFr.retirerIngredient('Pâtes')));
    await tester.pumpAndSettle();
    await backFromFiche(tester);

    final rows = await (db.select(
      db.recipeIngredients,
    )..where((i) => i.recipeId.equals(SeedRecipeIds.carbonara))).get();
    final pates = rows.singleWhere((i) => i.articleId == SeedIds.pates);
    expect(pates.deletedAt, isNotNull);
    expect(
      tester.widget<RecipeCard>(recipeCard('Pâtes carbonara')).card.pictoKey,
      'lardons',
    );
  });

  testWidgets('article déjà ingrédient : coche dans les résultats, un tap ne '
      'l’ajoute pas de nouveau', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    await _search(tester, 'riz');

    final indicator = tester.widget<InListIndicator>(
      find.descendant(
        of: _result('Riz'),
        matching: find.byType(InListIndicator),
      ),
    );
    expect(indicator.inList, isTrue);
    expect(
      find.bySemanticsLabel(
        'Riz, ${StringsFr.rayonEpicerieSalee}, ${StringsFr.dansLaRecette}',
      ),
      findsOneWidget,
    );
    await tester.tap(_result('Riz'));
    await tester.pumpAndSettle();
    expect(find.byType(IngredientRow), findsNWidgets(5));
    expect(_textField(tester, _searchField).controller!.text, 'riz');
    await backFromFiche(tester);
    expect(await _ingredients(db, SeedRecipeIds.chili), hasLength(5));
    handle.dispose();
  });

  testWidgets('kg : tap sur l’unité, Choix d’unité sous la ligne, 1,5 kg '
      'stocké 1500 g', (tester) async {
    final db = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');

    final unit = find.descendant(
      of: _row('Riz'),
      matching: _unitText(StringsFr.champUniteG),
    );
    await tester.tap(unit);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _row('Riz'), matching: find.byType(UnitChoice)),
      findsOneWidget,
    );
    final kg = find.descendant(
      of: _row('Riz'),
      matching: find.byKey(const ValueKey(InputUnit.kg)),
    );
    expect(
      tester.getSize(kg).height,
      greaterThanOrEqualTo(KadiSpacing.touchTarget),
    );
    await tester.tap(kg);
    await tester.pumpAndSettle();
    // Choix fermé, champ en kg.
    expect(find.byType(UnitChoice), findsNothing);
    expect(
      find.descendant(
        of: _row('Riz'),
        matching: _unitText(StringsFr.champUniteKg),
      ),
      findsOneWidget,
    );
    await tester.enterText(_quantity('Riz'), '1,5');
    await tester.pumpAndSettle();
    await backFromFiche(tester);

    final riz = (await _ingredients(
      db,
      SeedRecipeIds.chili,
    )).singleWhere((i) => i.articleId == SeedIds.riz);
    expect((riz.quantity, riz.unit), (1500, 'g'));

    // Vide = sans quantité.
    await editRecipe(tester, 'Chili con carne');
    expect(_textField(tester, _quantity('Riz')).controller!.text, '1500');
    await tester.enterText(_quantity('Riz'), '');
    await tester.pumpAndSettle();
    await backFromFiche(tester);
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
    await tester.tap(recipeCard('Chili con carne'));
    await tester.pumpAndSettle();
    await openRevue(tester, 1);
    await tester.tap(
      find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
    );
    await tester.pumpAndSettle();
    await openTab(tester, StringsFr.tabRecettes);
    final lines = await db.select(db.listLines).get();
    final contributions = await db.select(db.listContributions).get();
    final selections = await db.select(db.weekSelections).get();

    await editRecipe(tester, 'Chili con carne');
    await tester.enterText(_quantity('Riz'), '400');
    await tester.pumpAndSettle();
    await backFromFiche(tester);

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
      tester.widget<RecipeCard>(recipeCard('Chili con carne')).card.selected,
      isTrue,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('icône « modifier » : 48 dp, ouvre la fiche sans changer la '
      'sélection ; FAB empilé au-dessus de « Valider »', (tester) async {
    final db = await _openRecettes(tester);
    final edit = find.byTooltip(StringsFr.modifierRecette('Ratatouille'));
    expect(tester.getSize(edit), const Size.square(KadiSpacing.touchTarget));
    await editRecipe(tester, 'Ratatouille');
    await backFromFiche(tester);
    expect(await db.select(db.weekSelections).get(), isEmpty);
    expect(
      tester.widget<RecipeCard>(recipeCard('Ratatouille')).card.selected,
      isFalse,
    );

    // Sélectionnée : l'icône ne désélectionne pas non plus.
    await tester.tap(recipeCard('Ratatouille'));
    await tester.pumpAndSettle();
    await editRecipe(tester, 'Ratatouille');
    await backFromFiche(tester);
    expect(
      tester.widget<RecipeCard>(recipeCard('Ratatouille')).card.selected,
      isTrue,
    );

    final valider = find.widgetWithText(FilledButton, StringsFr.validerN(1));
    expect(
      tester.getRect(_fab).bottom,
      lessThanOrEqualTo(tester.getRect(valider).top),
    );
    final scheme = Theme.of(tester.element(_fab)).colorScheme;
    expect(
      tester
          .widget<Material>(
            find.descendant(of: _fab, matching: find.byType(Material)).first,
          )
          .color,
      scheme.primary,
    );
  });

  testWidgets('nom porté par un article hors catalogue : le même article '
      'entre au catalogue et devient ingrédient', (tester) async {
    final db = await _openRecettes(tester);
    final pilou = await db.transaction(
      () => CatalogueRepository(db, Clock()).resolveTypedArticle('Pilou'),
    );
    await editRecipe(tester, 'Chili con carne');
    await _search(tester, 'pilou');
    expect(find.byType(IngredientResultRow), findsNothing);
    await tester.tap(find.text(StringsFr.creerNom('pilou')));
    await tester.pumpAndSettle();
    expect(_row('Pilou'), findsOneWidget);
    await backFromFiche(tester);

    final row = await (db.select(
      db.articles,
    )..where((a) => a.normalizedName.equals('pilou'))).get();
    expect(row, hasLength(1));
    expect((row.single.id, row.single.inCatalogue), (pilou.id, true));
    final ingredients = await _ingredients(db, SeedRecipeIds.chili);
    expect(ingredients.last.articleId, pilou.id);
  });

  testWidgets('échec de « Créer « … » » : snackbar d’erreur, rien d’écrit', (
    tester,
  ) async {
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
    await _search(tester, 'Piment');
    await tester.tap(find.text(StringsFr.creerNom('Piment')));
    await tester.pumpAndSettle();

    expect(find.text(StringsFr.ajoutImpossible), findsOneWidget);
    expect(find.byType(IngredientRow), findsNWidgets(5));
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(await db.select(db.articles).get(), articles);
    expect(await db.select(db.recipeIngredients).get(), ingredients);
  });

  testWidgets('échec d’enregistrement : snackbar d’erreur, la dernière '
      'version écrite reste', (tester) async {
    final db = await _openRecettes(tester);
    final before = await db.select(db.recipeIngredients).get();
    await db.customStatement(
      'CREATE TRIGGER no_save BEFORE UPDATE ON recipe_ingredients '
      "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
    );
    await editRecipe(tester, 'Chili con carne');
    await tester.enterText(_quantity('Riz'), '400');
    await tester.pumpAndSettle();

    expect(find.text(StringsFr.enregistrementImpossible), findsOneWidget);
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(await db.select(db.recipeIngredients).get(), before);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('clavier ouvert, nombreux ingrédients : le nouveau Champ '
      'quantité prend le focus à l’écran, Entrée rend le focus à la '
      'recherche, à l’écran', (tester) async {
    const height = 700.0;
    const keyboard = 400.0;
    await _openRecettes(tester, size: const Size(400, height));
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await editRecipe(tester, 'Ratatouille');

    /// [finder] tient dans la partie visible, sous la Barre d'application.
    void expectOnScreen(Finder finder) {
      final rect = tester.getRect(finder);
      expect(
        rect.top,
        greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
      );
      expect(rect.bottom, lessThanOrEqualTo(height - keyboard));
    }

    for (final (query, name) in [
      ('riz', 'Riz'),
      ('lard', 'Lardons'),
      ('pâtes', 'Pâtes'),
      ('lait', 'Lait'),
    ]) {
      await tester.scrollUntilVisible(
        _searchField,
        -100,
        scrollable: _ficheScrollable,
      );
      await _search(tester, query);
      await tester.tap(_result(name));
      await tester.pumpAndSettle();

      expect(_focused(tester, _quantity(name)), isTrue);
      expectOnScreen(_quantity(name));

      await tester.enterText(_quantity(name), '2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_focused(tester, _searchField), isTrue);
      expectOnScreen(_searchField);
    }
    expect(find.byType(IngredientRow), findsNWidgets(11));
  });

  testWidgets('TalkBack : FAB, icône « modifier », nom, recherche, '
      'résultats, « Créer », ingrédients, quantités, unité et « Retirer » '
      'sont lus', (tester) async {
    final handle = tester.ensureSemantics();
    await _openRecettes(tester);

    expect(find.bySemanticsLabel(StringsFr.nouvelleRecette), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byTooltip(StringsFr.modifierRecette('Chili con carne')),
      ),
      isSemantics(
        tooltip: StringsFr.modifierRecette('Chili con carne'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    // La carte garde sa lecture et son tap.
    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );

    await editRecipe(tester, 'Chili con carne');
    expect(
      find.bySemanticsLabel(RegExp(StringsFr.nomDeLaRecette)),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(RegExp(StringsFr.ajouterUnIngredient)),
      findsWidgets,
    );
    expect(find.bySemanticsLabel('Riz, 300${_nbsp}g'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Quantité de Riz, 300${_nbsp}g'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byTooltip(StringsFr.retirerIngredient('Riz'))),
      isSemantics(
        tooltip: StringsFr.retirerIngredient('Riz'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.bySemanticsLabel(StringsFr.uniteDe(StringsFr.puceUniteG)),
      findsWidgets,
    );

    await _search(tester, 'hari');
    expect(
      find.bySemanticsLabel('Haricots rouges, ${StringsFr.rayonEpicerieSalee}'),
      findsOneWidget,
    );
    // Ajout par TalkBack.
    tester.semantics.tap(
      find.semantics.byLabel(
        'Haricots rouges, ${StringsFr.rayonEpicerieSalee}',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Haricots rouges'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Quantité de Haricots rouges, aucune'),
      findsOneWidget,
    );
    await tester.enterText(_quantity('Haricots rouges'), '500');
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Haricots rouges, 500${_nbsp}g'),
      findsOneWidget,
    );

    await _search(tester, 'Piment');
    expect(
      tester.getSemantics(find.bySemanticsLabel(StringsFr.creerNom('Piment'))),
      isSemantics(
        label: StringsFr.creerNom('Piment'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  for (final scale in [1.3, 2.0, 3.0]) {
    testWidgets('police ×$scale sur 360 dp : fiche, résultats et Choix '
        'd’unité sans débordement ni troncature', (tester) async {
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
      await tester.enterText(_quantity('Tomates concassées'), '999999');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.descendant(
          of: _row('Tomates concassées'),
          matching: _unitText(StringsFr.champUniteG),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(UnitChoice), findsOneWidget);

      await tester.scrollUntilVisible(
        _searchField,
        -100,
        scrollable: _ficheScrollable,
      );
      await _search(tester, 'haricots');
      expect(tester.takeException(), isNull);
      expect(_result('Haricots rouges'), findsOneWidget);
      await _search(tester, 'Piment d’Espelette fumé du Pays basque');
      expect(tester.takeException(), isNull);
      expect(find.byType(CreateArticleRow), findsOneWidget);
    });
  }
}
