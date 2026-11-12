import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';

import '../../helpers/navigation.dart';

import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// Réglages dont toute écriture des Paramètres échoue.
class _FailingSettings extends SettingsRepository {
  _FailingSettings(super.db, super.clock);

  @override
  Future<void> setKeepScreenOn(bool value) async =>
      throw StateError('échec simulé');

  @override
  Future<void> setGroupByRayon(bool value) async =>
      throw StateError('échec simulé');
}

Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

bool _value(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(_switch(title)).value;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openParametres(WidgetTester tester) =>
    _tap(tester, parametresTab);

Future<SettingsRow> _row(AppDatabase db) => db.select(db.settings).getSingle();

void main() {
  testWidgets('onglet Paramètres, le troisième : sans flèche retour, la '
      'Barre de navigation reste', (tester) async {
    await pumpKadi(tester);
    final labels = [
      for (final d in tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      ))
        d.label,
    ];
    expect(labels, [
      StringsFr.tabListe,
      StringsFr.tabRecettes,
      StringsFr.parametres,
    ]);

    await _openParametres(tester);
    expect(find.byType(ParametresScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_switch(StringsFr.garderEcranAllume), findsOneWidget);
    expect(_switch(StringsFr.themeSombre), findsOneWidget);
    expect(_switch(StringsFr.grouperParRayon), findsOneWidget);
    expect(find.text(StringsFr.frequentsTitre), findsNothing);

    await _tap(tester, listeTab);
    expect(find.byType(ParametresScreen), findsNothing);
  });

  testWidgets('Thème sombre : suit le téléphone tant qu’il n’est pas '
      'touché ; le switch écrit le thème et l’app le prend', (tester) async {
    final db = await pumpKadi(tester);
    await _openParametres(tester);
    ThemeMode? mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

    expect((await _row(db)).themeMode, 'system');
    expect(mode(), ThemeMode.system);
    expect(_value(tester, StringsFr.themeSombre), isFalse);

    await _tap(tester, _switch(StringsFr.themeSombre));
    expect((await _row(db)).themeMode, 'dark');
    expect(mode(), ThemeMode.dark);
    expect(_value(tester, StringsFr.themeSombre), isTrue);

    await _tap(tester, _switch(StringsFr.themeSombre));
    expect((await _row(db)).themeMode, 'light');
    expect(mode(), ThemeMode.light);
  });

  testWidgets('par défaut : Écran allumé désactivé, groupement activé ; les '
      'switches écrivent la base', (tester) async {
    final db = await pumpKadi(tester);
    await _openParametres(tester);

    expect(_value(tester, StringsFr.garderEcranAllume), isFalse);
    expect(_value(tester, StringsFr.grouperParRayon), isTrue);

    await _tap(tester, _switch(StringsFr.garderEcranAllume));
    expect(_value(tester, StringsFr.garderEcranAllume), isTrue);
    expect((await _row(db)).keepScreenOn, isTrue);

    await _tap(tester, _switch(StringsFr.grouperParRayon));
    expect(_value(tester, StringsFr.grouperParRayon), isFalse);
    expect((await _row(db)).groupByRayon, isFalse);
  });

  testWidgets('les switches suivent la base', (tester) async {
    final db = await pumpKadi(tester);
    await _openParametres(tester);

    await SettingsRepository(db, Clock()).setKeepScreenOn(true);
    await tester.pumpAndSettle();
    expect(_value(tester, StringsFr.garderEcranAllume), isTrue);
  });

  testWidgets('deux réglages modifiés : gardés après relance', (tester) async {
    final db = await pumpKadi(tester);
    await _openParametres(tester);
    await _tap(tester, _switch(StringsFr.garderEcranAllume));
    await _tap(tester, _switch(StringsFr.grouperParRayon));

    await pumpKadi(tester, database: db);
    await _openParametres(tester);
    expect(_value(tester, StringsFr.garderEcranAllume), isTrue);
    expect(_value(tester, StringsFr.grouperParRayon), isFalse);
  });

  testWidgets('écriture qui échoue : snackbar d’erreur, switch à la valeur en '
      'base', (tester) async {
    final db = await pumpKadi(
      tester,
      overrides: [
        settingsRepositoryProvider.overrideWith(
          (ref) => _FailingSettings(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
          ),
        ),
      ],
    );
    await _openParametres(tester);

    await _tap(tester, _switch(StringsFr.garderEcranAllume));
    expect(find.text(StringsFr.reglageImpossible), findsOneWidget);
    expect(_value(tester, StringsFr.garderEcranAllume), isFalse);
    expect((await _row(db)).keepScreenOn, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _tap(tester, _switch(StringsFr.grouperParRayon));
    expect(find.text(StringsFr.reglageImpossible), findsOneWidget);
    expect(_value(tester, StringsFr.grouperParRayon), isTrue);
    expect((await _row(db)).groupByRayon, isTrue);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('TalkBack : switches lus avec leur libellé et leur état', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpKadi(tester);
    await _openParametres(tester);

    expect(
      tester.getSemantics(_switch(StringsFr.garderEcranAllume)),
      isSemantics(
        label:
            '${StringsFr.garderEcranAllume}\n'
            '${StringsFr.garderEcranAllumeDetail}',
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_switch(StringsFr.grouperParRayon)),
      isSemantics(
        label:
            '${StringsFr.grouperParRayon}\n'
            '${StringsFr.grouperParRayonDetail}',
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('police ×2 sur 360 dp : libellés entiers, sans débordement', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await pumpKadi(tester);
    expect(tester.takeException(), isNull);

    await _openParametres(tester);
    expect(tester.takeException(), isNull);
    for (final text in [
      StringsFr.garderEcranAllume,
      StringsFr.garderEcranAllumeDetail,
      StringsFr.themeSombre,
      StringsFr.themeSombreDetail,
      StringsFr.grouperParRayon,
      StringsFr.grouperParRayonDetail,
    ]) {
      final finder = find.text(text);
      // La liste défile : chaque ligne est amenée à l'écran.
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: text);
      expect(tester.getRect(finder).right, lessThanOrEqualTo(360));
      expect(tester.widget<Text>(finder).overflow, isNull, reason: text);
      expect(tester.widget<Text>(finder).maxLines, isNull, reason: text);
    }
    expect(_switch(StringsFr.grouperParRayon).hitTestable(), findsOneWidget);
  });
}
