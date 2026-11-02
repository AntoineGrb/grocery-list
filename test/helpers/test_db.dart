import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

/// Base Drift en mémoire, flux fermés de façon synchrone (tests de widgets).
AppDatabase memoryDatabase() => AppDatabase.forTesting(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

/// Lit les vrais assets de `assets/seed/` depuis le disque.
Future<String> diskAssetLoader(String path) => File(path).readAsString();

/// Chemins des assets du contenu fourni lus par le chargeur.
const seedAssetPaths = [
  SeedLoader.articlesPath,
  SeedLoader.frequentsPath,
  SeedLoader.recettesPath,
];

/// Chargeur par chemin : le contenu de [overrides] pour ses chemins, le
/// disque pour les autres.
SeedAssetLoader assetLoaderWith(Map<String, String> overrides) =>
    (path) async => overrides[path] ?? await diskAssetLoader(path);

/// Lit tous les assets du contenu fourni (à appeler hors de la zone de test
/// des widgets, par `tester.runAsync`).
Future<Map<String, String>> readSeedAssets() async => {
  for (final path in seedAssetPaths) path: await diskAssetLoader(path),
};

/// Ids figés de `assets/seed/articles.json`.
abstract final class SeedIds {
  static const lait = 'f5feeb60-c1da-402b-9507-c64ee2c4949f';
  static const oeufs = '0ed8bc06-24ce-4c68-96b9-462ff6798ccf';
  static const tomates = '90664cd2-59db-4657-acc7-d1e6115bf0a4';
  static const courgettes = '61915f5f-59ee-4562-b1ad-51adb74ece4a';
  static const oignons = 'be6140d9-2886-4397-b038-952bf8612a5b';
  static const riz = 'd92eff2c-67fd-42bf-83d6-5f34033dc5e9';
  static const lardons = '02fe5b31-2754-4e5e-858b-f34811560f0c';
  static const pates = '615fcd7d-e1e7-4f8d-810e-706baccb099a';
  static const poivre = 'bbcff956-c443-4a7e-941f-70cc1bf254ff';
  static const poivrons = '46534d57-80f6-41b1-92fd-f5d849f39553';
  static const viandeHachee = '2de8b058-0ba2-4f13-a47f-81438b47b966';
}

/// Ids figés des recettes exemples de `assets/seed/recettes.json`.
abstract final class SeedRecipeIds {
  static const carbonara = '0d44ac0c-c91e-4c30-be13-29dbe0b31149';
  static const chili = '5f54fade-264b-49b5-be79-2e8b75f19d84';
  static const quiche = 'c4e99641-6f8f-4362-92d9-b09ee20d511f';
  static const ratatouille = '561f866d-5b41-4cab-bc7e-41cd7de47b20';
}

/// Fichier de recettes vide, à la [version] donnée.
String emptyRecettesFile([int version = 1]) =>
    '{"seed_version": $version, "recettes": []}';

/// Les 7 articles de la story 1 (`seed_version` 1), à garder à l'identique.
const originalArticles = <Map<String, Object?>>[
  {
    'id': SeedIds.lait,
    'name': 'Lait',
    'rayon': 'cremerie',
    'unit': 'piece',
    'picto_key': 'lait',
  },
  {
    'id': SeedIds.oeufs,
    'name': 'Œufs',
    'rayon': 'cremerie',
    'unit': 'piece',
    'picto_key': 'oeufs',
  },
  {
    'id': SeedIds.tomates,
    'name': 'Tomates',
    'rayon': 'fruits-legumes',
    'unit': 'g',
    'picto_key': 'tomates',
  },
  {
    'id': SeedIds.courgettes,
    'name': 'Courgettes',
    'rayon': 'fruits-legumes',
    'unit': 'g',
    'picto_key': 'courgettes',
  },
  {
    'id': SeedIds.oignons,
    'name': 'Oignons',
    'rayon': 'fruits-legumes',
    'unit': 'piece',
    'picto_key': 'oignons',
  },
  {
    'id': SeedIds.riz,
    'name': 'Riz',
    'rayon': 'epicerie-salee',
    'unit': 'g',
    'picto_key': 'riz',
  },
  {
    'id': SeedIds.lardons,
    'name': 'Lardons',
    'rayon': 'viande-poisson',
    'unit': 'g',
    'picto_key': 'lardons',
  },
];

SeedLoader seedLoader(
  AppDatabase db, {
  Clock? clock,
  SeedAssetLoader loadAsset = diskAssetLoader,
}) {
  final c = clock ?? Clock();
  return SeedLoader(
    db: db,
    settings: SettingsRepository(db, c),
    clock: c,
    loadAsset: loadAsset,
    normalizeName: normalizeName,
    frequentId: frequentId,
  );
}

/// Base en mémoire avec le contenu fourni chargé.
Future<AppDatabase> seededDatabase() async {
  final db = memoryDatabase();
  await seedLoader(db).run();
  return db;
}
