import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';

/// Terminer les courses (R4, R10, AD-3) : vide la liste et remet à zéro la
/// sélection de la semaine, en une transaction, annulable (AD-10).
class TerminerLesCourses {
  TerminerLesCourses(this._db, this._liste, this._recettes, this._undo);

  final AppDatabase _db;
  final ListeRepository _liste;
  final RecettesRepository _recettes;
  final Undo _undo;

  /// Vide la liste, supprime toutes les sélections actives et enregistre
  /// leur état d'avant dans Annuler. Rend l'entrée Annuler, ou `null` si la
  /// liste et la sélection étaient déjà vides (rien n'est écrit ni
  /// enregistré). Un échec lève et n'écrit rien.
  Future<UndoEntry?> call() async {
    final rows = await _db.transaction(
      () async => [
        ...await _liste.clearList(),
        ...await _recettes.clearSelections(),
      ],
    );
    if (rows.isEmpty) return null;
    return _undo.record(rows);
  }
}

final terminerLesCoursesProvider = Provider<TerminerLesCourses>(
  (ref) => TerminerLesCourses(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(recettesRepositoryProvider),
    ref.watch(undoProvider),
  ),
);
