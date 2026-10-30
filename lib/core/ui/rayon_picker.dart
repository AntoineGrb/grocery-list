import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import '../theme/kadi_tokens.dart';
import 'rayon_pastille.dart';

/// Épaisseur de la bordure du rayon choisi.
const _selectedBorderWidth = 2.0;

/// Choix de rayon (DESIGN `rayon-picker`) : les 13 pastilles dans l'ordre
/// de [Rayon.values], cible d'au moins 48 dp chacune ; le rayon [selected]
/// est entouré d'une bordure `on-surface`.
///
/// Chaque pastille est un bouton lu par son nom parlé (« Viande et
/// poisson »), sélectionné ou non. Partagé par la Feuille d'édition
/// d'article (depuis la Liste et le Panneau +) et Paramètres › Articles.
class RayonPicker extends StatelessWidget {
  const RayonPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Rayon? selected;
  final ValueChanged<Rayon> onSelected;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Wrap(
      spacing: KadiSpacing.s2,
      children: [
        for (final rayon in Rayon.values)
          Semantics(
            button: true,
            selected: rayon == selected,
            label: rayon.spokenLabel,
            onTap: () => onSelected(rayon),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey(rayon),
              onTap: () => onSelected(rayon),
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: KadiSpacing.touchTarget,
                  minWidth: KadiSpacing.touchTarget,
                ),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: RayonPastille(
                    rayon: rayon,
                    border: rayon == selected
                        ? Border.all(
                            color: onSurface,
                            width: _selectedBorderWidth,
                          )
                        : Border.all(
                            color: Colors.transparent,
                            width: _selectedBorderWidth,
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
