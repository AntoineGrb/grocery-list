import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:kadi/features/reglages/ui/parcours_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/recettes.dart';

/// Réglages dont l'écriture de l'ordre du parcours échoue.
class _FailingRouteOrder extends SettingsRepository {
  _FailingRouteOrder(super.db, super.clock);

  @override
  Future<void> setRouteOrder(List<Rayon> order) async =>
      throw StateError('échec simulé');
}

const _monter = CustomSemanticsAction(label: StringsFr.monter);
const _descendre = CustomSemanticsAction(label: StringsFr.descendre);

final _total = Rayon.values.length;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Ouvre Paramètres par ⚙, puis Parcours par sa ligne.
Future<void> _openParcours(WidgetTester tester) async {
  await _tap(tester, find.byType(SettingsAction));
  await _tap(tester, find.text(StringsFr.parcours));
  expect(find.byType(ParcoursScreen), findsOneWidget);
}

/// Monte Kadi sur un téléphone haut (les 13 lignes sont bâties) et ouvre
/// Parcours.
Future<AppDatabase> _pumpParcours(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  tallPhone(tester);
  final db = await pumpKadi(tester, overrides: overrides);
  await _openParcours(tester);
  return db;
}

Finder _row(Rayon rayon) =>
    find.byWidgetPredicate((w) => w is RouteRow && w.rayon == rayon);

Finder _handle(Rayon rayon) => find.descendant(
  of: _row(rayon),
  matching: find.byType(ReorderableDragStartListener),
);

/// Rayons affichés, de haut en bas.
List<Rayon> _shown(WidgetTester tester) => [
  for (final row in tester.widgetList<RouteRow>(find.byType(RouteRow)))
    row.rayon,
];

/// Ordre du parcours en base.
Future<List<Rayon>> _stored(AppDatabase db) async =>
    SettingsRepository.decodeRouteOrder(
      (await db.select(db.settings).getSingle()).routeOrder,
    );

/// L'ordre par défaut avec [rayon] déplacé à [index].
List<Rayon> _withAt(Rayon rayon, int index) => [...Rayon.values]
  ..remove(rayon)
  ..insert(index, rayon);

