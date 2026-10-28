import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock/clock.dart';
import '../db/app_database.dart';
import '../db/db_providers.dart';

/// État d'avant d'une ligne touchée par une action annulable (AD-10).
///
/// Soit la ligne telle qu'elle était ([UndoRow.before]), soit « absente » :
/// créée par l'action ([UndoRow.absent]).
class UndoRow {
  /// [row] est l'état complet de la ligne avant l'action (sa classe de
  /// données) ; toutes ses colonnes sont réécrites, les nulles comprises.
  UndoRow.before(this.table, Insertable<Object?> row)
    : _columns = {
        for (final MapEntry(:key, :value) in row.toColumns(false).entries)
          key: value as Variable,
      },
      _absentId = null;

  /// La ligne [id] de [table] n'existait pas avant l'action.
  UndoRow.absent(this.table, String id) : _columns = null, _absentId = id;

  final TableInfo<Table, dynamic> table;

  /// Colonnes de la ligne d'avant, par nom SQL.
  final Map<String, Variable>? _columns;
  final String? _absentId;

  /// Réécrit l'état d'avant avec `updated_at` = [stamp], ou supprime
  /// logiquement la ligne absente. Les flux de [table] sont notifiés.
  ///
  /// En SQL : l'insertion typée de drift omettrait les colonnes nulles
  /// (`deleted_at`, `checked_at`), qui ne seraient pas remises à nul.
  Future<void> _restore(AppDatabase db, int stamp) async {
    final name = '"${table.actualTableName}"';
    final columns = _columns;
    if (columns != null) {
      final values = {...columns, 'updated_at': Variable<int>(stamp)};
      final names = [for (final c in values.keys) '"$c"'];
      await db.customInsert(
        'INSERT INTO $name (${names.join(', ')}) '
        'VALUES (${List.filled(names.length, '?').join(', ')}) '
        'ON CONFLICT(id) DO UPDATE SET '
        '${[for (final n in names) '$n = excluded.$n'].join(', ')}',
        variables: values.values.toList(),
        updates: {table},
      );
      return;
    }
    await db.customUpdate(
      'UPDATE $name SET deleted_at = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable<int>(stamp),
        Variable<int>(stamp),
        Variable<String>(_absentId!),
      ],
      updates: {table},
      updateKind: UpdateKind.update,
    );
  }
}

/// Une action annulable enregistrée : ses lignes et le dernier horodatage
/// émis au moment de l'enregistrement.
class UndoEntry {
  UndoEntry._(this.rows, this.stamp);

  final List<UndoRow> rows;

  /// `Clock.last` à l'enregistrement ; s'il a bougé, une autre écriture a eu
  /// lieu.
  final int stamp;
}

/// Service Annuler (AD-10) : un seul emplacement.
///
/// L'emplacement est vidé par toute autre écriture (témoin : `Clock.last`),
/// par la fin du snackbar ([clear]) et par une nouvelle action ([record]).
class Undo {
  Undo(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;
  UndoEntry? _slot;

  /// Enregistre [rows], à appeler après la validation de la transaction de
  /// l'action. Remplace l'emplacement.
  UndoEntry record(List<UndoRow> rows) =>
      _slot = UndoEntry._(List.unmodifiable(rows), _clock.last);

  /// Réécrit l'état d'avant de [entry] dans une transaction, avec des
  /// `updated_at` neufs ; une ligne absente est supprimée logiquement.
  ///
  /// Rend `false` sans rien écrire si [entry] n'est plus l'emplacement ou si
  /// une autre écriture a eu lieu depuis. L'emplacement est vidé avant
  /// d'écrire ; un échec lève et n'écrit rien.
  Future<bool> undo(UndoEntry entry) async {
    if (!identical(_slot, entry)) return false;
    _slot = null;
    if (_clock.last != entry.stamp) return false;

    await _db.transaction(() async {
      for (final row in entry.rows) {
        await row._restore(_db, _clock.stamp());
      }
    });
    return true;
  }

  /// Vide l'emplacement s'il contient [entry], ou sans condition sans
  /// [entry].
  void clear([UndoEntry? entry]) {
    if (entry == null || identical(_slot, entry)) _slot = null;
  }
}

/// Le service Annuler unique de l'app (AD-10).
final undoProvider = Provider<Undo>(
  (ref) => Undo(ref.watch(databaseProvider), ref.watch(clockProvider)),
);
