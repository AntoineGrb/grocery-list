import 'dart:ui' show FlutterView;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';

/// Délai entre le tap sur la case et l'écriture : l'animation de la case M3
/// (≈ 200 ms) plus un temps de lecture.
const _checkDelay = Duration(milliseconds: 300);

/// Ligne d'article de la Liste : case, nom et quantité, sans Picto.
///
/// Seule la case coche ou décoche ; un tap sur le nom ne fait rien. Annoncée
/// « Tomates, 500 g, Fruits et légumes » avec l'état coché ou non coché.
class ItemRow extends ConsumerStatefulWidget {
  const ItemRow({super.key, required this.item});

  final ListeItem item;

  @override
  ConsumerState<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends ConsumerState<ItemRow> {
  /// État visé par un tap dont l'écriture n'est pas encore faite.
  bool? _pending;

  @override
  void didUpdateWidget(ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.checked != widget.item.checked) _pending = null;
  }

  void _toggle() {
    if (_pending != null) return;
    final item = widget.item;
    final target = !item.checked;
    setState(() => _pending = target);

    // Tout est lu maintenant : la ligne peut être démontée (ou reconstruite
    // ailleurs) avant l'écriture.
    _write(
      repository: ref.read(listeRepositoryProvider),
      view: View.of(context),
      delay: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _checkDelay,
      lineId: item.lineId,
      check: target,
      announcement: target
          ? StringsFr.cocheAnnonce(item.name)
          : StringsFr.nonCocheAnnonce(item.name),
    );
  }

  Future<void> _write({
    required ListeRepository repository,
    required FlutterView view,
    required Duration delay,
    required String lineId,
    required bool check,
    required String announcement,
  }) async {
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (check) {
        await repository.check(lineId);
      } else {
        await repository.uncheck(lineId);
      }
    } catch (_) {
      if (mounted) setState(() => _pending = null);
      return;
    }
    await SemanticsService.sendAnnouncement(
      view,
      announcement,
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kadiColors = KadiColors.of(context);
    final accent = kadiColors.rayon(item.rayon).accent;
    final shown = _pending ?? item.checked;
    final quantity = formatQuantity(item.quantity, item.unit);
    final spoken = [
      item.name,
      if (quantity.isNotEmpty) quantity,
      item.rayon.spokenLabel,
    ].join(', ');

    TextStyle? textStyle(TextStyle? base, Color color) => item.checked
        ? base?.copyWith(
            color: kadiColors.checked,
            decoration: TextDecoration.lineThrough,
            decorationColor: kadiColors.checked,
          )
        : base?.copyWith(color: color);

    return Semantics(
      label: spoken,
      checked: shown,
      onTap: _toggle,
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
                child: Checkbox(
                  value: shown,
                  onChanged: (_) => _toggle(),
                  activeColor: accent,
                  checkColor: scheme.surface,
                  side: BorderSide(color: accent, width: 2),
                ),
              ),
              const SizedBox(width: KadiSpacing.s1),
              Expanded(
                // Marge verticale du texte seul : un nom sur plusieurs
                // lignes garde de l'air, la case reste à 48 dp.
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s2),
                  child: Text(
                    item.name,
                    style: textStyle(
                      theme.textTheme.bodyLarge,
                      scheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (quantity.isNotEmpty) ...[
                const SizedBox(width: KadiSpacing.s3),
                Text(
                  quantity,
                  style: textStyle(
                    theme.textTheme.bodyMedium,
                    scheme.onSurfaceVariant,
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
