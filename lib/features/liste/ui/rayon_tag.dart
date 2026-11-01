import 'dart:math' as math;

import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:material_ui/material_ui.dart';

import 'quantity_tag.dart';

/// Hauteur plafond du menu : un rayon coupé dit qu'il défile.
const _menuMaxHeight = KadiSpacing.touchTarget * 5.5;

/// Hauteur gardée au menu quand la place manque au-dessus du tag.
const _menuMinHeight = KadiSpacing.touchTarget * 2;

/// Taille de la flèche du tag.
const _arrowSize = 18.0;

/// Tag Rayon du Panneau + (DESIGN `add-tag`) : point du rayon, nom et flèche.
/// Contour `outline` tant que le rayon montré est celui par défaut, fond de
/// pastille du rayon quand [chosen].
///
/// Ouvre au-dessus de lui la liste déroulante des rayons de [route], qui
/// défile. Ni le tag ni le menu ne prennent le focus : le clavier reste ouvert.
class RayonTag extends StatefulWidget {
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
  State<RayonTag> createState() => _RayonTagState();
}

class _RayonTagState extends State<RayonTag> {
  final _menu = MenuController();
  double _menuHeight = _menuMaxHeight;

  void _toggleMenu() {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    // La feuille retire la marge haute de son MediaQuery ; la vue la garde.
    final viewTop = MediaQueryData.fromView(View.of(context)).padding.top;
    final top = (context.findRenderObject()! as RenderBox)
        .localToGlobal(Offset.zero)
        .dy;
    setState(() {
      _menuHeight = math.max(
        math.min(top - viewTop, _menuMaxHeight),
        _menuMinHeight,
      );
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

    return MenuAnchor(
      controller: _menu,
      semanticLabel: StringsFr.rayon,
      // Un tap hors du menu le ferme seulement : ni ajout, ni panneau fermé.
      consumeOutsideTap: true,
      // Jamais plus large que l'écran, même en très grande police.
      crossAxisUnconstrained: false,
      // Le menu remplit [_menuHeight] : 13 rayons la dépassent toujours.
      alignmentOffset: Offset(0, -_menuHeight),
      style: MenuStyle(
        alignment: AlignmentDirectional.topStart,
        maximumSize: WidgetStatePropertyAll(Size(double.infinity, _menuHeight)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KadiRadius.lg),
            side: BorderSide(color: scheme.outline),
          ),
        ),
      ),
      menuChildren: [
        for (final entry in widget.route)
          MenuItemButton(
            key: ValueKey(entry),
            semanticsLabel: entry.spokenLabel,
            onPressed: () => widget.onSelected(entry),
            child: RayonPastille(rayon: entry),
          ),
      ],
      child: AddTag(
        color: widget.chosen ? colors.pastille : Colors.transparent,
        side: widget.chosen
            ? BorderSide.none
            : BorderSide(color: scheme.outline),
        semanticLabel: StringsFr.rayonTag(rayon.spokenLabel),
        onTap: _toggleMenu,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: KadiSpacing.rayonDot,
              height: KadiSpacing.rayonDot,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: KadiSpacing.s2),
            Flexible(
              child: Text(
                rayon.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: _arrowSize, color: foreground),
          ],
        ),
      ),
    );
  }
}
