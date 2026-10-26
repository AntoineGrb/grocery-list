import '../rayons/rayon.dart';

/// Réglages lus par toute l'app (AD-2).
class AppSettings {
  const AppSettings({
    required this.routeOrder,
    required this.groupByRayon,
    required this.keepScreenOn,
    required this.firstLaunch,
    required this.seedVersions,
  });

  /// Les 13 rayons dans l'ordre du parcours.
  final List<Rayon> routeOrder;
  final bool groupByRayon;
  final bool keepScreenOn;
  final bool firstLaunch;

  /// `seed_version` par fichier de `assets/seed/` (clé : nom sans extension).
  final Map<String, int> seedVersions;

  /// Valeurs par défaut (State Patterns d'EXPERIENCE.md, Paramètres).
  static final defaults = AppSettings(
    routeOrder: List.unmodifiable(Rayon.values),
    groupByRayon: true,
    keepScreenOn: false,
    firstLaunch: false,
    seedVersions: const {},
  );
}
