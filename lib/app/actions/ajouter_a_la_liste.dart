import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/state/revue.dart';

/// Ajouter à la liste, depuis la Revue (R5, AD-3, AD-16), en une
/// transaction : une contribution `week_selection` par part de recette de
/// chaque ligne, fusionnée par `ListeRepository` (AD-4), puis `validated_at`
/// sur toutes les sélections de la Revue, même sans ligne.
class AjouterALaListe {
  AjouterALaListe(this._db, this._liste, this._recettes);

  final AppDatabase _db;
  final ListeRepository _liste;
  final RecettesRepository _recettes;

  /// Ajoute les lignes de [revue] à la liste en cours et valide ses
  /// sélections. Un échec lève et n'écrit rien.
  Future<void> call(Revue revue) {
    return _db.transaction(() async {
      for (final group in revue.groups) {
        for (final line in group.lines) {
          for (final c in line.contributions) {
            await _liste.addRecipeContribution(
              line.articleId,
              weekSelectionId: c.selectionId,
              quantity: c.quantity,
              unit: c.unit,
            );
          }
        }
      }
      await _recettes.markValidated(revue.selectionIds);
    });
  }
}

final ajouterALaListeProvider = Provider<AjouterALaListe>(
  (ref) => AjouterALaListe(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
    ref.watch(recettesRepositoryProvider),
  ),
);
