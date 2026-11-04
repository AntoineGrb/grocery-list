import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/db_providers.dart';
import '../settings/settings_providers.dart';
import 'backup_archive.dart';
import 'backup_import.dart';

/// Ouvre [file] dans la feuille de partage ; vrai sauf si Antoine la ferme
/// sans rien choisir.
typedef ShareFile = Future<bool> Function(File file);

/// Ouvre le sélecteur de fichier et rend le contenu du fichier choisi ;
/// `null` si Antoine le ferme sans rien choisir.
typedef PickBackupFile = Future<List<int>?> Function();

/// L'exporteur de sauvegarde sur la base de l'app (AD-9).
final backupExporterProvider = Provider<BackupExporter>(
  (ref) => BackupExporter(ref.watch(databaseProvider)),
);

/// Dossier où l'archive est écrite : le dossier temporaire de l'app, rien
/// au-delà. Remplacé en test par un dossier temporaire.
final exportDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

/// Feuille de partage Android (`share_plus`), sans permission (C2) : le
/// paquet copie le fichier dans son cache et le partage par son
/// `FileProvider`. Remplacé en test par un double.
final shareFileProvider = Provider<ShareFile>(
  (ref) => (file) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/zip')]),
    );
    return result.status != ShareResultStatus.dismissed;
  },
);

/// L'importeur de sauvegarde sur la base de l'app (AD-9).
final backupImporterProvider = Provider<BackupImporter>(
  (ref) => BackupImporter(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

/// Sélecteur de fichier Android (`file_picker`, Storage Access Framework),
/// sans permission (C2) : tout type de fichier, la validation de l'import
/// refuse ce qui n'est pas une sauvegarde. Remplacé en test par un double.
final pickBackupFileProvider = Provider<PickBackupFile>(
  (ref) => () async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    return file.readAsBytes();
  },
);
