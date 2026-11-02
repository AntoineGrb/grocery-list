import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/state/revue.dart';

/// Ajouter à la liste, depuis la Revue (R5, AD-3, AD-16), en une
/// transaction : les contributions `week_selection` des lignes cochées, avec
/// leurs quantités corrigées ([revueWrites]), fusionnées par
/// `ListeRepository` (AD-4), puis `validated_at` sur toutes les sélections
/// de la Revue, même sans contribution.
class AjouterALaListe {
  AjouterALaListe(this._db, this._liste, this._recettes);

  final AppDatabase _db;
  final ListeRepository _liste;
  final RecettesRepository _recettes;

  /// Ajoute les lignes cochées de [revue], corrigées par [draft], à la liste
  /// en cours et valide ses sélections. Un échec lève et n'écrit rien.
  Future<void> call(Revue revue, {RevueDraft draft = const RevueDraft()}) {
    final writes = revueWrites(revue, draft);
    return _db.transaction(() async {
      for (final w in writes) {
        await _liste.addRecipeContribution(
          w.articleId,
          weekSelectionId: w.selectionId,
          quantity: w.quantity,
          unit: w.unit,
        );
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
