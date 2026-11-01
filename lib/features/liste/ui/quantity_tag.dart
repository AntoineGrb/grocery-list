import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Tag du Panneau + (DESIGN `add-tag`) : puce de 32 dp en [color], bordée de
/// [side], cible de 48 dp.
///
/// Un bouton à part, lu [semanticLabel], même posé sur une ligne elle-même
/// tappable.
class AddTag extends StatelessWidget {
  const AddTag({
    super.key,
    required this.color,
    required this.side,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final BorderSide side;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KadiRadius.sm),
      side: side,
    );

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      // Le pourtour de la puce prend aussi le tap ; l'encre reste sur elle.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: KadiSpacing.touchTarget,
            minHeight: KadiSpacing.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KadiSpacing.s2,
              vertical: (KadiSpacing.touchTarget - KadiSpacing.tagHeight) / 2,
            ),
            child: Material(
              color: color,
              shape: shape,
              child: InkWell(
                onTap: onTap,
                excludeFromSemantics: true,
                customBorder: shape,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: KadiSpacing.tagHeight,
                  ),
                  child: Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KadiSpacing.s2,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tag quantité (DESIGN `add-tag`). Vide : le texte [emptyLabel] sur un contour
/// `outline`. Plein : [value] en `surface` sur un fond `on-surface-variant`,
/// jamais d'argile.
class QuantityTag extends StatelessWidget {
  const QuantityTag({
    super.key,
    required this.value,
    required this.emptyLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  /// Quantité lue (`formatQuantity`) ; vide, le tag est en contour.
  final String value;
  final String emptyLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = value.isNotEmpty;

    return AddTag(
      color: filled ? scheme.onSurfaceVariant : Colors.transparent,
      side: filled ? BorderSide.none : BorderSide(color: scheme.outline),
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: Text(
        filled ? value : emptyLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          color: filled ? scheme.surface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