/// Glisse la poignée de [rayon] de [dy], par petits pas, et la dépose.
Future<void> _dragHandle(WidgetTester tester, Rayon rayon, double dy) async {
  final gesture = await tester.startGesture(tester.getCenter(_handle(rayon)));
  await tester.pump();
  const steps = 6;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Hauteur d'une Ligne de parcours.
double _rowHeight(WidgetTester tester) =>
    tester.getSize(_row(Rayon.fruitsLegumes)).height;

/// Glisse Boulangerie (2e) en premier.
Future<void> _dragBoulangerieFirst(WidgetTester tester) =>
    _dragHandle(tester, Rayon.boulangerie, -1.5 * _rowHeight(tester));

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

String _label(Rayon rayon, int position) =>
    StringsFr.positionSur(rayon.spokenLabel, position, _total);

void main() {
  testWidgets('Paramètres : ligne « Parcours » sous les switches, au-dessus '
      'd’Exporter ; elle pousse Parcours, titre, flèche retour, les 13 '
      'rayons dans l’ordre par défaut', (tester) async {
    tallPhone(tester);
    await pumpKadi(tester);
    await _tap(tester, find.byType(SettingsAction));

    final parcours = find.widgetWithText(ListTile, StringsFr.parcours);
    expect(parcours, findsOneWidget);
    expect(
      find.descendant(
        of: parcours,
        matching: find.text(StringsFr.parcoursDetail),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: parcours, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    final y = tester.getTopLeft(parcours).dy;
    expect(
      y,
      greaterThan(tester.getTopLeft(find.text(StringsFr.grouperParRayon)).dy),
    );
    expect(
      y,
      lessThan(tester.getTopLeft(find.text(StringsFr.exporterMesDonnees)).dy),
    );

    await _tap(tester, parcours);
    expect(find.byType(ParcoursScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(StringsFr.parcours),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(_shown(tester), Rayon.values);

    await _tap(tester, find.byType(BackButton));
    expect(find.byType(ParcoursScreen), findsNothing);
    expect(find.byType(ParametresScreen), findsOneWidget);
  });

  testWidgets('Ligne de parcours : Pastille du rayon, poignée à droite en '
      'on-surface-variant, ligne et poignée de 48 dp au moins', (tester) async {
    await _pumpParcours(tester);

    final row = _row(Rayon.boulangerie);
    expect(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is RayonPastille && w.rayon == Rayon.boulangerie,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    final handle = tester.getSize(_handle(Rayon.boulangerie));
    expect(handle.width, greaterThanOrEqualTo(48));
    expect(handle.height, greaterThanOrEqualTo(48));
    expect(
      tester.getCenter(_handle(Rayon.boulangerie)).dx,
      greaterThan(tester.getCenter(find.text(Rayon.boulangerie.label)).dx),
    );
    final icon = tester.widget<Icon>(
      find.descendant(of: row, matching: find.byIcon(Icons.drag_handle)),
    );
    expect(
      icon.color,
      Theme.of(tester.element(row)).colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('glisser Boulangerie en premier : route_order commence par '
      'boulangerie, les 13 rayons écrits', (tester) async {
    final db = await _pumpParcours(tester);
    expect(_shown(tester), Rayon.values);

    await _dragBoulangerieFirst(tester);

    final expected = _withAt(Rayon.boulangerie, 0);
    expect(_shown(tester), expected);
    final row = await db.select(db.settings).getSingle();
    expect(row.routeOrder, SettingsRepository.encodeRouteOrder(expected));
    expect(row.routeOrder.split(','), hasLength(13));
    expect(row.routeOrder, startsWith('boulangerie,fruits-legumes,'));
  });

  testWidgets('glisser vers le bas : Fruits et légumes déposé en 3e', (
    tester,
  ) async {
    final db = await _pumpParcours(tester);

    await _dragHandle(tester, Rayon.fruitsLegumes, 1.75 * _rowHeight(tester));

    final expected = _withAt(Rayon.fruitsLegumes, 2);
    expect(_shown(tester), expected);
    expect(await _stored(db), expected);
  });

  testWidgets('glisser hors de la poignée, même après un appui long : rien '
      'ne bouge (seule la poignée glisse)', (tester) async {
    final db = await _pumpParcours(tester);
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(13));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text(Rayon.boulangerie.label)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, -0.25 * _rowHeight(tester)));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_shown(tester), Rayon.values);
    expect(await _stored(db), Rayon.values);
  });

  testWidgets('ordre modifié puis relance : même ordre', (tester) async {
    final db = await _pumpParcours(tester);
    await _dragBoulangerieFirst(tester);

    await pumpKadi(tester, database: db);
    await _openParcours(tester);
    expect(_shown(tester), _withAt(Rayon.boulangerie, 0));
  });

  testWidgets('écriture qui échoue : l’ordre revient à celui de la base, '
      'snackbar d’erreur', (tester) async {
    final db = await _pumpParcours(
      tester,
      overrides: [
        settingsRepositoryProvider.overrideWith(
          (ref) => _FailingRouteOrder(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
          ),
        ),
      ],
    );

    await _dragBoulangerieFirst(tester);

    expect(find.text(StringsFr.parcoursImpossible), findsOneWidget);
    expect(_shown(tester), Rayon.values);
    expect(await _stored(db), Rayon.values);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('les lignes suivent la base', (tester) async {
    final db = await _pumpParcours(tester);

    await SettingsRepository(
      db,
      Clock(),
    ).setRouteOrder(_withAt(Rayon.divers, 0));
    await tester.pumpAndSettle();
    expect(_shown(tester), _withAt(Rayon.divers, 0));
  });

  group('TalkBack', () {
    testWidgets('ligne lue « Fruits et légumes, position 1 sur 13 » ; pas de '
        '« Monter » sur la première, pas de « Descendre » sur la dernière', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpParcours(tester);

      expect(
        _label(Rayon.fruitsLegumes, 1),
        'Fruits et légumes, position 1 '
        'sur 13',
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(_label(Rayon.fruitsLegumes, 1)),
        ),
        isSemantics(
          label: _label(Rayon.fruitsLegumes, 1),
          customActions: [_descendre],
        ),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(_label(Rayon.boulangerie, 2)),
        ),
        isSemantics(
          label: _label(Rayon.boulangerie, 2),
          customActions: [_monter, _descendre],
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(_label(Rayon.divers, 13))),
        isSemantics(label: _label(Rayon.divers, 13), customActions: [_monter]),
      );
      handle.dispose();
    });

    testWidgets('« Descendre » sur Fruits et légumes : échangé avec le 2e, '
        'écrit, annoncé « Fruits et légumes, position 2 sur 13 » ; '
        '« Monter » le remet en tête', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = _captureAnnouncements(tester);
      final db = await _pumpParcours(tester);

      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.fruitsLegumes, 1)),
        _descendre,
      );
      await tester.pumpAndSettle();

      final swapped = _withAt(Rayon.fruitsLegumes, 1);
      expect(_shown(tester), swapped);
      expect(await _stored(db), swapped);
      expect(announcements, ['Fruits et légumes, position 2 sur 13']);
      expect(
        find.bySemanticsLabel(_label(Rayon.boulangerie, 1)),
        findsOneWidget,
      );

      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.fruitsLegumes, 2)),
        _monter,
      );
      await tester.pumpAndSettle();
      expect(_shown(tester), Rayon.values);
      expect(await _stored(db), Rayon.values);
      expect(announcements.last, 'Fruits et légumes, position 1 sur 13');
      handle.dispose();
    });

    testWidgets('« Monter » sur Boulangerie : annoncé « Boulangerie, '
        'position 1 sur 13 » ; « Descendre » sur un rayon du milieu : un '
        'seul cran', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = _captureAnnouncements(tester);
      final db = await _pumpParcours(tester);

      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.boulangerie, 2)),
        _monter,
      );
      await tester.pumpAndSettle();
      expect(_shown(tester), _withAt(Rayon.boulangerie, 0));
      expect(announcements, ['Boulangerie, position 1 sur 13']);

      // Crèmerie est 4e : « Descendre » l'échange avec le 5e, sans
      // l'envoyer à la fin.
      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.cremerie, 4)),
        _descendre,
      );
      await tester.pumpAndSettle();
      final expected = _withAt(Rayon.boulangerie, 0)
        ..remove(Rayon.cremerie)
        ..insert(4, Rayon.cremerie);
      expect(_shown(tester), expected);
      expect(await _stored(db), expected);
      expect(announcements.last, 'Crèmerie, position 5 sur 13');
      handle.dispose();
    });

    testWidgets('après un glisser, « Descendre » reste un seul cran', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpParcours(tester);
      await _dragBoulangerieFirst(tester);
      // Glisser rendu à sa place : aucun déplacement ne suit.
      await _dragHandle(tester, Rayon.cremerie, 0.45 * _rowHeight(tester));
      expect(_shown(tester), _withAt(Rayon.boulangerie, 0));

      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.fruitsLegumes, 2)),
        _descendre,
      );
      await tester.pumpAndSettle();
      expect(
        _shown(tester),
        _withAt(Rayon.boulangerie, 0)
          ..remove(Rayon.fruitsLegumes)
          ..insert(2, Rayon.fruitsLegumes),
      );
      handle.dispose();
    });

    testWidgets('après un glisser annulé, « Descendre » reste un seul cran', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final db = await _pumpParcours(tester);

      // Glisser commencé sur Crèmerie, puis le doigt est perdu : la liste
      // n'appelle pas onReorderEnd.
      final gesture = await tester.startGesture(
        tester.getCenter(_handle(Rayon.cremerie)),
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(Offset(0, 0.2 * _rowHeight(tester)));
        await tester.pump();
      }
      // Glisser en cours : Crèmerie est soulevée hors de la liste, dans
      // l'overlay.
      final inList = find.descendant(
        of: find.byType(ReorderableListView),
        matching: _row(Rayon.cremerie),
      );
      expect(inList, findsNothing);
      expect(_row(Rayon.cremerie), findsOneWidget);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(inList, findsOneWidget);
      expect(_shown(tester), Rayon.values);

      // « Descendre » est aussi l'action « à la fin » de la liste : suivre
      // le glisser annulé enverrait Fruits et légumes en dernier.
      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.fruitsLegumes, 1)),
        _descendre,
      );
      await tester.pumpAndSettle();
      final expected = _withAt(Rayon.fruitsLegumes, 1);
      expect(_shown(tester), expected);
      expect(await _stored(db), expected);
      handle.dispose();
    });

    testWidgets('écriture qui échoue : pas d’annonce, snackbar, ordre de la '
        'base', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = _captureAnnouncements(tester);
      await _pumpParcours(
        tester,
        overrides: [
          settingsRepositoryProvider.overrideWith(
            (ref) => _FailingRouteOrder(
              ref.watch(databaseProvider),
              ref.watch(clockProvider),
            ),
          ),
        ],
      );

      tester.semantics.customAction(
        find.semantics.byLabel(_label(Rayon.fruitsLegumes, 1)),
        _descendre,
      );
      await tester.pumpAndSettle();
      expect(_shown(tester), Rayon.values);
      expect(find.text(StringsFr.parcoursImpossible), findsOneWidget);
      expect(announcements, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });

  testWidgets('animations coupées : ligne soulevée d’un coup, déplacement '
      'sans animation', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final handle = tester.ensureSemantics();
    await _pumpParcours(tester);

    // Ligne soulevée dès le premier pas du glisser.
    final step = -0.25 * _rowHeight(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(_handle(Rayon.boulangerie)),
    );
    await tester.pump();
    // Deux pas franchissent le seuil du glisser.
    for (var i = 0; i < 2; i++) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump();
    }
    final lifted = find.ancestor(
      of: find.byType(RouteRow),
      matching: find.byWidgetPredicate((w) => w is Material && w.elevation > 0),
    );
    expect(lifted, findsOneWidget);
    expect(tester.widget<Material>(lifted).elevation, 6);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_shown(tester), _withAt(Rayon.boulangerie, 0));

    // Action TalkBack : la ligne est à sa place à l'image suivante.
    tester.semantics.customAction(
      find.semantics.byLabel(_label(Rayon.boulangerie, 1)),
      _descendre,
    );
    await tester.pump();
    expect(_shown(tester), Rayon.values);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
    expect(_shown(tester), Rayon.values);
    handle.dispose();
  });

  testWidgets('police ×2 sur 360 dp : le nom passe à la ligne, rien ne '
      'déborde', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await pumpKadi(tester);
    await _tap(tester, find.byType(SettingsAction));
    expect(tester.takeException(), isNull);
    for (final text in [StringsFr.parcours, StringsFr.parcoursDetail]) {
      final finder = find.text(text);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: text);
      expect(tester.getRect(finder).right, lessThanOrEqualTo(360));
      expect(tester.widget<Text>(finder).maxLines, isNull, reason: text);
    }

    // L'aide montrée en haut de la liste a glissé le libellé sous la Barre
    // d'application : la ligne entière revient à l'écran avant le toucher.
    final parcoursRow = find.widgetWithText(ListTile, StringsFr.parcours);
    await tester.ensureVisible(parcoursRow);
    await tester.pumpAndSettle();
    await _tap(tester, parcoursRow);
    expect(find.byType(ParcoursScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    final rows = tester.widgetList<RouteRow>(find.byType(RouteRow)).toList();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      final name = find.descendant(
        of: _row(row.rayon),
        matching: find.text(row.rayon.label),
      );
      expect(tester.getRect(name).right, lessThanOrEqualTo(360));
      expect(tester.widget<Text>(name).overflow, isNull);
      expect(tester.widget<Text>(name).maxLines, isNull);
      expect(tester.getRect(_handle(row.rayon)).right, lessThanOrEqualTo(360));
    }
    // Un nom long passe à la ligne au lieu de déborder, face à un nom court
    // en haut de la liste (Divers, en fin, n'est pas bâti à cette hauteur).
    Finder nameOf(Rayon rayon) =>
        find.descendant(of: _row(rayon), matching: find.text(rayon.label));
    expect(
      tester.getSize(nameOf(Rayon.fruitsLegumes)).height,
      greaterThan(tester.getSize(nameOf(Rayon.cremerie)).height),
    );
  });
}
