import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../strings/strings_fr.dart';
import '../theme/kadi_tokens.dart';
import '../units/unit.dart';

/// Chiffres au plus dans le champ : 999 999 g, ml ou pièces.
const _maxDigits = 6;

/// Texte du Champ quantité pour [quantity] stockée en [unit] (AD-6) : g et
/// ml tels quels, pièces en nombre entier (millièmes arrondis, au moins 1
/// pour une quantité non nulle) ; vide sans quantité.
String quantityFieldText(int? quantity, Unit unit) {
  if (quantity == null || quantity <= 0) return '';
  if (unit != Unit.piece) return '$quantity';
  final pieces = (quantity + 500) ~/ 1000;
  return '${pieces < 1 ? 1 : pieces}';
}

/// Quantité stockée (AD-6) pour le [text] saisi en [unit] : g et ml
/// entiers, pièces ×1000. Vide ou 0 : `null`, « sans quantité ».
int? quantityFromFieldText(String text, Unit unit) {
  final value = int.tryParse(text.trim());
  if (value == null || value <= 0) return null;
  return unit == Unit.piece ? value * 1000 : value;
}

/// Suffixe du champ : g, ml, pièces.
String _suffix(Unit unit) => switch (unit) {
  Unit.g => StringsFr.champUniteG,
  Unit.ml => StringsFr.champUniteMl,
  Unit.piece => StringsFr.champUnitePieces,
};

/// Champ quantité (DESIGN `quantity-field`) : nombre entier dans l'unité
/// de saisie [unit], suffixe d'unité en `on-surface-variant` ; vide = sans
/// quantité. Clavier numérique, chiffres seulement, hauteur 48 dp.
///
/// Partagé par la Feuille d'édition d'article, le Panneau +, la Revue et la
/// Ligne d'ingrédient ; [quantityFieldText] et [quantityFromFieldText]
/// convertissent entre le texte et la quantité stockée.
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.controller,
    required this.unit,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Unit unit;
  final FocusNode? focusNode;

  /// Saisie de l'utilisateur.
  final ValueChanged<String>? onChanged;

  /// Validation du clavier.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KadiRadius.xs),
      borderSide: BorderSide(color: scheme.outline),
    );

    return SizedBox(
      height: KadiSpacing.touchTarget,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_maxDigits),
        ],
        textAlign: TextAlign.end,
        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          // Le thème global n'a pas de bordure : le Champ quantité en a une.
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: KadiSpacing.s3,
          ),
          // En `suffixIcon` : un `suffixText` reste masqué tant que le champ
          // est vide et sans focus, et l'unité doit toujours se voir.
          suffixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(end: KadiSpacing.s3),
            child: Text(
              _suffix(unit),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(),
        ),
      ),
    );
  }
}
