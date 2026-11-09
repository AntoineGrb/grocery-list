import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Hauteur d'un tag du Panneau + (V2 2f).
const addTagHeight = 36.0;

/// Tag du Panneau + (V2 2f) : puce de 36 dp en [color], rayon 10, sans
/// bordure, cible de 48 dp ; [padding] à l'intérieur de la puce.
///
/// Un bouton à part, lu [semanticLabel], même posé sur une ligne elle-même
/// tappable ; [selected] le dit choisi à TalkBack.
class AddTag extends StatelessWidget {
  const AddTag({
    super.key,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.selected,
  });

  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(KadiRadius.tag)),
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      // Le pourtour de la puce prend aussi le tap ; l'encre reste sur elle.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Padding(
          // 6 dp entre deux tags, cible de 48 dp en hauteur.
          padding: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: (KadiSpacing.touchTarget - addTagHeight) / 2,
          ),
          child: Material(
            color: color,
            shape: shape,
            child: InkWell(
              onTap: onTap,
              excludeFromSemantics: true,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: addTagHeight),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Style du texte d'un tag du Panneau + : Roboto 14/500.
TextStyle? addTagTextStyle(BuildContext context, Color color) =>
    Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color);

/// Tag quantité du Panneau + (V2 2f). Vide : [emptyLabel] sur le fond des
/// tags. Plein : [value] en `surface` sur fond encre, jamais d'argile.
class PanelQuantityTag extends StatelessWidget {
  const PanelQuantityTag({
    super.key,
    required this.value,
    required this.emptyLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  /// Quantité lue (`formatQuantity`) ; vide, le tag est neutre.
  final String value;
  final String emptyLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = value.isNotEmpty;

    return AddTag(
      color: filled ? scheme.onSurface : scheme.surfaceContainerHigh,
      semanticLabel: semanticLabel,
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: filled ? 12 : 10),
      child: Text(
        filled ? value : emptyLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: addTagTextStyle(
          context,
          filled ? scheme.surface : scheme.onSurface,
        ),
      ),
    );
  }
}
