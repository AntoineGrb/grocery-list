import 'package:material_ui/material_ui.dart';

import '../pictos/picto.dart';
import '../rayons/rayon.dart';
import '../strings/strings_fr.dart';
import '../theme/kadi_colors.dart';
import '../theme/kadi_tokens.dart';
import '../units/unit.dart';
import 'dashed_border.dart';

/// Tag quantité de la V2 (README redesign §4.2, variante 2b) : la quantité
/// lue sur la pastille du rayon ; sans quantité, un carré pointillé à
/// l'accent avec une balance. Un tap ouvre le Module quantité.
///
/// [height] vaut 30 dp (Fiche recette) ou 28 dp (Revue) ; la cible de tap
/// s'étend sur [tapHeight].
class QuantityTag extends StatelessWidget {
  const QuantityTag({
    super.key,
    required this.name,
    required this.rayon,
    required this.quantity,
    required this.unit,
    required this.onTap,
    this.height = 30,
    this.tapHeight = KadiSpacing.touchTarget,
  });

  /// Nom de l'article, pour TalkBack.
  final String name;
  final Rayon rayon;
  final int? quantity;
  final Unit? unit;
  final VoidCallback onTap;
  final double height;
  final double tapHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = KadiColors.of(context).rayon(rayon);
    final value = formatQuantity(quantity, unit);
    const radius = BorderRadius.all(Radius.circular(KadiRadius.sm));

    final Widget visual = value.isEmpty
        ? DashedBorder(
            color: colors.accent,
            radius: KadiRadius.sm,
            child: SizedBox.square(
              dimension: height,
              child: Icon(KadiGlyphs.scales, size: 17, color: colors.accent),
            ),
          )
        // IntrinsicWidth : le tag prend la largeur de sa valeur, pas toute
        // la place offerte (Revue : jusqu'à 40 % de l'écran).
        : IntrinsicWidth(
            child: Container(
              constraints: BoxConstraints(minHeight: height),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.pastille,
                borderRadius: radius,
              ),
              // Police agrandie : la valeur entière, réduite si la place manque.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );

    return Semantics(
      container: true,
      button: true,
      label: value.isEmpty
          ? StringsFr.ajouterUneQuantiteA(name)
          : StringsFr.quantiteDe(name, value),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: tapHeight,
            minWidth: tapHeight,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            heightFactor: 1,
            child: visual,
          ),
        ),
      ),
    );
  }
}
