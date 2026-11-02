import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Recettes. Propriétaire : `recettes` (AD-2).
class Recipes extends Table with SyncColumns {
  TextColumn get name => text()();

  /// Lien facultatif vers la recette en ligne.
  TextColumn get link => text().nullable()();

  /// Nom du fichier de la photo dans `photos/` (AD-18), nul sans photo.
  TextColumn get photo => text().nullable()();
}
