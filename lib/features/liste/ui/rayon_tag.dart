import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';
import 'quantity_tag.dart';

/// Hauteur plafond du menu : un rayon coupé dit qu'il défile.
const _menuMaxHeight = KadiSpacing.touchTarget * 5.5;

/// Hauteur gardée au menu quand la place manque au-dessus du panneau.
const _menuMinHeight = KadiSpacing.touchTarget * 2;

/// Taille de la flèche du tag.
const _arrowSize = 18.0;

/// Bord gauche des pop-ups du Panneau + : la marge intérieure de sa carte.
const addPopupLeft = KadiSpacing.s2 + KadiSpacing.margin;

/// Largeur des pop-ups du Panneau + sur un écran de [screenWidth].
double addPopupWidth(double screenWidth) =>
    math.min(KadiSpacing.addPopupMaxWidth, screenWidth - 2 * addPopupLeft);

/// Tag Rayon du Panneau + (DESIGN `add-tag`) : point du rayon, nom et flèche.
/// Fond des tags tant que le rayon montré est celui par défaut, fond de
/// pastille du rayon quand [chosen].
///
/// Ouvre juste au-dessus de la carte du panneau, calée sur sa marge gauche, la
/// liste déroulante des rayons de [route], qui défile. Ni le tag ni le menu ne
/// prennent le focus : le clavier reste ouvert.
class RayonTag extends ConsumerStatefulWidget {
  const RayonTag({
    super.key,
    required this.rayon,
    required this.chosen,
    required this.route,
    required this.onSelected,
  });

  final Rayon rayon;
  final bool chosen;

  /// Les rayons dans l'ordre du parcours.
  final List<Rayon> route;
  final ValueChanged<Rayon> onSelected;

  @override
  ConsumerState<RayonTag> createState() => _RayonTagState();
}

class _RayonTagState extends ConsumerState<RayonTag> {
  final _menu = MenuController();
  double _menuHeight = _menuMaxHeight;
  Offset _menuOffset = Offset.zero;

  void _toggleMenu() {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    // La feuille retire la marge haute de son MediaQuery ; la vue la garde.
    final viewTop = MediaQueryData.fromView(View.of(context)).padding.top;
    final tag = (context.findRenderObject()! as RenderBox).localToGlobal(
      Offset.zero,
    );
    final bottom =
        (ref.read(listePanelProvider).top ?? tag.dy) - KadiSpacing.s2;
    final height = math.max(
      math.min(bottom - viewTop, _menuMaxHeight),
      _menuMinHeight,
    );
    setState(() {
      _menuHeight = height;
      _menuOffset = Offset(addPopupLeft - tag.dx, bottom - height - tag.dy);
    });
    _menu.open();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rayon = widget.rayon;
    final colors = KadiColors.of(context).rayon(rayon);
    final foreground = widget.chosen
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final width = addPopupWidth(MediaQuery.sizeOf(context).width);

    // Le menu défile sans barre visible : le menu M3 dessine la sienne.
    return Theme(
      data: theme.copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(0),
          thumbColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      child: MenuAnchor(
        controller: _menu,
        semanticLabel: StringsFr.rayon,
        // Un tap hors du menu le ferme seulement : ni ajout, ni panneau fermé.
        consumeOutsideTap: true,
        // Jamais plus large que l'écran, même en très grande police.
        crossAxisUnconstrained: false,
        // Le menu remplit [_menuHeight] : 13 rayons la dépassent toujours.
        alignmentOffset: _menuOffset,
        style: MenuStyle(
          alignment: AlignmentDirectional.topStart,
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          // Sans ombre ni contour : le fond suffit sur la Liste assombrie.
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: WidgetStatePropertyAll(Size(width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(width, _menuHeight)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: KadiSpacing.s2),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(KadiRadius.lg)),
            ),
          ),
        ),
        menuChildren: [
          for (final entry in widget.route)
            MenuItemButton(
              key: ValueKey(entry),
              semanticsLabel: entry.spokenLabel,
              onPressed: () => widget.onSelected(entry),
              style: MenuItemButton.styleFrom(
                minimumSize: const Size(0, KadiSpacing.touchTarget),
                padding: const EdgeInsets.symmetric(
                  horizontal: KadiSpacing.margin,
                ),
              ),
              leadingIcon: _RayonDot(
                color: KadiColors.of(context).rayon(entry),
              ),
              trailingIcon: entry == rayon
                  ? Icon(Icons.check, color: scheme.onSurfaceVariant)
                  : null,
              child: Text(
                entry.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
        ],
        child: AddTag(
          color: widget.chosen ? colors.pastille : scheme.surfaceContainerHigh,
          semanticLabel: StringsFr.rayonTag(rayon.spokenLabel),
          onTap: _toggleMenu,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RayonDot(color: colors),
              const SizedBox(width: KadiSpacing.s2),
              Flexible(
                child: Text(
                  rayon.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: _arrowSize, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Point d'accent d'un rayon, dans le tag et dans le menu.
class _RayonDot extends StatelessWidget {
  const _RayonDot({required this.color});

  final RayonColors color;

  @override
  Widget build(BuildContext context) => Container(
    width: KadiSpacing.rayonDot,
    height: KadiSpacing.rayonDot,
    decoration: BoxDecoration(color: color.accent, shape: BoxShape.circle),
  );
}
