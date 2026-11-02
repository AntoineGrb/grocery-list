import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';

/// Nouvelle liste (R8, AD-3), confirmée par dialogue (C9) : en une
/// transaction, toutes les lignes de la liste, cochées ou non, leurs
/// contributions et toutes les sélections de la semaine sont supprimées
/// logiquement (AD-7, AD-16). Pas d'Annuler.
class NouvelleListe {
  NouvelleListe(this._db, this._liste, this._recettes, this._undo);

  final AppDatabase _db;
  final ListeRepository _liste;
  final RecettesRepository _recettes;
  final Undo _undo;

  /// Efface la liste et la sélection. Une liste et une sélection déjà vides
  /// n'écrivent rien. L'emplacement Annuler est vidé : un Annuler encore
  /// affiché (Terminer les courses) ne rend plus ce qui vient d'être
  /// effacé. Un échec lève et n'écrit rien.
  Future<void> call() async {
    await _db.transaction(() async {
      await _liste.clearList();
      await _recettes.clearSelections();
    });
    _undo.clear();
  }
}

final nouvelleListeProvider = Provider<NouvelleListe>(
  (ref) => NouvelleListe(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(recettesRepositoryProvider),
    ref.watch(undoProvider),
  ),
);
