import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/liste/ui/quantity_popup.dart';
import 'package:kadi/features/liste/ui/quantity_tag.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/liste/ui/rayon_tag.dart';
import 'package:kadi/features/liste/ui/row_highlight.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

const _keyboard = 300.0;

/// Id de l'article Piles fourni.
const _pilesFourni = '647841c6-7cff-40f4-a8dd-69d7e781eb8b';

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
Finder get _search => _inSheet(find.byType(TextField)).first;

/// Le Tag Quantité du champ, pas celui d'une ligne.
final _quantityTag = find.byWidgetPredicate(
  (w) => w is QuantityTag && w.emptyLabel == StringsFr.quantite,
);
final _rayonTag = find.byType(RayonTag);
final _title = _inSheet(find.byType(FrequentsTitle));
final _menuEntries = find.byType(MenuItemButton);
Finder _menuEntry(Rayon rayon) => find.byKey(ValueKey(rayon));

final _popup = find.byType(QuantityPopup);
Finder get _popupField =>
    find.descendant(of: _popup, matching: find.byType(TextField));
final _undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);

Finder _frequent(String name) => find.widgetWithText(FrequentRow, name);
Finder _result(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SearchResultRow));
Finder _row(String name) => find.widgetWithText(ItemRow, name);
Finder _inTag(Finder tag, String text) =>
    find.descendant(of: tag, matching: find.text(text));

