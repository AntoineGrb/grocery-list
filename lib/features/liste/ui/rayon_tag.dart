import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';
import 'quantity_tag.dart';

/// Hauteur gardée au menu quand la place manque au-dessus du panneau.
const _menuMinHeight = KadiSpacing.touchTarget * 2;

/// Bord gauche du menu des rayons au-dessus du Panneau + (V2 2f).
const addPopupLeft = KadiSpacing.margin;

/// Largeur du menu des rayons sur un écran de [screenWidth] : marges 16 à
/// gauche, 40 à droite.
double addPopupWidth(double screenWidth) => screenWidth - addPopupLeft - 40;

/// Tag Rayon du Panneau + (V2 2f) : fond pastille du rayon, point, nom et
/// flèche. [chosen] le dit réglé à TalkBack.
///
/// Ouvre juste au-dessus de la carte du panneau le menu des rayons de
/// [route] (README redesign §4.4), qui défile. Ni le tag ni le menu ne
/// prennent le focus.
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
  double _menuHeight = rayonMenuMaxHeight;
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
      math.min(bottom - viewTop, rayonMenuMaxHeight),
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
    final scheme = Theme.of(context).colorScheme;
    final rayon = widget.rayon;
    final colors = KadiColors.of(context).rayon(rayon);

    return RayonMenuAnchor(
      controller: _menu,
      route: widget.route,
      current: rayon,
      onSelected: widget.onSelected,
      width: addPopupWidth(MediaQuery.sizeOf(context).width),
      maxHeight: _menuHeight,
      alignment: AlignmentDirectional.topStart,
      alignmentOffset: _menuOffset,
      child: AddTag(
        color: colors.pastille,
        selected: widget.chosen,
        semanticLabel: StringsFr.rayonTag(rayon.spokenLabel),
        onTap: _toggleMenu,
        padding: const EdgeInsetsDirectional.only(start: 10, end: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RayonDot(rayon: rayon),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                rayon.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: addTagTextStyle(context, scheme.onSurface),
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: scheme.onSurface),
          ],
        ),
      ),
    );
  }
}
