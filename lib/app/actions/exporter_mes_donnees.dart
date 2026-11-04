import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/backup/backup_archive.dart';
import 'package:kadi/core/backup/backup_providers.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';

/// Issue d'un export : partagé, ou feuille de partage fermée sans choix.
enum ExportResult { shared, dismissed }

/// Exporter mes données (R21, AD-9) : écrit l'archive de sauvegarde dans le
/// dossier temporaire de l'app, avec les photos de recette (le dossier vient
/// de `recettes`, `core/backup` ne connaît aucune fonctionnalité), puis
/// l'ouvre dans la feuille de partage. N'écrit rien en base.
class ExporterMesDonnees {
  ExporterMesDonnees(this._exporter, this._photos, this._target, this._share);

  final BackupExporter _exporter;

  /// Dossier des photos de recette.
  final Future<Directory> Function() _photos;

  /// Dossier temporaire de l'app, où l'archive est écrite.
  final Future<Directory> Function() _target;
  final ShareFile _share;

  /// Exporte puis partage. Un échec de l'export ou du partage lève.
  Future<ExportResult> call() async {
    final file = await _exporter.export(
      photos: await _photos(),
      target: await _target(),
    );
    return await _share(file) ? ExportResult.shared : ExportResult.dismissed;
  }
}

final exporterMesDonneesProvider = Provider<ExporterMesDonnees>(
  (ref) => ExporterMesDonnees(
    ref.watch(backupExporterProvider),
    // Le dossier de `photosDirectoryProvider`, relu à chaque export : un
    // échec de lecture n'est pas gardé.
    ref.watch(recipePhotosProvider).directory,
    ref.watch(exportDirectoryProvider),
    ref.watch(shareFileProvider),
  ),
);
