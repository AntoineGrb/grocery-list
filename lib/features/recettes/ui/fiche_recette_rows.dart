import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/dashed_border.dart';
import 'package:kadi/core/ui/picto_disc.dart';
import 'package:kadi/core/ui/quantity_tag.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';

/// Ingrédient du brouillon de la Fiche recette (brouillon d'écran) : son id
/// stable, son article, sa quantité et son rayon, modifiable (3d).
class IngredientDraft {
  IngredientDraft._({
    required this.id,
    required this.articleId,
    required this.name,
    required this.pictoKey,
    required this.originalRayon,
    required this.unit,
    this.value,
  }) : rayon = originalRayon;

  /// Ingrédient lu de la base.
  factory IngredientDraft.read(RecipeSheetIngredient ingredient) =>
      IngredientDraft._(
        id: ingredient.id,
        articleId: ingredient.articleId,
        name: ingredient.name,
        pictoKey: ingredient.pictoKey,
        originalRayon: ingredient.rayon,
        unit: ingredient.unit ?? ingredient.articleUnit,
        value: ingredient.quantity == null || ingredient.unit == null
            ? null
            : (quantity: ingredient.quantity!, unit: ingredient.unit!),
      );

  /// Ingrédient ajouté depuis la recherche, d'id [id] : sans quantité.
  factory IngredientDraft.added(String id, CatalogueArticle article) =>
      IngredientDraft._(
        id: id,
        articleId: article.id,
        name: article.name,
        pictoKey: article.pictoKey,
        originalRayon: article.rayon,
        unit: article.unit,
      );

  final String id;
  final String articleId;
  final String name;
  final String pictoKey;

  /// Rayon de l'article à l'ouverture.
  final Rayon originalRayon;

  /// Unité préchoisie du Module quantité : celle de l'ingrédient, sinon
  /// celle de l'article ; nulle : pièce.
  final Unit? unit;

  /// Rayon montré, écrit au catalogue à l'enregistrement s'il a changé.
  Rayon rayon;

  /// Quantité à écrire ; nulle : sans quantité.
  StoredQuantity? value;

  /// Clé de sa Ligne d'ingrédient, pour la mesurer et la faire défiler.
  final rowKey = GlobalKey();

  /// Unité de saisie du Module quantité.
  InputUnit get inputUnit => InputUnit.of(value?.unit ?? unit ?? Unit.piece);
}

/// Ligne d'ingrédient de la V2 (README redesign 2b) : disque picto (tap :
/// menu des rayons, 3d), nom, tag quantité (tap : Module quantité, 3c) ;
/// filet bas. Glisser vers la gauche la retire ([onRemove]).
class IngredientRow extends StatelessWidget {
  const IngredientRow({
    super.key,
    required this.ingredient,
    required this.onPictoTap,
    required this.onQuantityTap,
    required this.onRemove,
  });

  final IngredientDraft ingredient;
  final VoidCallback onPictoTap;
  final VoidCallback onQuantityTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = ingredient.name;
    final value = ingredient.value;

    return Dismissible(
      key: ValueKey('dismiss-${ingredient.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: scheme.error,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.margin),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: StringsFr.retirerIngredient(name)):
              onRemove,
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          margin: const EdgeInsets.symmetric(horizontal: KadiSpacing.margin),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.surfaceContainerHigh),
            ),
          ),
          child: Row(
            children: [
              Semantics(
                container: true,
                button: true,
                label: StringsFr.rayonDe(name, ingredient.rayon.spokenLabel),
                excludeSemantics: true,
                onTap: onPictoTap,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPictoTap,
                  child: SizedBox(
                    width: KadiSpacing.touchTarget,
                    height: KadiSpacing.touchTarget,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PictoDisc(
                        pictoKey: ingredient.pictoKey,
                        rayon: ingredient.rayon,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s2),
                  child: Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KadiSpacing.s3),
              ConstrainedBox(
                // Police agrandie : le tag garde au plus 40 % de la largeur.
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                ),
                child: QuantityTag(
                  name: name,
                  rayon: ingredient.rayon,
                  quantity: value?.quantity,
                  unit: value?.unit,
                  onTap: onQuantityTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de résultat de l'ajout d'ingrédient (README redesign 3a) : disque
/// picto, nom et rayon dessous, + à l'encre ; déjà dans la recette, ✓ à
/// l'accent du rayon et « Déjà dans la recette », sans effet au tap.
class IngredientResultRow extends StatelessWidget {
  const IngredientResultRow({
    super.key,
    required this.article,
    required this.inRecipe,
    required this.onTap,
  });

  final CatalogueArticle article;
  final bool inRecipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = KadiColors.of(context).rayon(article.rayon).accent;

    return Semantics(
      container: true,
      button: true,
      label: [
        article.name,
        article.rayon.spokenLabel,
        if (inRecipe) StringsFr.dansLaRecette,
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KadiRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.s3),
            child: Row(
              children: [
                PictoDisc(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: KadiSpacing.s1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 20 / 16,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          inRecipe
                              ? StringsFr.dejaDansLaRecette
                              : article.rayon.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 16 / 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                Icon(
                  inRecipe ? Icons.check : Icons.add,
                  size: 22,
                  color: inRecipe ? accent : scheme.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « Ajouter « … » » sous les résultats, quand aucun article ne porte
/// exactement ce nom : cercle pointillé avec +, puis « Nouvel ingrédient ·
/// rayon modifiable ensuite ». Fait comme Entrée.
class CreateArticleRow extends StatelessWidget {
  const CreateArticleRow({super.key, required this.name, required this.onTap});

  /// La saisie, telle que tapée.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringsFr.ajouterNom(name);

    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KadiRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.s3),
            child: Row(
              children: [
                DashedBorder(
                  color: scheme.outline,
                  circle: true,
                  strokeWidth: 1,
                  child: SizedBox.square(
                    dimension: PictoDisc.large,
                    child: Icon(Icons.add, size: 20, color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: KadiSpacing.s1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 20 / 16,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          StringsFr.nouvelIngredientDetail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 16 / 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
