import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

/// Lecture des assets du contenu fourni ; remplacée en test.
final seedAssetLoaderProvider = Provider<SeedAssetLoader>(
  (ref) => rootBundle.loadString,
);

/// Ouverture de la base et chargement du contenu fourni (AD-8), avant tout
/// écran. Pas de nouvel essai automatique : un échec affiche l'écran
/// d'erreur bloquant.
final appStartupProvider = FutureProvider<void>((ref) async {
  final loader = SeedLoader(
    db: ref.watch(databaseProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
    loadAsset: ref.watch(seedAssetLoaderProvider),
    normalizeName: normalizeName,
    frequentId: frequentId,
  );
  await loader.run();
}, retry: (retryCount, error) => null);
