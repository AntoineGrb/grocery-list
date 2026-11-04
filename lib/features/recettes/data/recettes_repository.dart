import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:uuid/uuid.dart';

import 'recettes_models.dart';
import 'recipe_link.dart';

export 'recettes_models.dart';

/// Propriétaire de `recipes`, `recipe_ingredients` et `week_selections`
/// (AD-2).
class RecettesRepository {
  RecettesRepository(this._db, this._clock, {this._uuid = const Uuid()});

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  /// Cartes des recettes actives, triées par nom normalisé puis `id`.
  ///
  /// L'ingrédient principal est le premier ingrédient actif par `position`
  /// dont l'article est actif (un article supprimé compte comme supprimé,
  /// AD-7).
  Stream<List<RecipeCardItem>> watchCards() {
    const mainIngredient =
        'FROM recipe_ingredients i '
        'INNER JOIN articles a ON a.id = i.article_id AND a.deleted_at IS NULL '
        'WHERE i.recipe_id = r.id AND i.deleted_at IS NULL '
        'ORDER BY i.position, i.id LIMIT 1';
    const activeSelection =
        'FROM week_selections s '
        'WHERE s.recipe_id = r.id AND s.deleted_at IS NULL';
    final query = _db.customSelect(
      'SELECT r.id, r.name, r.photo, '
      '(SELECT a.picto_key $mainIngredient) AS picto_key, '
      '(SELECT a.rayon $mainIngredient) AS rayon, '
      'EXISTS (SELECT 1 $activeSelection) AS selected, '
      'EXISTS (SELECT 1 $activeSelection AND s.validated_at IS NOT NULL) '
      'AS validated '
      'FROM recipes r WHERE r.deleted_at IS NULL',
      readsFrom: {
        _db.recipes,
        _db.recipeIngredients,
        _db.articles,
        _db.weekSelections,
      },
    );
    return query.watch().map((rows) {
      final cards = [
        for (final row in rows)
          RecipeCardItem(
            recipeId: row.read<String>('id'),
            name: row.read<String>('name'),
            photo: row.readNullable<String>('photo'),
            pictoKey: row.readNullable<String>('picto_key') ?? '',
            rayon:
                Rayon.tryFromCode(row.readNullable<String>('rayon') ?? '') ??
                Rayon.divers,
            selected: row.read<bool>('selected'),
            validated: row.read<bool>('validated'),
          ),
      ];
      return _sortedByName(cards, (c) => c.name, (c) => c.recipeId);
    });
  }

  /// Nouvel id (UUID v4) d'une recette ou d'un ingrédient de la Fiche
  /// recette, tiré à l'ouverture d'une fiche vide ou à l'ajout (AD-7).
  String newId() => _uuid.v4();

  /// La recette active [recipeId] pour la Fiche recette : son nom et ses
  /// ingrédients actifs par `position` dont l'article est actif (AD-7), avec
  /// le nom, le picto, le rayon et l'unité actuels de l'article. `null` si la
  /// recette est absente ou supprimée.
  Future<RecipeSheet?> readSheet(String recipeId) async {
    final recipe =
        await (_db.select(_db.recipes)
              ..where((r) => r.id.equals(recipeId) & r.deletedAt.isNull()))
            .getSingleOrNull();
    if (recipe == null) return null;
    final i = _db.recipeIngredients;
    final a = _db.articles;
    final rows =
        await (_db.select(i).join([
                innerJoin(
                  a,
                  a.id.equalsExp(i.articleId) & a.deletedAt.isNull(),
                ),
              ])
              ..where(i.recipeId.equals(recipeId) & i.deletedAt.isNull())
              ..orderBy([OrderingTerm.asc(i.position), OrderingTerm.asc(i.id)]))
            .get();
    return RecipeSheet(
      recipeId: recipe.id,
      name: recipe.name,
      link: recipe.link,
      photo: recipe.photo,
      ingredients: [
        for (final row in rows)
          _sheetIngredient(row.readTable(i), row.readTable(a)),
      ],
    );
  }

