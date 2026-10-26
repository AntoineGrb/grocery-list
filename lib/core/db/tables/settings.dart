import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Réglages : une seule ligne à id fixe. Propriétaire : `core/settings` (AD-2).
@DataClassName('SettingsRow')
class Settings extends Table with SyncColumns {
  /// Les 13 codes de rayon d'AD-11, dans l'ordre du parcours, séparés par `,`.
  TextColumn get routeOrder => text()();

  BoolColumn get groupByRayon => boolean()();

  BoolColumn get keepScreenOn => boolean()();

  /// Levé par le chargeur après l'insertion des recettes exemples (AD-13).
  BoolColumn get firstLaunch => boolean()();

  /// `seed_version` par fichier de `assets/seed/`, en JSON
  /// (`{"articles": 1}`) (AD-8).
  TextColumn get seedVersions => text()();
}
