import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';

/// Désélectionner une recette validée (R6, AD-3), en une transaction : sa
/// sélection est supprimée logiquement (AD-16) et ses contributions quittent
/// les lignes non cochées et non manuelles de la liste (AD-4, AD-5) ;
/// annulable (AD-10).
class DeselectionnerUneRecette {
  DeselectionnerUneRecette(this._db, this._liste, this._recettes, this._undo);

  final AppDatabase _db;
  final ListeRepository _liste;
  final RecettesRepository _recettes;
  final Undo _undo;

  /// Désélectionne la recette validée [recipeId] et enregistre l'état d'avant
  /// dans Annuler. Rend l'entrée Annuler, même si aucune ligne de la liste
  /// n'a changé, ou `null` si la recette n'a pas de sélection validée (rien
  /// n'est écrit ni enregistré). Un échec lève et n'écrit rien.
  Future<UndoEntry?> call(String recipeId) async {
    final rows = await _db.transaction(() async {
      final deselected = await _recettes.deselectValidated(recipeId);
      return [
        ...deselected.undoRows,
        for (final id in deselected.selectionIds)
          ...await _liste.removeSelectionContributions(id),
      ];
    });
    if (rows.isEmpty) return null;
    return _undo.record(rows);
  }
}

final deselectionnerUneRecetteProvider = Provider<DeselectionnerUneRecette>(
  (ref) => DeselectionnerUneRecette(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(recettesRepositoryProvider),
    ref.watch(undoProvider),
  ),
);
