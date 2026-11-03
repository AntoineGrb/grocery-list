import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Dialogue de confirmation (DESIGN `confirm-dialog`) : [title], [message],
/// l'action de repli [keepLabel] (`on-surface`) et l'action [confirmLabel]
/// (`error`). Montré par [showConfirmDialog].
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.keepLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String keepLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const target = Size(KadiSpacing.touchTarget, KadiSpacing.touchTarget);
    return AlertDialog(
      // Grande police système : le texte défile au lieu de déborder.
      scrollable: true,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KadiRadius.xl)),
      ),
      title: Text(title),
      titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
        color: scheme.onSurface,
      ),
      content: Text(message),
      contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            minimumSize: target,
          ),
          child: Text(keepLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: scheme.error,
            minimumSize: target,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Montre un [ConfirmDialog] ; rend `true` sur [confirmLabel] seulement.
/// L'action de repli, le retour et un tap hors du dialogue rendent `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String keepLabel,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        keepLabel: keepLabel,
        confirmLabel: confirmLabel,
      ),
    ) ??
    false;
