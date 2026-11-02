import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.steps.dart';
import 'tables/articles.dart';
import 'tables/frequents.dart';
import 'tables/list_contributions.dart';
import 'tables/list_lines.dart';
import 'tables/recipe_ingredients.dart';
import 'tables/recipes.dart';
import 'tables/settings.dart';
import 'tables/week_selections.dart';

export 'tables/articles.dart';
export 'tables/frequents.dart';
export 'tables/list_contributions.dart';
export 'tables/list_lines.dart';
export 'tables/recipe_ingredients.dart';
export 'tables/recipes.dart';
export 'tables/settings.dart';
export 'tables/week_selections.dart';

part 'app_database.g.dart';

/// La base unique de Kadi (AD-1). Toutes les tables sont définies dans
/// `tables/`.
@DriftDatabase(
  tables: [
    Articles,
    Frequents,
    ListLines,
    ListContributions,
    Settings,
    Recipes,
    RecipeIngredients,
    WeekSelections,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Base de l'app, ouverte par `driftDatabase` de drift_flutter.
  AppDatabase() : super(driftDatabase(name: 'kadi'));

  /// Base sur un exécuteur fourni (tests sur Drift en mémoire).
  AppDatabase.forTesting(super.executor);

  /// Un seul `schemaVersion` (AD-14) ; chaque story qui change le schéma
  /// l'incrémente, ajoute une étape de migration non destructive et
  /// `dart run drift_dev make-migrations`.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2 : articles hors catalogue (AD-17) ; les articles existants
      // restent au catalogue (défaut vrai).
      from1To2: (m, schema) async {
        await m.addColumn(schema.articles, schema.articles.inCatalogue);
      },
      // v3 : recettes, ingrédients et sélections de la semaine (epic 2),
      // créées vides ; rien d'existant ne change.
      from2To3: (m, schema) async {
        await m.createTable(schema.recipes);
        await m.createTable(schema.recipeIngredients);
        await m.createTable(schema.weekSelections);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
