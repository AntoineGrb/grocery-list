import 'package:drift/drift.dart';

import 'articles.dart';
import 'sync_columns.dart';

/// Lignes de la liste. Propriétaire : `liste` (AD-2).
///
/// La quantité n'est jamais stockée : c'est la somme des contributions
/// actives (AD-4).
@DataClassName('ListLine')
class ListLines extends Table with SyncColumns {
  TextColumn get articleId => text().references(Articles, #id)();

  /// Rayon copié de l'article à la création (AD-15).
  TextColumn get rayon => text()();

  /// Unité de la ligne, nulle sans quantité ; `unit_key` vaut l'unité ou `-`.
  TextColumn get unit => text().nullable()();

  /// Fixé à la création, ne change jamais ; ordonne les lignes (AD-4).
  IntColumn get addedAt => integer()();

  IntColumn get checkedAt => integer().nullable()();

  /// Fixé quand la quantité est corrigée à la main (AD-5).
  IntColumn get manualAt => integer().nullable()();
}
