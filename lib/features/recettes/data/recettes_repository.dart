import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:uuid/uuid.dart';

/// Carte d'une recette active de l'écran Recettes.
class RecipeCardItem {
  const RecipeCardItem({
    required this.recipeId,
    required this.name,
    required this.pictoKey,
    required this.rayon,
    required this.selected,
    required this.validated,
  });

  final String recipeId;
  final String name;

  /// Picto de l'ingrédient principal (premier par `position`), vide sans
  /// ingrédient : le résolveur rend alors le repli neutre.
  final String pictoKey;

  /// Rayon actuel de l'article de l'ingrédient principal, sinon Divers.
  final Rayon rayon;

  /// Une sélection active de la recette existe (AD-16).
  final bool selected;

  /// Cette sélection a été validée par Ajouter à la liste.
  final bool validated;
}

/// Ingrédient d'une recette sélectionnée à valider, source de la Revue.
class RevueSource {
  const RevueSource({
    required this.selectionId,
    required this.articleId,
    required this.name,
    required this.pictoKey,
    required this.rayon,
    this.quantity,
    this.unit,
    this.articleUnit,
  });

  /// Sélection de la recette (`week_selections.id`).
  final String selectionId;
  final String articleId;
  final String name;
  final String pictoKey;

  /// Rayon actuel de l'article (AD-15).
  final Rayon rayon;

  /// Quantité stockée (AD-6), nulle avec [unit].
  final int? quantity;
  final Unit? unit;

  /// Unité par défaut de l'article (`articles.unit`), nulle sans unité.
  final Unit? articleUnit;
}

/// Sélections à valider et leurs ingrédients, dans l'ordre des recettes
/// (nom normalisé) puis `position`.
typedef PendingSelections = ({
  List<String> selectionIds,
  List<RevueSource> ingredients,
});

/// Sélections validées supprimées par [RecettesRepository.deselectValidated]
/// et leur état d'avant pour Annuler (AD-10).
typedef DeselectedSelections = ({
  List<String> selectionIds,
  List<UndoRow> undoRows,
});

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
      'SELECT r.id, r.name, '
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
            pictoKey: row.readNullable<String>('picto_key') ?? '',
            rayon:
                Rayon.tryFromCode(row.readNullable<String>('rayon') ?? '') ??
                Rayon.divers,
            selected: row.read<bool>('selected'),
            validated: row.read<bool>('validated'),
          ),
      ];
      return cards..sort(_byName);
    });
  }

  static int _byName(RecipeCardItem a, RecipeCardItem b) {
    final byName = normalizeName(a.name).compareTo(normalizeName(b.name));
    return byName != 0 ? byName : a.recipeId.compareTo(b.recipeId);
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
    final ordered =
        [for (final row in selections) (row.readTable(s), row.readTable(r))]
          ..sort((x, y) {
            final byName = normalizeName(x.$2.name)
                .compareTo(normalizeName(y.$2.name));
            return byName != 0 ? byName : x.$1.id.compareTo(y.$1.id);
          });
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
      pictoKey: article.pictoKey,
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
