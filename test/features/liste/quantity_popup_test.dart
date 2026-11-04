import 'dart:async' show unawaited;

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_panel.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/item_edit_sheet.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/liste/ui/quantity_popup.dart';
import 'package:kadi/features/liste/ui/quantity_tag.dart';
import 'package:kadi/features/liste/ui/row_highlight.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

const _keyboard = 300.0;

/// Vue assez haute pour que tous les fréquents tiennent dans le panneau.
Future<AppDatabase> _pumpTall(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 3000);
  addTearDown(tester.view.reset);
  return pumpKadi(tester);
}

/// Téléphone de 412×914 dp, clavier de [keyboard] dp.
Future<AppDatabase> _pumpPhone(
  WidgetTester tester, {
  double keyboard = _keyboard,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 914);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  return pumpKadi(tester);
}

final _sheet = find.byType(AddSheet);
Finder _inSheet(Finder finder) => find.descendant(of: _sheet, matching: finder);

/// Le Champ d'ajout du panneau.
Finder get _search => _inSheet(find.byType(TextField)).first;

Finder _frequent(String name) => find.widgetWithText(FrequentRow, name);
Finder _result(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SearchResultRow));
Finder _tag(Finder row) =>
    find.descendant(of: row, matching: find.byType(QuantityTag));

/// La puce visible du tag, sans sa cible de 48 dp.
Finder _tagChip(Finder row) =>
    find.descendant(of: _tag(row), matching: find.byType(Material));
Finder _indicator(Finder row, IconData icon) =>
    find.descendant(of: row, matching: find.byIcon(icon));
Finder _listRow(String name) => find.widgetWithText(ItemRow, name);

final _popup = find.byType(QuantityPopup);
Finder _inPopup(Finder finder) => find.descendant(of: _popup, matching: finder);
final _card = _inPopup(find.byType(Material)).first;
final _field = _inPopup(find.byType(TextField));
final _chips = _inPopup(find.byType(ChoiceChip));
Finder _chip(InputUnit unit) => _inPopup(find.byKey(ValueKey(unit)));

