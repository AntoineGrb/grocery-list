import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/backup/backup_archive.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/features/recettes/data/recipe_photos.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

/// Double du sélecteur de fichier : compte les ouvertures et rend [result]
/// (`null` = fermé sans choix), ou attend [pending] s'il est posé.
class _FakePicker {
  var calls = 0;
  List<int>? result;
  Completer<List<int>?>? pending;

  Future<List<int>?> call() async {
    calls++;
    final wait = pending;
    if (wait != null) return wait.future;
    return result;
  }
}

class _Env {
  _Env(this.db, this.picker, this.photos);
  final AppDatabase db;
  final _FakePicker picker;
  final Directory photos;
}

Finder get _importRow =>
    find.widgetWithText(ListTile, StringsFr.importerUneSauvegarde);

Directory _tempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows : un fichier encore ouvert.
    }
  });
  return dir;
}

/// Sauvegarde d'un autre téléphone : contenu fourni, Écran allumé activé,
/// groupement coupé, et la photo `chili.jpg` sur le Chili. Écrite par
/// l'exporteur de la story 2, hors de la zone de test des widgets.
Future<List<int>> _backup(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final source = await seededDatabase();
    try {
      final clock = Clock();
      final settings = SettingsRepository(source, clock);
      await settings.setKeepScreenOn(true);
      await settings.setGroupByRayon(false);
      final root = Directory.systemTemp.createTempSync('kadi_source_');
      try {
        final photos = Directory('${root.path}${Platform.pathSeparator}photos')
          ..createSync();
        File('${photos.path}${Platform.pathSeparator}chili.jpg')
            .writeAsBytesSync([1, 2, 3]);
        await (source.update(
          source.recipes,
        )..where((r) => r.id.equals(SeedRecipeIds.chili))).write(
          RecipesCompanion(
            photo: const Value('chili.jpg'),
            updatedAt: Value(clock.stamp()),
          ),
        );
        final file = await BackupExporter(source).export(
          photos: photos,
          target: Directory('${root.path}${Platform.pathSeparator}out'),
        );
        return file.readAsBytesSync();
      } finally {
        root.deleteSync(recursive: true);
      }
    } finally {
      await source.close();
    }
  });
  return bytes!;
}

/// Kadi ouvert sur Paramètres ; photos dans un dossier temporaire (ou un
/// dossier documents illisible avec [failingPhotos]), sélecteur de fichier
/// remplacé par un double.
Future<_Env> _openParametres(
  WidgetTester tester, {
  bool failingPhotos = false,
}) async {
  final documents = _tempDir('kadi_docs_');
  final photos = Directory(
    '${documents.path}${Platform.pathSeparator}${RecipePhotos.folder}',
  );
  final picker = _FakePicker();
  final db = await pumpKadi(
    tester,
    pickBackupFile: picker.call,
    overrides: [
      recipePhotosProvider.overrideWithValue(
        RecipePhotos(
          failingPhotos
              ? () async => throw const FileSystemException('échec simulé')
              : () async => documents,
        ),
      ),
    ],
  );
  await tester.tap(find.byType(SettingsAction));
  await tester.pumpAndSettle();
  return _Env(db, picker, photos);
}

Future<void> _tapImport(WidgetTester tester) async {
  await tester.tap(_importRow);
  await tester.pumpAndSettle();
}

/// Laisse partir le snackbar affiché.
Future<void> _dismissSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester) =>
    tester.widget<ListTile>(_importRow).enabled;

bool _switchOn(WidgetTester tester, String title) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
    .value;

Future<List<Map<String, Object?>>> _rows(AppDatabase db) async => [
  for (final t in db.allTables)
    for (final row
        in await db
            .customSelect('SELECT * FROM "${t.actualTableName}" ORDER BY id')
            .get())
      {'_table': t.actualTableName, ...row.data},
];

