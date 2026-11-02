import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';

import 'recipe_link.dart';

/// Carte d'une recette active de l'écran Recettes.
class RecipeCardItem {
  const RecipeCardItem({
    required this.recipeId,
    required this.name,
    required this.pictoKey,
    required this.rayon,
    required this.selected,
    required this.validated,
    this.photo,
  });

  final String recipeId;
  final String name;

  /// Nom du fichier de la photo dans `photos/` (AD-18), nul sans photo : la
  /// carte montre alors le visuel de repli.
  final String? photo;

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

/// Ingrédient d'une recette tel que le lit la Fiche recette.
class RecipeSheetIngredient {
  const RecipeSheetIngredient({
    required this.id,
    required this.articleId,
    required this.name,
    required this.pictoKey,
    required this.rayon,
    this.quantity,
    this.unit,
    this.articleUnit,
  });

  /// `recipe_ingredients.id`.
  final String id;
  final String articleId;

  /// Nom, picto et rayon actuels de l'article (AD-15).
  final String name;
  final String pictoKey;
  final Rayon rayon;

  /// Quantité stockée (AD-6), nulle avec [unit].
  final int? quantity;
  final Unit? unit;

  /// Unité par défaut de l'article (`articles.unit`), nulle sans unité.
  final Unit? articleUnit;
}

/// Recette active lue par la Fiche recette : nom et ingrédients actifs par
/// `position`.
class RecipeSheet {
  const RecipeSheet({
    required this.recipeId,
    required this.name,
    required this.ingredients,
    this.link,
    this.photo,
  });

  final String recipeId;
  final String name;
  final List<RecipeSheetIngredient> ingredients;

  /// Lien de la recette, nul sans lien.
  final String? link;

  /// Nom du fichier de la photo dans `photos/` (AD-18), nul sans photo.
  final String? photo;
}

/// Ingrédient du brouillon de la Fiche recette, à écrire : son id (stable,
/// tiré à l'ajout), son article et sa quantité stockée, nulle avec [unit].
class RecipeDraftIngredient {
  const RecipeDraftIngredient({
    required this.id,
    required this.articleId,
    this.quantity,
    this.unit,
  });

  final String id;
  final String articleId;
  final int? quantity;
  final Unit? unit;
}

/// Brouillon de la Fiche recette : la recette [recipeId] (tirée à l'ouverture
/// d'une fiche vide), son nom tel que saisi, ses ingrédients dans l'ordre,
/// son lien tel que saisi et sa photo.
class RecipeDraft {
  const RecipeDraft({
    required this.recipeId,
    required this.name,
    required this.ingredients,
    this.link,
    this.photo,
  });

  final String recipeId;
  final String name;
  final List<RecipeDraftIngredient> ingredients;

  /// Lien tel que saisi, écrit nettoyé ([cleanRecipeLink]) : vide, nul.
  final String? link;

  /// Nom du fichier de la photo dans `photos/` (AD-18), nul sans photo.
  final String? photo;
}

/// Nom de recette écrit pour la saisie [input] : sans espaces de bord ni
/// espaces doublés ; vide, la fiche n'est pas valide.
String cleanRecipeName(String input) =>
    input.trim().split(RegExp(r'\s+')).join(' ');

/// Sélections à valider et leurs ingrédients, dans l'ordre des recettes
/// (nom normalisé) puis `position`.
typedef PendingSelections = ({
  List<String> selectionIds,
  List<RevueSource> ingredients,
});

/// Sélections validées supprimées par `RecettesRepository.deselectValidated`
/// et leur état d'avant pour Annuler (AD-10).
typedef DeselectedSelections = ({
  List<String> selectionIds,
  List<UndoRow> undoRows,
});

/// Recette supprimée par `RecettesRepository.deleteRecipe` : son nom, pour le
/// snackbar, et son état d'avant pour Annuler (AD-10).
typedef DeletedRecipe = ({String name, UndoRow undoRow});
