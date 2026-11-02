import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_panel.dart';
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

/// Barre d'application sans marge haute dans les tests.
const _appBarBottom = kToolbarHeight;

/// Monte Kadi sur un téléphone de 412×914 dp, clavier de [keyboard] dp.
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

/// Ajoute 30 articles du rayon [rayon] à la Liste.
Future<void> _fill(WidgetTester tester, AppDatabase db, Rayon rayon) async {
  final articles =
      await (db.select(db.articles)
            ..where((a) => a.rayon.equals(rayon.code) & a.deletedAt.isNull())
            ..limit(30))
          .get();
  expect(articles, hasLength(30));
  final repo = ListeRepository(db, Clock());
  for (final article in articles) {
    await repo.addArticle(article.id);
  }
  await tester.pumpAndSettle();
}

final _sheet = find.byType(AddSheet);
Finder _inSheet(Finder finder) => find.descendant(of: _sheet, matching: finder);

/// Le corps du panneau, au-dessus du clavier (la feuille passe dessous).
final _body = _inSheet(find.byType(Scaffold));
final _undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);
final _search = _inSheet(find.byType(TextField));

Finder _frequent(String name) => find.widgetWithText(FrequentRow, name);
Finder _row(String name) => find.widgetWithText(ItemRow, name);

/// Partie visible de l'En-tête de [rayon], sous sa marge haute.
Finder _headerPastille(String rayon) => find.descendant(
  of: find.widgetWithText(RayonHeader, rayon),
  matching: find.byType(RayonPastille),
);

Finder _highlight(String name) =>
    find.ancestor(of: _row(name), matching: find.byType(RowHighlight));

ListePanel _panel(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ListeScreen)),
  listen: false,
).read(listePanelProvider);

/// Position de défilement de la Liste.
ScrollPosition _listScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// Réserve du bas de la Liste.
double _reserve(WidgetTester tester) => tester
    .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
    .padding!
    .resolve(TextDirection.ltr)
    .bottom;

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Fait défiler les fréquents du panneau jusqu'à [name], puis le touche.
Future<void> _tapFrequent(WidgetTester tester, String name) async {
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
  await _tap(tester, _frequent(name));
}

