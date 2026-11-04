import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/backup/backup_import.dart';
import 'package:kadi/core/backup/backup_providers.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';

/// Issue d'un import : importé, ou sélecteur fermé sans choix.
enum ImportResult { imported, cancelled }

/// Importer une sauvegarde (R21, AD-9), sans confirmation (C9) : le fichier
/// choisi est lu et validé en entier avant toute écriture, ses photos
/// absentes sont copiées dans le dossier des photos (qui vient de
/// `recettes`, `core/backup` ne connaît aucune fonctionnalité), puis, en une
/// transaction, la fusion générique par `id` et la réconciliation des
/// doublons par chaque propriétaire (AD-2) : articles et fréquents, puis
/// ingrédients et sélections, puis lignes et contributions.
class ImporterUneSauvegarde {
  ImporterUneSauvegarde(
    this._db,
    this._importer,
    this._catalogue,
    this._recettes,
    this._liste,
    this._undo,
    this._photos,
    this._pick,
  );

  final AppDatabase _db;
  final BackupImporter _importer;
  final CatalogueRepository _catalogue;
  final RecettesRepository _recettes;
  final ListeRepository _liste;
  final Undo _undo;

  /// Dossier des photos de recette.
  final Future<Directory> Function() _photos;
  final PickBackupFile _pick;

  /// Ouvre le sélecteur de fichier puis importe le fichier choisi.
  ///
  /// Sélecteur fermé : rien n'est écrit. Fichier invalide : lève une
  /// [InvalidBackupException], rien n'est écrit, ni en base ni dans le
  /// dossier des photos. Un échec d'écriture lève, la transaction est
  /// annulée et les photos copiées sont supprimées. Après un import réussi,
  /// l'emplacement Annuler est vidé (AD-10).
  Future<ImportResult> call() async {
    final bytes = await _pick();
    if (bytes == null) return ImportResult.cancelled;
    final contents = _importer.read(bytes);
    final copied = _importer.copyMissingPhotos(contents, await _photos());
    try {
      await _db.transaction(() async {
        final inserted = await _importer.merge(contents);
        final articles = await _catalogue.reconcileImportedArticles(
          inserted[_db.articles.actualTableName] ?? const {},
        );
        final selections = await _recettes.reconcileImported(articles);
        await _liste.reconcileImported(
          articles: articles,
          selections: selections,
        );
      });
    } catch (_) {
      BackupImporter.deletePhotos(copied);
      rethrow;
    }
    _undo.clear();
    return ImportResult.imported;
  }
}

final importerUneSauvegardeProvider = Provider<ImporterUneSauvegarde>(
  (ref) => ImporterUneSauvegarde(
    ref.watch(databaseProvider),
    ref.watch(backupImporterProvider),
    ref.watch(catalogueRepositoryProvider),
    ref.watch(recettesRepositoryProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(undoProvider),
    // Le dossier de `photosDirectoryProvider`, relu à chaque import, comme
    // à l'export.
    ref.watch(recipePhotosProvider).directory,
    ref.watch(pickBackupFileProvider),
  ),
);
