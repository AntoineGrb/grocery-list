import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

/// Terminer les courses (R4, AD-3) : vide la liste en une transaction,
/// annulable (AD-10).
///
/// L'epic 2 y ajoutera la remise à zéro de la sélection de la semaine, dans
/// la même transaction.
class TerminerLesCourses {
  TerminerLesCourses(this._db, this._liste, this._undo);

  final AppDatabase _db;
  final ListeRepository _liste;
  final Undo _undo;

  /// Vide la liste et enregistre son état d'avant dans Annuler. Rend
  /// l'entrée Annuler, ou `null` si la liste était déjà vide (rien n'est
  /// écrit ni enregistré). Un échec lève et n'écrit rien.
  Future<UndoEntry?> call() async {
    final rows = await _db.transaction(_liste.clearList);
    if (rows.isEmpty) return null;
    return _undo.record(rows);
  }
}

final terminerLesCoursesProvider = Provider<TerminerLesCourses>(
  (ref) => TerminerLesCourses(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(undoProvider),
  ),
);
