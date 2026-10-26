import 'package:drift/drift.dart';

/// Colonnes communes à toutes les tables (AD-7) : `id` UUID texte,
/// `updated_at` et `deleted_at` en millisecondes UTC.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