/// Tape [text] puis Entrée.
Future<void> _enter(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Laisse l'écriture et le flux arriver, sans faire avancer les animations
/// plus que nécessaire.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

/// Annonces TalkBack reçues.
List<String> _captureAnnouncements(WidgetTester tester) {
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

/// Couleur du fond de la ligne [name].
Color _background(WidgetTester tester, String name) => tester
    .widget<ColoredBox>(
      find
          .descendant(of: _highlight(name), matching: find.byType(ColoredBox))
          .first,
    )
    .color;

/// Opacité du fondu de la ligne [name].
double _opacity(WidgetTester tester, String name) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: _highlight(name),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void _expectAbovePanel(WidgetTester tester, String name) {
  final bottom = tester.getBottomLeft(_row(name)).dy;
  expect(bottom, lessThanOrEqualTo(_panel(tester).top! + 1));
  expect(tester.getTopLeft(_row(name)).dy, greaterThanOrEqualTo(_appBarBottom));
}

void main() {
  group('addPanelHeight', () {
    const chrome =
        KadiSpacing.panelHandleHeight +
        KadiSpacing.addFieldHeight +
        KadiSpacing.touchTarget;

    test('au contenu : poignée, champ, tags, puis les lignes demandées', () {
      expect(
        addPanelHeight(
          const MediaQueryData(
            size: Size(412, 914),
            padding: EdgeInsets.only(top: 24),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          rows: 1,
        ),
        chrome + KadiSpacing.rowMinHeight,
      );
    });

    test('jamais plus des deux tiers de la zone libre : écran − clavier − '
        'marge haute − Barre d’application', () {
      expect(
        addPanelHeight(
          const MediaQueryData(
            size: Size(412, 914),
            padding: EdgeInsets.only(top: 24),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          rows: 10,
        ),
        closeTo((914 - 300 - 24 - kToolbarHeight) * 2 / 3, 0.01),
      );
    });

    test('jamais moins que la poignée, le champ et les tags', () {
      expect(
        addPanelHeight(
          const MediaQueryData(
            size: Size(800, 360),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          rows: 3,
        ),
        chrome,
      );
    });
  });

  group('ListePanel', () {
    test('open et close préviennent seulement quand la géométrie change', () {
      final panel = ListePanel();
      addTearDown(panel.dispose);
      var notified = 0;
      panel.addListener(() => notified++);

      panel.close();
      expect(notified, 0);
      expect(panel.isOpen, isFalse);

      panel.open(top: 200, height: 400);
      panel.open(top: 200, height: 400);
      expect(notified, 1);
      expect(panel.isOpen, isTrue);
      expect((panel.top, panel.height), (200, 400));

      panel.close();
      expect(notified, 2);
      expect((panel.top, panel.height), (null, null));
    });

    test('reveal : une demande consommée une fois, ignorée panneau fermé', () {
      final panel = ListePanel();
      addTearDown(panel.dispose);

      panel.reveal('a');
      expect(panel.takeReveal(), isNull);

      panel.open(top: 200, height: 400);
      panel.reveal('b');
      expect(panel.takeReveal(), 'b');
      expect(panel.takeReveal(), isNull);

      panel.reveal('c');
      panel.close();
      expect(panel.takeReveal(), isNull);
    });
  });

  group('le panneau', () {
    testWidgets('412×914 et clavier de 300 dp : seul le titre des fréquents '
        'dépasse, carte à 8 dp du clavier, Liste assombrie par un voile '
        'léger', (tester) async {
      await _pumpPhone(tester);
      await _openPanel(tester);

      final top = tester.getTopLeft(_body).dy;
      expect(top, closeTo(_panel(tester).top!, 0.01));
      expect(tester.getBottomLeft(_body).dy, 914 - _keyboard - 8);
      expect(tester.getTopLeft(_body).dx, 8);
      expect(
        tester.getSize(_body).height,
        KadiSpacing.panelHandleHeight +
            KadiSpacing.addFieldHeight +
            KadiSpacing.touchTarget +
            KadiSpacing.touchTarget,
      );
      expect(_inSheet(find.byType(FrequentsTitle)), findsOneWidget);
      expect(
        tester.getBottomLeft(_inSheet(find.byType(FrequentsTitle))).dy,
        lessThanOrEqualTo(tester.getBottomLeft(_body).dy + 0.01),
      );

      final route = ModalRoute.of(tester.element(_sheet))!;
      final scheme = Theme.of(tester.element(_sheet)).colorScheme;
      expect(route.barrierColor, scheme.scrim);
      expect(route.barrierColor!.a, inExclusiveRange(0, 0.5));
      expect(route.barrierDismissible, isTrue);
    });

    testWidgets('clavier fermé : le titre et quelques fréquents, la carte au '
        'bas de l’écran', (tester) async {
      await _pumpPhone(tester, keyboard: 0);
      await _openPanel(tester);

      expect(tester.getBottomLeft(_body).dy, 914 - 8);
      expect(
        tester.getSize(_body).height,
        KadiSpacing.panelHandleHeight +
            KadiSpacing.addFieldHeight +
            KadiSpacing.touchTarget +
            KadiSpacing.rowMinHeight * 5.5,
      );
    });

    testWidgets('saisie : jusqu’à trois résultats visibles', (tester) async {
      await _pumpPhone(tester);
      await _openPanel(tester);
      await tester.enterText(_search, 'o');
      await tester.pumpAndSettle();

      expect(
        tester.getSize(_body).height,
        KadiSpacing.panelHandleHeight +
            KadiSpacing.addFieldHeight +
            KadiSpacing.touchTarget +
            KadiSpacing.rowMinHeight * 3,
      );
    });

    testWidgets('carte sans bordure ni ombre, coins arrondis, poignée '
        'fine sans la poignée M3, hors de la sémantique', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPhone(tester);
      await _openPanel(tester);

      final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(bottomSheet.showDragHandle, isFalse);
      final material = tester.widget<Material>(
        find.ancestor(of: _body, matching: find.byType(Material)).first,
      );
      final theme = Theme.of(tester.element(_sheet));
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(KadiRadius.xl)),
      );
      expect(material.color, theme.colorScheme.surfaceContainer);
      expect(material.elevation, 0);

      expect(tester.getSize(find.byType(PanelHandle)).height, 20);
      expect(
        tester.getTopLeft(find.byType(PanelHandle)).dy,
        tester.getTopLeft(_body).dy,
      );
      expect(
        find.descendant(
          of: find.byType(PanelHandle),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tap hors du panneau : il se ferme, la Liste retrouve sa '
        'réserve ; rien n’est coché à travers la barrière', (tester) async {
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      expect(_reserve(tester), _panel(tester).height);

      // La case de Lait reste visible au-dessus du panneau.
      final box = find.descendant(
        of: _row('Lait'),
        matching: find.byType(Checkbox),
      );
      expect(tester.getBottomLeft(box).dy, lessThan(_panel(tester).top!));
      await tester.tapAt(tester.getCenter(box));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(_panel(tester).isOpen, isFalse);
      expect(_reserve(tester), KadiSpacing.listBottomInset);
      final line = (await db.select(db.listLines).get()).single;
      expect(line.checkedAt, isNull);
    });

    testWidgets('glissement vers le bas et retour : il se ferme aussi', (
      tester,
    ) async {
      await _pumpPhone(tester);

      await _openPanel(tester);
      await tester.drag(find.byType(PanelHandle), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(_panel(tester).isOpen, isFalse);

      await _openPanel(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(_panel(tester).isOpen, isFalse);
    });

    testWidgets('clavier ouvert puis fermé : le panneau suit et recalcule sa '
        'hauteur, la géométrie publiée aussi', (tester) async {
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      final withKeyboard = tester.getSize(_body).height;
      expect(tester.getBottomLeft(_body).dy, 914 - _keyboard - 8);

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final height = tester.getSize(_body).height;
      expect(height, greaterThan(withKeyboard));
      expect(
        height,
        KadiSpacing.panelHandleHeight +
            KadiSpacing.addFieldHeight +
            KadiSpacing.touchTarget +
            KadiSpacing.rowMinHeight * 5.5,
      );
      expect(tester.getBottomLeft(_body).dy, 914 - 8);
      expect(_panel(tester).height, height + 8);
      expect(_panel(tester).top, closeTo(tester.getTopLeft(_body).dy, 0.01));
      expect(_reserve(tester), height + 8);

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();
      expect(tester.getSize(_body).height, withKeyboard);
    });

    testWidgets('clavier qui se ferme pendant la fermeture du panneau : il ne '
        'se rouvre pas dans la Liste', (tester) async {
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      Navigator.of(tester.element(_sheet)).pop();
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(_panel(tester).isOpen, isFalse);
      expect(_reserve(tester), KadiSpacing.listBottomInset);
    });

    testWidgets('liste vide : le message se centre dans la zone libre, puis '
        'au milieu du corps une fois le panneau fermé', (tester) async {
      await _pumpPhone(tester);
      await _openPanel(tester);

      final message = find.text(StringsFr.listeVide);
      expect(
        tester.getCenter(message).dy,
        closeTo((_appBarBottom + _panel(tester).top!) / 2, 1),
      );

      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(message).dy,
        closeTo((_appBarBottom + (914 - _keyboard)) / 2, 1),
      );
    });

    testWidgets('liste vide, clavier fermé : centré dans la zone libre, pas '
        'sous le panneau', (tester) async {
      await _pumpPhone(tester, keyboard: 0);
      await _openPanel(tester);

      expect(
        tester.getCenter(find.text(StringsFr.listeVide)).dy,
        closeTo((_appBarBottom + _panel(tester).top!) / 2, 1),
      );
    });
  });

  group('ajout visible dans la Liste', () {
    testWidgets('30 lignes, fréquent d’un rayon sous la zone libre : la Liste '
        'défile, le bas de la ligne au haut du panneau, ligne surlignée', (
      tester,
    ) async {
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await _openPanel(tester);
      expect(_listScroll(tester).pixels, 0);

      await _tapFrequent(tester, 'Lait');

      expect(_listScroll(tester).pixels, greaterThan(0));
      expect(
        tester.getBottomLeft(_row('Lait')).dy,
        closeTo(_panel(tester).top!, 1),
      );
      expect(tester.widget<RowHighlight>(_highlight('Lait')).arriving, isTrue);
      expect(
        tester.widget<RowHighlight>(_highlight('Lait')).color,
        KadiColors.of(tester.element(_row('Lait')))
            .rayon(Rayon.cremerie)
            .pastille,
      );
    });

    testWidgets('dernière ligne de la Liste : atteinte, jamais cachée par le '
        'panneau', (tester) async {
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await _openPanel(tester);

      await _tapFrequent(tester, 'Essuie-tout');

      expect(
        tester.getBottomLeft(_row('Essuie-tout')).dy,
        closeTo(_panel(tester).top!, 1),
      );
      expect(
        _listScroll(tester).pixels,
        lessThanOrEqualTo(_listScroll(tester).maxScrollExtent),
      );
    });

    testWidgets('ligne ajoutée clavier fermé, puis clavier ouvert : le panneau '
        'monte, la ligne reste au-dessus de lui', (tester) async {
      final db = await _pumpPhone(tester, keyboard: 0);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await _openPanel(tester);
      await _tapFrequent(tester, 'Lait');
      final lowTop = _panel(tester).top!;

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();

      expect(_panel(tester).top, lessThan(lowTop));
      expect(
        tester.getBottomLeft(_row('Lait')).dy,
        lessThanOrEqualTo(_panel(tester).top! + 1),
      );
    });

    testWidgets('clavier fermé : le calcul suit le haut du panneau, plus bas', (
      tester,
    ) async {
      final db = await _pumpPhone(tester, keyboard: 0);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await _openPanel(tester);

      await _tapFrequent(tester, 'Lait');

      expect(
        tester.getBottomLeft(_row('Lait')).dy,
        closeTo(_panel(tester).top!, 1),
      );
    });

    testWidgets('ligne au-dessus de la zone libre : la Liste remonte, En-tête '
        'de rayon visible', (tester) async {
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.epicerieSalee);
      final scroll = _listScroll(tester);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      await _openPanel(tester);
      final before = _listScroll(tester).pixels;
      expect(before, greaterThan(0));

      await _tapFrequent(tester, 'Bananes');

      expect(_listScroll(tester).pixels, lessThan(before));
      _expectAbovePanel(tester, 'Bananes');
      expect(
        tester.getTopLeft(_headerPastille('Fruits & légumes')).dy,
        greaterThanOrEqualTo(_appBarBottom),
      );
    });

    testWidgets('ligne au-dessus, au milieu de la Liste : la marge laisse voir '
        'l’En-tête de rayon, le défilement ne va pas en butée', (tester) async {
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await _fill(tester, db, Rayon.epicerieSalee);
      final scroll = _listScroll(tester);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      await _openPanel(tester);

      await _tapFrequent(tester, 'Lait');

      expect(_listScroll(tester).pixels, greaterThan(0));
      _expectAbovePanel(tester, 'Lait');
      expect(
        tester.getTopLeft(_row('Lait')).dy,
        closeTo(_appBarBottom + KadiSpacing.touchTarget, 1),
      );
      expect(
        tester.getTopLeft(_headerPastille('Crèmerie')).dy,
        greaterThanOrEqualTo(_appBarBottom),
      );
    });

    testWidgets('ligne déjà visible : animée, position de défilement '
        'inchangée', (tester) async {
      final db = await _pumpPhone(tester, keyboard: 0);
      final repo = ListeRepository(db, Clock());
      await repo.addArticle(SeedIds.tomates);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await tester.tap(_frequent('Bananes'));
      await _pumpUntilFound(tester, _row('Bananes'));

      expect(tester.widget<RowHighlight>(_highlight('Bananes')).arriving, true);
      expect(_opacity(tester, 'Bananes'), lessThan(1));
      expect(_background(tester, 'Bananes').a, greaterThan(0));

      await tester.pumpAndSettle();

      expect(_listScroll(tester).pixels, 0);
      expect(_opacity(tester, 'Bananes'), 1);
      expect(_background(tester, 'Bananes').a, 0);
      _expectAbovePanel(tester, 'Bananes');
      // La ligne qui était là n'est pas surlignée.
      expect(_opacity(tester, 'Tomates'), 1);
      expect(_background(tester, 'Tomates').a, 0);
    });

    testWidgets('premier ajout : le message vide laisse place à la ligne, en '
        'haut de l’écran', (tester) async {
      await _pumpPhone(tester);
      await _openPanel(tester);
      expect(find.text(StringsFr.listeVide), findsOneWidget);

      await _tapFrequent(tester, 'Bananes');

      expect(find.text(StringsFr.listeVide), findsNothing);
      expect(_listScroll(tester).pixels, 0);
      _expectAbovePanel(tester, 'Bananes');
      expect(tester.widget<RowHighlight>(_highlight('Bananes')).arriving, true);
    });

    testWidgets('quantité ou rayon changés : la ligne garde son id, aucun '
        'surlignage', (tester) async {
      final db = await _pumpPhone(tester);
      final repo = ListeRepository(db, Clock());
      final added = await repo.addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await repo.setQuantity(added.lineId, 2000, unit: Unit.piece);
      await repo.setRayon(added.lineId, Rayon.epicerieSalee);
      await tester.pumpAndSettle();

      expect(tester.widget<RowHighlight>(_highlight('Lait')).arriving, isFalse);
      expect(tester.widget<RowHighlight>(_highlight('Lait')).replays, 0);
    });
  });

  group('Entrée', () {
    testWidgets('article présent hors écran : rien d’ajouté ni retiré, la '
        'Liste montre sa ligne et la surligne ; annonce « Lait, dans la '
        'liste »', (tester) async {
      final announcements = _captureAnnouncements(tester);
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      expect(_listScroll(tester).pixels, 0);
      final lines = await db.select(db.listLines).get();
      final contributions = await db.select(db.listContributions).get();

      await tester.enterText(_search, 'lait');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pumpUntilFound(
        tester,
        find.byWidgetPredicate((w) => w is RowHighlight && w.replays == 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Surlignage seul : pas de fondu d'une ligne déjà là.
      expect(_background(tester, 'Lait').a, greaterThan(0));
      expect(_opacity(tester, 'Lait'), 1);

      await tester.pumpAndSettle();

      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.listContributions).get(), contributions);
      expect(
        tester.getBottomLeft(_row('Lait')).dy,
        closeTo(_panel(tester).top!, 1),
      );
      expect(_background(tester, 'Lait').a, 0);
      expect(announcements, contains(StringsFr.dansLaListeAnnonce('Lait')));
      expect(announcements, contains('Lait, dans la liste'));
    });

    testWidgets('article présent, tag quantité ou rayon appliqué : annonce '
        '« Lait modifié », plus « dans la liste »', (tester) async {
      final announcements = _captureAnnouncements(tester);
      final db = await _pumpPhone(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await tester.enterText(_search, 'lait');
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byWidgetPredicate(
          (w) => w is QuantityTag && w.emptyLabel == StringsFr.quantite,
        ),
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(QuantityPopup),
          matching: find.byType(TextField),
        ),
        '2',
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(announcements, contains('Lait modifié'));
      expect(
        announcements,
        isNot(contains(StringsFr.dansLaListeAnnonce('Lait'))),
      );

      announcements.clear();
      await tester.enterText(_search, 'lait');
      await tester.pumpAndSettle();
      await _tap(tester, find.byType(RayonTag));
      await tester.ensureVisible(find.byKey(const ValueKey(Rayon.boissons)));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey(Rayon.boissons)));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(announcements, ['Lait modifié']);
    });

    testWidgets('« piles » : champ vidé, rien sous le champ, ligne dans la '
        'Liste ; annonce « Piles ajouté, Divers »', (tester) async {
      final announcements = _captureAnnouncements(tester);
      final db = await _pumpPhone(tester);
      await (db.update(
        db.articles,
      )..where((a) => a.normalizedName.equals('piles'))).write(
        const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
      );
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _enter(tester, 'piles');

      expect(tester.widget<TextField>(_search).controller!.text, isEmpty);
      expect(_inSheet(find.text('Piles')), findsNothing);
      expect(_row('Piles'), findsOneWidget);
      _expectAbovePanel(tester, 'Piles');
      expect(announcements, contains('Piles ajouté, Divers'));
    });

    testWidgets('échec d’écriture : snackbar, saisie gardée, aucune annonce', (
      tester,
    ) async {
      final announcements = _captureAnnouncements(tester);
      final db = await _pumpPhone(tester);
      await db.customStatement(
        'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      await _openPanel(tester);

      await _enter(tester, 'lait');

      expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
      expect(tester.widget<TextField>(_search).controller!.text, 'lait');
      expect(announcements, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('tap', () {
    testWidgets('fréquent ajouté : annonce « Lait ajouté, Crèmerie » ; '
        'libellé parlé du rayon', (tester) async {
      final announcements = _captureAnnouncements(tester);
      await _pumpPhone(tester);
      await _openPanel(tester);

      await _tapFrequent(tester, 'Bananes');
      await _tapFrequent(tester, 'Lait');

      expect(announcements, contains('Bananes ajouté, Fruits et légumes'));
      expect(announcements, contains('Lait ajouté, Crèmerie'));
    });

    testWidgets('fréquent qui retire : ni défilement ni surlignage ; Annuler '
        'la remet et la montre', (tester) async {
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.epicerieSalee);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);
      final top = _panel(tester).top!;
      final before = tester.getBottomLeft(_row('Lait')).dy;
      expect(before, lessThan(top));

      await _tapFrequent(tester, 'Lait');
      expect(_row('Lait'), findsNothing);
      expect(_listScroll(tester).pixels, 0);
      expect(_inSheet(_undoAction), findsOneWidget);

      await _tap(tester, _undoAction);

      expect(_row('Lait'), findsOneWidget);
      expect(tester.widget<RowHighlight>(_highlight('Lait')).arriving, isTrue);
      _expectAbovePanel(tester, 'Lait');
    });

    testWidgets('Annuler pour une ligne hors de la zone libre : la Liste la '
        'montre', (tester) async {
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openPanel(tester);

      await _tapFrequent(tester, 'Lait');
      expect(_listScroll(tester).pixels, 0);

      await _tap(tester, _undoAction);

      expect(
        tester.getBottomLeft(_row('Lait')).dy,
        closeTo(_panel(tester).top!, 1),
      );
    });
  });

  group('animations coupées', () {
    testWidgets('ni fondu ni surlignage, saut direct', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final db = await _pumpPhone(tester);
      await _fill(tester, db, Rayon.fruitsLegumes);
      await _openPanel(tester);
      await tester.enterText(_search, 'lait');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SearchResultRow, 'Lait'));
      await _pumpUntilFound(tester, _row('Lait'));

      // Dès l'apparition : opaque, sans fond, pas de glissement en cours.
      expect(_opacity(tester, 'Lait'), 1);
      expect(_background(tester, 'Lait').a, 0);
      await tester.pump();
      expect(_listScroll(tester).activity, isA<IdleScrollActivity>());
      expect(
        tester.getBottomLeft(_row('Lait')).dy,
        closeTo(_panel(tester).top!, 1),
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Entrée sur une ligne présente : saut direct, sans surlignage',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final db = await _pumpPhone(tester);
        await _fill(tester, db, Rayon.fruitsLegumes);
        await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
        await tester.pumpAndSettle();
        await _openPanel(tester);

        await _enter(tester, 'lait');

        expect(_background(tester, 'Lait').a, 0);
        expect(
          tester.getBottomLeft(_row('Lait')).dy,
          closeTo(_panel(tester).top!, 1),
        );
      },
    );
  });

  testWidgets('panneau fermé : un ajout n’est ni animé ni montré', (
    tester,
  ) async {
    final db = await _pumpPhone(tester);
    await _fill(tester, db, Rayon.fruitsLegumes);
    await _openPanel(tester);
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(_reserve(tester), KadiSpacing.listBottomInset);

    await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
    await _pumpUntilFound(tester, _row('Lait'));

    expect(tester.widget<RowHighlight>(_highlight('Lait')).arriving, isFalse);
    expect(_opacity(tester, 'Lait'), 1);
    expect(_background(tester, 'Lait').a, 0);
    await tester.pumpAndSettle();
    expect(_listScroll(tester).pixels, 0);
  });
}
