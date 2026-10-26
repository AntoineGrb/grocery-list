import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';

/// Ligne d'article de la Liste : nom et quantité, sans Picto.
///
/// Annoncée « Lait, Crèmerie » ; la coche arrive avec sa story.
class ItemRow extends StatelessWidget {
  const ItemRow({super.key, required this.item});

  final ListeItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quantity = formatQuantity(item.quantity, item.unit);
    final spoken = [
      item.name,
      if (quantity.isNotEmpty) quantity,
      item.rayon.spokenLabel,
    ].join(', ');

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KadiSpacing.margin,
            vertical: KadiSpacing.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
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
