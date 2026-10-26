import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Catalogue d'articles. Propriétaire : `catalogue` (AD-2).
class Articles extends Table with SyncColumns {
  TextColumn get name => text()();

  /// `normalizeName(name)` ; unique parmi les articles actifs (AD-17).
  TextColumn get normalizedName => text()();

  /// Code de rayon par défaut (AD-11).
  TextColumn get rayon => text()();

  /// Unité par défaut : `g`, `ml`, `piece` ou nulle (sans) (AD-6).
  TextColumn get unit => text().nullable()();

  /// Clé de picto stable, en kebab-case (AD-18).
  TextColumn get pictoKey => text()();
}
