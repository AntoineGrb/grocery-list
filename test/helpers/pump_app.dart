import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'test_db.dart';

/// Monte Kadi sur une base en mémoire, avec les vrais assets du contenu
/// fourni (sauf les chemins de [assetOverrides]) et les [overrides] en plus.
/// L'app s'ouvre sur la Liste ; la base est fermée au démontage.
Future<AppDatabase> pumpKadi(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Map<String, String> assetOverrides = const {},
}) async {
  final assets = (await tester.runAsync(readSeedAssets))!;
  final db = memoryDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedAssetLoaderProvider.overrideWithValue(
          assetLoaderWith({...assets, ...assetOverrides}),
        ),
        ...overrides,
      ],
      child: const KadiApp(),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  return db;
}
