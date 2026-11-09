import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import '../strings/strings_fr.dart';
import '../theme/kadi_colors.dart';
import '../theme/kadi_tokens.dart';

/// Hauteur plafond du menu (README redesign §4.4) : il défile au-delà.
const rayonMenuMaxHeight = 300.0;

/// Menu des rayons de la V2 (README redesign §4.4), partagé par le Panneau +
/// (2f) et la Fiche recette (3d) : carte `surface-container` au rayon 20,
/// une ligne par rayon de [route] (ordre du parcours) avec son point, son nom
/// et ✓ sur [current]. Un tap hors du menu le ferme seulement.
///
/// [alignment] place le coin haut-gauche du menu sur [child] ;
/// [alignmentOffset] le décale.
class RayonMenuAnchor extends StatelessWidget {
  const RayonMenuAnchor({
    super.key,
    required this.controller,
    required this.route,
    required this.current,
    required this.onSelected,
    required this.width,
    required this.child,
    this.maxHeight = rayonMenuMaxHeight,
    this.alignment = AlignmentDirectional.bottomStart,
    this.alignmentOffset = Offset.zero,
  });

  final MenuController controller;
  final List<Rayon> route;
  final Rayon? current;
  final ValueChanged<Rayon> onSelected;
  final double width;
  final double maxHeight;
  final AlignmentGeometry alignment;
  final Offset alignmentOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Le menu défile sans barre visible : le menu M3 dessine la sienne.
    return Theme(
      data: theme.copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(0),
          thumbColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      child: MenuAnchor(
        controller: controller,
        semanticLabel: StringsFr.rayon,
        consumeOutsideTap: true,
        crossAxisUnconstrained: false,
        alignmentOffset: alignmentOffset,
        style: MenuStyle(
          alignment: alignment,
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.black),
          elevation: const WidgetStatePropertyAll(8),
          minimumSize: WidgetStatePropertyAll(Size(width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(width, maxHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(KadiRadius.menu)),
            ),
          ),
        ),
        menuChildren: [
          for (final entry in route)
            MenuItemButton(
              key: ValueKey(entry),
              semanticsLabel: entry.spokenLabel,
              onPressed: () => onSelected(entry),
              style: MenuItemButton.styleFrom(
                minimumSize: const Size(0, KadiSpacing.touchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                overlayColor: scheme.surfaceContainerHigh,
              ),
              leadingIcon: RayonDot(rayon: entry),
              trailingIcon: entry == current
                  ? Icon(Icons.check, size: 20, color: scheme.onSurface)
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  entry.label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
        child: child,
      ),
    );
  }
}

/// Point d'accent de 10 dp d'un rayon.
class RayonDot extends StatelessWidget {
  const RayonDot({super.key, required this.rayon});

  final Rayon rayon;

  @override
  Widget build(BuildContext context) => Container(
    width: KadiSpacing.rayonDot,
    height: KadiSpacing.rayonDot,
    decoration: BoxDecoration(
      color: KadiColors.of(context).rayon(rayon).accent,
      shape: BoxShape.circle,
    ),
  );
}
