import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/backup/backup_providers.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/screen/screen_awake.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_screen_awake.dart';
import 'test_db.dart';

/// Monte Kadi sur une base en mémoire, avec les vrais assets du contenu
/// fourni (sauf les chemins de [assetOverrides]) et les [overrides] en plus.
///
/// Par défaut, l'app s'ouvre sur la Liste : le contenu fourni est chargé et
/// le drapeau de premier lancement baissé avant de monter l'app. Avec
/// [firstLaunch], la base est vide : c'est le premier lancement, l'app
/// s'ouvre sur Recettes. Avec [database], cette base est reprise (relance
/// de l'app), telle quelle et sans être fermée ici. La base créée ici est
/// fermée au démontage. Le maintien de l'écran passe par [screenAwake], un
/// [FakeScreenAwake] neuf par défaut : aucun test n'appelle la plateforme.
/// De même, la feuille de partage est [shareFile] (par défaut un double qui
/// rend « partagé ») et l'export écrit dans [exportDirectory] (par défaut un
/// dossier temporaire créé au premier export, supprimé en fin de test).
Future<AppDatabase> pumpKadi(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Map<String, String> assetOverrides = const {},
  bool firstLaunch = false,
  AppDatabase? database,
  ScreenAwake? screenAwake,
  ShareFile? shareFile,
  Future<Directory> Function()? exportDirectory,
}) async {
  assert(
    !(firstLaunch && database != null),
    'firstLaunch part d’une base vide : incompatible avec database',
  );
  final assets = (await tester.runAsync(readSeedAssets))!;
  final loadAsset = assetLoaderWith({...assets, ...assetOverrides});
  final db = database ?? memoryDatabase();
  if (database == null && !firstLaunch) {
    await tester.runAsync(() async {
      try {
        await seedLoader(db, loadAsset: loadAsset).run();
      } catch (_) {
        // Contenu invalide : rien n'est écrit, le démarrage échouera de même.
        return;
      }
      await SettingsRepository(db, Clock()).setFirstLaunch(false);
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      // Une relance monte un nouveau conteneur, jamais celui d'avant.
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedAssetLoaderProvider.overrideWithValue(loadAsset),
        screenAwakeProvider.overrideWithValue(screenAwake ?? FakeScreenAwake()),
        shareFileProvider.overrideWithValue(shareFile ?? (_) async => true),
        exportDirectoryProvider.overrideWithValue(
          exportDirectory ?? _tempExportDirectory(),
        ),
        ...overrides,
      ],
      child: const KadiApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (database == null) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await db.close();
    });
  }
  return db;
}

/// Dossier temporaire d'export, créé au premier appel (E/S synchrones : la
/// zone de test des widgets n'attend pas les E/S asynchrones) et supprimé en
/// fin de test.
Future<Directory> Function() _tempExportDirectory() {
  Directory? dir;
  return () async {
    if (dir != null) return dir!;
    final created = dir = Directory.systemTemp.createTempSync('kadi_export_');
    addTearDown(() {
      try {
        created.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows : un fichier encore ouvert.
      }
    });
    return created;
  };
}
