import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/quantity_input.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';

/// Facteur de police au-delà duquel le rayon d'un résultat, ou le Champ
/// quantité d'un ingrédient, passe sous le nom.
const _inlineMaxTextScale = 1.3;

/// Largeur du Champ quantité d'une Ligne d'ingrédient, suffixe d'unité
/// tappable compris.
const _fieldWidth = 144.0;

/// Ingrédient du brouillon de la Fiche recette (brouillon d'écran) : son id
/// stable, son article, le texte de son Champ quantité et l'unité de saisie.
class IngredientDraft {
  IngredientDraft._({
    required this.id,
    required this.articleId,
    required this.name,
    required this.pictoKey,
    required this.rayon,
    required InputUnit unit,
    this.originalQuantity,
    this.originalUnit,
  }) : unit = unit,
       _initialUnit = unit,
       _originalText = quantityFieldText(originalQuantity, unit) {
    controller = TextEditingController(text: _originalText);
  }

  /// Ingrédient lu de la base : son unité, sinon celle de l'article, sinon
  /// pièce.
  factory IngredientDraft.read(RecipeSheetIngredient ingredient) {
    final unit = ingredient.unit ?? ingredient.articleUnit;
    return IngredientDraft._(
      id: ingredient.id,
      articleId: ingredient.articleId,
      name: ingredient.name,
      pictoKey: ingredient.pictoKey,
      rayon: ingredient.rayon,
      unit: unit == null ? InputUnit.piece : InputUnit.of(unit),
      originalQuantity: ingredient.quantity,
      originalUnit: ingredient.unit,
    );
  }

  /// Ingrédient ajouté depuis la recherche, d'id [id] : sans quantité, dans
  /// l'unité de l'article, sinon pièce (AD-15).
  factory IngredientDraft.added(String id, CatalogueArticle article) {
    final unit = article.unit;
    return IngredientDraft._(
      id: id,
      articleId: article.id,
      name: article.name,
      pictoKey: article.pictoKey,
      rayon: article.rayon,
      unit: unit == null ? InputUnit.piece : InputUnit.of(unit),
    );
  }

  final String id;
  final String articleId;
  final String name;
  final String pictoKey;
  final Rayon rayon;

  /// Quantité stockée lue de la base, gardée telle quelle tant que le champ
  /// et l'unité n'ont pas changé (le texte des pièces est arrondi).
  final int? originalQuantity;
  final Unit? originalUnit;

  final InputUnit _initialUnit;
  final String _originalText;

  late final TextEditingController controller;
  final focusNode = FocusNode();

  /// Clé de sa Ligne d'ingrédient, pour la mesurer et la faire défiler.
  final rowKey = GlobalKey();

  /// Unité de saisie du Champ quantité.
  InputUnit unit;

  /// Quantité à écrire : celle lue tant que rien n'a changé, sinon le texte
  /// du champ dans [unit] (vide ou 0 = sans quantité ; kg et L en g et ml,
  /// AD-6).
  StoredQuantity? get value =>
      controller.text == _originalText && unit == _initialUnit
      ? storedQuantityOf(originalQuantity, originalUnit)
      : quantityFromFieldText(controller.text, unit);

