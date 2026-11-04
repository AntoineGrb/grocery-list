import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../settings/settings_repository.dart';
import 'backup_archive.dart';

/// Le fichier choisi n'est pas une sauvegarde Kadi lisible : rien n'a été
/// écrit, ni en base ni dans le dossier des photos.
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.reason);

  /// Ce qui ne va pas (journal de test, jamais affiché).
  final String reason;

  @override
  String toString() => 'InvalidBackupException: $reason';
}

/// Migration des tables d'une sauvegarde d'une version du format vers la
/// suivante (AD-9, AD-14) : lignes brutes par nom SQL de table.
typedef BackupMigration = Map<String, List<BackupRow>> Function(
  Map<String, List<BackupRow>> tables,
);

/// Sauvegarde lue et validée, prête à fusionner : rien n'est encore écrit.
class BackupContents {
  const BackupContents._(this.tables, this.photos);

  /// Lignes de chaque table du fichier, par nom SQL ; chaque ligne porte
  /// toutes les colonnes de sa table (les absentes à leur valeur par défaut),
  /// en valeurs SQLite (entier, réel, texte, null).
  final Map<String, List<BackupRow>> tables;

  /// Photos de recette de `photos/`, par nom de fichier.
  final Map<String, Uint8List> photos;
}

/// Import d'une sauvegarde (AD-9) : lecture et validation complète de
/// l'archive ([read]) avant toute écriture, copie des photos absentes
/// ([copyMissingPhotos]), puis fusion générique ligne par ligne par `id`
/// ([merge]).
///
/// Générique comme l'export : les tables et leurs colonnes viennent de
/// `allTables`. Les doublons de clé naturelle ne sont pas réglés ici : chaque
/// propriétaire les réconcilie après la fusion, dans la même transaction
/// (AD-2) ; `core` ne connaît aucune fonctionnalité. Les E/S de fichier sont
/// synchrones, comme celles de l'export.
class BackupImporter {
  BackupImporter(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  /// Migrations du format, par version de départ : la migration `n` mène un
  /// fichier de la version `n` à `n + 1`. Vide tant que le schéma n'a pas
  /// changé depuis la version 3 ; une version absente de la table (et
  /// différente de `schemaVersion`) est refusée.
  static const Map<int, BackupMigration> migrations = {};

  /// Ordre de la fusion, celui des dépendances (AD-9). Une table future
  /// absente de la liste est fusionnée après celles-ci, avant les réglages.
  static const mergeOrder = [
    'articles',
    'recipes',
    'recipe_ingredients',
    'week_selections',
    'list_lines',
    'list_contributions',
    'frequents',
    'settings',
  ];

  /// Lit et valide l'archive [bytes], sans rien écrire.
  ///
  /// Lève une [InvalidBackupException] si ce n'est pas un zip lisible, si
  /// `data.json` manque ou n'est pas un objet JSON, si `format_version`
  /// n'est pas un entier connu, si `tables` nomme une table inconnue, si une
  /// ligne porte une colonne inconnue, une valeur du mauvais type, ou pas de
  /// valeur pour une colonne requise sans défaut, si un `id` est vide ou en
  /// double dans sa table, ou si une entrée de `photos/` n'est pas un simple
  /// nom de fichier.
  BackupContents read(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const InvalidBackupException('archive zip illisible');
    }

    ArchiveFile? dataFile;
    final photos = <String, Uint8List>{};
    for (final entry in archive.files) {
      final name = entry.name;
      if (name == BackupFormat.dataFile) {
        if (!entry.isFile) {
          throw const InvalidBackupException('data.json n’est pas un fichier');
        }
        dataFile = entry;
        continue;
      }
      // Les autres entrées ne sont jamais extraites.
      if (!name.startsWith(BackupFormat.photosFolder)) continue;
      final photo = name.substring(BackupFormat.photosFolder.length);
      if (photo.isEmpty && !entry.isFile) continue; // Le dossier `photos/`.
      if (!entry.isFile || !isPhotoName(photo)) {
        throw InvalidBackupException('entrée de photo invalide : $name');
      }
      photos.putIfAbsent(photo, () => _contentOf(entry));
    }
    if (dataFile == null) {
      throw const InvalidBackupException('data.json absent');
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(_contentOf(dataFile)));
    } on InvalidBackupException {
      rethrow;
    } catch (_) {
      throw const InvalidBackupException('data.json n’est pas du JSON');
    }
    if (json is! Map<String, Object?>) {
      throw const InvalidBackupException('data.json n’est pas un objet');
    }

