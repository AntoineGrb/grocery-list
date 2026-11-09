import 'package:material_ui/material_ui.dart';

import '../theme/kadi_tokens.dart';

/// Poignée des feuilles de la V2 : 32 × 4 dp, `on-surface-variant` à 60 %.
/// Décorative, exclue de la sémantique.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      child: Container(
        width: KadiSpacing.panelHandleWidth,
        height: KadiSpacing.panelHandleThickness,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant
              .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}
