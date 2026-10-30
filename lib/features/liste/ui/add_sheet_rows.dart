import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Largeur du Champ quantité sous une ligne dépliée.
const _quantityFieldWidth = 160.0;

/// Ligne dépliée du dernier ajout du Panneau + : Champ quantité dans
/// [unit] (absent sans unité), lu « Quantité », puis Choix de rayon, le
/// rayon [rayon] de la ligne entouré. Facultatifs tous les deux.
class AddedLineEditor extends StatelessWidget {
  const AddedLineEditor({
    super.key,
    required this.unit,
    required this.quantityController,
    required this.rayon,
    required this.onRayonSelected,
    this.onQuantityChanged,
    this.onQuantitySubmitted,
  });

  final Unit? unit;
  final TextEditingController quantityController;
  final ValueChanged<String>? onQuantityChanged;
  final ValueChanged<String>? onQuantitySubmitted;
  final Rayon rayon;
  final ValueChanged<Rayon> onRayonSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final unit = this.unit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        0,
        KadiSpacing.margin,
        KadiSpacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unit != null) ...[
            Row(
              children: [
                Expanded(
                  // Le champ porte lui-même le nom lu « Quantité ».
                  child: ExcludeSemantics(
                    child: Text(StringsFr.quantite, style: labelStyle),
                  ),
                ),
                SizedBox(
                  width: _quantityFieldWidth,
                  child: Semantics(
                    label: StringsFr.quantite,
                    child: QuantityField(
                      controller: quantityController,
                      unit: unit,
                      onChanged: onQuantityChanged,
                      onSubmitted: onQuantitySubmitted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KadiSpacing.s3),
          ],
          Text(StringsFr.rayon, style: labelStyle),
          const SizedBox(height: KadiSpacing.s2),
          RayonPicker(selected: rayon, onSelected: onRayonSelected),
        ],
      ),
    );
  }
}

/// Seule ligne des résultats quand la saisie ne trouve rien : signe +
/// neutre et « Ajouter « piles » », qui fait comme Entrée. Un bouton, lu
/// « Ajouter « piles » ».
class AddTypedRow extends StatelessWidget {
  const AddTypedRow({super.key, required this.name, required this.onTap});

  /// La saisie, telle que tapée.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = StringsFr.ajouterNom(name);

    return Semantics(
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

/// Indicateur d'état à droite d'une ligne du Panneau + : coche à l'accent du
/// rayon dans la liste, signe + en `on-surface-variant` hors liste.
class InListIndicator extends StatelessWidget {
  const InListIndicator({super.key, required this.rayon, required this.inList});

  final Rayon rayon;
  final bool inList;

  @override
  Widget build(BuildContext context) {
    return inList
        ? Icon(Icons.check, color: KadiColors.of(context).rayon(rayon).accent)
        : Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
  }
}

/// Ligne de fréquent : Picto, nom et indicateur d'état. Annoncée « Lait »
/// hors liste, « Lait, dans la liste » dans la liste.
class FrequentRow extends StatelessWidget {
  const FrequentRow({
    super.key,
    required this.article,
    required this.inList,
    required this.onTap,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: inList
          ? '${article.name}, ${StringsFr.dansLaListe}'
          : article.name,
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
                Picto(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    article.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                InListIndicator(rayon: article.rayon, inList: inList),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de résultat : Picto, nom, rayon et indicateur d'état. Annoncée
/// « Lait, Crèmerie », avec « dans la liste » s'il y est.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.article,
    required this.onTap,
    this.inList = false,
  });

  final CatalogueArticle article;
  final bool inList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: [
        article.name,
        article.rayon.spokenLabel,
        if (inList) StringsFr.dansLaListe,
      ].join(', '),
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
                Picto(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    article.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                Text(
                  article.rayon.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                InListIndicator(rayon: article.rayon, inList: inList),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
