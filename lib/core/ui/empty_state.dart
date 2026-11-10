import 'package:material_ui/material_ui.dart';

import '../theme/kadi_theme.dart';
import '../theme/kadi_tokens.dart';

/// Message d'état vide : une phrase centrée, en `on-surface-variant`.
///
/// Variante illustrée (Liste vide) : un grand disque `surfaceContainerHigh`
/// avec [glyph], un [title] display au-dessus de la phrase et une [action]
/// dessous. L'illustration est exclue de la sémantique.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.glyph,
    this.title,
    this.action,
  });

  final String message;
  final IconData? glyph;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glyph = this.glyph;
    final title = this.title;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              ExcludeSemantics(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(glyph, size: 56, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: KadiSpacing.s5),
            ],
            if (title != null) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: KadiText.screenTitle.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: KadiSpacing.s2),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: KadiSpacing.s5),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
