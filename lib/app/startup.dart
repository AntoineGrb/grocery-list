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
///
/// Rend `true` au premier lancement : le chargeur a levé le drapeau en
/// insérant des recettes exemples, maintenant ou à un démarrage qui n'a pas
/// abouti. Le drapeau est alors baissé (AD-13), et l'app s'ouvre sur
/// Recettes pour cette session seulement.
final appStartupProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final loader = SeedLoader(
    db: ref.watch(databaseProvider),
    settings: settings,
    clock: ref.watch(clockProvider),
    loadAsset: ref.watch(seedAssetLoaderProvider),
    normalizeName: normalizeName,
    frequentId: frequentId,
  );
  await loader.run();
  if (!(await settings.read()).firstLaunch) return false;
  await settings.setFirstLaunch(false);
  return true;
}, retry: (retryCount, error) => null);

/// Ligne d'accueil de Recettes (R11) : montrée pendant la session qui a
/// baissé le drapeau de premier lancement, jamais persistée. Recettes la
/// retire ([WelcomeNotifier.dismiss]) quand il n'y a plus de recette.
final welcomeProvider = NotifierProvider<WelcomeNotifier, bool>(
  WelcomeNotifier.new,
);

class WelcomeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(appStartupProvider).value ?? false;

  /// Retire la ligne d'accueil jusqu'à la fin de la session.
  void dismiss() {
    if (state) state = false;
  }
}