/// La puce visible du tag [tag], sans sa cible de 48 dp.
Finder _chip(Finder tag) =>
    find.descendant(of: tag, matching: find.byType(Material)).first;

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _closePanel(WidgetTester tester) async {
  Navigator.of(tester.element(_sheet)).pop();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Ouvre le Tag Rayon et y choisit [rayon], après défilement du menu.
Future<void> _chooseRayon(WidgetTester tester, Rayon rayon) async {
  await _tap(tester, _rayonTag);
  await tester.ensureVisible(_menuEntry(rayon));
  await tester.pumpAndSettle();
  await _tap(tester, _menuEntry(rayon));
}

/// Règle le Tag Quantité : [text] tapé dans la popup, puis Entrée.
Future<void> _setQuantity(WidgetTester tester, String text) async {
  await _tap(tester, _quantityTag);
  await tester.enterText(_popupField, text);
  await tester.pump();
  await _enter(tester);
}

/// Laisse se fermer le snackbar ouvert.
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
    tester.widget<TextField>(_search).controller!.text;

/// Les deux tags sont revenus à zéro.
void _expectTagsAtZero(WidgetTester tester, {required String rayon}) {
  expect(_inTag(_quantityTag, StringsFr.quantite), findsOneWidget);
  expect(_inTag(_rayonTag, rayon), findsOneWidget);
  expect(tester.widget<RayonTag>(_rayonTag).chosen, isFalse);
}

/// « piles » absent du catalogue : l'article fourni est supprimé.
Future<void> _withoutPiles(WidgetTester tester, AppDatabase db) async {
  await (db.update(db.articles)..where((a) => a.id.equals(_pilesFourni))).write(
    const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
  );
  await tester.pumpAndSettle();
}

Future<Article> _articleNamed(AppDatabase db, String normalized) =>
    (db.select(db.articles)..where(
          (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
        ))
        .getSingle();

/// Lignes actives non cochées de [articleId].
Future<List<ListLine>> _lines(AppDatabase db, String articleId) =>
    (db.select(db.listLines)..where(
          (l) =>
              l.articleId.equals(articleId) &
              l.deletedAt.isNull() &
              l.checkedAt.isNull(),
        ))
        .get();

Future<List<ListContribution>> _contributions(AppDatabase db, String lineId) =>
    (db.select(
      db.listContributions,
    )..where((c) => c.lineId.equals(lineId) & c.deletedAt.isNull())).get();

/// Toutes les lignes, contributions et articles : rien ne doit bouger.
Future<List<Object>> _snapshot(AppDatabase db) async => [
  ...await db.select(db.listLines).get(),
  ...await db.select(db.listContributions).get(),
  ...await db.select(db.articles).get(),
];

/// Le fond surligné de la ligne [name] se joue.
Finder _highlight(String name) =>
    find.ancestor(of: _row(name), matching: find.byType(RowHighlight));

void _failAdds(AppDatabase db) => db.customStatement(
  'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
  "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
);

void _failContributions(AppDatabase db) => db.customStatement(
  'CREATE TRIGGER no_contribution BEFORE INSERT ON list_contributions '
  "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
);

void main() {
  final twoPieces = formatQuantity(2000, Unit.piece);

  group('les tags sous le champ', () {
    testWidgets('sous le Champ d’ajout, le titre des fréquents après ; cible '
        'de 48 dp, puce de 32 dp, en contour', (tester) async {
      await _pumpPhone(tester);
      await _openPanel(tester);

      final fieldBottom = tester.getBottomLeft(_search).dy;
      for (final tag in [_quantityTag, _rayonTag]) {
        expect(tag, findsOneWidget);
        expect(tester.getTopLeft(tag).dy, greaterThanOrEqualTo(fieldBottom));
        expect(
          tester.getBottomLeft(tag).dy,
          lessThanOrEqualTo(tester.getTopLeft(_title).dy),
        );
        expect(tester.getSize(tag).height, KadiSpacing.touchTarget);
        expect(tester.getSize(_chip(tag)).height, KadiSpacing.tagHeight);
      }
      expect(
        tester.getCenter(_quantityTag).dx,
        lessThan(tester.getCenter(_rayonTag).dx),
      );
      // Puces alignées sur le Champ d'ajout.
      expect(tester.getTopLeft(_chip(_quantityTag)).dx, KadiSpacing.margin);

      final theme = Theme.of(tester.element(_rayonTag));
      final divers = KadiColors.of(tester.element(_rayonTag))
          .rayon(Rayon.divers);
      expect(_inTag(_quantityTag, StringsFr.quantite), findsOneWidget);
      expect(_inTag(_rayonTag, Rayon.divers.label), findsOneWidget);
      expect(
        find.descendant(
          of: _rayonTag,
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
      );
      final chip = tester.widget<Material>(_chip(_rayonTag));
      final shape = chip.shape! as RoundedRectangleBorder;
      expect(chip.color, Colors.transparent);
      expect(shape.side.color, theme.colorScheme.outline);
      expect(shape.borderRadius, BorderRadius.circular(KadiRadius.sm));
      final dot = tester.widget<Container>(
        find.descendant(of: _rayonTag, matching: find.byType(Container)),
      );
      expect((dot.decoration! as BoxDecoration).color, divers.accent);
    });

    testWidgets(
      'TalkBack : « Quantité, aucune », « Quantité, 500 g », « Rayon, '
      'Divers », rayon parlé, boutons',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpTall(tester);
        await _openPanel(tester);

        expect(
          tester.getSemantics(find.bySemanticsLabel('Quantité, aucune')),
          isSemantics(
            label: 'Quantité, aucune',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Rayon, Divers')),
          isSemantics(
            label: 'Rayon, Divers',
            isButton: true,
            hasTapAction: true,
          ),
        );

        await _tap(tester, _quantityTag);
        await tester.enterText(_popupField, '500');
        await tester.pump();
        await _tap(tester, find.byKey(const ValueKey(InputUnit.g)));
        await _enter(tester);
        final value = StringsFr.quantiteTag(formatQuantity(500, Unit.g));
        expect(value.replaceAll(' ', ' '), 'Quantité, 500 g');
        expect(find.bySemanticsLabel(value), findsOneWidget);

        await _chooseRayon(tester, Rayon.fruitsLegumes);
        expect(
          find.bySemanticsLabel('Rayon, Fruits et légumes'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('rien n’est écrit avant l’ajout', (tester) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);
      final before = await _snapshot(db);

      await _type(tester, 'lait');
      await _setQuantity(tester, '2');
      await _chooseRayon(tester, Rayon.boissons);

      expect(await _snapshot(db), before);
      await _closePanel(tester);
      expect(await _snapshot(db), before);
    });
  });

  group('le Tag Rayon', () {
    testWidgets(
      '« lait » : Crèmerie en contour ; Entrée : ligne sous Crèmerie, '
      'tag de nouveau Divers',
      (tester) async {
        final db = await _pumpTall(tester);
        await _openPanel(tester);

        await _type(tester, 'lait');

        _expectTagsAtZero(tester, rayon: Rayon.cremerie.label);
        final dot = tester.widget<Container>(
          find.descendant(of: _rayonTag, matching: find.byType(Container)),
        );
        expect(
          (dot.decoration! as BoxDecoration).color,
          KadiColors.of(tester.element(_rayonTag)).rayon(Rayon.cremerie).accent,
        );

        await _enter(tester);

        expect(
          (await _lines(db, SeedIds.lait)).single.rayon,
          Rayon.cremerie.code,
        );
        _expectTagsAtZero(tester, rayon: Rayon.divers.label);
      },
    );

    testWidgets('casse et accents ignorés ; nom partiel : Divers', (
      tester,
    ) async {
      await _pumpTall(tester);
      await _openPanel(tester);

      await _type(tester, 'lai');
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);

      await _type(tester, 'LÂIT');
      _expectTagsAtZero(tester, rayon: Rayon.cremerie.label);

      await _type(tester, ' oeufs ');
      _expectTagsAtZero(tester, rayon: Rayon.cremerie.label);

      await _type(tester, 'xyz');
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
    });

    testWidgets('choisi : plein au fond de pastille, il prime sur l’article et '
        'reste quand le texte change', (tester) async {
      await _pumpTall(tester);
      await _openPanel(tester);
      await _type(tester, 'lait');

      await _chooseRayon(tester, Rayon.boissons);

      final context = tester.element(_rayonTag);
      final chip = tester.widget<Material>(_chip(_rayonTag));
      expect(chip.color, KadiColors.of(context).rayon(Rayon.boissons).pastille);
      expect((chip.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(tester.widget<RayonTag>(_rayonTag).chosen, isTrue);
      final label = tester.widget<Text>(
        _inTag(_rayonTag, Rayon.boissons.label),
      );
      expect(label.style!.color, Theme.of(context).colorScheme.onSurface);

      await _type(tester, 'beurre');
      expect(_inTag(_rayonTag, Rayon.boissons.label), findsOneWidget);
    });

    testWidgets('menu : 13 pastilles dans l’ordre du parcours, au-dessus du '
        'tag, hauteur plafonnée, qui défile', (tester) async {
      final db = await _pumpPhone(tester);
      final route = [
        Rayon.boissons,
        ...Rayon.values.where((r) => r != Rayon.boissons),
      ];
      await db
          .update(db.settings)
          .write(
            SettingsCompanion(
              routeOrder: Value(SettingsRepository.encodeRouteOrder(route)),
            ),
          );
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _tap(tester, _rayonTag);

      expect(_menuEntries, findsNWidgets(Rayon.values.length));
      expect(
        tester
            .widgetList<RayonPastille>(
              find.descendant(
                of: _menuEntries,
                matching: find.byType(RayonPastille),
              ),
            )
            .map((p) => p.rayon),
        route,
      );
      final panel = find.ancestor(
        of: _menuEntries.first,
        matching: find.byType(SingleChildScrollView),
      );
      final menu = find
          .ancestor(of: panel.first, matching: find.byType(Material))
          .first;
      expect(
        tester.getBottomLeft(menu).dy,
        lessThanOrEqualTo(tester.getTopLeft(_chip(_rayonTag)).dy),
      );
      expect(tester.getTopLeft(menu).dy, greaterThanOrEqualTo(0));
      expect(tester.getSize(menu).height, lessThanOrEqualTo(264));

      final scroll = tester.state<ScrollableState>(
        find
            .descendant(of: panel.first, matching: find.byType(Scrollable))
            .first,
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(
        tester.getSize(_menuEntries.first).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets(
      'clavier ouvert : ouvrir le menu et choisir gardent le focus du '
      'champ et le clavier',
      (tester) async {
        await _pumpPhone(tester);
        await _openPanel(tester);
        await _type(tester, 'lait');
        expect(_focused(tester, _search), isTrue);

        await _tap(tester, _rayonTag);
        expect(_focused(tester, _search), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.ensureVisible(_menuEntry(Rayon.hygiene));
        await tester.pumpAndSettle();
        expect(_focused(tester, _search), isTrue);

        await _tap(tester, _menuEntry(Rayon.hygiene));

        expect(_menuEntries, findsNothing);
        expect(_inTag(_rayonTag, Rayon.hygiene.label), findsOneWidget);
        expect(_focused(tester, _search), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(_fieldText(tester), 'lait');
      },
    );

    testWidgets('tap hors du menu : il se ferme seul, ni ajout ni panneau '
        'fermé ; second tap sur le tag aussi', (tester) async {
      final db = await _pumpPhone(tester);
      await _openPanel(tester);

      await _tap(tester, _rayonTag);
      expect(_menuEntries, findsNWidgets(13));
      await tester.tapAt(tester.getCenter(_frequent('Tomates')));
      await tester.pumpAndSettle();
      expect(_menuEntries, findsNothing);
      expect(await _lines(db, SeedIds.tomates), isEmpty);

      await _tap(tester, _rayonTag);
      await tester.tapAt(const Offset(400, 900));
      await tester.pumpAndSettle();
      expect(_menuEntries, findsNothing);
      expect(_sheet, findsOneWidget);

      await _tap(tester, _rayonTag);
      expect(_menuEntries, findsNWidgets(13));
      await _tap(tester, _rayonTag);
      expect(_menuEntries, findsNothing);
      expect(_sheet, findsOneWidget);
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
    });

    testWidgets('TalkBack : les entrées lues par leur nom parlé, activables', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpTall(tester);
      await _openPanel(tester);

      await _tap(tester, _rayonTag);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Fruits et légumes')),
        isSemantics(label: 'Fruits et légumes', hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('petit téléphone, marge haute : le menu raccourci reste '
        'au-dessus du tag, sous la marge', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.padding = const FakeViewPadding(top: 40);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.reset);
      await pumpKadi(tester);
      await _openPanel(tester);

      await _tap(tester, _rayonTag);

      final menu = find
          .ancestor(of: _menuEntries.first, matching: find.byType(Material))
          .first;
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(menu).dy, greaterThanOrEqualTo(40));
      expect(
        tester.getBottomLeft(menu).dy,
        lessThanOrEqualTo(tester.getTopLeft(_chip(_rayonTag)).dy),
      );
    });

    testWidgets('écran couché, peu de place : le menu reste à l’écran, sans '
        'débordement', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.reset);
      await pumpKadi(tester);
      await _openPanel(tester);

      await _tap(tester, _rayonTag);

      expect(tester.takeException(), isNull);
      expect(_menuEntries, findsNWidgets(13));
    });

    for (final scale in [1.3, 2.0, 3.0]) {
      testWidgets('police ×$scale sur 360 dp : tags et menu tiennent', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.reset);
        await pumpKadi(tester);
        await _openPanel(tester);

        await _type(tester, 'pomme de terre');
        await _chooseRayon(tester, Rayon.fruitsLegumes);

        expect(tester.takeException(), isNull);
        expect(_inTag(_rayonTag, Rayon.fruitsLegumes.label), findsOneWidget);

        await _tap(tester, _rayonTag);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'fermer le panneau par retour, menu ouvert : pas d’erreur, rien '
      'd’écrit',
      (tester) async {
        final db = await _pumpPhone(tester);
        await _openPanel(tester);
        final before = await _snapshot(db);

        await _tap(tester, _rayonTag);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(_sheet, findsNothing);
        expect(tester.takeException(), isNull);
        expect(await _snapshot(db), before);
      },
    );
  });

  group('le Tag Quantité', () {
    testWidgets('titre de la popup : le texte tapé, sinon « Quantité » ; unité '
        'de l’article au nom exact, sinon pièce', (tester) async {
      await _pumpTall(tester);
      await _openPanel(tester);

      await _tap(tester, _quantityTag);
      expect(
        find.descendant(of: _popup, matching: find.text(StringsFr.quantite)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey(InputUnit.piece)))
            .selected,
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await _type(tester, 'tom');
      await _tap(tester, _quantityTag);
      expect(
        find.descendant(of: _popup, matching: find.text('tom')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey(InputUnit.piece)))
            .selected,
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await _type(tester, 'tomates');
      await _tap(tester, _quantityTag);
      expect(
        find.descendant(of: _popup, matching: find.text('tomates')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey(InputUnit.g)))
            .selected,
        isTrue,
      );
    });

    for (final (name, close) in <(String, Future<void> Function(WidgetTester))>[
      ('Entrée', _enter),
      (
        'retour',
        (tester) async {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        },
      ),
    ]) {
      testWidgets('fermée par $name : le focus et le clavier reviennent au '
          'champ', (tester) async {
        await _pumpPhone(tester);
        await _openPanel(tester);

        await _tap(tester, _quantityTag);
        expect(_focused(tester, _popupField), isTrue);
        await tester.enterText(_popupField, '4');
        await tester.pump();
        await close(tester);

        expect(_popup, findsNothing);
        expect(_focused(tester, _search), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          _inTag(_quantityTag, formatQuantity(4000, Unit.piece)),
          findsOne,
        );
      });
    }

    testWidgets('clavier fermé avant : le champ reprend quand même le focus', (
      tester,
    ) async {
      await _pumpPhone(tester, keyboard: 0);
      await _openPanel(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_focused(tester, _search), isFalse);

      await _setQuantity(tester, '4');

      expect(_focused(tester, _search), isTrue);
    });

    testWidgets(
      'plein avec la valeur, rouvert sur elle ; vidé : « Quantité » en '
      'contour',
      (tester) async {
        await _pumpTall(tester);
        await _openPanel(tester);

        await _setQuantity(tester, '4');

        final four = formatQuantity(4000, Unit.piece);
        expect(_inTag(_quantityTag, four), findsOneWidget);
        final theme = Theme.of(tester.element(_quantityTag));
        final filled = tester.widget<Material>(_chip(_quantityTag));
        expect(filled.color, theme.colorScheme.onSurfaceVariant);

        await _tap(tester, _quantityTag);
        expect(tester.widget<TextField>(_popupField).controller!.text, '4');
        await tester.enterText(_popupField, '');
        await tester.pump();
        await _enter(tester);

        expect(_inTag(_quantityTag, StringsFr.quantite), findsOneWidget);
        final empty = tester.widget<Material>(_chip(_quantityTag));
        expect(empty.color, Colors.transparent);
      },
    );

    testWidgets('fermée sans saisie : le tag garde sa valeur', (tester) async {
      await _pumpTall(tester);
      await _openPanel(tester);
      await _setQuantity(tester, '4');

      await _tap(tester, _quantityTag);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        _inTag(_quantityTag, formatQuantity(4000, Unit.piece)),
        findsOneWidget,
      );
    });
  });

  group('Entrée', () {
    testWidgets('« piles », Entretien, 4 pièces : « Piles 4 » sous Entretien, '
        'champ vidé, clavier ouvert, tags à zéro ; puis retirée et retapée : '
        'Divers, sans quantité', (tester) async {
      final db = await _pumpTall(tester);
      await _withoutPiles(tester, db);
      await _openPanel(tester);

      await _type(tester, 'piles');
      await _chooseRayon(tester, Rayon.entretien);
      await _setQuantity(tester, '4');
      await _enter(tester);

      final piles = await _articleNamed(db, 'piles');
      expect(piles.rayon, 'divers');
      expect(piles.unit, isNull);
      expect(piles.inCatalogue, isFalse);
      final line = (await _lines(db, piles.id)).single;
      expect(line.rayon, Rayon.entretien.code);
      expect(line.manualAt, isNull);
      final contribution = (await _contributions(db, line.id)).single;
      expect(contribution.source, ContributionSource.ajout);
      expect(contribution.quantity, 4000);

      expect(_fieldText(tester), isEmpty);
      expect(_focused(tester, _search), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
      expect(
        tester.getTopLeft(_row('Piles')).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.widgetWithText(RayonHeader, Rayon.entretien.label),
              )
              .dy,
        ),
      );
      expect(
        find.descendant(
          of: _row('Piles'),
          matching: find.text(formatQuantity(4000, Unit.piece)),
        ),
        findsOneWidget,
      );

      await ListeRepository(db, Clock()).removeArticle(piles.id);
      await tester.pumpAndSettle();

      await _type(tester, 'piles');
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
      await _enter(tester);

      final again = (await _lines(db, piles.id)).single;
      expect(again.rayon, 'divers');
      expect(again.unit, isNull);
    });

    testWidgets('« lait », Boissons : ligne sous Boissons, l’article reste en '
        'Crèmerie ; ajout suivant de nouveau sous Crèmerie', (tester) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);
      final before = await _articleNamed(db, 'lait');

      await _type(tester, 'lait');
      await _chooseRayon(tester, Rayon.boissons);
      await _enter(tester);

      expect(
        (await _lines(db, SeedIds.lait)).single.rayon,
        Rayon.boissons.code,
      );
      expect(await _articleNamed(db, 'lait'), before);

      await ListeRepository(db, Clock()).removeArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _type(tester, 'lait');
      await _enter(tester);

      expect(
        (await _lines(db, SeedIds.lait)).single.rayon,
        Rayon.cremerie.code,
      );
    });

    testWidgets('Lait présent à 1 pièce, tag 2 : une seule ligne à 2, montrée '
        'et surlignée, tags à zéro', (tester) async {
      final db = await _pumpPhone(tester);
      final added = await ListeRepository(
        db,
        Clock(),
      ).addArticle(SeedIds.lait, quantity: 1000, unit: Unit.piece);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _type(tester, 'lait');
      await _setQuantity(tester, '2');
      await _enter(tester);

      final line = (await _lines(db, SeedIds.lait)).single;
      expect(line.id, added.lineId);
      expect(line.manualAt, isNotNull);
      expect((await _contributions(db, line.id)).single.quantity, 2000);
      expect(
        find.descendant(of: _row('Lait'), matching: find.text(twoPieces)),
        findsOneWidget,
      );
      expect(tester.widget<RowHighlight>(_highlight('Lait')).replays, 1);
      expect(_fieldText(tester), isEmpty);
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
    });

    testWidgets(
      'Lait présent, Boissons : ligne déplacée, sans autre changement '
      'et surlignée',
      (tester) async {
        final db = await _pumpPhone(tester);
        final added = await ListeRepository(
          db,
          Clock(),
        ).addArticle(SeedIds.lait, quantity: 1000, unit: Unit.piece);
        await tester.pumpAndSettle();
        await _openPanel(tester);
        final contributions = await _contributions(db, added.lineId);

        await _type(tester, 'lait');
        await _chooseRayon(tester, Rayon.boissons);
        await _enter(tester);

        final line = (await _lines(db, SeedIds.lait)).single;
        expect(line.rayon, Rayon.boissons.code);
        expect(line.manualAt, isNull);
        expect(await _contributions(db, line.id), contributions);
        expect(
          tester.getTopLeft(_row('Lait')).dy,
          greaterThan(
            tester
                .getTopLeft(
                  find.widgetWithText(RayonHeader, Rayon.boissons.label),
                )
                .dy,
          ),
        );
        expect(tester.widget<RowHighlight>(_highlight('Lait')).replays, 1);
        _expectTagsAtZero(tester, rayon: Rayon.divers.label);
      },
    );

    /// Lait, le plus ancien, puis 30 lignes de Fruits & légumes : Lait, en
    /// Crèmerie, est tout en bas ; passé en Fruits & légumes, il est en tête.
    Future<ListeRepository> fillBelowLait(
      WidgetTester tester,
      AppDatabase db,
    ) async {
      final repo = ListeRepository(db, Clock());
      await repo.addArticle(SeedIds.lait);
      final fruits =
          await (db.select(db.articles)
                ..where(
                  (a) =>
                      a.rayon.equals(Rayon.fruitsLegumes.code) &
                      a.deletedAt.isNull(),
                )
                ..limit(30))
              .get();
      for (final article in fruits) {
        await repo.addArticle(article.id);
      }
      await tester.pumpAndSettle();
      return repo;
    }

    /// La ligne de Lait est entièrement visible au-dessus du panneau.
    void expectLaitAbovePanel(WidgetTester tester) {
      final top = ProviderScope.containerOf(
        tester.element(find.byType(ListeScreen)),
        listen: false,
      ).read(listePanelProvider).top!;
      expect(
        tester.getTopLeft(_row('Lait')).dy,
        greaterThanOrEqualTo(kToolbarHeight),
      );
      expect(tester.getBottomLeft(_row('Lait')).dy, lessThanOrEqualTo(top + 1));
    }

    testWidgets('ligne déplacée loin de sa place : la Liste la montre à sa '
        'nouvelle place', (tester) async {
      final db = await _pumpPhone(tester);
      await fillBelowLait(tester, db);
      await _openPanel(tester);

      await _type(tester, 'lait');
      await _chooseRayon(tester, Rayon.fruitsLegumes);
      await _enter(tester);

      expectLaitAbovePanel(tester);
      expect(tester.widget<RowHighlight>(_highlight('Lait')).replays, 1);
    });

    testWidgets(
      'demande de montrer reçue avant le flux : la ligne est remontrée '
      'quand son rayon arrive',
      (tester) async {
        final db = await _pumpPhone(tester);
        final repo = await fillBelowLait(tester, db);
        final line = (await _lines(db, SeedIds.lait)).single;
        await _openPanel(tester);

        ProviderScope.containerOf(
          tester.element(find.byType(ListeScreen)),
          listen: false,
        ).read(listePanelProvider).reveal(line.id);
        await tester.pumpAndSettle();
        expectLaitAbovePanel(tester);

        await repo.setRayon(line.id, Rayon.fruitsLegumes);
        await tester.pumpAndSettle();

        expectLaitAbovePanel(tester);
      },
    );

    testWidgets('échec : snackbar, saisie et tags gardés', (tester) async {
      final db = await _pumpTall(tester);
      await _withoutPiles(tester, db);
      _failAdds(db);
      await _openPanel(tester);

      await _type(tester, 'piles');
      await _chooseRayon(tester, Rayon.entretien);
      await _setQuantity(tester, '4');
      await _enter(tester);

      expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
      expect(_fieldText(tester), 'piles');
      expect(_inTag(_rayonTag, Rayon.entretien.label), findsOneWidget);
      expect(tester.widget<RayonTag>(_rayonTag).chosen, isTrue);
      expect(
        _inTag(_quantityTag, formatQuantity(4000, Unit.piece)),
        findsOneWidget,
      );
      await _letSnackBarClose(tester);
    });

    testWidgets('présent, échec du remplacement : snackbar, saisie et tags '
        'gardés, ligne intacte', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(
        db,
        Clock(),
      ).addArticle(SeedIds.lait, quantity: 1000, unit: Unit.piece);
      _failContributions(db);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      final before = await _snapshot(db);

      await _type(tester, 'lait');
      await _setQuantity(tester, '2');
      await _enter(tester);

      expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
      expect(_fieldText(tester), 'lait');
      expect(_inTag(_quantityTag, twoPieces), findsOneWidget);
      expect(await _snapshot(db), before);
      await _letSnackBarClose(tester);
    });

    testWidgets('champ vide : rien, tags intacts', (tester) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);
      await _setQuantity(tester, '2');
      await _chooseRayon(tester, Rayon.boissons);
      final before = await _snapshot(db);

      await _enter(tester);

      expect(await _snapshot(db), before);
      expect(_inTag(_quantityTag, twoPieces), findsOneWidget);
      expect(_inTag(_rayonTag, Rayon.boissons.label), findsOneWidget);
    });

    testWidgets(
      '« xyz », Hygiène, tap sur « Ajouter « xyz » » : comme Entrée',
      (tester) async {
        final db = await _pumpTall(tester);
        await _openPanel(tester);

        await _type(tester, 'xyz');
        await _chooseRayon(tester, Rayon.hygiene);
        await _tap(tester, find.byType(AddTypedRow));

        final xyz = await _articleNamed(db, 'xyz');
        expect(xyz.rayon, 'divers');
        expect(xyz.inCatalogue, isFalse);
        expect((await _lines(db, xyz.id)).single.rayon, Rayon.hygiene.code);
        expect(_fieldText(tester), isEmpty);
        _expectTagsAtZero(tester, rayon: Rayon.divers.label);
      },
    );
  });

  group('les autres gestes', () {
    testWidgets('« lai », tag 2, tap sur Lait hors liste : Lait à 2, tags à '
        'zéro, le champ garde son texte', (tester) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);

      await _type(tester, 'lai');
      await _setQuantity(tester, '2');
      await _chooseRayon(tester, Rayon.boissons);
      await _tap(tester, _result('Lait'));

      final line = (await _lines(db, SeedIds.lait)).single;
      expect(line.rayon, Rayon.boissons.code);
      expect(line.manualAt, isNull);
      final contribution = (await _contributions(db, line.id)).single;
      expect(contribution.source, ContributionSource.ajout);
      expect(contribution.quantity, 2000);
      expect((await _articleNamed(db, 'lait')).rayon, Rayon.cremerie.code);

      expect(_fieldText(tester), 'lai');
      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
    });

    testWidgets('« lai », tag 2, tap sur Lait présent : retiré avec Annuler, '
        'tags intacts', (tester) async {
      final db = await _pumpTall(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _type(tester, 'lai');
      await _setQuantity(tester, '2');
      await _tap(tester, _result('Lait'));

      expect(await _lines(db, SeedIds.lait), isEmpty);
      expect(_inSheet(_undoAction), findsOneWidget);
      expect(_inTag(_quantityTag, twoPieces), findsOneWidget);
      await _letSnackBarClose(tester);
    });

    testWidgets('résultat, échec de l’écriture : snackbar, saisie et tags '
        'gardés', (tester) async {
      final db = await _pumpTall(tester);
      _failAdds(db);
      await _openPanel(tester);

      await _type(tester, 'lai');
      await _setQuantity(tester, '2');
      await _tap(tester, _result('Lait'));

      expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
      expect(_fieldText(tester), 'lai');
      expect(_inTag(_quantityTag, twoPieces), findsOneWidget);
      await _letSnackBarClose(tester);
    });

    testWidgets('tag 2 et Boissons, tap sur un fréquent : ajouté sans quantité '
        'sous son rayon, tags toujours là', (tester) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);
      await _setQuantity(tester, '2');
      await _chooseRayon(tester, Rayon.boissons);

      await _tap(tester, _frequent('Lait'));

      final line = (await _lines(db, SeedIds.lait)).single;
      expect(line.rayon, Rayon.cremerie.code);
      expect(line.unit, isNull);
      expect((await _contributions(db, line.id)).single.quantity, isNull);
      expect(_inTag(_quantityTag, twoPieces), findsOneWidget);
      expect(_inTag(_rayonTag, Rayon.boissons.label), findsOneWidget);
    });

    testWidgets('effacer le texte : tags intacts', (tester) async {
      await _pumpTall(tester);
      await _openPanel(tester);
      await _type(tester, 'lait');
      await _setQuantity(tester, '2');
      await _chooseRayon(tester, Rayon.boissons);

      await _tap(tester, find.byTooltip(StringsFr.effacerLeTexte));

      expect(_fieldText(tester), isEmpty);
      expect(_inTag(_quantityTag, twoPieces), findsOneWidget);
      expect(_inTag(_rayonTag, Rayon.boissons.label), findsOneWidget);
    });

    testWidgets('panneau fermé puis rouvert : tags à zéro, rien d’écrit', (
      tester,
    ) async {
      final db = await _pumpTall(tester);
      await _openPanel(tester);
      final before = await _snapshot(db);
      await _setQuantity(tester, '2');
      await _chooseRayon(tester, Rayon.boissons);

      await _closePanel(tester);
      expect(await _snapshot(db), before);
      await _openPanel(tester);

      _expectTagsAtZero(tester, rayon: Rayon.divers.label);
      expect(await _snapshot(db), before);
    });
  });
}
