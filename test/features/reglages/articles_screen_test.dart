import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_rows.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/reglages/ui/article_lines.dart';
import 'package:kadi/features/reglages/ui/article_sheet.dart';
import 'package:kadi/features/reglages/ui/articles_screen.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/recettes.dart';
import '../../helpers/test_db.dart';

/// Catalogue dont toute écriture de la Fiche article échoue.
class _FailingCatalogue extends CatalogueRepository {
  _FailingCatalogue(super.db, super.clock);

  @override
  Future<CatalogueArticle> updateArticle(
    String articleId, {
    required String name,
    required Rayon rayon,
    required Unit? unit,
  }) async => throw StateError('échec simulé');

  @override
  Future<CatalogueArticle> createCatalogueArticle(
    String name, {
    required Rayon rayon,
    required Unit? unit,
  }) async => throw StateError('échec simulé');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Liste défilante des Paramètres.
Finder get _parametresScrollable => find
    .descendant(
      of: find.byType(ParametresScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Ouvre Paramètres par ⚙, puis Articles par sa ligne (amenée à l'écran :
/// les Paramètres sont une liste paresseuse).
Future<void> _openArticles(WidgetTester tester) async {
  await _tap(tester, find.byType(SettingsAction));
  await tester.scrollUntilVisible(
    find.text(StringsFr.articlesTitre),
    100,
    scrollable: _parametresScrollable,
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.text(StringsFr.articlesTitre));
  expect(find.byType(ArticlesScreen), findsOneWidget);
}

/// Monte Kadi sur un téléphone haut (toute la Fiche article est bâtie) et
/// ouvre Paramètres › Articles.
Future<AppDatabase> _pumpArticles(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Future<void> Function(AppDatabase db)? before,
}) async {
  tallPhone(tester);
  final db = await pumpKadi(tester, overrides: overrides);
  if (before != null) {
    await before(db);
    await tester.pumpAndSettle();
  }
  await _openArticles(tester);
  return db;
}

/// Champ de recherche de l'écran.
Finder get _search => find.descendant(
  of: find.byType(ArticlesScreen),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
}

/// Ligne d'article de [name].
Finder _line(String name) =>
    find.byWidgetPredicate((w) => w is ArticleLine && w.article.name == name);

/// Ligne « Créer « … » ».
final _createLine = find.byType(CreateArticleLine);

final _sheet = find.byType(ArticleSheet);
Finder _inSheet(Finder finder) => find.descendant(of: _sheet, matching: finder);

/// Champ Nom de la fiche.
Finder get _nameField => _inSheet(find.byType(TextField));

Finder get _saveButton =>
    _inSheet(find.widgetWithText(FilledButton, StringsFr.enregistrer));

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_saveButton).onPressed != null;

/// Pastille [rayon] du Choix de rayon de la fiche.
Finder _rayonChoice(Rayon rayon) => _inSheet(find.byKey(ValueKey(rayon)));

/// Puce d'unité par défaut de [unit] (`null` = sans).
Finder _unitChip(Unit? unit) =>
    _inSheet(find.byKey(ValueKey('unit-${unit?.code ?? 'sans'}')));

/// Touche [finder] dans la fiche, amené à l'écran d'abord.
Future<void> _tapInSheet(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await _tap(tester, finder);
}

/// Cherche [query] et ouvre la fiche de [name].
Future<void> _openSheet(WidgetTester tester, String query, String name) async {
  await _type(tester, query);
  await _tap(tester, _line(name));
  expect(_sheet, findsOneWidget);
}

Future<void> _save(WidgetTester tester) async {
  expect(_saveEnabled(tester), isTrue);
  await _tapInSheet(tester, _saveButton);
}

Future<Article> _article(AppDatabase db, String id) =>
    (db.select(db.articles)..where((a) => a.id.equals(id))).getSingle();

/// Articles actifs de nom normalisé [normalized].
Future<List<Article>> _activeNamed(AppDatabase db, String normalized) =>
    (db.select(db.articles)..where(
          (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
        ))
        .get();

/// Lignes actives (cochées ou non) de [articleId].
Future<List<ListLine>> _activeLines(AppDatabase db, String articleId) =>
    (db.select(db.listLines)
          ..where((l) => l.articleId.equals(articleId) & l.deletedAt.isNull()))
        .get();

/// Revient à l'onglet ouvert sous les Paramètres (retour sur Articles, puis
/// sur Paramètres).
Future<void> _backToTabs(WidgetTester tester) async {
  await _tap(tester, find.byType(BackButton));
  await _tap(tester, find.byType(BackButton));
  expect(find.byType(ParametresScreen), findsNothing);
}

/// Panneau + : tape [query] dans le Champ d'ajout.
Future<void> _searchInPanel(WidgetTester tester, String query) async {
  await _tap(tester, find.byType(FloatingActionButton));
  await tester.enterText(
    find
        .descendant(of: find.byType(AddSheet), matching: find.byType(TextField))
        .first,
    query,
  );
  await tester.pumpAndSettle();
}

/// Ligne de résultat [name] du Panneau +.
Finder _panelResult(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SearchResultRow));

Future<void> _closePanel(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(AddSheet))).pop();
  await tester.pumpAndSettle();
}

