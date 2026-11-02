import 'package:drift/drift.dart';

import 'articles.dart';
import 'recipes.dart';
import 'sync_columns.dart';

/// Ingrédients d'une recette. Propriétaire : `recettes` (AD-2).
class RecipeIngredients extends Table with SyncColumns {
  TextColumn get recipeId => text().references(Recipes, #id)();

  TextColumn get articleId => text().references(Articles, #id)();

  /// Ordre dans la recette ; le premier est l'ingrédient principal.
  IntColumn get position => integer()();

  /// Entier (g, ml ou millièmes de pièce), nul avec [unit] (AD-6).
  IntColumn get quantity => integer().nullable()();

  /// Unité copiée de l'article à l'ajout (AD-15), nulle avec [quantity].
  TextColumn get unit => text().nullable()();
}
