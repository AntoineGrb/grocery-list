import 'package:flutter/semantics.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/quantity_tag.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../state/revue.dart';

/// Espace insécable entre le nombre et son unité.
const _nbsp = ' ';

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

/// Ligne de Revue de la V2 (README redesign 2d), dans la carte de son rayon.
///
/// - Gardée (par défaut) : rond plein à l'accent avec ✓, nom, tag quantité
///   de 28 dp à droite (tap : Module quantité, [onQuantityTap]) ;
/// - « J'ai ! » : maison, nom barré en couleur `checked`, « J'ai ! » à
///   droite, sans tag.
///
/// Un tap sur la ligne bascule ([onToggle]) ; le tag est une cible à part.
/// Lue « Pâtes, 500 g, Épicerie salée » avec son état coché ; le changement
/// est annoncé.
class RevueRow extends StatelessWidget {
  const RevueRow({
    super.key,
    required this.line,
    required this.checked,
    required this.quantity,
    required this.unit,
    required this.onToggle,
    required this.onQuantityTap,
  });

  final RevueLine line;

  /// Gardée : l'article ira dans la liste.
  final bool checked;

  /// Quantité montrée (corrigée ou d'origine), nulle avec [unit].
  final int? quantity;
  final Unit? unit;
  final VoidCallback onToggle;
  final VoidCallback onQuantityTap;

  void _toggle(BuildContext context) {
    final view = View.of(context);
    final announcement = checked
        ? StringsFr.nonCocheAnnonce(line.name)
        : StringsFr.cocheAnnonce(line.name);
    onToggle();
    SemanticsService.sendAnnouncement(view, announcement, TextDirection.ltr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kadiColors = KadiColors.of(context);
    final accent = kadiColors.rayon(line.rayon).accent;
    final text = revueQuantityText(quantity, unit);
    final spoken = [
      line.name,
      if (checked && text.isNotEmpty) text,
      if (!checked) StringsFr.jAi,
      line.rayon.spokenLabel,
    ].join(', ');

    final mark = checked
        ? Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 16, color: scheme.surface),
          )
        : SizedBox.square(
            dimension: 22,
            child: Icon(Icons.home_outlined, size: 20, color: scheme.outline),
          );

    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            label: spoken,
            checked: checked,
            onTap: () => _toggle(context),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _toggle(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 42),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      mark,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: KadiSpacing.s1,
                          ),
                          child: Text(
                            line.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 15,
                              color: checked
                                  ? scheme.onSurface
                                  : kadiColors.checked,
                              decoration: checked
                                  ? null
                                  : TextDecoration.lineThrough,
                              decorationColor: kadiColors.checked,
                            ),
                          ),
                        ),
                      ),
                      if (!checked) ...[
                        const SizedBox(width: 10),
                        Text(
                          StringsFr.jAi,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kadiColors.checked,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (checked)
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: QuantityTag(
              name: line.name,
              rayon: line.rayon,
              quantity: quantity,
              unit: unit,
              height: 28,
              tapHeight: 42,
              onTap: onQuantityTap,
            ),
          ),
      ],
    );
  }
}
