import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/keep_screen_on.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_screen_awake.dart';
import '../helpers/pump_app.dart';

/// Monte Kadi sur la Liste, Écran allumé à [keepScreenOn], avec [screen]
/// pour double du maintien.
Future<AppDatabase> _pumpApp(
  WidgetTester tester,
  FakeScreenAwake screen, {
  bool keepScreenOn = true,
}) async {
  // Le cycle de vie du binding survit d'un test à l'autre : on le remet.
  addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );
  final db = await pumpKadi(tester, screenAwake: screen);
  if (keepScreenOn) {
    await SettingsRepository(db, Clock()).setKeepScreenOn(true);
    await tester.pumpAndSettle();
  }
  return db;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Passe l'app à [state] par les étapes intermédiaires d'Android (paused →
/// hidden → inactive → resumed, et l'inverse) : un AppLifecycleListener
/// (champ de recherche de Recettes) refuse les sauts.
Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  const order = [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  final current = tester.binding.lifecycleState;
  final from = current == null ? -1 : order.indexOf(current);
  final to = order.indexOf(state);
  if (from >= 0 && to >= 0 && (to - from).abs() > 1) {
    final step = to > from ? 1 : -1;
    for (var i = from + step; i != to; i += step) {
      tester.binding.handleAppLifecycleStateChanged(order[i]);
    }
  }
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pump();
}

void main() {
  group('shouldKeepScreenOn', () {
    test('seulement réglage vrai, sur la Liste, au premier plan', () {
      expect(
        shouldKeepScreenOn(
          setting: true,
          path: AppRoutes.liste,
          lifecycle: AppLifecycleState.resumed,
        ),
        isTrue,
      );
      expect(
        shouldKeepScreenOn(
          setting: true,
          path: AppRoutes.liste,
          lifecycle: null,
        ),
        isTrue,
      );
      expect(
        shouldKeepScreenOn(
          setting: false,
          path: AppRoutes.liste,
          lifecycle: AppLifecycleState.resumed,
        ),
        isFalse,
      );
      for (final path in [
        AppRoutes.recettes,
        AppRoutes.parametres,
        AppRoutes.revue,
        '',
      ]) {
        expect(
          shouldKeepScreenOn(
            setting: true,
            path: path,
            lifecycle: AppLifecycleState.resumed,
          ),
          isFalse,
          reason: path,
        );
      }
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        expect(
          shouldKeepScreenOn(
            setting: true,
            path: AppRoutes.liste,
            lifecycle: state,
          ),
          isFalse,
          reason: '$state',
        );
      }
    });

    test('contrôleur : une demande par changement, jamais deux fois la '
        'même', () {
      final screen = FakeScreenAwake();
      final controller = KeepScreenOnController(screen);
      void update(bool setting, String path) => controller.update(
        setting: setting,
        path: path,
        lifecycle: AppLifecycleState.resumed,
      );

      update(false, AppRoutes.liste);
      expect(screen.calls, isEmpty);
      update(true, AppRoutes.liste);
      update(true, AppRoutes.liste);
      expect(screen.calls, [true]);
      update(true, AppRoutes.recettes);
      update(false, AppRoutes.recettes);
      expect(screen.calls, [true, false]);
      update(true, AppRoutes.liste);
      controller.release();
      controller.release();
      expect(screen.calls, [true, false, true, false]);
    });
  });

  group('app montée', () {
    testWidgets('réglage vrai, onglet Liste : maintien demandé', (
      tester,
    ) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen);
      expect(screen.calls, [true]);
    });

    testWidgets('réglage vrai à la relance : maintien demandé dès '
        'l’ouverture sur la Liste', (tester) async {
      final first = FakeScreenAwake();
      final db = await _pumpApp(tester, first);
      expect(first.enabled, isTrue);

      final screen = FakeScreenAwake();
      await pumpKadi(tester, database: db, screenAwake: screen);
      expect(screen.calls, [true]);
    });

    testWidgets('changement d’onglet : relâché sur Recettes, redemandé au '
        'retour sur la Liste', (tester) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen);

      await _tap(tester, find.text(StringsFr.tabRecettes));
      expect(screen.calls, [true, false]);

      await _tap(tester, find.text(StringsFr.tabListe));
      expect(screen.calls, [true, false, true]);
    });

    testWidgets('Paramètres ouvert depuis la Liste : relâché ; au retour, '
        'redemandé', (tester) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen);

      await _tap(tester, find.byType(SettingsAction));
      expect(find.byType(ParametresScreen), findsOneWidget);
      expect(screen.calls, [true, false]);

      await _tap(tester, find.byType(BackButton));
      expect(find.byType(ParametresScreen), findsNothing);
      expect(screen.calls, [true, false, true]);
    });

    testWidgets('Panneau + ouvert sur la Liste : le maintien reste', (
      tester,
    ) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen);

      await _tap(tester, find.byType(FloatingActionButton));
      expect(find.byType(AddSheet), findsOneWidget);
      expect(screen.calls, [true]);
    });

    testWidgets('arrière-plan : relâché en inactive ou paused, redemandé au '
        'retour au premier plan sur la Liste', (tester) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen);

      await _lifecycle(tester, AppLifecycleState.inactive);
      expect(screen.calls, [true, false]);
      await _lifecycle(tester, AppLifecycleState.hidden);
      await _lifecycle(tester, AppLifecycleState.paused);
      expect(screen.calls, [true, false]);

      await _lifecycle(tester, AppLifecycleState.resumed);
      expect(screen.calls, [true, false, true]);
    });

    testWidgets('retour au premier plan sur Recettes : pas de maintien', (
      tester,
    ) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen);
      await _tap(tester, find.text(StringsFr.tabRecettes));

      await _lifecycle(tester, AppLifecycleState.paused);
      await _lifecycle(tester, AppLifecycleState.resumed);
      expect(screen.calls, [true, false]);
    });

    testWidgets('réglage faux : jamais de maintien, où que ce soit', (
      tester,
    ) async {
      final screen = FakeScreenAwake();
      await _pumpApp(tester, screen, keepScreenOn: false);

      await _tap(tester, find.text(StringsFr.tabRecettes));
      await _tap(tester, find.text(StringsFr.tabListe));
      await _lifecycle(tester, AppLifecycleState.paused);
      await _lifecycle(tester, AppLifecycleState.resumed);
      await _tap(tester, find.byType(SettingsAction));
      await _tap(tester, find.byType(BackButton));

      expect(screen.enables, 0);
    });

    testWidgets('réglage activé dans Paramètres : maintien au retour sur la '
        'Liste ; désactivé sur la Liste, relâché', (tester) async {
      final screen = FakeScreenAwake();
      final db = await _pumpApp(tester, screen, keepScreenOn: false);

      await _tap(tester, find.byType(SettingsAction));
      await _tap(tester, find.text(StringsFr.garderEcranAllume));
      expect(screen.calls, isEmpty);

      await _tap(tester, find.byType(BackButton));
      expect(screen.calls, [true]);

      await SettingsRepository(db, Clock()).setKeepScreenOn(false);
      await tester.pumpAndSettle();
      expect(screen.calls, [true, false]);
    });
  });
}
