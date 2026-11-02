import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../state/revue.dart';

/// Coche ronde de 24 dp, comme la Ligne d'article.
const _checkScale = KadiSpacing.picto / Checkbox.width;

/// Espace insécable entre le nombre et son unité.
const _nbsp = ' ';

/// Quantité exacte d'une Ligne de Revue, dans l'unité de la ligne (sans
/// l'arrondi de lecture de la Liste) : « 400 g », « 200 ml », « 6 pièces » ;
/// vide sans quantité.
String revueQuantityText(int? quantity, Unit? unit) {
  if (quantity == null || unit == null) return '';
  final text = quantityFieldText(quantity, InputUnit.of(unit));
  if (text.isEmpty) return '';
  final suffix = switch (unit) {
    Unit.g => StringsFr.uniteG,
    Unit.ml => StringsFr.uniteMl,
    Unit.piece => text == '1' ? StringsFr.unitePiece : StringsFr.unitePieces,
  };
  return '$text$_nbsp$suffix';
}

/// Ligne de Revue (DESIGN `review-row`) : coche ronde cochée à l'accent du
/// rayon, Picto, nom et quantité exacte. Lecture seule pour l'instant : la
/// coche ne change pas.
///
/// Annoncée « Lardons, 400 g, Viande et poisson », cochée.
class RevueRow extends StatelessWidget {
  const RevueRow({super.key, required this.line});

  final RevueLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = KadiColors.of(context).rayon(line.rayon).accent;
    final quantity = revueQuantityText(line.quantity, line.unit);
    final spoken = [
      line.name,
      if (quantity.isNotEmpty) quantity,
      line.rayon.spokenLabel,
    ].join(', ');

    return Semantics(
      label: spoken,
      checked: true,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.only(
            left: KadiSpacing.s1,
            right: KadiSpacing.margin,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: KadiSpacing.touchTarget,
                child: Transform.scale(
                  scale: _checkScale,
                  child: Checkbox(
                    value: true,
                    onChanged: (_) {},
                    shape: const CircleBorder(),
                    activeColor: accent,
                    checkColor: scheme.surface,
                    side: BorderSide(color: accent, width: 2 / _checkScale),
                    splashRadius: KadiSpacing.touchTarget / 2 / _checkScale,
                    overlayColor: WidgetStatePropertyAll(
                      accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KadiSpacing.s1),
              Picto(pictoKey: line.pictoKey, rayon: line.rayon),
              const SizedBox(width: KadiSpacing.s3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s2),
                  child: Text(
                    line.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (quantity.isNotEmpty) ...[
                const SizedBox(width: KadiSpacing.s3),
                Text(
                  quantity,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
