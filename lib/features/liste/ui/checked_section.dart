import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import 'item_row.dart';

/// Section Cochés, en bas de la Liste : filet, en-tête « Cochés (n) » et,
/// une fois dépliée, les lignes cochées.
///
/// Repliée par défaut ; l'état replié / déplié vit dans le widget, jamais
/// persisté. En-tête annoncé « Cochés, 2 articles, replié ».
class CheckedSection extends StatefulWidget {
  const CheckedSection({super.key, required this.items});

  /// Lignes cochées, la dernière cochée en tête.
  final List<ListeItem> items;

  @override
  State<CheckedSection> createState() => _CheckedSectionState();
}

class _CheckedSectionState extends State<CheckedSection>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  // Garder l'état déplié quand la section sort de l'écran au défilement.
  @override
  bool get wantKeepAlive => true;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = widget.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: KadiSpacing.s2),
        Divider(height: 1, thickness: 1, color: scheme.outline),
        Semantics(
          button: true,
          label: StringsFr.cochesLu(count, expanded: _expanded),
          onTap: _toggle,
          excludeSemantics: true,
          child: InkWell(
            onTap: _toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: KadiSpacing.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: KadiSpacing.s3,
                  right: KadiSpacing.margin,
                ),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_more : Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: KadiSpacing.s2),
                    Text(
                      StringsFr.cochesTitre(count),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _expanded ? StringsFr.replier : StringsFr.afficher,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final item in widget.items)
            ItemRow(key: ValueKey(item.lineId), item: item),
      ],
    );
  }
}