  static RecipeSheetIngredient _sheetIngredient(
    RecipeIngredient ingredient,
    Article article,
  ) {
    final unit = Unit.tryFromCode(ingredient.unit);
    final quantity = ingredient.quantity;
    final hasQuantity = unit != null && quantity != null && quantity > 0;
    return RecipeSheetIngredient(
      id: ingredient.id,
      articleId: article.id,
      name: article.name,
      pictoKey: article.pictoKey,
      rayon: Rayon.tryFromCode(article.rayon) ?? Rayon.divers,
      quantity: hasQuantity ? quantity : null,
      unit: hasQuantity ? unit : null,
      articleUnit: Unit.tryFromCode(article.unit),
    );
  }

  /// Écrit le brouillon [draft] de la Fiche recette en une transaction, au
  /// tap sur « Enregistrer » (R1) : la recette (insérée, ou nom, lien
  /// nettoyé et photo mis à jour),
  /// ses ingrédients (insérés, ou position, article, quantité et unité mis à
  /// jour) ; les ingrédients actifs absents du brouillon sont supprimés
  /// logiquement (AD-7). Seules les lignes qui changent sont écrites.
  ///
  /// Rien n'est écrit, et le résultat est faux, si le brouillon n'a pas de
  /// nom une fois nettoyé ([cleanRecipeName]) ou pas d'ingrédient, ou si la
  /// recette a été supprimée : la recette en base reste telle quelle.
  Future<bool> saveDraft(RecipeDraft draft) {
    final name = cleanRecipeName(draft.name);
    if (name.isEmpty || draft.ingredients.isEmpty) return Future.value(false);
    final link = cleanRecipeLink(draft.link);
    final photo = draft.photo;
    return _db.transaction(() async {
      final recipe = await (_db.select(
        _db.recipes,
      )..where((r) => r.id.equals(draft.recipeId))).getSingleOrNull();
      if (recipe == null) {
        await _db
            .into(_db.recipes)
            .insert(
              RecipesCompanion.insert(
                id: draft.recipeId,
                updatedAt: _clock.stamp(),
                name: name,
                link: Value(link),
                photo: Value(photo),
              ),
            );
      } else if (recipe.deletedAt != null) {
        return false;
      } else if (recipe.name != name ||
          recipe.link != link ||
          recipe.photo != photo) {
        await (_db.update(
          _db.recipes,
        )..where((r) => r.id.equals(recipe.id))).write(
          RecipesCompanion(
            name: Value(name),
            link: Value(link),
            photo: Value(photo),
            updatedAt: Value(_clock.stamp(recipe.updatedAt)),
          ),
        );
      }

      // Ce que la fiche a lu ([readSheet]) : un ingrédient dont l'article
      // est supprimé n'y est pas, et reste tel quel.
      final i = _db.recipeIngredients;
      final a = _db.articles;
      final existing = {
        for (final row
            in await (_db.select(i).join([
                  innerJoin(
                    a,
                    a.id.equalsExp(i.articleId) & a.deletedAt.isNull(),
                  ),
                ])..where(
                  i.recipeId.equals(draft.recipeId) & i.deletedAt.isNull(),
                ))
                .get())
          row.readTable(i).id: row.readTable(i),
      };
      for (final (position, ingredient) in draft.ingredients.indexed) {
        final hasQuantity =
            ingredient.quantity != null &&
            ingredient.quantity! > 0 &&
            ingredient.unit != null;
        final quantity = hasQuantity ? ingredient.quantity : null;
        final unit = hasQuantity ? ingredient.unit!.code : null;
        final before = existing.remove(ingredient.id);
        if (before == null) {
          await _db
              .into(_db.recipeIngredients)
              .insert(
                RecipeIngredientsCompanion.insert(
                  id: ingredient.id,
                  updatedAt: _clock.stamp(),
                  recipeId: draft.recipeId,
                  articleId: ingredient.articleId,
                  position: position,
                  quantity: Value(quantity),
                  unit: Value(unit),
                ),
              );
        } else if (before.position != position ||
            before.articleId != ingredient.articleId ||
            before.quantity != quantity ||
            before.unit != unit) {
          await (_db.update(
            _db.recipeIngredients,
          )..where((i) => i.id.equals(before.id))).write(
            RecipeIngredientsCompanion(
              articleId: Value(ingredient.articleId),
              position: Value(position),
              quantity: Value(quantity),
              unit: Value(unit),
              updatedAt: Value(_clock.stamp(before.updatedAt)),
            ),
          );
        }
      }
      for (final removed in existing.values) {
        final stamp = _clock.stamp(removed.updatedAt);
        await (_db.update(
          _db.recipeIngredients,
        )..where((i) => i.id.equals(removed.id))).write(
          RecipeIngredientsCompanion(
            deletedAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
      }
      return true;
    });
  }

  /// Supprime logiquement la recette [recipeId] en une transaction (R1,
  /// AD-7) : seule sa ligne est écrite ; ses ingrédients et ses sélections
  /// comptent comme supprimés par leur parent. La liste en cours ne change
  /// pas (R7) et le fichier de sa photo est gardé, pour Annuler.
  ///
  /// Rend son nom et son état d'avant (AD-10), ou `null` sans rien écrire si
  /// la recette est absente ou déjà supprimée.
  Future<DeletedRecipe?> deleteRecipe(String recipeId) {
    return _db.transaction(() async {
      final recipe =
          await (_db.select(_db.recipes)
                ..where((r) => r.id.equals(recipeId) & r.deletedAt.isNull()))
              .getSingleOrNull();
      if (recipe == null) return null;
      final stamp = _clock.stamp(recipe.updatedAt);
      await (_db.update(
        _db.recipes,
      )..where((r) => r.id.equals(recipe.id))).write(
        RecipesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
      );
      return (name: recipe.name, undoRow: UndoRow.before(_db.recipes, recipe));
    });
  }

  /// Trie [items] sur place par nom normalisé ([name]) puis par [id], et les
  /// rend : ordre des cartes et des sélections à valider.
  static List<T> _sortedByName<T>(
    List<T> items,
    String Function(T) name,
    String Function(T) id,
  ) {
    return items..sort((x, y) {
      final byName = normalizeName(name(x)).compareTo(normalizeName(name(y)));
      return byName != 0 ? byName : id(x).compareTo(id(y));
    });
  }

  /// Sélectionne la recette [recipeId] pour la semaine : une nouvelle ligne
  /// `week_selections` (AD-16). Rien n'est écrit si la recette est absente ou
  /// supprimée, ou si elle a déjà une sélection active.
  Future<void> select(String recipeId) {
    return _db.transaction(() async {
      final recipe =
          await (_db.select(_db.recipes)
                ..where((r) => r.id.equals(recipeId) & r.deletedAt.isNull()))
              .getSingleOrNull();
      if (recipe == null) return;
      if ((await _activeSelections(recipeId)).isNotEmpty) return;
      await _db
          .into(_db.weekSelections)
          .insert(
            WeekSelectionsCompanion.insert(
              id: _uuid.v4(),
              updatedAt: _clock.stamp(),
              recipeId: recipeId,
            ),
          );
    });
  }

  /// Désélectionne la recette [recipeId] si sa sélection n'est pas validée :
  /// la sélection est supprimée logiquement (AD-16). Une sélection validée
  /// ne change pas (sa désélection est une action transverse, AD-3).
  Future<void> deselect(String recipeId) {
    return _db.transaction(() async {
      final pending = [
        for (final s in await _activeSelections(recipeId))
          if (s.validatedAt == null) s,
      ];
      for (final s in pending) {
        final stamp = _clock.stamp(s.updatedAt);
        await (_db.update(
          _db.weekSelections,
        )..where((x) => x.id.equals(s.id))).write(
          WeekSelectionsCompanion(
            deletedAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
      }
    });
  }

  /// Supprime logiquement la sélection validée de la recette [recipeId]
  /// (AD-16), désélection d'une recette validée (AD-3). À appeler dans la
  /// transaction de l'action : pas de transaction propre.
  ///
  /// Rend les ids des sélections supprimées, dont l'action retire les
  /// contributions, et leur état d'avant pour Annuler (AD-10). Sans
  /// sélection active validée, rien n'est écrit et le résultat est vide.
  Future<DeselectedSelections> deselectValidated(String recipeId) async {
    final validated = [
      for (final s in await _activeSelections(recipeId))
        if (s.validatedAt != null) s,
    ];
    if (validated.isEmpty) {
      return (selectionIds: <String>[], undoRows: <UndoRow>[]);
    }
    final stamp = _clock.stamp(
      validated.map((s) => s.updatedAt).reduce((a, b) => a > b ? a : b),
    );
    await (_db.update(
      _db.weekSelections,
    )..where((s) => s.id.isIn([for (final s in validated) s.id]))).write(
      WeekSelectionsCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
    );
    return (
      selectionIds: [for (final s in validated) s.id],
      undoRows: [
        for (final s in validated) UndoRow.before(_db.weekSelections, s),
      ],
    );
  }

  /// Supprime logiquement toutes les sélections actives, validées ou non
  /// (AD-16) : remise à zéro de la sélection de la semaine par Terminer les
  /// courses et Nouvelle liste (AD-3). À appeler dans la transaction de
  /// l'action : pas de transaction propre.
  ///
  /// Rend leur état d'avant pour Annuler (AD-10) ; sans sélection active,
  /// rien n'est écrit et le résultat est vide.
  Future<List<UndoRow>> clearSelections() async {
    final active = await (_db.select(
      _db.weekSelections,
    )..where((s) => s.deletedAt.isNull())).get();
    if (active.isEmpty) return const [];
    // Un seul horodatage, postérieur à chaque ancien `updated_at`.
    final stamp = _clock.stamp(
      active.map((s) => s.updatedAt).reduce((a, b) => a > b ? a : b),
    );
    await (_db.update(
      _db.weekSelections,
    )..where((s) => s.id.isIn([for (final s in active) s.id]))).write(
      WeekSelectionsCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
    );
    return [for (final s in active) UndoRow.before(_db.weekSelections, s)];
  }

  /// Réconcilie les recettes après la fusion d'une sauvegarde (AD-9), à
  /// appeler dans la transaction de l'import, après celle des articles.
  ///
  /// Les ingrédients actifs d'un article supprimé par la réconciliation
  /// passent sur l'article gardé ([articles] : id supprimé → id gardé). Parmi
  /// les sélections actives d'une même recette, une seule est gardée : une
  /// validée de préférence, puis la plus ancienne (`validated_at`, puis
  /// `updated_at`, puis id) ; les autres sont supprimées logiquement.
  ///
  /// Rend la sélection gardée de chaque sélection supprimée (id supprimé →
  /// id gardé), pour que `liste` y reporte les contributions.
  Future<Map<String, String>> reconcileImported(
    Map<String, String> articles,
  ) async {
    if (articles.isNotEmpty) {
      final ingredients =
          await (_db.select(_db.recipeIngredients)..where(
                (i) => i.articleId.isIn(articles.keys) & i.deletedAt.isNull(),
              ))
              .get();
      for (final i in ingredients) {
        await (_db.update(
          _db.recipeIngredients,
        )..where((x) => x.id.equals(i.id))).write(
          RecipeIngredientsCompanion(
            articleId: Value(articles[i.articleId]!),
            updatedAt: Value(_clock.stamp(i.updatedAt)),
          ),
        );
      }
    }

    final active = await (_db.select(
      _db.weekSelections,
    )..where((s) => s.deletedAt.isNull())).get();
    final byRecipe = <String, List<WeekSelection>>{};
    for (final s in active) {
      byRecipe.putIfAbsent(s.recipeId, () => []).add(s);
    }
    final replaced = <String, String>{};
    for (final group in byRecipe.values) {
      if (group.length < 2) continue;
      group.sort((x, y) {
        final xv = x.validatedAt, yv = y.validatedAt;
        if ((xv == null) != (yv == null)) return xv == null ? 1 : -1;
        if (xv != null && yv != null && xv != yv) return xv.compareTo(yv);
        if (x.updatedAt != y.updatedAt) {
          return x.updatedAt.compareTo(y.updatedAt);
        }
        return x.id.compareTo(y.id);
      });
      final kept = group.first;
      for (final other in group.skip(1)) {
        final stamp = _clock.stamp(other.updatedAt);
        await (_db.update(
          _db.weekSelections,
        )..where((s) => s.id.equals(other.id))).write(
          WeekSelectionsCompanion(
            deletedAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
        replaced[other.id] = kept.id;
      }
    }
    return replaced;
  }

  Future<List<WeekSelection>> _activeSelections(String recipeId) => (_db.select(
    _db.weekSelections,
  )..where((s) => s.recipeId.equals(recipeId) & s.deletedAt.isNull())).get();

  /// Sélections actives non validées des recettes actives, et leurs
  /// ingrédients actifs dont l'article est actif, avec le nom, le picto et
  /// le rayon actuels de l'article (AD-15).
  Future<PendingSelections> pendingSelections() async {
    final s = _db.weekSelections;
    final r = _db.recipes;
    final selections = await (_db.select(s).join([
      innerJoin(r, r.id.equalsExp(s.recipeId) & r.deletedAt.isNull()),
    ])..where(s.deletedAt.isNull() & s.validatedAt.isNull())).get();
    final ordered = _sortedByName(
      [for (final row in selections) (row.readTable(s), row.readTable(r))],
      (x) => x.$2.name,
      (x) => x.$1.id,
    );
    if (ordered.isEmpty) {
      return (selectionIds: <String>[], ingredients: <RevueSource>[]);
    }

    final i = _db.recipeIngredients;
    final a = _db.articles;
    final rows =
        await (_db.select(i).join([
                innerJoin(
                  a,
                  a.id.equalsExp(i.articleId) & a.deletedAt.isNull(),
                ),
              ])
              ..where(
                i.recipeId.isIn([
                      for (final (_, recipe) in ordered) recipe.id,
                    ]) &
                    i.deletedAt.isNull(),
              )
              ..orderBy([OrderingTerm.asc(i.position), OrderingTerm.asc(i.id)]))
            .get();
    final byRecipe = <String, List<(RecipeIngredient, Article)>>{};
    for (final row in rows) {
      final ingredient = row.readTable(i);
      byRecipe.putIfAbsent(ingredient.recipeId, () => []).add((
        ingredient,
        row.readTable(a),
      ));
    }

    return (
      selectionIds: [for (final (selection, _) in ordered) selection.id],
      ingredients: [
        for (final (selection, recipe) in ordered)
          for (final (ingredient, article)
              in byRecipe[recipe.id] ?? const <(RecipeIngredient, Article)>[])
            _source(selection.id, ingredient, article),
      ],
    );
  }

  static RevueSource _source(
    String selectionId,
    RecipeIngredient ingredient,
    Article article,
  ) {
    final unit = Unit.tryFromCode(ingredient.unit);
    final quantity = unit == null ? null : ingredient.quantity;
    return RevueSource(
      selectionId: selectionId,
      articleId: article.id,
      name: article.name,
      rayon: Rayon.tryFromCode(article.rayon) ?? Rayon.divers,
      quantity: quantity == null || quantity <= 0 ? null : quantity,
      unit: quantity == null || quantity <= 0 ? null : unit,
      articleUnit: Unit.tryFromCode(article.unit),
    );
  }

  /// Fixe `validated_at` des sélections [selectionIds] actives et non
  /// encore validées (AD-16). À appeler dans la transaction de l'action
  /// Ajouter à la liste (AD-3) : pas de transaction propre.
  Future<void> markValidated(List<String> selectionIds) async {
    if (selectionIds.isEmpty) return;
    final selections =
        await (_db.select(_db.weekSelections)..where(
              (s) =>
                  s.id.isIn(selectionIds) &
                  s.deletedAt.isNull() &
                  s.validatedAt.isNull(),
            ))
            .get();
    if (selections.isEmpty) return;
    final stamp = _clock.stamp(
      selections.map((s) => s.updatedAt).reduce((a, b) => a > b ? a : b),
    );
    await (_db.update(
      _db.weekSelections,
    )..where((s) => s.id.isIn([for (final s in selections) s.id]))).write(
      WeekSelectionsCompanion(
        validatedAt: Value(stamp),
        updatedAt: Value(stamp),
      ),
    );
  }
}
