import 'package:flutter/semantics.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/round_check.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../state/revue.dart';

/// Largeur du Champ quantité à droite de la ligne à ×1 : « 500 g » et
/// « 6 pièces » y tiennent entiers ; elle suit la police jusqu'à
/// [_inlineFieldMaxTextScale].
const _fieldWidth = 96.0;

/// Facteur de police au-delà duquel le Champ quantité passe sous le nom.
const _inlineFieldMaxTextScale = 1.3;

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

/// Ligne de Revue (DESIGN `review-row`) : coche ronde à l'accent du rayon,
/// nom, et à droite, pour une ligne chiffrée seulement, le Champ quantité
/// discret (rempli, sans bordure) dans l'unité de la ligne
/// ([RevueLine.fieldUnit]), sans Choix d'unité. Pas de Picto (C7). Une
/// ligne sans quantité n'a ni champ ni texte de quantité.
///
/// Un tap sur la coche décoche ou recoche ([onToggle]) ; décochée, le nom
/// passe en couleur `checked`, sans barré, et la ligne reste en place. La
/// ligne est lue « Pâtes, 500 g, Épicerie salée » avec son état coché ; le
/// champ, à part, « Quantité de Pâtes, 500 g ». Le changement est annoncé
/// « Pâtes, non coché » / « Pâtes, coché ».
class RevueRow extends StatelessWidget {
  const RevueRow({
    super.key,
    required this.line,
    required this.checked,
    required this.controller,
    required this.onToggle,
  });

  final RevueLine line;
  final bool checked;

  /// Texte saisi du Champ quantité, gardé par l'écran (brouillon) ; nul pour
  /// une ligne sans quantité, qui n'a pas de champ.
  final TextEditingController? controller;
  final VoidCallback onToggle;

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
    final controller = this.controller;
    if (controller == null) return _build(context, '', null);
    final inputUnit = InputUnit.of(line.fieldUnit);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final stored = quantityFromFieldText(value.text, inputUnit);
        final quantity = revueQuantityText(stored?.quantity, stored?.unit);
        return _build(
          context,
          quantity,
          Semantics(
            label: StringsFr.quantiteDe(line.name, quantity),
            child: QuantityField(
              controller: controller,
              unit: inputUnit,
              filled: true,
            ),
          ),
        );
      },
    );
  }

  /// La ligne, avec [field] à droite (sous le nom en grande police) ou sans
  /// champ s'il est nul.
  Widget _build(BuildContext context, String quantity, Widget? field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kadiColors = KadiColors.of(context);
    final accent = kadiColors.rayon(line.rayon).accent;
    final spoken = [
      line.name,
      if (quantity.isNotEmpty) quantity,
      line.rayon.spokenLabel,
    ].join(', ');
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final large = textScale > _inlineFieldMaxTextScale;
    final fieldWidth =
        _fieldWidth * textScale.clamp(1.0, _inlineFieldMaxTextScale);

    final head = Semantics(
      label: spoken,
      checked: checked,
      onTap: () => _toggle(context),
      excludeSemantics: true,
      child: Row(
        children: [
          RoundCheck(
            value: checked,
            onChanged: () => _toggle(context),
            accent: accent,
          ),
          const SizedBox(width: KadiSpacing.s1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s2),
              // Décochée : couleur cochée sans barré, l'article reste là.
              child: Text(
                line.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: checked ? scheme.onSurface : kadiColors.checked,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.only(
          left: KadiSpacing.s1,
          right: KadiSpacing.margin,
        ),
        // En grande police, le champ passe sous le nom : rien ne déborde.
        child: field == null
            ? head
            : large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head,
                  Padding(
                    padding: const EdgeInsets.only(
                      left: KadiSpacing.touchTarget + KadiSpacing.s1,
                      bottom: KadiSpacing.s2,
                    ),
                    child: field,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: head),
                  const SizedBox(width: KadiSpacing.s3),
                  SizedBox(width: fieldWidth, child: field),
                ],
              ),
      ),
    );
  }
}
