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

  /// Faux pour un article hors catalogue, né d'un texte validé par Entrée
  /// dans le Panneau + : absent de la recherche et de Paramètres › Articles
  /// (AD-17). Vrai pour les articles d'avant la v2 (AD-14).
  BoolColumn get inCatalogue => boolean().withDefault(const Constant(true))();
}
