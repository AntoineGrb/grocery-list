import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';

/// Supprime les sélections puis échoue, dans la transaction de l'action.
class FailingClearSelectionsRepository extends RecettesRepository {
  FailingClearSelectionsRepository(super.db, super.clock);

  @override
  Future<List<UndoRow>> clearSelections() async {
    await super.clearSelections();
    throw StateError('échec simulé');
  }
}
