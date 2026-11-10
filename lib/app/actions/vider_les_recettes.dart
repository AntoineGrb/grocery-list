import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';

/// Vider les recettes (↻ de Recettes), confirmée par dialogue : en une
/// transaction, toutes les sélections de la semaine sont supprimées
/// logiquement, ainsi que ce qu'elles avaient mis dans la liste. Les lignes
/// ajoutées ou retouchées à la main restent (AD-7, AD-16). Annulable
/// (AD-10).
class ViderLesRecettes {
  ViderLesRecettes(this._db, this._liste, this._recettes, this._undo);

  final AppDatabase _db;
  final ListeRepository _liste;
  final RecettesRepository _recettes;
  final Undo _undo;

  /// Retire les recettes de la semaine et leurs ingrédients de la liste.
  /// Rend l'entrée Annuler, ou `null` si rien n'était sélectionné (rien
  /// n'est écrit). Un échec lève et n'écrit rien.
  Future<UndoEntry?> call() async {
    final rows = await _db.transaction(
      () async => [
        ...await _liste.removeRecipeContributions(),
        ...await _recettes.clearSelections(),
      ],
    );
    if (rows.isEmpty) return null;
    return _undo.record(rows);
  }
}

final viderLesRecettesProvider = Provider<ViderLesRecettes>(
  (ref) => ViderLesRecettes(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(recettesRepositoryProvider),
    ref.watch(undoProvider),
  ),
);
