import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/reglages/ui/article_lines.dart';
import 'package:kadi/features/reglages/ui/frequents_screen.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

/// Articles fournis absents des fréquents.
const _piles = '647841c6-7cff-40f4-a8dd-69d7e781eb8b'; // Divers
const _lessive = '5fbd7732-9a3d-4f27-989a-e8c5c9c835be'; // Entretien

/// Catalogue dont toute écriture des fréquents échoue.
class _FailingCatalogue extends CatalogueRepository {
  _FailingCatalogue(super.db, super.clock);

  @override
  Future<void> addFrequent(String articleId) async =>
      throw StateError('échec simulé');

  @override
  Future<CatalogueArticle> createFrequentArticle(String name) async =>
      throw StateError('échec simulé');

  @override
  Future<List<UndoRow>> removeFrequent(String articleId) async =>
      throw StateError('échec simulé');

  @override
  Future<CatalogueArticle> updateArticle(
    String articleId, {
    required String name,
    required Rayon rayon,
    required Unit? unit,
    String? pictoKey,
  }) async => throw StateError('échec simulé');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _letSnackBarClose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Vue très haute : les 31 fréquents tiennent dans l'écran et dans le
/// Panneau +.
void _tallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 3000);
  addTearDown(tester.view.reset);
}

/// Liste défilante des Paramètres.
Finder get _parametresScrollable => find
    .descendant(
      of: find.byType(ParametresScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Ouvre Paramètres par ⚙, puis Fréquents par sa ligne (amenée à l'écran :
/// les Paramètres sont une liste paresseuse).
Future<void> _openFrequents(WidgetTester tester) async {
  await _tap(tester, find.byType(SettingsAction));
  await tester.scrollUntilVisible(
    find.text(StringsFr.frequentsTitre),
    100,
    scrollable: _parametresScrollable,
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.text(StringsFr.frequentsTitre));
  expect(find.byType(FrequentsScreen), findsOneWidget);
}

/// Monte Kadi dans une vue très haute et ouvre Paramètres › Fréquents.
Future<AppDatabase> _pumpFrequents(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Future<void> Function(AppDatabase db)? before,
}) async {
  _tallView(tester);
  final db = await pumpKadi(tester, overrides: overrides);
  if (before != null) {
    await before(db);
    await tester.pumpAndSettle();
  }
  await _openFrequents(tester);
  return db;
}

/// Champ de recherche de l'écran.
Finder get _search => find.descendant(
  of: find.byType(FrequentsScreen),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_search).controller!.text;

/// Ligne de fréquent de [name].
Finder _line(String name) =>
    find.byWidgetPredicate((w) => w is FrequentLine && w.article.name == name);

/// Ligne de résultat de [name].
Finder _result(String name) => find.byWidgetPredicate(
  (w) => w is FrequentResultLine && w.article.name == name,
);

/// Icône de retrait du fréquent [name].
Finder _removeButton(String name) =>
    find.byTooltip(StringsFr.retirerDesFrequents(name));

final _createLine = find.byType(CreateArticleLine);
final _undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);
final _rayonSheet = find.byType(FrequentRayonSheet);

/// Articles des Lignes de fréquent, dans l'ordre affiché.
List<CatalogueArticle> _shownFrequents(WidgetTester tester) => [
  for (final line in tester.widgetList<FrequentLine>(find.byType(FrequentLine)))
    line.article,
];

/// Articles des Lignes de fréquent du Panneau +, dans l'ordre affiché.
List<CatalogueArticle> _panelFrequents(WidgetTester tester) => [
  for (final row in tester.widgetList<FrequentRow>(find.byType(FrequentRow)))
    row.article,
];

Future<Frequent?> _frequent(AppDatabase db, String articleId) => (db.select(
  db.frequents,
)..where((f) => f.id.equals(frequentId(articleId)))).getSingleOrNull();

Future<Article> _article(AppDatabase db, String id) =>
    (db.select(db.articles)..where((a) => a.id.equals(id))).getSingle();

Future<List<Article>> _activeNamed(AppDatabase db, String normalized) =>
    (db.select(db.articles)..where(
          (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
        ))
        .get();

Future<void> _openPanel(WidgetTester tester) =>
    _tap(tester, find.byType(FloatingActionButton));

void main() {
  // Tous les fréquents tiennent dans le Panneau +.
  setUp(() => addPanelFrequentRows = 40);
  tearDown(() => addPanelFrequentRows = 4.5);

  testWidgets('Paramètres : ligne « Fréquents » juste sous « Articles », qui '
      'pousse Fréquents, titre et flèche retour', (tester) async {
    _tallView(tester);
    await pumpKadi(tester);
    await _tap(tester, find.byType(SettingsAction));

    expect(find.text(StringsFr.frequentsDetail), findsOneWidget);
    final articles = tester.getTopLeft(find.text(StringsFr.articlesTitre)).dy;
    final frequents = tester.getTopLeft(find.text(StringsFr.frequentsTitre)).dy;
    final exporter = tester
        .getTopLeft(find.text(StringsFr.exporterMesDonnees))
        .dy;
    expect(frequents, greaterThan(articles));
    expect(frequents, lessThan(exporter));
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, StringsFr.frequentsTitre),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );

    await _tap(tester, find.text(StringsFr.frequentsTitre));
    expect(find.byType(FrequentsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(StringsFr.frequentsTitre),
      ),
      findsOneWidget,
    );
    expect(find.text(StringsFr.ajouterUnFrequent), findsOneWidget);
    await _tap(tester, find.byType(BackButton));
    expect(find.byType(FrequentsScreen), findsNothing);
    expect(find.byType(ParametresScreen), findsOneWidget);
  });

  testWidgets('« Gérer » du Panneau + : panneau fermé, Fréquents affiché ; '
      'retour : la Liste, panneau fermé', (tester) async {
    _tallView(tester);
    await pumpKadi(tester);
    await _openPanel(tester);
    expect(find.byType(AddSheet), findsOneWidget);

    await _tap(tester, find.widgetWithText(TextButton, StringsFr.gerer));
    expect(find.byType(AddSheet), findsNothing);
    expect(find.byType(FrequentsScreen), findsOneWidget);
    expect(find.byType(ParametresScreen), findsNothing);

    await _tap(tester, find.byType(BackButton));
    expect(find.byType(FrequentsScreen), findsNothing);
    expect(find.byType(AddSheet), findsNothing);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
  });

  testWidgets('critère d’acceptation : « Gérer », retirer Lait, ajouter '
      'Lessive, revenir : le panneau n’a plus Lait et a Lessive en dernier '
      'd’Entretien', (tester) async {
    _tallView(tester);
    final db = await pumpKadi(tester);
    await _openPanel(tester);
    await _tap(tester, find.widgetWithText(TextButton, StringsFr.gerer));

    await _tap(tester, _removeButton('Lait'));
    expect(_line('Lait'), findsNothing);
    await _type(tester, 'less');
    await _tap(tester, _result('Lessive'));
    expect(_fieldText(tester), isEmpty);
    expect(_line('Lessive'), findsOneWidget);

    await _tap(tester, find.byType(BackButton));
    await _letSnackBarClose(tester);
    await _openPanel(tester);
    final panel = _panelFrequents(tester);
    expect(panel.map((a) => a.id), isNot(contains(SeedIds.lait)));
    final entretien = [
      for (final a in panel)
        if (a.rayon == Rayon.entretien) a.id,
    ];
    expect(entretien.last, _lessive);
    expect(entretien.length, greaterThan(1));
    expect((await _frequent(db, SeedIds.lait))!.deletedAt, isNotNull);
    expect((await _frequent(db, _lessive))!.deletedAt, isNull);
  });

  testWidgets('les fréquents dans l’ordre du parcours, comme le panneau : '
      'Picto, nom, rayon écrit, icône de retrait de 48 dp', (tester) async {
    await _pumpFrequents(
      tester,
      before: (db) => db
          .update(db.settings)
          .write(
            SettingsCompanion(
              routeOrder: Value(
                SettingsRepository.encodeRouteOrder([
                  Rayon.cremerie,
                  ...Rayon.values.where((r) => r != Rayon.cremerie),
                ]),
              ),
            ),
          ),
    );

    final shown = _shownFrequents(tester);
    expect(shown, hasLength(31));
    final route = [
      Rayon.cremerie,
      ...Rayon.values.where((r) => r != Rayon.cremerie),
    ];
    final indexes = [for (final a in shown) route.indexOf(a.rayon)];
    expect(indexes, [...indexes]..sort());
    expect(shown.first.rayon, Rayon.cremerie);
    // Lait avant Œufs (position) ; Crèmerie avant Fruits & légumes.
    final ids = shown.map((a) => a.id).toList();
    expect(ids.indexOf(SeedIds.lait), lessThan(ids.indexOf(SeedIds.oeufs)));
    expect(ids.indexOf(SeedIds.lait), lessThan(ids.indexOf(SeedIds.tomates)));

    final lait = _line('Lait');
    expect(
      find.descendant(of: lait, matching: find.text(Rayon.cremerie.label)),
      findsOneWidget,
    );
    final rayonText = tester.widget<Text>(
      find.descendant(of: lait, matching: find.text(Rayon.cremerie.label)),
    );
    final theme = Theme.of(tester.element(lait));
    expect(rayonText.style?.fontSize, theme.textTheme.bodyMedium?.fontSize);
    expect(rayonText.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(tester.getSize(lait).height, greaterThanOrEqualTo(48));
    final remove = _removeButton('Lait');
    expect(find.descendant(of: lait, matching: remove), findsOneWidget);
    expect(tester.getSize(remove).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
    expect(
      tester.getCenter(remove).dx,
      greaterThan(tester.getCenter(find.text('Lait')).dx),
    );
  });

  testWidgets('retirer Lait : « Retiré des fréquents : Lait » ; absent du '
      'panneau ; Annuler le remet à sa place', (tester) async {
    final db = await _pumpFrequents(tester);
    final before = _shownFrequents(tester).map((a) => a.id).toList();
    final position = (await _frequent(db, SeedIds.lait))!.position;

    await _tap(tester, _removeButton('Lait'));
    expect(_line('Lait'), findsNothing);
    expect(find.text(StringsFr.retireDesFrequents('Lait')), findsOneWidget);
    expect((await _frequent(db, SeedIds.lait))!.deletedAt, isNotNull);

    await _tap(tester, _undoAction);
    expect(_shownFrequents(tester).map((a) => a.id).toList(), before);
    final restored = (await _frequent(db, SeedIds.lait))!;
    expect(restored.deletedAt, isNull);
    expect(restored.position, position);

    // Retiré de nouveau, sans Annuler : absent des Ajouts fréquents.
    await _letSnackBarClose(tester);
    await _tap(tester, _removeButton('Lait'));
    await _letSnackBarClose(tester);
    await _tap(tester, find.byType(BackButton));
    await _tap(tester, find.byType(BackButton));
    await _openPanel(tester);
    expect(find.widgetWithText(FrequentRow, 'Lait'), findsNothing);
    expect(find.widgetWithText(FrequentRow, 'Œufs'), findsOneWidget);
  });

  testWidgets('ajouter : « pil », + sur Piles : en dernier de son rayon, '
      'dans le panneau aussi ; champ vidé', (tester) async {
    final db = await _pumpFrequents(tester);

    await _type(tester, 'pil');
    expect(_line('Lait'), findsNothing);
    final piles = _result('Piles');
    expect(piles, findsOneWidget);
    expect(
      find.descendant(of: piles, matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: piles, matching: find.text(Rayon.divers.label)),
      findsOneWidget,
    );
    await _tap(tester, piles);

    expect(_fieldText(tester), isEmpty);
    expect(_shownFrequents(tester).last.id, _piles);
    expect((await _frequent(db, _piles))!.deletedAt, isNull);

    await _tap(tester, find.byType(BackButton));
    await _tap(tester, find.byType(BackButton));
    await _openPanel(tester);
    expect(_panelFrequents(tester).last.id, _piles);
  });

  testWidgets('réactiver : Lait retiré puis ajouté de nouveau, même id, '
      'actif, en dernier de Crèmerie', (tester) async {
    final db = await _pumpFrequents(tester);

    await _tap(tester, _removeButton('Lait'));
    await _letSnackBarClose(tester);
    await _type(tester, 'lait');
    await _tap(tester, _result('Lait'));

    final rows = await (db.select(
      db.frequents,
    )..where((f) => f.articleId.equals(SeedIds.lait))).get();
    expect(rows.single.id, frequentId(SeedIds.lait));
    expect(rows.single.deletedAt, isNull);
    final cremerie = [
      for (final a in _shownFrequents(tester))
        if (a.rayon == Rayon.cremerie) a.id,
    ];
    expect(cremerie.last, SeedIds.lait);
    expect(cremerie.length, greaterThan(1));
  });

  testWidgets('déjà fréquent : coche, tap sans effet', (tester) async {
    final db = await _pumpFrequents(tester);
    final before = await db.select(db.frequents).get();

    await _type(tester, 'lait');
    final lait = _result('Lait');
    expect(
      find.descendant(of: lait, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lait, matching: find.byIcon(Icons.add)),
      findsNothing,
    );
    await _tap(tester, lait);

    expect(_fieldText(tester), 'lait');
    expect(await db.select(db.frequents).get(), before);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('créer : « Kombucha » → Créer « Kombucha » : article du '
      'catalogue (Divers, sans unité) et fréquent', (tester) async {
    final db = await _pumpFrequents(tester);

    await _type(tester, 'kombucha');
    expect(find.text(StringsFr.creerNom('Kombucha')), findsOneWidget);
    await _tap(tester, _createLine);

    final row = (await _activeNamed(db, 'kombucha')).single;
    expect(row.name, 'Kombucha');
    expect(row.inCatalogue, isTrue);
    expect(row.rayon, Rayon.divers.code);
    expect(row.unit, isNull);
    expect((await _frequent(db, row.id))!.deletedAt, isNull);
    expect(_fieldText(tester), isEmpty);
    expect(_line('Kombucha'), findsOneWidget);
    expect(_shownFrequents(tester).last.id, row.id);

    // Nom exact d'un article du catalogue : pas de création.
    await _type(tester, 'LAIT');
    expect(_createLine, findsNothing);
  });

  testWidgets('rayon : Lait → Boissons : en dernier de Boissons, ordre des '
      'autres inchangé ; la ligne de liste existante ne bouge pas, le '
      'prochain ajout de Lait arrive en Boissons', (tester) async {
    late String oldLine;
    final db = await _pumpFrequents(
      tester,
      before: (db) async {
        oldLine = (await ListeRepository(db, Clock()).addArticle(SeedIds.lait))
            .lineId;
      },
    );
    final others = [
      for (final a in _shownFrequents(tester))
        if (a.id != SeedIds.lait) a.id,
    ];

    await _tap(tester, _line('Lait'));
    expect(_rayonSheet, findsOneWidget);
    final picker = find.descendant(
      of: _rayonSheet,
      matching: find.byType(RayonPicker),
    );
    expect(tester.widget<RayonPicker>(picker).selected, Rayon.cremerie);
    final boissons = find.descendant(
      of: _rayonSheet,
      matching: find.byKey(const ValueKey(Rayon.boissons)),
    );
    await tester.ensureVisible(boissons);
    await tester.pumpAndSettle();
    await _tap(tester, boissons);

    expect(_rayonSheet, findsNothing);
    final article = await _article(db, SeedIds.lait);
    expect(article.rayon, Rayon.boissons.code);
    expect(article.name, 'Lait');
    expect(article.unit, Unit.piece.code);
    final shown = _shownFrequents(tester);
    expect([
      for (final a in shown)
        if (a.id != SeedIds.lait) a.id,
    ], others);
    final inBoissons = [
      for (final a in shown)
        if (a.rayon == Rayon.boissons) a.id,
    ];
    expect(inBoissons.last, SeedIds.lait);
    expect(
      find.descendant(
        of: _line('Lait'),
        matching: find.text(Rayon.boissons.label),
      ),
      findsOneWidget,
    );

    final liste = ListeRepository(db, Clock());
    final old = await (db.select(
      db.listLines,
    )..where((l) => l.id.equals(oldLine))).getSingle();
    expect(old.rayon, Rayon.cremerie.code);
    // Cochée, elle n'est pas complétée : l'ajout suivant crée une ligne.
    await liste.check(oldLine);
    final added = await liste.addArticle(SeedIds.lait);
    final line = await (db.select(
      db.listLines,
    )..where((l) => l.id.equals(added.lineId))).getSingle();
    expect(line.rayon, Rayon.boissons.code);
  });

  testWidgets('même rayon touché : rien n’est écrit', (tester) async {
    final db = await _pumpFrequents(tester);
    final before = await _article(db, SeedIds.lait);

    await _tap(tester, _line('Lait'));
    final cremerie = find.descendant(
      of: _rayonSheet,
      matching: find.byKey(const ValueKey(Rayon.cremerie)),
    );
    await tester.ensureVisible(cremerie);
    await tester.pumpAndSettle();
    await _tap(tester, cremerie);

    expect(_rayonSheet, findsNothing);
    expect(await _article(db, SeedIds.lait), before);
  });

  testWidgets('vide : tous les fréquents retirés, message d’état vide', (
    tester,
  ) async {
    await _pumpFrequents(
      tester,
      before: (db) => db
          .update(db.frequents)
          .write(
            const FrequentsCompanion(deletedAt: Value(1), updatedAt: Value(1)),
          ),
    );

    expect(find.text(StringsFr.pasEncoreDeFrequents), findsOneWidget);
    expect(find.byType(FrequentLine), findsNothing);

    // La recherche reste possible.
    await _type(tester, 'lait');
    expect(_result('Lait'), findsOneWidget);
    expect(find.text(StringsFr.pasEncoreDeFrequents), findsNothing);
  });

  testWidgets('écritures qui échouent : snackbar d’erreur, rien n’est '
      'écrit', (tester) async {
    final db = await _pumpFrequents(
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
    final frequents = await db.select(db.frequents).get();
    final articles = await db.select(db.articles).get();

    await _tap(tester, _removeButton('Lait'));
    expect(find.text(StringsFr.frequentImpossible), findsOneWidget);
    expect(_line('Lait'), findsOneWidget);
    await _letSnackBarClose(tester);

    await _type(tester, 'pil');
    await _tap(tester, _result('Piles'));
    expect(find.text(StringsFr.frequentImpossible), findsOneWidget);
    expect(_fieldText(tester), 'pil');
    await _letSnackBarClose(tester);

    await _type(tester, 'kombucha');
    await _tap(tester, _createLine);
    expect(find.text(StringsFr.frequentImpossible), findsOneWidget);
    await _letSnackBarClose(tester);

    await _type(tester, '');
    await _tap(tester, _line('Lait'));
    final boissons = find.descendant(
      of: _rayonSheet,
      matching: find.byKey(const ValueKey(Rayon.boissons)),
    );
    await tester.ensureVisible(boissons);
    await tester.pumpAndSettle();
    await _tap(tester, boissons);
    expect(find.text(StringsFr.frequentImpossible), findsOneWidget);
    await _letSnackBarClose(tester);

    expect(await db.select(db.frequents).get(), frequents);
    expect(await db.select(db.articles).get(), articles);
  });

  testWidgets('TalkBack : champ, lignes, retrait, résultats et Choix de '
      'rayon lus ; une ligne s’ouvre par TalkBack', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpFrequents(tester);

    expect(
      tester.getSemantics(_search),
      isSemantics(label: StringsFr.ajouterUnFrequent, isTextField: true),
    );
    final lait = 'Lait, ${Rayon.cremerie.spokenLabel}';
    expect(
      tester.getSemantics(_line('Lait')),
      isSemantics(label: lait, isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(_removeButton('Lait')),
      isSemantics(
        tooltip: StringsFr.retirerDesFrequents('Lait'),
        isButton: true,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel(lait));
    await tester.pumpAndSettle();
    expect(_rayonSheet, findsOneWidget);
    expect(
      tester.getSemantics(
        find.descendant(of: _rayonSheet, matching: find.text('Lait')),
      ),
      isSemantics(label: 'Lait', isHeader: true),
    );
    expect(
      tester.getSemantics(
        find.descendant(
          of: _rayonSheet,
          matching: find.bySemanticsLabel(Rayon.cremerie.spokenLabel),
        ),
      ),
      isSemantics(
        label: Rayon.cremerie.spokenLabel,
        isButton: true,
        isSelected: true,
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_rayonSheet, findsNothing);

    await _type(tester, 'lait');
    expect(
      tester.getSemantics(_result('Lait')),
      isSemantics(
        label: StringsFr.dejaFrequent('Lait'),
        isButton: false,
        hasTapAction: false,
      ),
    );
    await _type(tester, 'pil');
    expect(
      tester.getSemantics(_result('Piles')),
      isSemantics(
        label: 'Piles, ${Rayon.divers.spokenLabel}',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await _type(tester, 'kombucha');
    expect(
      tester.getSemantics(_createLine),
      isSemantics(
        label: StringsFr.creerNom('Kombucha'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('police ×2 sur 360 dp : Paramètres, Fréquents, résultats et '
      'Choix de rayon sans débordement, noms entiers', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await pumpKadi(tester);

    await _openFrequents(tester);
    expect(tester.takeException(), isNull);
    final first = find.byType(FrequentLine).first;
    for (final text in tester.widgetList<Text>(
      find.descendant(of: first, matching: find.byType(Text)),
    )) {
      expect(text.overflow, isNull);
      expect(text.maxLines, isNull);
    }
    expect(tester.getRect(first).right, lessThanOrEqualTo(360));
    final remove = find.descendant(
      of: first,
      matching: find.byType(IconButton),
    );
    expect(tester.getRect(remove).right, lessThanOrEqualTo(360));
    expect(remove.hitTestable(), findsOneWidget);

    // Une ligne plus bas dans la liste paresseuse.
    await tester.scrollUntilVisible(
      _line('Papier toilette'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(FrequentsScreen),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Papier toilette')).right,
      lessThanOrEqualTo(360),
    );

    await _tap(tester, _line('Papier toilette'));
    expect(tester.takeException(), isNull);
    expect(_rayonSheet, findsOneWidget);
    final divers = find.descendant(
      of: _rayonSheet,
      matching: find.byKey(const ValueKey(Rayon.divers)),
    );
    await tester.ensureVisible(divers);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(divers.hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _type(tester, 'papier');
    expect(tester.takeException(), isNull);
    expect(_result('Papier toilette'), findsOneWidget);
    expect(
      tester.getRect(find.text('Papier toilette')).right,
      lessThanOrEqualTo(360),
    );
  });
}
