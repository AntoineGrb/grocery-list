import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

/// Base Drift en mémoire, flux fermés de façon synchrone (tests de widgets).
AppDatabase memoryDatabase() => AppDatabase.forTesting(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

/// Lit les vrais assets de `assets/seed/` depuis le disque.
Future<String> diskAssetLoader(String path) => File(path).readAsString();

/// Ids figés de `assets/seed/articles.json`.
abstract final class SeedIds {
  static const lait = 'f5feeb60-c1da-402b-9507-c64ee2c4949f';
  static const oeufs = '0ed8bc06-24ce-4c68-96b9-462ff6798ccf';
  static const tomates = '90664cd2-59db-4657-acc7-d1e6115bf0a4';
  static const riz = 'd92eff2c-67fd-42bf-83d6-5f34033dc5e9';
}

SeedLoader seedLoader(
  AppDatabase db, {
  Clock? clock,
  SeedAssetLoader loadAsset = diskAssetLoader,
}) => SeedLoader(
  db: db,
  settings: SettingsRepository(db, clock ?? Clock()),
  loadAsset: loadAsset,
  normalizeName: normalizeName,
);

/// Base en mémoire avec le contenu fourni chargé.
Future<AppDatabase> seededDatabase() async {
  final db = memoryDatabase();
  await seedLoader(db).run();
  return db;
}