void main() {
  testWidgets('ligne « Importer une sauvegarde » sous « Exporter mes '
      'données », avec son aide, cible de 48 dp au moins', (tester) async {
    await _openParametres(tester);

    expect(_importRow, findsOneWidget);
    expect(find.text(StringsFr.importerUneSauvegardeDetail), findsOneWidget);
    final row = tester.getRect(_importRow);
    final exportRow = tester.getRect(
      find.widgetWithText(ListTile, StringsFr.exporterMesDonnees),
    );
    expect(row.top, greaterThanOrEqualTo(exportRow.bottom));
    expect(row.height, greaterThanOrEqualTo(48));
    expect(_enabled(tester), isTrue);
  });

  testWidgets('toucher : le fichier choisi est importé, réglages et photo '
      'repris, puis « Sauvegarde importée. »', (tester) async {
    final env = await _openParametres(tester);
    env.picker.result = await _backup(tester);
    expect(_switchOn(tester, StringsFr.garderEcranAllume), isFalse);
    expect(_switchOn(tester, StringsFr.grouperParRayon), isTrue);

    await _tapImport(tester);

    expect(env.picker.calls, 1);
    expect(find.text(StringsFr.sauvegardeImportee), findsOneWidget);
    expect(_switchOn(tester, StringsFr.garderEcranAllume), isTrue);
    expect(_switchOn(tester, StringsFr.grouperParRayon), isFalse);
    final chili = await (env.db.select(
      env.db.recipes,
    )..where((r) => r.id.equals(SeedRecipeIds.chili))).getSingle();
    expect(chili.photo, 'chili.jpg');
    expect(
      File('${env.photos.path}${Platform.pathSeparator}chili.jpg')
          .readAsBytesSync(),
      [1, 2, 3],
    );
    expect(_enabled(tester), isTrue);
    await _dismissSnackBar(tester);
  });

  testWidgets('fichier invalide : « Ce fichier n’est pas une sauvegarde '
      'Kadi. », rien ne change', (tester) async {
    final env = await _openParametres(tester);
    env.picker.result = utf8.encode('Pas une sauvegarde.');
    final before = await _rows(env.db);

    await _tapImport(tester);

    expect(find.text(StringsFr.pasUneSauvegardeKadi), findsOneWidget);
    expect(find.text(StringsFr.sauvegardeImportee), findsNothing);
    expect(await _rows(env.db), before);
    expect(env.photos.existsSync(), isFalse);
    expect(_enabled(tester), isTrue);
    await _dismissSnackBar(tester);
  });

  testWidgets('sauvegarde d’une version inconnue : refusée comme invalide', (
    tester,
  ) async {
    final env = await _openParametres(tester);
    final valid = await _backup(tester);
    // Même archive, `format_version` 99.
    final archive = ZipDecoder().decodeBytes(valid);
    final data = jsonDecode(
      utf8.decode(archive.findFile(BackupFormat.dataFile)!.content),
    ) as Map<String, Object?>;
    data[BackupFormat.formatVersionKey] = 99;
    env.picker.result = ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.string(BackupFormat.dataFile, jsonEncode(data))),
    );

    await _tapImport(tester);
    expect(find.text(StringsFr.pasUneSauvegardeKadi), findsOneWidget);
    expect(_switchOn(tester, StringsFr.garderEcranAllume), isFalse);
    await _dismissSnackBar(tester);
  });

  testWidgets('sélecteur fermé sans choix : aucun snackbar, rien ne '
      'change', (tester) async {
    final env = await _openParametres(tester);
    final before = await _rows(env.db);

    await _tapImport(tester);

    expect(env.picker.calls, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(await _rows(env.db), before);
    expect(_enabled(tester), isTrue);
  });

  testWidgets('échec d’écriture : « Import impossible. »', (tester) async {
    final env = await _openParametres(tester, failingPhotos: true);
    env.picker.result = await _backup(tester);

    await _tapImport(tester);

    expect(find.text(StringsFr.importImpossible), findsOneWidget);
    expect(find.text(StringsFr.sauvegardeImportee), findsNothing);
    expect(_switchOn(tester, StringsFr.garderEcranAllume), isFalse);
    expect(_enabled(tester), isTrue);
    await _dismissSnackBar(tester);
  });

  testWidgets('pendant l’import : la ligne est désactivée, un second toucher '
      'ne relance rien', (tester) async {
    final env = await _openParametres(tester);
    final pending = env.picker.pending = Completer<List<int>?>();

    await _tapImport(tester);
    expect(env.picker.calls, 1);
    expect(_enabled(tester), isFalse);
    await tester.tap(_importRow, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(env.picker.calls, 1);

    pending.complete(null);
    await tester.pumpAndSettle();
    expect(_enabled(tester), isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('TalkBack : la ligne est lue avec son libellé et son aide, et '
      'se touche', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await _openParametres(tester);

    expect(
      tester.getSemantics(_importRow),
      isSemantics(
        label:
            '${StringsFr.importerUneSauvegarde}\n'
            '${StringsFr.importerUneSauvegardeDetail}',
        hasTapAction: true,
        isEnabled: true,
      ),
    );
    tester.semantics.tap(
      find.semantics.byLabel(RegExp('^${StringsFr.importerUneSauvegarde}')),
    );
    await tester.pumpAndSettle();
    expect(env.picker.calls, 1);
    handle.dispose();
  });

  testWidgets('police ×2 sur 360 dp : libellé et aide entiers, sans '
      'débordement', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await _openParametres(tester);
    expect(tester.takeException(), isNull);

    for (final text in [
      StringsFr.importerUneSauvegarde,
      StringsFr.importerUneSauvegardeDetail,
    ]) {
      final finder = find.text(text);
      // Les lignes au-dessus la poussent sous l'écran, hors de ce que la
      // liste construit : elle défile jusqu'à la construire et la montrer.
      await tester.scrollUntilVisible(finder, 100);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: text);
      expect(tester.getRect(finder).right, lessThanOrEqualTo(360));
      expect(tester.widget<Text>(finder).overflow, isNull, reason: text);
      expect(tester.widget<Text>(finder).maxLines, isNull, reason: text);
    }
    expect(_importRow.hitTestable(), findsOneWidget);
  });
}
