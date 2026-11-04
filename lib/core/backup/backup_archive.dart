import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../db/app_database.dart';

/// Format de l'archive de sauvegarde (AD-9), partagé par l'export et
/// l'import : noms de fichier et clés du JSON.
abstract final class BackupFormat {
  /// Fichier des données, à la racine de l'archive.
  static const dataFile = 'data.json';

  /// Dossier des photos de recette dans l'archive (AD-18).
  static const photosFolder = 'photos/';

  /// Version du format : le `schemaVersion` de la base (AD-14).
  static const formatVersionKey = 'format_version';

  /// Instant de l'export, en millisecondes UTC.
  static const exportedAtKey = 'exported_at';

  /// Lignes brutes de chaque table, par nom SQL de la table.
  static const tablesKey = 'tables';

  /// Suffixe du fichier en cours d'écriture, renommé une fois complet.
  static const partSuffix = '.part';

  /// `kadi-sauvegarde-AAAA-MM-JJ.zip`, à la date locale de [at].
  static String fileName(DateTime at) {
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'kadi-sauvegarde-${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)}.zip';
  }
}

/// Lignes brutes d'une table : colonne SQL → valeur telle que SQLite la
/// stocke (entier, texte, null).
typedef BackupRow = Map<String, Object?>;

/// Écrit l'archive de sauvegarde (AD-9) : `data.json` avec toutes les tables
/// de la base, lignes supprimées comprises, et `photos/` avec chaque fichier
/// du dossier des photos.
///
/// Générique : les tables viennent de `allTables`, les lignes de
/// `SELECT *` ; une table ajoutée à la base entre dans l'export sans changer
/// ce code. Les E/S de fichier sont synchrones : l'export est court, et la
/// zone de test des widgets n'attend pas les E/S asynchrones.
class BackupExporter {
  BackupExporter(this._db);

  final AppDatabase _db;

  /// Lit toutes les tables dans une seule transaction (instantané cohérent),
  /// sans rien écrire.
  Future<Map<String, List<BackupRow>>> readTables() => _db.transaction(
    () async => {
      for (final table in _db.allTables)
        table.actualTableName: [
          for (final row
              in await _db
                  .customSelect('SELECT * FROM "${table.actualTableName}"')
                  .get())
            Map<String, Object?>.of(row.data),
        ],
    },
  );

  /// Écrit `kadi-sauvegarde-<date>.zip` dans [target] et rend ce fichier.
  ///
  /// [photos] est le dossier des photos de recette : chacun de ses fichiers
  /// est copié tel quel (sans compression) sous `photos/` ; un dossier
  /// absent donne une archive sans photo, une photo référencée mais absente
  /// du disque est ignorée. [now] fixe l'instant de l'export (tests).
  ///
  /// L'archive est écrite dans un fichier `.part`, renommé une fois
  /// complet : un échec lève et ne laisse aucun fichier partiel.
  Future<File> export({
    required Directory photos,
    required Directory target,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final tables = await readTables();
    final data = jsonEncode({
      BackupFormat.formatVersionKey: _db.schemaVersion,
      BackupFormat.exportedAtKey: at.toUtc().millisecondsSinceEpoch,
      BackupFormat.tablesKey: tables,
    });

    final file = File(_join(target, BackupFormat.fileName(at)));
    final part = File('${file.path}${BackupFormat.partSuffix}');
    try {
      target.createSync(recursive: true);
      _writeZip(part, data, _photoFiles(photos), at);
      if (file.existsSync()) file.deleteSync();
      return part.renameSync(file.path);
    } catch (_) {
      _deleteQuietly(part);
      rethrow;
    }
  }

  /// Fichiers du dossier des photos, par nom ; aucun si le dossier n'existe
  /// pas (base fraîche).
  static List<File> _photoFiles(Directory photos) {
    if (!photos.existsSync()) return const [];
    return photos.listSync().whereType<File>().toList()
      ..sort((a, b) => _name(a).compareTo(_name(b)));
  }

  static void _writeZip(
    File part,
    String data,
    List<File> photos,
    DateTime at,
  ) {
    final output = OutputFileStream(part.path);
    final encoder = ZipFileEncoder();
    var closed = false;
    try {
      encoder.createWithStream(output, modified: at);
      encoder.addArchiveFile(ArchiveFile.string(BackupFormat.dataFile, data));
      for (final photo in photos) {
        // Supprimée depuis la lecture du dossier : ignorée.
        if (!photo.existsSync()) continue;
        encoder.addFileSync(
          photo,
          '${BackupFormat.photosFolder}${_name(photo)}',
          ZipFileEncoder.store,
        );
      }
      encoder.closeSync();
      closed = true;
    } finally {
      if (!closed) {
        try {
          output.closeSync();
        } catch (_) {}
      }
    }
  }

  static String _name(File file) => file.uri.pathSegments.last;

  static String _join(Directory dir, String name) =>
      '${dir.path}${Platform.pathSeparator}$name';

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