    final version = json[BackupFormat.formatVersionKey];
    if (version is! int) {
      throw const InvalidBackupException('format_version absent');
    }
    var tables = _rawTables(json[BackupFormat.tablesKey]);
    tables = _migrate(version, tables);
    return BackupContents._(_validated(tables), photos);
  }

  /// Un simple nom de fichier : ni `.`, ni `/`, ni `\`, ni `..` ; aucune
  /// photo ne s'écrit ni ne se lit hors du dossier des photos.
  static bool isPhotoName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      !name.contains('/') &&
      !name.contains(r'\') &&
      !name.contains('..') &&
      !name.contains('\u0000');

  static Uint8List _contentOf(ArchiveFile entry) {
    try {
      return entry.readBytes() ?? Uint8List(0);
    } catch (_) {
      throw InvalidBackupException('entrée illisible : ${entry.name}');
    }
  }

  /// `tables` : un objet de listes d'objets.
  static Map<String, List<BackupRow>> _rawTables(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const InvalidBackupException('tables absent');
    }
    return {
      for (final MapEntry(:key, :value) in raw.entries)
        key: switch (value) {
          final List<Object?> rows => [
            for (final row in rows)
              if (row is Map<String, Object?>)
                Map<String, Object?>.of(row)
              else
                throw InvalidBackupException('ligne invalide dans $key'),
          ],
          _ => throw InvalidBackupException('table invalide : $key'),
        },
    };
  }

  /// Mène [tables] de la version [version] au `schemaVersion` par
  /// [migrations] ; une version inconnue ou plus récente est refusée.
  Map<String, List<BackupRow>> _migrate(
    int version,
    Map<String, List<BackupRow>> tables,
  ) {
    final target = _db.schemaVersion;
    if (version > target) {
      throw InvalidBackupException('format_version $version trop récent');
    }
    var migrated = tables;
    for (var v = version; v < target; v++) {
      final step = migrations[v];
      if (step == null) {
        throw InvalidBackupException('format_version $version inconnu');
      }
      try {
        migrated = step(migrated);
      } catch (_) {
        throw InvalidBackupException('migration $v → ${v + 1} impossible');
      }
    }
    return migrated;
  }

  /// Valide chaque ligne contre sa table de `allTables` et la complète :
  /// colonnes absentes à leur valeur par défaut, booléens en 0/1.
  Map<String, List<BackupRow>> _validated(Map<String, List<BackupRow>> raw) {
    final tables = {for (final t in _db.allTables) t.actualTableName: t};
    return {
      for (final MapEntry(key: name, value: rows) in raw.entries)
        name: _validRows(
          tables[name] ??
              (throw InvalidBackupException('table inconnue : $name')),
          rows,
        ),
    };
  }

  static List<BackupRow> _validRows(
    TableInfo<Table, dynamic> table,
    List<BackupRow> rows,
  ) {
    final name = table.actualTableName;
    final columns = table.$columns;
    final known = {for (final c in columns) c.name};
    final ids = <String>{};
    final valid = <BackupRow>[];
    for (final row in rows) {
      for (final key in row.keys) {
        if (!known.contains(key)) {
          throw InvalidBackupException('colonne inconnue : $name.$key');
        }
      }
      final complete = <String, Object?>{
        for (final c in columns)
          c.name: _checked(
            name,
            c,
            row.containsKey(c.name) ? row[c.name] : _defaultOf(name, c),
          ),
      };
      final id = complete['id'];
      if (id is! String || id.isEmpty || !ids.add(id)) {
        throw InvalidBackupException('id vide ou en double dans $name');
      }
      if (complete['updated_at'] is! int) {
        throw InvalidBackupException('updated_at invalide dans $name');
      }
      // Le nom de photo d'une recette se lit dans le dossier des photos :
      // jamais un chemin (AD-18).
      final photo = name == 'recipes' ? complete['photo'] : null;
      if (photo is String && !isPhotoName(photo)) {
        throw const InvalidBackupException('photo de recette invalide');
      }
      valid.add(complete);
    }
    return valid;
  }

  /// Valeur par défaut d'une colonne absente d'une ligne : son défaut SQL
  /// constant ou Dart, sinon null si elle l'accepte ; une colonne requise
  /// sans défaut rend le fichier invalide.
  static Object? _defaultOf(String table, GeneratedColumn<Object> column) {
    final sqlDefault = column.defaultValue;
    if (sqlDefault is Constant) return sqlDefault.value;
    if (sqlDefault == null) {
      final client = column.clientDefault;
      if (client != null) return client();
      if (column.$nullable) return null;
    }
    throw InvalidBackupException(
      'colonne requise absente : $table.${column.name}',
    );
  }

  /// [value] en valeur SQLite du type de [column], sinon le fichier est
  /// invalide : une valeur mal typée ne doit jamais entrer en base.
  static Object? _checked(
    String table,
    GeneratedColumn<Object> column,
    Object? value,
  ) {
    Never invalid() => throw InvalidBackupException(
      'valeur invalide pour $table.${column.name}',
    );
    if (value == null) return column.$nullable ? null : invalid();
    final type = column.type;
    if (type == DriftSqlType.string) return value is String ? value : invalid();
    if (type == DriftSqlType.int || type == DriftSqlType.bigInt) {
      return value is int ? value : invalid();
    }
    if (type == DriftSqlType.bool) {
      if (value == true || (value is int && value == 1)) return 1;
      if (value == false || (value is int && value == 0)) return 0;
      return invalid();
    }
    if (type == DriftSqlType.double) {
      return value is num ? value.toDouble() : invalid();
    }
    // Dates en entiers (convention du projet), `any` : valeurs simples.
    if (type == DriftSqlType.dateTime || type == DriftSqlType.any) {
      return value is int || value is String || value is double
          ? value
          : invalid();
    }
    // Blob et types inconnus : JSON ne les porte pas.
    return invalid();
  }

  /// Copie dans [directory] les photos de [contents] absentes du dossier
  /// (par nom de fichier) et rend les fichiers créés, à supprimer si la
  /// fusion échoue ([deletePhotos]). Un échec supprime ce qui a été copié et
  /// lève.
  List<File> copyMissingPhotos(BackupContents contents, Directory directory) {
    final copied = <File>[];
    try {
      for (final MapEntry(key: name, value: bytes) in contents.photos.entries) {
        final file = File('${directory.path}${Platform.pathSeparator}$name');
        if (file.existsSync()) continue;
        directory.createSync(recursive: true);
        copied.add(file);
        file.writeAsBytesSync(bytes, flush: true);
      }
    } catch (_) {
      deletePhotos(copied);
      rethrow;
    }
    return copied;
  }

  /// Supprime [files] ; un échec est ignoré (au pire, une photo orpheline
  /// reste dans le dossier).
  static void deletePhotos(List<File> files) {
    for (final file in files) {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
  }

  /// Fusionne [contents] dans la base, à appeler dans une transaction :
  /// table par table dans l'ordre de [mergeOrder], une ligne absente
  /// localement est insérée telle quelle, une ligne présente est remplacée
  /// seulement si son `updated_at` importé est plus grand (égalité : la
  /// locale reste) ; suppressions logiques comprises (AD-7). Les réglages
  /// prennent l'ordre du parcours, le groupement et Écran allumé du fichier
  /// et gardent leur premier lancement et leurs `seed_version`
  /// ([SettingsRepository.applyImported]).
  ///
  /// Rend, par nom SQL de table, les ids des lignes insérées (absentes
  /// localement avant l'import) : les réconciliations gardent la ligne
  /// locale d'un doublon.
  Future<Map<String, Set<String>>> merge(BackupContents contents) async {
    final settingsName = _db.settings.actualTableName;
    final byName = {for (final t in _db.allTables) t.actualTableName: t};
    final ordered = [
      for (final name in mergeOrder) ?byName[name],
      for (final t in _db.allTables)
        if (!mergeOrder.contains(t.actualTableName)) t,
    ];
    final inserted = <String, Set<String>>{};
    for (final table in ordered) {
      final name = table.actualTableName;
      if (name == settingsName) continue;
      inserted[name] = await _mergeTable(table, contents.tables[name]);
    }
    await _mergeSettings(contents.tables[settingsName]);
    return inserted;
  }

  Future<Set<String>> _mergeTable(
    TableInfo<Table, dynamic> table,
    List<BackupRow>? rows,
  ) async {
    final inserted = <String>{};
    if (rows == null || rows.isEmpty) return inserted;
    final name = '"${table.actualTableName}"';
    final local = {
      for (final row
          in await _db.customSelect('SELECT id, updated_at FROM $name').get())
        row.read<String>('id'): row.read<int>('updated_at'),
    };
    for (final row in rows) {
      final id = row['id']! as String;
      final before = local[id];
      if (before == null) {
        final columns = [for (final c in row.keys) '"$c"'];
        await _db.customInsert(
          'INSERT INTO $name (${columns.join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')})',
          variables: [for (final v in row.values) Variable<Object>(v)],
          updates: {table},
        );
        inserted.add(id);
      } else if ((row['updated_at']! as int) > before) {
        final columns = [
          for (final c in row.keys)
            if (c != 'id') c,
        ];
        await _db.customUpdate(
          'UPDATE $name SET '
          '${[for (final c in columns) '"$c" = ?'].join(', ')} '
          'WHERE id = ?',
          variables: [
            for (final c in columns) Variable<Object>(row[c]),
            Variable<String>(id),
          ],
          updates: {table},
          updateKind: UpdateKind.update,
        );
      }
    }
    return inserted;
  }

  /// La ligne de réglages du fichier (id fixe) : ses trois réglages
  /// utilisateur sont toujours repris, par le propriétaire de `settings`.
  Future<void> _mergeSettings(List<BackupRow>? rows) async {
    final row = rows
        ?.where((r) => r['id'] == SettingsRepository.rowId)
        .firstOrNull;
    if (row == null) return;
    final s = _db.settings;
    await _settings.applyImported(
      routeOrder: row[s.routeOrder.name]! as String,
      groupByRayon: row[s.groupByRayon.name] == 1,
      keepScreenOn: row[s.keepScreenOn.name] == 1,
    );
  }
}