ListePanel _panel(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ListeScreen)),
  listen: false,
).read(listePanelProvider);

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Fait défiler les fréquents du panneau jusqu'à [name].
Future<void> _scrollTo(WidgetTester tester, String name) async {
  await tester.scrollUntilVisible(
    _frequent(name),
    100,
    scrollable: find
        .descendant(
          of: _inSheet(find.byType(ListView)),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openPopup(WidgetTester tester, Finder row) =>
    _tap(tester, _tag(row));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

Future<void> _pressEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Tap hors de la carte, sur la barrière.
Future<void> _tapOutside(WidgetTester tester) async {
  final top = tester.getTopLeft(_card).dy;
  await tester.tapAt(Offset(20, top - 8 < 0 ? 900 : top - 8));
  await tester.pumpAndSettle();
}

Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _letSnackBarClose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

bool _focused(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

/// La ligne [name] de la Liste porte la quantité [text].
Finder _listRowWith(String name, String text) =>
    find.descendant(of: _listRow(name), matching: find.text(text));

/// Lignes actives non cochées de [articleId].
Future<List<ListLine>> _lines(AppDatabase db, String articleId) =>
    (db.select(db.listLines)..where(
          (l) =>
              l.articleId.equals(articleId) &
              l.deletedAt.isNull() &
              l.checkedAt.isNull(),
        ))
        .get();

/// Quantité affichée par la ligne [lineId] : somme des contributions actives.
Future<int?> _quantity(AppDatabase db, String lineId) async {
  final contributions = await (db.select(
    db.listContributions,
  )..where((c) => c.lineId.equals(lineId) & c.deletedAt.isNull())).get();
  return contributions
      .map((c) => c.quantity)
      .nonNulls
      .fold<int?>(null, (sum, q) => (sum ?? 0) + q);
}

/// Toutes les lignes et contributions : rien ne doit bouger sans écriture.
Future<List<Object>> _snapshot(AppDatabase db) async => [
  ...await db.select(db.listLines).get(),
  ...await db.select(db.listContributions).get(),
];

void _failContributions(AppDatabase db) => db.customStatement(
  'CREATE TRIGGER no_quantity BEFORE INSERT ON list_contributions '
  "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
);

void main() {
  // Écran très haut : tous les fréquents tiennent dans le panneau.
  setUp(() => addPanelFrequentRows = 40);
  tearDown(() => addPanelFrequentRows = 4.5);

  test('oldestLineByArticle : la première ligne reçue de chaque article', () {
    ListeItem item(String lineId, String articleId) => ListeItem(
      lineId: lineId,
      articleId: articleId,
      name: articleId,
      rayon: Rayon.divers,
      unit: null,
      quantity: null,
    );

    final lines = oldestLineByArticle([
      item('a1', 'a'),
      item('b1', 'b'),
      item('a2', 'a'),
    ]);

    expect(lines.keys, unorderedEquals(['a', 'b']));
    expect(lines['a']!.lineId, 'a1');
    expect(lines['b']!.lineId, 'b1');
  });

  group('le tag quantité', () {
    testWidgets('hors liste : signe +, aucun tag', (tester) async {
      await _pumpTall(tester);
      await _openPanel(tester);

      expect(_indicator(_frequent('Lait'), Icons.add), findsOneWidget);
      expect(_tag(_frequent('Lait')), findsNothing);
    });

    testWidgets('tap sur Lait : coche et, à sa gauche, « Qté » en contour ; '
        'cible de 48 dp, puce de 32 dp, ligne de même hauteur, aucun crayon', (
      tester,
    ) async {
      await _pumpTall(tester);
      await _openPanel(tester);

      await _tap(tester, _frequent('Lait'));

      final row = _frequent('Lait');
      final check = _indicator(row, Icons.check);
      expect(check, findsOneWidget);
      expect(_tag(row), findsOneWidget);
      expect(_tag(_frequent('Beurre')), findsNothing);
      expect(
        tester.getCenter(_tag(row)).dx,
        lessThan(tester.getCenter(check).dx),
      );

      expect(tester.getSize(_tag(row)).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(_tag(row)).height, 48);
      expect(tester.getSize(_tagChip(row)).height, KadiSpacing.tagHeight);
      expect(
        tester.getSize(row).height,
        tester.getSize(_frequent('Beurre')).height,
      );

      final theme = Theme.of(tester.element(row));
      final chip = tester.widget<Material>(_tagChip(row));
      final shape = chip.shape! as RoundedRectangleBorder;
      expect(chip.color, theme.colorScheme.surfaceContainerHigh);
      expect(shape.side, BorderSide.none);
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(KadiRadius.sm)),
      );
      final text = tester.widget<Text>(
        find.descendant(of: _tag(row), matching: find.text(StringsFr.qte)),
      );
      expect(text.style!.color, theme.colorScheme.onSurfaceVariant);
      expect(text.style!.fontSize, theme.textTheme.labelLarge!.fontSize);

      // Aucun crayon dans le panneau.
      expect(_inSheet(find.byIcon(Icons.edit_outlined)), findsNothing);
      expect(_inSheet(find.byType(QuantityField)), findsNothing);
    });

    testWidgets('avec une quantité : la valeur en plein', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(
        db,
        Clock(),
      ).addArticle(SeedIds.lait, quantity: 500, unit: Unit.g);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      final row = _frequent('Lait');
      expect(
        find.descendant(
          of: _tag(row),
          matching: find.text(formatQuantity(500, Unit.g)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Qté')),
        findsNothing,
      );

      final theme = Theme.of(tester.element(row));
      final chip = tester.widget<Material>(_tagChip(row));
      expect(chip.color, theme.colorScheme.onSurfaceVariant);
      expect((chip.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _tag(row),
                matching: find.text(formatQuantity(500, Unit.g)),
              ),
            )
            .style!
            .color,
        theme.colorScheme.surface,
      );
    });

    testWidgets('article coché dans la Liste, panneau ouvert : tag absent, + '
        'revenu', (tester) async {
      final db = await _pumpTall(tester);
      final repo = ListeRepository(db, Clock());
      final added = await repo.addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      expect(_tag(_frequent('Lait')), findsOneWidget);

      await repo.check(added.lineId);
      await tester.pumpAndSettle();

      expect(_tag(_frequent('Lait')), findsNothing);
      expect(_indicator(_frequent('Lait'), Icons.add), findsOneWidget);
    });

    testWidgets('article à deux lignes : le tag montre et édite la plus '
        'ancienne', (tester) async {
      final db = await _pumpTall(tester);
      final repo = ListeRepository(db, Clock());
      final oldest = await repo.addArticle(
        SeedIds.lait,
        quantity: 500,
        unit: Unit.ml,
      );
      final other = await repo.addArticle(
        SeedIds.lait,
        quantity: 2000,
        unit: Unit.piece,
      );
      await tester.pumpAndSettle();
      await _openPanel(tester);

      final row = _frequent('Lait');
      expect(
        find.descendant(
          of: _tag(row),
          matching: find.text(formatQuantity(500, Unit.ml)),
        ),
        findsOneWidget,
      );

      await _openPopup(tester, row);
      expect(_fieldText(tester), '500');
      expect(tester.widget<ChoiceChip>(_chip(InputUnit.ml)).selected, isTrue);
      await _type(tester, '700');
      await _pressEnter(tester);

      expect(await _quantity(db, oldest.lineId), 700);
      expect(await _quantity(db, other.lineId), 2000);
      expect(
        find.descendant(
          of: _tag(row),
          matching: find.text(formatQuantity(700, Unit.ml)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('résultat de recherche dans la liste : même tag, même popup', (
      tester,
    ) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);
      await tester.enterText(_search, 'lai');
      await tester.pumpAndSettle();
      expect(_tag(_result('Lait')), findsNothing);
      await _tap(tester, _result('Lait'));
      // L'ajout vide le champ : on cherche de nouveau.
      await tester.enterText(_search, 'lai');
      await tester.pumpAndSettle();
      expect(_tag(_result('Lait')), findsOneWidget);

      await _openPopup(tester, _result('Lait'));
      expect(_popup, findsOneWidget);
      await _type(tester, '3');
      await _pressEnter(tester);

      final line = (await _lines(db, SeedIds.lait)).single;
      expect(await _quantity(db, line.id), 3000);
      expect(
        find.descendant(
          of: _tag(_result('Lait')),
          matching: find.text(formatQuantity(3000, Unit.piece)),
        ),
        findsOneWidget,
      );
      // La recherche reste affichée, le texte aussi.
      expect(tester.widget<TextField>(_search).controller!.text, 'lai');
    });

    testWidgets('TalkBack : ligne et tag lus à part ; le tag, bouton, ouvre '
        'la popup', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await _pumpTall(tester);
      final repo = ListeRepository(db, Clock());
      await repo.addArticle(SeedIds.lait);
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Lait, dans la liste')),
        isSemantics(
          label: 'Lait, dans la liste',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Quantité de Lait, aucune')),
        isSemantics(
          label: 'Quantité de Lait, aucune',
          isButton: true,
          hasTapAction: true,
        ),
      );
      final tomates = StringsFr.quantiteDe(
        'Tomates',
        formatQuantity(500, Unit.g),
      );
      expect(tomates.replaceAll(' ', ' '), 'Quantité de Tomates, 500 g');
      expect(find.bySemanticsLabel(tomates), findsOneWidget);

      tester.semantics.tap(
        find.semantics.byPredicate(
          (node) => node.label == 'Quantité de Lait, aucune',
        ),
      );
      await tester.pumpAndSettle();
      expect(_popup, findsOneWidget);
      handle.dispose();
    });

    /// Monte seule la ligne de résultat de Tomates, dans le rayon [rayon].
    Future<void> pumpResultRow(
      WidgetTester tester, {
      required double scale,
      required double width,
      required Rayon rayon,
      required int quantity,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: KadiTheme.light,
          home: Scaffold(
            body: SearchResultRow(
              article: CatalogueArticle(
                id: 'a',
                name: 'Tomates',
                rayon: rayon,
                unit: Unit.piece,
                pictoKey: 'tomates',
              ),
              inList: true,
              line: ListeItem(
                lineId: 'l',
                articleId: 'a',
                name: 'Tomates',
                rayon: rayon,
                unit: Unit.piece,
                quantity: quantity,
              ),
              onTap: () {},
              onQuantityTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('police normale : comme un fréquent, sans rayon écrit', (
      tester,
    ) async {
      await pumpResultRow(
        tester,
        scale: 1,
        width: 412,
        rayon: Rayon.cremerie,
        quantity: 2000,
      );

      expect(find.text(Rayon.cremerie.label), findsNothing);
      expect(_tag(find.byType(SearchResultRow)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('police ×1,3 sur 412 dp : la coche d’une ligne dans la liste '
        'est alignée sur le + d’une ligne hors liste, le tag plafonné', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 800);
      addTearDown(tester.view.reset);
      CatalogueArticle article(String id, String name) => CatalogueArticle(
        id: id,
        name: name,
        rayon: Rayon.cremerie,
        unit: Unit.piece,
        pictoKey: id,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KadiTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                FrequentRow(
                  article: article('a', 'Lait'),
                  inList: true,
                  line: const ListeItem(
                    lineId: 'l',
                    articleId: 'a',
                    name: 'Lait',
                    rayon: Rayon.cremerie,
                    unit: Unit.piece,
                    quantity: 999000,
                  ),
                  onTap: () {},
                  onQuantityTap: (_) {},
                ),
                FrequentRow(
                  article: article('b', 'Beurre'),
                  inList: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getCenter(_indicator(_frequent('Lait'), Icons.check)).dx,
        tester.getCenter(_indicator(_frequent('Beurre'), Icons.add)).dx,
      );
      expect(
        tester.getSize(_tag(_frequent('Lait'))).width,
        lessThanOrEqualTo(KadiSpacing.tagMaxWidth),
      );
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.3, 2.0, 3.0]) {
      testWidgets('police ×$scale, écran étroit : la ligne tient avec son '
          'tag, sans rayon écrit', (tester) async {
        await pumpResultRow(
          tester,
          scale: scale,
          width: 360,
          rayon: Rayon.fruitsLegumes,
          quantity: 999000,
        );

        expect(_tag(find.byType(SearchResultRow)), findsOneWidget);
        expect(find.text(Rayon.fruitsLegumes.label), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('la popup', () {
    testWidgets('s’ouvre au-dessus du haut du panneau, aux marges, sans rayon '
        'ni Supprimer, sans feuille de plus, et ne touche pas la ligne', (
      tester,
    ) async {
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _scrollTo(tester, 'Tomates');
      final before = await _snapshot(db);

      await _openPopup(tester, _frequent('Tomates'));

      expect(_popup, findsOneWidget);
      expect(_sheet, findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(ItemEditSheet), findsNothing);
      expect(_inPopup(find.byType(RayonPicker)), findsNothing);
      expect(find.text(StringsFr.rayon), findsNothing);
      expect(_inPopup(find.text(StringsFr.supprimer)), findsNothing);
      expect(await _snapshot(db), before);

      final panelTop = _panel(tester).top!;
      expect(tester.getBottomLeft(_card).dy, closeTo(panelTop - 8, 0.01));
      // Calée sur la marge gauche de la carte du panneau, compacte.
      expect(tester.getTopLeft(_card).dx, KadiSpacing.s2 + KadiSpacing.margin);
      expect(tester.getSize(_card).width, KadiSpacing.addPopupMaxWidth);
      expect(tester.getTopLeft(_card).dy, greaterThanOrEqualTo(0));

      final theme = Theme.of(tester.element(_popup));
      final card = tester.widget<Material>(_card);
      final shape = card.shape! as RoundedRectangleBorder;
      expect(card.color, theme.colorScheme.surfaceContainerHigh);
      expect(card.elevation, 0);
      expect(shape.side, BorderSide.none);
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(KadiRadius.lg)),
      );

      // Sans titre visible ; Valider à côté du champ.
      expect(_inPopup(find.text('Tomates')), findsNothing);
      final submit = _inPopup(find.byType(SubmitButton));
      expect(submit, findsOneWidget);
      expect(
        tester.getCenter(submit).dy,
        closeTo(tester.getCenter(_field).dy, 1),
      );
      expect(
        tester.getTopLeft(submit).dx,
        greaterThan(tester.getTopRight(_field).dx),
      );
      expect(_focused(tester, _field), isTrue);
      // Le focus automatique ne montre pas la poignée du curseur.
      final editable = tester.state<EditableTextState>(
        find.descendant(of: _field, matching: find.byType(EditableText)),
      );
      expect(editable.selectionOverlay?.handlesAreVisible ?? false, isFalse);
      expect(_chips, findsNWidgets(InputUnit.values.length));
      // Tomates est en g : la puce g est préchoisie.
      expect(tester.widget<ChoiceChip>(_chip(InputUnit.g)).selected, isTrue);

      final route = ModalRoute.of(tester.element(_popup))!;
      expect(route, isA<PopupRoute<QuantityEdit>>());
      expect(route.barrierColor!.a, 0);
      expect(route.barrierDismissible, isTrue);
      expect(route.navigator, Navigator.of(tester.element(_sheet)));
    });

    testWidgets('« 2 » puis Entrée : popup fermée, tag « 2 pièces », Liste à '
        'jour, une seule écriture manuelle, aucun surlignage', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      final contributions =
          (await db.select(db.listContributions).get()).length;

      await _openPopup(tester, _frequent('Lait'));
      expect(
        tester.widget<ChoiceChip>(_chip(InputUnit.piece)).selected,
        isTrue,
      );
      await _type(tester, '2');
      await _pressEnter(tester);

      expect(_popup, findsNothing);
      expect(_sheet, findsOneWidget);
      final two = formatQuantity(2000, Unit.piece);
      expect(
        find.descendant(of: _tag(_frequent('Lait')), matching: find.text(two)),
        findsOneWidget,
      );
      expect(_listRowWith('Lait', two), findsOneWidget);

      final line = (await _lines(db, SeedIds.lait)).single;
      expect(line.unit, 'piece');
      expect(line.manualAt, isNotNull);
      expect(await _quantity(db, line.id), 2000);
      expect(
        await db.select(db.listContributions).get(),
        hasLength(contributions + 1),
      );

      final highlight = tester.widget<RowHighlight>(
        find.ancestor(
          of: _listRow('Lait'),
          matching: find.byType(RowHighlight),
        ),
      );
      expect(highlight.arriving, isFalse);
      expect(highlight.replays, 0);
    });

    testWidgets('échec d’écriture : snackbar dans le panneau, tag inchangé', (
      tester,
    ) async {
      final db = await _pumpTall(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      _failContributions(db);
      await _openPanel(tester);

      await _openPopup(tester, _frequent('Lait'));
      await _type(tester, '2');
      await _pressEnter(tester);

      expect(_popup, findsNothing);
      expect(
        _inSheet(find.text(StringsFr.modificationImpossible)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _tag(_frequent('Lait')),
          matching: find.text(StringsFr.qte),
        ),
        findsOneWidget,
      );
      await _letSnackBarClose(tester);
    });

    testWidgets('Lait à 2, champ vidé, tap hors de la carte : tag « Qté », '
        'Liste sans quantité', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(
        db,
        Clock(),
      ).addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _openPopup(tester, _frequent('Lait'));
      expect(_fieldText(tester), '2');
      await _type(tester, '');
      await _tapOutside(tester);

      expect(_popup, findsNothing);
      expect(_sheet, findsOneWidget);
      expect(
        find.descendant(
          of: _tag(_frequent('Lait')),
          matching: find.text(StringsFr.qte),
        ),
        findsOneWidget,
      );
      final two = formatQuantity(2000, Unit.piece);
      expect(_listRowWith('Lait', two), findsNothing);
      final line = (await _lines(db, SeedIds.lait)).single;
      expect(line.unit, isNull);
      expect(await _quantity(db, line.id), isNull);
    });

    for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
      ('tap hors de la carte', _tapOutside),
      ('retour', _pressBack),
      ('Entrée', _pressEnter),
    ]) {
      testWidgets('ouverte puis fermée sans saisie par $name : aucune '
          'écriture, même sur un texte préchargé arrondi', (tester) async {
        final db = await _pumpTall(tester);
        final repo = ListeRepository(db, Clock());
        // 1,5 pièce : le champ préchargé dit « 2 ».
        await repo.addArticle(SeedIds.lait, quantity: 1500, unit: Unit.piece);
        await repo.addArticle(SeedIds.tomates);
        await tester.pumpAndSettle();
        await _openPanel(tester);
        final before = await _snapshot(db);

        await _openPopup(tester, _frequent('Lait'));
        expect(_fieldText(tester), '2');
        await close(tester);

        expect(_popup, findsNothing);
        expect(await _snapshot(db), before);
        final line = (await _lines(db, SeedIds.lait)).single;
        expect(line.manualAt, isNull);
      });
    }

    testWidgets('saisie égale à la valeur : aucune écriture', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(
        db,
        Clock(),
      ).addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      final before = await _snapshot(db);

      await _openPopup(tester, _frequent('Lait'));
      await _type(tester, '3');
      await _type(tester, '2');
      await _pressBack(tester);

      expect(await _snapshot(db), before);
    });

    testWidgets('Tomates 500 g, puce kg, « 1,5 », retour : tag « 1,5 kg », '
        'enregistré en g ; le panneau reste ouvert', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(
        db,
        Clock(),
      ).addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _openPopup(tester, _frequent('Tomates'));
      await _tap(tester, _chip(InputUnit.kg));
      expect(tester.widget<ChoiceChip>(_chip(InputUnit.kg)).selected, isTrue);
      await _type(tester, '1,5');
      await _pressBack(tester);

      expect(_popup, findsNothing);
      expect(_sheet, findsOneWidget);
      final line = (await _lines(db, SeedIds.tomates)).single;
      expect(line.unit, 'g');
      expect(await _quantity(db, line.id), 1500);
      expect(
        find.descendant(
          of: _tag(_frequent('Tomates')),
          matching: find.text(formatQuantity(1500, Unit.g)),
        ),
        findsOneWidget,
      );
      expect(formatQuantity(1500, Unit.g).replaceAll(' ', ' '), '1,5 kg');
    });

    testWidgets(
      'Tomates 300 g et 2 pièces, la plus ancienne passée en pièces : '
      'une seule ligne fusionnée, tag à jour',
      (tester) async {
        final db = await _pumpTall(tester);
        final repo = ListeRepository(db, Clock());
        final oldest = await repo.addArticle(
          SeedIds.tomates,
          quantity: 300,
          unit: Unit.g,
        );
        await repo.addArticle(
          SeedIds.tomates,
          quantity: 2000,
          unit: Unit.piece,
        );
        await tester.pumpAndSettle();
        await _openPanel(tester);

        await _openPopup(tester, _frequent('Tomates'));
        expect(_fieldText(tester), '300');
        await _tap(tester, _chip(InputUnit.piece));
        await _type(tester, '1');
        await _pressEnter(tester);

        final line = (await _lines(db, SeedIds.tomates)).single;
        expect(line.id, oldest.lineId);
        expect(line.unit, 'piece');
        expect(await _quantity(db, line.id), 3000);
        expect(
          find.descendant(
            of: _tag(_frequent('Tomates')),
            matching: find.text(formatQuantity(3000, Unit.piece)),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('fermée : le panneau reste ouvert, le Champ d’ajout reprend le '
        'focus et le clavier', (tester) async {
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await tester.enterText(_search, 'tomates');
      await tester.pumpAndSettle();
      expect(_focused(tester, _search), isTrue);

      await _openPopup(tester, _result('Tomates'));
      expect(_focused(tester, _field), isTrue);
      expect(_focused(tester, _search), isFalse);

      await _pressBack(tester);

      expect(_sheet, findsOneWidget);
      expect(_focused(tester, _search), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets(
      'fermée après Entrée : le Champ d’ajout reprend aussi le focus',
      (tester) async {
        final db = await _pumpPhone(tester);
        await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
        await tester.pumpAndSettle();
        await _openPanel(tester);
        await tester.enterText(_search, 'tomates');
        await tester.pumpAndSettle();

        await _openPopup(tester, _result('Tomates'));
        await _type(tester, '250');
        await _pressEnter(tester);

        expect(_sheet, findsOneWidget);
        expect(_focused(tester, _search), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      },
    );

    testWidgets('fermée, clavier fermé avant : le Champ d’ajout ne prend pas '
        'le focus qu’il n’avait pas', (tester) async {
      final db = await _pumpPhone(tester, keyboard: 0);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _scrollTo(tester, 'Tomates');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_focused(tester, _search), isFalse);

      await _openPopup(tester, _frequent('Tomates'));
      expect(_focused(tester, _field), isTrue);
      await _pressBack(tester);

      expect(_sheet, findsOneWidget);
      expect(_focused(tester, _search), isFalse);
    });

    testWidgets('le clavier s’ouvre puis se ferme : le panneau bouge, la carte '
        'le suit', (tester) async {
      final db = await _pumpPhone(tester, keyboard: 0);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _scrollTo(tester, 'Tomates');
      await _openPopup(tester, _frequent('Tomates'));
      final lowTop = _panel(tester).top!;
      expect(tester.getBottomLeft(_card).dy, closeTo(lowTop - 8, 0.01));

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();

      final highTop = _panel(tester).top!;
      expect(highTop, isNot(lowTop));
      expect(tester.getBottomLeft(_card).dy, closeTo(highTop - 8, 0.01));
      expect(tester.getTopLeft(_card).dy, greaterThanOrEqualTo(0));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(tester.getBottomLeft(_card).dy, closeTo(lowTop - 8, 0.01));
    });

    testWidgets('marge haute du téléphone : la carte reste dessous', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 40);
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _scrollTo(tester, 'Tomates');

      await _openPopup(tester, _frequent('Tomates'));

      expect(tester.getTopLeft(_card).dy, greaterThanOrEqualTo(40));
      expect(
        tester.getBottomLeft(_card).dy,
        closeTo(_panel(tester).top! - 8, 0.01),
      );
    });

    testWidgets('écran couché, panneau sans place au-dessus : la carte reste '
        'sous la marge haute et au-dessus du clavier', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.reset);
      final db = await pumpKadi(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await tester.tap(_inSheet(find.byType(QuantityTag)).first);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(_card).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomLeft(_card).dy, lessThanOrEqualTo(360 - 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('très grande police : la carte défile, le champ reste '
        'atteignable, rien ne déborde', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpPhone(tester);
      await _openPanel(tester);

      unawaited(
        showQuantityPopup(
          tester.element(_sheet),
          title: 'Tomates',
          initialUnit: InputUnit.g,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(_card).dy, greaterThanOrEqualTo(0));
      expect(
        tester.getBottomLeft(_card).dy,
        closeTo(_panel(tester).top! - 8, 0.01),
      );
      expect(_inPopup(find.byType(SingleChildScrollView)), findsOneWidget);
      expect(_focused(tester, _field), isTrue);
    });

    testWidgets('fondu et léger zoom depuis le bord bas, qui ne bouge pas', (
      tester,
    ) async {
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _scrollTo(tester, 'Tomates');

      await tester.tap(_tag(_frequent('Tomates')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final fade = tester.widget<FadeTransition>(
        _inPopup(find.byType(FadeTransition)).first,
      );
      final scale = tester.widget<ScaleTransition>(
        _inPopup(find.byType(ScaleTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(scale.scale.value, inExclusiveRange(0.9, 1));
      expect(scale.alignment, Alignment.bottomLeft);
      expect(
        tester.getBottomLeft(_card).dy,
        closeTo(_panel(tester).top! - 8, 0.01),
      );

      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(scale.scale.value, 1);
    });

    testWidgets('animations coupées : apparition immédiate', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _scrollTo(tester, 'Tomates');

      await tester.tap(_tag(_frequent('Tomates')));
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        _inPopup(find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1);
      expect(
        tester
            .widget<ScaleTransition>(
              _inPopup(find.byType(ScaleTransition)).first,
            )
            .scale
            .value,
        1,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('deux taps rapides sur le tag : une seule popup', (
      tester,
    ) async {
      final db = await _pumpTall(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      final tag = tester.widget<QuantityTag>(_tag(_frequent('Lait')));
      tag.onTap();
      tag.onTap();
      await tester.pumpAndSettle();

      expect(_popup, findsOneWidget);
      await _pressBack(tester);
      expect(_popup, findsNothing);
      expect(_sheet, findsOneWidget);
    });

    testWidgets('Entrée reçue deux fois : la popup se ferme, pas le panneau', (
      tester,
    ) async {
      final db = await _pumpTall(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      await _openPopup(tester, _frequent('Lait'));

      final onSubmitted = tester.widget<TextField>(_field).onSubmitted!;
      onSubmitted('');
      onSubmitted('');
      await tester.pumpAndSettle();

      expect(_popup, findsNothing);
      expect(_sheet, findsOneWidget);
    });
  });

  group('showQuantityPopup', () {
    /// Panneau ouvert ; rend le contexte d'où ouvrir la popup.
    Future<BuildContext> open(WidgetTester tester) async {
      await _pumpTall(tester);
      await _openPanel(tester);
      return tester.element(_sheet);
    }

    testWidgets('fermée sans saisie : null, « inchangé »', (tester) async {
      final context = await open(tester);

      final result = showQuantityPopup(
        context,
        title: 'Lait',
        quantity: 500,
        unit: Unit.g,
        initialUnit: InputUnit.g,
      );
      await tester.pumpAndSettle();
      await _pressBack(tester);

      expect(await result, isNull);
    });

    testWidgets('saisie sans quantité de départ : la valeur stockée', (
      tester,
    ) async {
      final context = await open(tester);

      final result = showQuantityPopup(
        context,
        title: StringsFr.quantite,
        initialUnit: InputUnit.kg,
      );
      await tester.pumpAndSettle();
      await _type(tester, '1,5');
      await _pressEnter(tester);

      expect(await result, (value: (quantity: 1500, unit: Unit.g)));
    });

    testWidgets('champ vidé : une valeur vide, distincte d’« inchangé »', (
      tester,
    ) async {
      final context = await open(tester);

      final result = showQuantityPopup(
        context,
        title: 'Lait',
        quantity: 500,
        unit: Unit.g,
        initialUnit: InputUnit.g,
      );
      await tester.pumpAndSettle();
      await _type(tester, '');
      await _tapOutside(tester);

      final edit = await result;
      expect(edit, isNotNull);
      expect(edit!.value, isNull);
    });
  });
}