  /// Change d'unité en gardant le nombre tapé, sans les décimales que
  /// [next] n'admet pas.
  void selectUnit(InputUnit next) {
    unit = next;
    final text = quantityTextForUnit(controller.text, next);
    if (text != controller.text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// Libellé d'unité lu du suffixe : pièce, g, kg, ml, L.
String _unitLabel(InputUnit unit) => switch (unit) {
  InputUnit.piece => StringsFr.puceUnitePiece,
  InputUnit.g => StringsFr.puceUniteG,
  InputUnit.kg => StringsFr.puceUniteKg,
  InputUnit.ml => StringsFr.puceUniteMl,
  InputUnit.l => StringsFr.puceUniteL,
};

/// Ligne d'ingrédient (DESIGN `ingredient-row`) : Picto, nom, Champ quantité
/// dans l'unité de l'ingrédient et icône de retrait de 48 dp. Un tap sur
/// l'unité du champ ouvre ou ferme le Choix d'unité sous la ligne.
///
/// Lue « Haricots rouges, 500 g » ; le champ, à part, « Quantité de Haricots
/// rouges, 500 g » ; son unité « Unité, g » ; le retrait « Retirer Haricots
/// rouges ». En grande police, le champ passe sous le nom.
class IngredientRow extends StatelessWidget {
  const IngredientRow({
    super.key,
    required this.ingredient,
    required this.unitOpen,
    required this.onUnitTap,
    required this.onUnitSelected,
    required this.onChanged,
    required this.onRemove,
  });

  final IngredientDraft ingredient;

  /// Le Choix d'unité est ouvert sous la ligne.
  final bool unitOpen;
  final VoidCallback onUnitTap;
  final ValueChanged<InputUnit> onUnitSelected;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ingredient.controller,
      builder: (context, _, _) {
        final value = ingredient.value;
        return _build(context, formatQuantity(value?.quantity, value?.unit));
      },
    );
  }

  Widget _build(BuildContext context, String quantity) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = ingredient.name;
    final large =
        MediaQuery.textScalerOf(context).scale(1) > _inlineMaxTextScale;

    final head = Semantics(
      container: true,
      label: [name, if (quantity.isNotEmpty) quantity].join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          Picto(pictoKey: ingredient.pictoKey, rayon: ingredient.rayon),
          const SizedBox(width: KadiSpacing.s3),
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
        ],
      ),
    );

    final field = Semantics(
      container: true,
      label: StringsFr.quantiteDe(name, quantity),
      child: QuantityField(
        controller: ingredient.controller,
        focusNode: ingredient.focusNode,
        unit: ingredient.unit,
        onChanged: (_) => onChanged(),
        onUnitTap: onUnitTap,
        unitSemanticsLabel: StringsFr.uniteDe(_unitLabel(ingredient.unit)),
      ),
    );

    final remove = IconButton(
      tooltip: StringsFr.retirerIngredient(name),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(KadiSpacing.touchTarget),
      ),
      onPressed: onRemove,
      icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: KadiSpacing.margin,
          end: KadiSpacing.s1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (large) ...[
              Row(
                children: [
                  Expanded(child: head),
                  remove,
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: KadiSpacing.picto + KadiSpacing.s3,
                  end: KadiSpacing.s3,
                  bottom: KadiSpacing.s2,
                ),
                child: field,
              ),
            ] else
              Row(
                children: [
                  Expanded(child: head),
                  const SizedBox(width: KadiSpacing.s3),
                  SizedBox(width: _fieldWidth, child: field),
                  remove,
                ],
              ),
            if (unitOpen)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: KadiSpacing.picto + KadiSpacing.s3,
                  end: KadiSpacing.s3,
                  bottom: KadiSpacing.s2,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: UnitChoice(
                    selected: ingredient.unit,
                    onSelected: onUnitSelected,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de résultat de la popup d'ajout d'ingrédient (DESIGN
/// `search-result-row`, comme les Lignes de résultat du Panneau +) :
/// Picto, nom, rayon et indicateur : signe + hors de la recette, coche à
/// l'accent du rayon déjà ingrédient. Lue « Haricots rouges, Épicerie
/// salée », avec « dans la recette » si elle y est.
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
    final large =
        MediaQuery.textScalerOf(context).scale(1) > _inlineMaxTextScale;
    final meta = Text(
      article.rayon.label,
      maxLines: large ? null : 1,
      overflow: large ? null : TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KadiSpacing.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.margin),
            child: Row(
              children: [
                Picto(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: KadiSpacing.s2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        if (large) meta,
                      ],
                    ),
                  ),
                ),
                if (!large) ...[
                  const SizedBox(width: KadiSpacing.s3),
                  Flexible(child: meta),
                ],
                const SizedBox(width: KadiSpacing.s3),
                InListIndicator(rayon: article.rayon, inList: inRecipe),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « Créer « … » » sous les résultats de la popup d'ajout, quand aucun
/// article ne porte exactement ce nom : signe + neutre, fait comme Entrée ;
/// lue « Créer « Piment » ».
class CreateArticleRow extends StatelessWidget {
  const CreateArticleRow({super.key, required this.name, required this.onTap});

  /// La saisie, telle que tapée.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringsFr.creerNom(name);

    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KadiSpacing.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KadiSpacing.margin,
              vertical: KadiSpacing.s2,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: KadiSpacing.picto,
                  child: Icon(Icons.add, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
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
