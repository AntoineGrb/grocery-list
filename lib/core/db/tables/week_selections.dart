import 'package:drift/drift.dart';

import 'recipes.dart';
import 'sync_columns.dart';

/// Sélection d'une recette pour la semaine. Propriétaire : `recettes`
/// (AD-2). Chaque sélection crée une nouvelle ligne, jamais réactivée sauf
/// par Annuler (AD-16).
class WeekSelections extends Table with SyncColumns {
  TextColumn get recipeId => text().references(Recipes, #id)();

  /// Fixé par Ajouter à la liste seulement (AD-16) ; nul : à valider.
  IntColumn get validatedAt => integer().nullable()();
}
