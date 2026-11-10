import '../rayons/rayon.dart';

/// Thème de l'app : celui du téléphone, clair ou sombre.
enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.code);

  /// Valeur de la colonne `settings.theme_mode`.
  final String code;

  /// Préférence de [code] ; un code inconnu suit le téléphone.
  static ThemePreference fromCode(String code) => values.firstWhere(
    (p) => p.code == code,
    orElse: () => ThemePreference.system,
  );
}

/// Réglages lus par toute l'app (AD-2).
class AppSettings {
  const AppSettings({
    required this.routeOrder,
    required this.groupByRayon,
    required this.keepScreenOn,
    required this.firstLaunch,
    required this.seedVersions,
    this.theme = ThemePreference.system,
  });

  /// Les 13 rayons dans l'ordre du parcours.
  final List<Rayon> routeOrder;
  final bool groupByRayon;
  final bool keepScreenOn;
  final bool firstLaunch;

  /// `seed_version` par fichier de `assets/seed/` (clé : nom sans extension).
  final Map<String, int> seedVersions;

  /// Thème choisi dans les Paramètres.
  final ThemePreference theme;

  /// Valeurs par défaut (State Patterns d'EXPERIENCE.md, Paramètres).
  static final defaults = AppSettings(
    routeOrder: List.unmodifiable(Rayon.values),
    groupByRayon: true,
    keepScreenOn: false,
    firstLaunch: false,
    seedVersions: const {},
  );
}
