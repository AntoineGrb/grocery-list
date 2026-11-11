import 'dart:ui' show FlutterView;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/round_check.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';

/// Délai entre le tap sur la case et le départ de la ligne : l'animation de
/// la case (≈ 200 ms) plus un temps de lecture.
const _checkDelay = Duration(milliseconds: 250);

/// Départ de la ligne cochée ou décochée : fondu et repli, puis écriture ;
/// elle réapparaît dans sa nouvelle section.
const _leaveDuration = Duration(milliseconds: 300);

/// Actions TalkBack équivalentes au glisser et à l'appui long (R24).
const _supprimerAction = CustomSemanticsAction(label: StringsFr.supprimer);
const _modifierAction = CustomSemanticsAction(label: StringsFr.modifier);

/// Ligne d'article de la Liste : case, nom et quantité, sans Picto.
///
/// Seule la case coche ou décoche ; un tap sur le nom ne fait rien. Glisser
/// vers la gauche supprime ([onRemove]) ; un appui long ouvre la Feuille
/// d'édition ([onEdit]). Annoncée « Tomates, 500 g, Fruits et légumes »
/// avec l'état coché ou non coché, et les actions « Supprimer » et
/// « Modifier ».
class ItemRow extends ConsumerStatefulWidget {
  const ItemRow({super.key, required this.item, this.onRemove, this.onEdit});

  final ListeItem item;

  /// Supprime la ligne (avec snackbar Annuler) ; rend `false` si
  /// l'écriture a échoué et que la ligne reste. Sans elle, pas de glisser.
  final Future<bool> Function()? onRemove;

  /// Ouvre la Feuille d'édition d'article. Sans elle, pas d'appui long.
  final VoidCallback? onEdit;

  @override
  ConsumerState<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends ConsumerState<ItemRow> {
  /// État visé par un tap dont l'écriture n'est pas encore faite.
  bool? _pending;

  /// Vrai pendant le fondu de départ, avant l'écriture.
  bool _leaving = false;

  /// Ligne glissée et supprimée : masquée jusqu'à ce que le flux de la
  /// Liste la retire. Un `Dismissible` rejeté doit quitter l'arbre tout de
  /// suite.
  bool _dismissed = false;

  /// Change la clé du `Dismissible` quand une ligne masquée revient (même
  /// ligne réémise), pour repartir d'un `Dismissible` neuf.
  int _generation = 0;

  @override
  void didUpdateWidget(ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.checked != widget.item.checked) {
      _pending = null;
      _leaving = false;
    }
    if (_dismissed && !identical(oldWidget.item, widget.item)) {
      _dismissed = false;
      _generation++;
    }
  }

  Future<bool> _confirmDismiss(DismissDirection _) async =>
      await widget.onRemove?.call() ?? false;

  void _toggle() {
    if (_pending != null) return;
    final item = widget.item;
    final target = !item.checked;
    setState(() => _pending = target);

    // Tout est lu maintenant : la ligne peut être démontée (ou reconstruite
    // ailleurs) avant l'écriture.
    if (!target) ref.read(listeReturningProvider).add(item.lineId);
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
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
        if (mounted) setState(() => _leaving = true);
        await Future<void>.delayed(_leaveDuration);
      }
      if (check) {
        await repository.check(lineId);
      } else {
        await repository.uncheck(lineId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pending = null;
          _leaving = false;
        });
      }
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
    if (_dismissed) return const SizedBox.shrink();
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

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.only(
          left: KadiSpacing.s1,
          right: KadiSpacing.margin,
        ),
        child: Row(
          children: [
            RoundCheck(value: shown, onChanged: _toggle, accent: accent),
            const SizedBox(width: KadiSpacing.s1),
            Expanded(
              // Marge verticale du texte seul : un nom sur plusieurs
              // lignes garde de l'air, la case reste à 48 dp.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textStyle(
                        theme.textTheme.bodyLarge,
                        scheme.onSurface,
                      ),
                    ),
                    // Recette(s) d'origine (V2 2e).
                    if (item.recipeNames.isNotEmpty)
                      Text(
                        item.recipeNames.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 16 / 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
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
    );

    final onEdit = widget.onEdit;
    if (onEdit != null) {
      row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onEdit,
        child: row,
      );
    }
    if (widget.onRemove != null) {
      final noAnimation = MediaQuery.disableAnimationsOf(context);
      row = Dismissible(
        key: ValueKey((item.lineId, _generation)),
        direction: DismissDirection.endToStart,
        // Animations coupées : la ligne part sans glissement ni repli.
        movementDuration: noAnimation
            ? Duration.zero
            : const Duration(milliseconds: 200),
        resizeDuration: noAnimation
            ? Duration.zero
            : const Duration(milliseconds: 300),
        confirmDismiss: _confirmDismiss,
        onDismissed: (_) => setState(() => _dismissed = true),
        background: ColoredBox(
          color: scheme.error,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: KadiSpacing.margin,
              ),
              child: Icon(Icons.delete_outline, color: scheme.onError),
            ),
          ),
        ),
        child: row,
      );
    }

    // Fondu et repli de la ligne qui change de section.
    row = ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: _leaving ? 0 : 1,
        duration: _leaveDuration,
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _leaving ? 0 : 1,
          duration: _leaveDuration,
          curve: Curves.easeOut,
          child: row,
        ),
      ),
    );

    final onRemove = widget.onRemove;
    return Semantics(
      label: spoken,
      checked: shown,
      onTap: _toggle,
      customSemanticsActions: {
        if (onRemove != null) _supprimerAction: () => onRemove(),
        _modifierAction: ?onEdit,
      },
      excludeSemantics: true,
      child: row,
    );
  }
}