/// Ouvre une Fiche recette vide depuis Recettes.
Future<void> _newRecipe(WidgetTester tester) async {
  await openTab(tester, StringsFr.tabRecettes);
  await _tap(tester, find.byType(FloatingActionButton));
  expect(find.byType(FicheRecetteScreen), findsOneWidget);
}

Future<void> _letSnackBarClose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Paramètres : ligne « Articles » juste sous « Parcours », qui '
      'pousse Articles, titre et flèche retour', (tester) async {
    tallPhone(tester);
    await pumpKadi(tester);
    await _tap(tester, find.byType(SettingsAction));

    expect(find.text(StringsFr.articlesDetail), findsOneWidget);
    final parcours = tester.getTopLeft(find.text(StringsFr.parcours)).dy;
    final articles = tester.getTopLeft(find.text(StringsFr.articlesTitre)).dy;
    final exporter = tester
        .getTopLeft(find.text(StringsFr.exporterMesDonnees))
        .dy;
    expect(articles, greaterThan(parcours));
    expect(articles, lessThan(exporter));
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, StringsFr.articlesTitre),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );

    await _tap(tester, find.text(StringsFr.articlesTitre));
    expect(find.byType(ArticlesScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(StringsFr.articlesTitre),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.byType(BackButton));
    expect(find.byType(ArticlesScreen), findsNothing);
    expect(find.byType(ParametresScreen), findsOneWidget);
  });

  testWidgets('champ vide : le catalogue par ordre alphabétique, sans les '
      'articles hors catalogue', (tester) async {
    late String typedId;
    await _pumpArticles(
      tester,
      before: (db) async {
        typedId = (await CatalogueRepository(
          db,
          Clock(),
        ).resolveTypedArticle('Physalis')).id;
      },
    );

    expect(find.text(StringsFr.chercherUnArticle), findsOneWidget);
    expect(_createLine, findsNothing);
    final shown = tester
        .widgetList<ArticleLine>(find.byType(ArticleLine))
        .map((l) => l.article)
        .toList();
    expect(shown.length, greaterThan(5));
    final names = shown.map((a) => normalizeName(a.name)).toList();
    expect(names, [...names]..sort());
    expect(shown.map((a) => a.id), isNot(contains(typedId)));

    // Cherché par son nom : jamais montré, seule la création est proposée.
    await _type(tester, 'physalis');
    expect(find.byType(ArticleLine), findsNothing);
    expect(_createLine, findsOneWidget);
  });

  testWidgets('« tom » : Tomates et son rayon écrit ; « Créer « Tom » » en '
      'tête ; « tomates » : pas de création ; × vide le champ', (tester) async {
    await _pumpArticles(tester);

    await _type(tester, 'tom');
    expect(_line('Tomates'), findsOneWidget);
    expect(
      find.descendant(
        of: _line('Tomates'),
        matching: find.text(Rayon.fruitsLegumes.label),
      ),
      findsOneWidget,
    );
    for (final line in tester.widgetList<ArticleLine>(
      find.byType(ArticleLine),
    )) {
      expect(normalizeName(line.article.name), contains('tom'));
    }
    expect(_createLine, findsOneWidget);
    expect(find.text(StringsFr.creerNom('Tom')), findsOneWidget);
    expect(
      tester.getTopLeft(_createLine).dy,
      lessThan(tester.getTopLeft(_line('Tomates')).dy),
    );
    expect(tester.getSize(_line('Tomates')).height, greaterThanOrEqualTo(48));

    await _type(tester, 'TOMATES');
    expect(_line('Tomates'), findsOneWidget);
    expect(_createLine, findsNothing);

    await _tap(tester, find.byTooltip(StringsFr.effacerLeTexte));
    expect(tester.widget<TextField>(_search).controller!.text, isEmpty);
    expect(find.byTooltip(StringsFr.effacerLeTexte), findsNothing);
    expect(find.byType(ArticleLine), findsWidgets);
  });

  testWidgets('modifier Tomates (Épicerie salée, ml) : la Fiche article '
      'écrit l’article ; la ligne déjà dans la liste reste en Fruits & '
      'légumes, un nouvel ajout par le Panneau + arrive en Épicerie salée, '
      'un ingrédient ajouté préchoisit ml', (tester) async {
    late String oldLine;
    final db = await _pumpArticles(
      tester,
      before: (db) async {
        final liste = ListeRepository(db, Clock());
        oldLine = (await liste.addArticle(SeedIds.tomates)).lineId;
        // Cochée : un nouvel ajout crée une ligne au lieu de la compléter.
        await liste.check(oldLine);
      },
    );

    await _openSheet(tester, 'tomates', 'Tomates');
    expect(_inSheet(find.text('Tomates')), findsWidgets);
    expect(_saveEnabled(tester), isFalse);
    await _tapInSheet(tester, _rayonChoice(Rayon.epicerieSalee));
    await _tapInSheet(tester, _unitChip(Unit.ml));
    await _save(tester);

    expect(_sheet, findsNothing);
    final row = await _article(db, SeedIds.tomates);
    expect(row.rayon, Rayon.epicerieSalee.code);
    expect(row.unit, Unit.ml.code);
    expect(row.pictoKey, 'tomates');
    expect(
      find.descendant(
        of: _line('Tomates'),
        matching: find.text(Rayon.epicerieSalee.label),
      ),
      findsOneWidget,
    );

    await _backToTabs(tester);
    await _searchInPanel(tester, 'tomates');
    await _tap(tester, _panelResult('Tomates'));
    await _closePanel(tester);

    final lines = await _activeLines(db, SeedIds.tomates);
    expect(lines, hasLength(2));
    final old = lines.singleWhere((l) => l.id == oldLine);
    final added = lines.singleWhere((l) => l.id != oldLine);
    expect(old.rayon, Rayon.fruitsLegumes.code);
    expect(old.checkedAt, isNotNull);
    expect(added.rayon, Rayon.epicerieSalee.code);
    expect(added.checkedAt, isNull);

    await _newRecipe(tester);
    await addIngredientBySheet(tester, 'tomates', 'Tomates');
    final ingredient = tester.widget<IngredientRow>(
      find.byWidgetPredicate(
        (w) => w is IngredientRow && w.ingredient.name == 'Tomates',
      ),
    );
    expect(ingredient.ingredient.unit, InputUnit.ml);
  });

  testWidgets('« Créer « Piment » » : fiche « Nouvel article » préremplie ; '
      'l’article du catalogue est trouvé ensuite par l’écran, le Panneau + '
      'et la Fiche recette', (tester) async {
    final db = await _pumpArticles(tester);

    await _type(tester, '  piment ');
    expect(find.text(StringsFr.creerNom('Piment')), findsOneWidget);
    await _tap(tester, _createLine);
    expect(_sheet, findsOneWidget);
    expect(_inSheet(find.text(StringsFr.nouvelArticle)), findsOneWidget);
    expect(tester.widget<TextField>(_nameField).controller!.text, 'Piment');
    expect(_saveEnabled(tester), isTrue);
    await _tapInSheet(tester, _rayonChoice(Rayon.fruitsLegumes));
    await _tapInSheet(tester, _unitChip(Unit.g));
    await _save(tester);

    expect(_sheet, findsNothing);
    final row = (await _activeNamed(db, 'piment')).single;
    expect(row.name, 'Piment');
    expect(row.inCatalogue, isTrue);
    expect(row.rayon, Rayon.fruitsLegumes.code);
    expect(row.unit, Unit.g.code);
    expect(_line('Piment'), findsOneWidget);
    expect(_createLine, findsNothing);

    await _backToTabs(tester);
    // La police des tests donne à chaque glyphe 1 em de large, presque deux
    // fois Roboto : sur 400 dp, les tags « Quantité » et « Fruits & légumes »
    // (le rayon de Piment) passent sur deux rangées, ce qu'ils ne font pas
    // au téléphone en police normale. Le panneau ne compte qu'une rangée de
    // tags (story des tags, revue) : la rangée de trop prendrait toute la
    // place de l'unique résultat. Plus large, les tags tiennent sur une
    // rangée, comme au téléphone.
    tester.view.physicalSize = const Size(800, 1400);
    await tester.pumpAndSettle();
    await _searchInPanel(tester, 'piment');
    expect(_panelResult('Piment'), findsOneWidget);
    await _closePanel(tester);

    await _newRecipe(tester);
    await openIngredientSheet(tester);
    await tester.enterText(ingredientSheetField, 'piment');
    await tester.pumpAndSettle();
    expect(ingredientResult('Piment'), findsOneWidget);
  });

  testWidgets('créer un nom hors catalogue (tapé dans le Panneau +) : même '
      'id, entre au catalogue avec les valeurs de la fiche', (tester) async {
    late String typedId;
    final db = await _pumpArticles(
      tester,
      before: (db) async {
        typedId = (await CatalogueRepository(
          db,
          Clock(),
        ).resolveTypedArticle('physalis')).id;
      },
    );

    await _type(tester, 'Physalis');
    expect(find.byType(ArticleLine), findsNothing);
    await _tap(tester, _createLine);
    await _tapInSheet(tester, _rayonChoice(Rayon.fruitsLegumes));
    await _tapInSheet(tester, _unitChip(Unit.piece));
    await _save(tester);

    final row = (await _activeNamed(db, 'physalis')).single;
    expect(row.id, typedId);
    expect(row.inCatalogue, isTrue);
    expect(row.rayon, Rayon.fruitsLegumes.code);
    expect(row.unit, Unit.piece.code);
    expect(_line('Physalis'), findsOneWidget);
  });

  testWidgets('nom pris : Lait renommé « tomates » est refusé sous le champ, '
      'rien n’est écrit ; une frappe efface le message', (tester) async {
    final db = await _pumpArticles(tester);
    final before = await _article(db, SeedIds.lait);

    await _openSheet(tester, 'lait', 'Lait');
    await tester.enterText(_nameField, 'tomates');
    await tester.pumpAndSettle();
    await _save(tester);

    expect(_sheet, findsOneWidget);
    expect(_inSheet(find.text(StringsFr.nomDejaPris)), findsOneWidget);
    expect(await _article(db, SeedIds.lait), before);

    await tester.enterText(_nameField, 'tomates bio');
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.nomDejaPris), findsNothing);
  });

  testWidgets('Lait (fréquent) passé en Boissons : rayon changé, fréquent '
      'en dernier', (tester) async {
    final db = await _pumpArticles(tester);
    final positions = [
      for (final f in await db.select(db.frequents).get())
        if (f.deletedAt == null) f.position,
    ];
    final max = positions.reduce((a, b) => a > b ? a : b);

    await _openSheet(tester, 'lait', 'Lait');
    await _tapInSheet(tester, _rayonChoice(Rayon.boissons));
    await _save(tester);

    expect((await _article(db, SeedIds.lait)).rayon, Rayon.boissons.code);
    final frequent = await (db.select(
      db.frequents,
    )..where((f) => f.id.equals(frequentId(SeedIds.lait)))).getSingle();
    expect(frequent.position, max + 1);
  });

  testWidgets('fiche modifiée puis fermée : rien n’est écrit, sans '
      'confirmation', (tester) async {
    final db = await _pumpArticles(tester);
    final before = await _article(db, SeedIds.tomates);

    await _openSheet(tester, 'tomates', 'Tomates');
    await tester.enterText(_nameField, 'Tomates rondes');
    await tester.pumpAndSettle();
    await _tapInSheet(tester, _rayonChoice(Rayon.epicerieSalee));
    await _tapInSheet(tester, _unitChip(null));
    expect(_saveEnabled(tester), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await _article(db, SeedIds.tomates), before);

    // Rouverte : les valeurs de la base.
    await _tap(tester, _line('Tomates'));
    expect(tester.widget<TextField>(_nameField).controller!.text, 'Tomates');
    expect(tester.widget<ChoiceChip>(_unitChip(Unit.g)).selected, isTrue);
  });

  testWidgets('écriture qui échoue : snackbar d’erreur dans la fiche, qui '
      'reste ouverte ; rien n’est écrit', (tester) async {
    final db = await _pumpArticles(
      tester,
      overrides: [
        catalogueRepositoryProvider.overrideWith(
          (ref) => _FailingCatalogue(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
          ),
        ),
      ],
    );
    final before = await _article(db, SeedIds.tomates);

    await _openSheet(tester, 'tomates', 'Tomates');
    await _tapInSheet(tester, _rayonChoice(Rayon.epicerieSalee));
    await _save(tester);

    expect(find.text(StringsFr.articleImpossible), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(_saveEnabled(tester), isTrue);
    expect(await _article(db, SeedIds.tomates), before);
    await _letSnackBarClose(tester);

    // Une création qui échoue de même.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _type(tester, 'piment');
    await _tap(tester, _createLine);
    await _save(tester);
    expect(find.text(StringsFr.articleImpossible), findsOneWidget);
    expect(await _activeNamed(db, 'piment'), isEmpty);
    await _letSnackBarClose(tester);
  });

  testWidgets('« Enregistrer » : actif dès qu’un champ a changé et que le '
      'nom n’est pas vide ; en création, le nom suffit', (tester) async {
    await _pumpArticles(tester);

    await _openSheet(tester, 'tomates', 'Tomates');
    expect(_saveEnabled(tester), isFalse);
    await tester.enterText(_nameField, 'Tomates cerises');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);
    await tester.enterText(_nameField, '  tomates ');
    await tester.pump();
    // Même nom nettoyé : rien n'a changé.
    expect(_saveEnabled(tester), isFalse);
    await tester.enterText(_nameField, '   ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
    await tester.enterText(_nameField, 'Tomates');
    await _tapInSheet(tester, _unitChip(Unit.piece));
    expect(_saveEnabled(tester), isTrue);
    await _tapInSheet(tester, _unitChip(Unit.g));
    expect(_saveEnabled(tester), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _type(tester, 'piment');
    await _tap(tester, _createLine);
    expect(_saveEnabled(tester), isTrue);
    await tester.enterText(_nameField, ' ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('unité par défaut : pièce · g · ml · sans, jamais kg ni L ; '
      'la puce choisie en contour on-surface avec coche, sans argile ; '
      'Picto affiché, non interactif', (tester) async {
    await _pumpArticles(tester);
    await _openSheet(tester, 'tomates', 'Tomates');

    final chips = tester
        .widgetList<ChoiceChip>(_inSheet(find.byType(ChoiceChip)))
        .toList();
    expect(
      [for (final c in chips) (c.label as Text).data],
      [
        StringsFr.puceUnitePiece,
        StringsFr.puceUniteG,
        StringsFr.puceUniteMl,
        StringsFr.puceUniteSans,
      ],
    );
    expect(_inSheet(find.text(StringsFr.puceUniteKg)), findsNothing);
    expect(_inSheet(find.text(StringsFr.puceUniteL)), findsNothing);

    final scheme = Theme.of(tester.element(_sheet)).colorScheme;
    final g = tester.widget<ChoiceChip>(_unitChip(Unit.g));
    expect(g.selected, isTrue);
    expect(g.showCheckmark, isTrue);
    expect(g.side?.color, scheme.onSurface);
    for (final chip in chips) {
      expect(
        chip.color?.resolve({WidgetState.selected}),
        isNot(scheme.primary),
      );
    }
    expect(tester.widget<ChoiceChip>(_unitChip(Unit.ml)).selected, isFalse);

    expect(_inSheet(find.byType(RayonPicker)), findsOneWidget);
    expect(
      tester.widget<RayonPicker>(_inSheet(find.byType(RayonPicker))).selected,
      Rayon.fruitsLegumes,
    );
    // Picto de l'article, hors de tout bouton : le choix vient avec le pack.
    final picto = _inSheet(find.byType(Picto));
    expect(picto, findsOneWidget);
    expect(tester.widget<Picto>(picto).pictoKey, 'tomates');
    expect(
      find.ancestor(of: picto, matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('TalkBack : champ de recherche, lignes, « Créer « … » » et '
      'fiche lus ; une ligne s’ouvre par TalkBack', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpArticles(tester);

    expect(
      tester.getSemantics(_search),
      isSemantics(label: StringsFr.chercherUnArticle, isTextField: true),
    );
    await _type(tester, 'tom');
    final tomates = 'Tomates, ${Rayon.fruitsLegumes.spokenLabel}';
    expect(
      tester.getSemantics(_line('Tomates')),
      isSemantics(label: tomates, isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(_createLine),
      isSemantics(
        label: StringsFr.creerNom('Tom'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byTooltip(StringsFr.effacerLeTexte)),
      isSemantics(
        tooltip: StringsFr.effacerLeTexte,
        isButton: true,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel(tomates));
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);

    expect(
      tester.getSemantics(_inSheet(find.text('Tomates')).first),
      isSemantics(label: 'Tomates', isHeader: true),
    );
    expect(
      tester.getSemantics(_nameField),
      isSemantics(label: StringsFr.nom, isTextField: true),
    );
    expect(
      tester.getSemantics(
        find.descendant(
          of: _inSheet(find.byType(RayonPicker)),
          matching: find.bySemanticsLabel(Rayon.fruitsLegumes.spokenLabel),
        ),
      ),
      isSemantics(
        label: Rayon.fruitsLegumes.spokenLabel,
        isButton: true,
        isSelected: true,
      ),
    );
    for (final (unit, label) in [
      (Unit.piece, StringsFr.puceUnitePiece),
      (Unit.g, StringsFr.puceUniteG),
      (Unit.ml, StringsFr.puceUniteMl),
      (null, StringsFr.puceUniteSans),
    ]) {
      expect(
        tester.getSemantics(_unitChip(unit)),
        isSemantics(
          label: label,
          isButton: true,
          hasSelectedState: true,
          isSelected: unit == Unit.g,
          hasTapAction: true,
        ),
        reason: label,
      );
    }
    expect(
      tester.getSemantics(_saveButton),
      isSemantics(
        label: StringsFr.enregistrer,
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('police ×2 sur 360 dp : Paramètres, Articles et Fiche article '
      'sans débordement, noms entiers', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await pumpKadi(tester);

    await _openArticles(tester);
    expect(tester.takeException(), isNull);
    final first = find.byType(ArticleLine).first;
    for (final text in tester.widgetList<Text>(
      find.descendant(of: first, matching: find.byType(Text)),
    )) {
      expect(text.overflow, isNull);
      expect(text.maxLines, isNull);
    }
    expect(tester.getRect(first).right, lessThanOrEqualTo(360));

    await _type(tester, 'papier');
    expect(tester.takeException(), isNull);
    expect(_line('Papier toilette'), findsOneWidget);
    expect(
      tester.getRect(find.text('Papier toilette')).right,
      lessThanOrEqualTo(360),
    );

    await _tap(tester, _line('Papier toilette'));
    expect(tester.takeException(), isNull);
    expect(_sheet, findsOneWidget);
    await tester.ensureVisible(_saveButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_saveButton.hitTestable(), findsOneWidget);
    await tester.ensureVisible(_unitChip(null));
    await tester.pumpAndSettle();
    expect(_unitChip(null).hitTestable(), findsOneWidget);
  });
}
