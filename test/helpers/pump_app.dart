import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'test_db.dart';

/// Monte Kadi sur une base en mémoire, avec les vrais assets du contenu
/// fourni (sauf les chemins de [assetOverrides]) et les [overrides] en plus.
///
/// Par défaut, l'app s'ouvre sur la Liste : le contenu fourni est chargé et
/// le drapeau de premier lancement baissé avant de monter l'app. Avec
/// [firstLaunch], la base est vide : c'est le premier lancement, l'app
/// s'ouvre sur Recettes. Avec [database], cette base est reprise (relance
/// de l'app), telle quelle et sans être fermée ici. La base créée ici est
/// fermée au démontage.
Future<AppDatabase> pumpKadi(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Map<String, String> assetOverrides = const {},
  bool firstLaunch = false,
  AppDatabase? database,
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
