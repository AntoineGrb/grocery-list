import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../strings/strings_fr.dart';
import '../theme/kadi_tokens.dart';
import '../units/unit.dart';

/// Chiffres au plus avant la virgule : 999 999 g, kg, ml, L ou pièces.
const _maxDigits = 6;

/// Texte du Champ quantité pour [quantity] stockée, lue en [unit] (AD-6) :
/// g et ml tels quels, kg et L en millièmes (virgule, au plus 3 décimales,
/// sans zéros de fin), pièces en nombre entier (millièmes arrondis, au
/// moins 1 pour une quantité non nulle) ; vide sans quantité.
String quantityFieldText(int? quantity, InputUnit unit) {
  if (quantity == null || quantity <= 0) return '';
  switch (unit) {
    case InputUnit.g || InputUnit.ml:
      return '$quantity';
    case InputUnit.piece:
      final pieces = (quantity + 500) ~/ 1000;
      return '${pieces < 1 ? 1 : pieces}';
    case InputUnit.kg || InputUnit.l:
      final whole = quantity ~/ 1000;
      final fraction = (quantity % 1000)
          .toString()
          .padLeft(3, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      return fraction.isEmpty ? '$whole' : '$whole,$fraction';
  }
}

/// Quantité stockée et son unité (AD-6) pour le [text] saisi en [unit], par
/// l'unique [storedQuantity] : « 1,5 » kg → 1500 g. Vide ou 0 : `null`,
/// « sans quantité ».
StoredQuantity? quantityFromFieldText(String text, InputUnit unit) =>
    storedQuantity(text, unit);

/// [text] gardé tel quel pour [unit], sauf les décimales qu'elle n'admet
/// pas : « 1,5 » passé en g devient « 1 », « 1,2345 » en kg « 1,234 ».
String quantityTextForUnit(String text, InputUnit unit) {
  final comma = text.indexOf(',');
  if (comma < 0) return text;
  if (unit.decimals == 0) return text.substring(0, comma);
  final end = comma + 1 + unit.decimals;
  return text.length > end ? text.substring(0, end) : text;
}

/// Suffixe du champ : pièces, g, kg, ml, l.
String _suffix(InputUnit unit) => switch (unit) {
  InputUnit.piece => StringsFr.champUnitePieces,
  InputUnit.g => StringsFr.champUniteG,
  InputUnit.kg => StringsFr.champUniteKg,
  InputUnit.ml => StringsFr.champUniteMl,
  InputUnit.l => StringsFr.champUniteL,
};

/// Virgule décimale : le point devient une virgule ; une saisie hors de
/// « 6 chiffres, puis au plus [decimals] décimales » est refusée.
class _DecimalFormatter extends TextInputFormatter {
  _DecimalFormatter(int decimals)
    : _pattern = RegExp('^[0-9]{0,$_maxDigits}(,[0-9]{0,$decimals})?\$');

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Même longueur : la sélection reste valable.
    final text = newValue.text.replaceAll('.', ',');
    if (!_pattern.hasMatch(text)) return oldValue;
    return newValue.copyWith(text: text);
  }
}

/// Champ quantité (DESIGN `quantity-field`) : nombre dans l'unité de
/// saisie [unit], suffixe d'unité en `on-surface-variant` ; vide = sans
/// quantité. Clavier numérique, chiffres seulement, virgule décimale pour
/// kg et L ; hauteur 48 dp.
///
/// Partagé par la Feuille d'édition d'article, la Popup quantité, la Revue et
/// la Ligne d'ingrédient ; [quantityFieldText] et [quantityFromFieldText]
/// convertissent entre le texte et la quantité stockée.
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.controller,
    required this.unit,
    this.focusNode,
    this.autofocus = false,
    this.filled = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final InputUnit unit;
  final FocusNode? focusNode;

  /// Prend le focus à son apparition, clavier ouvert.
  final bool autofocus;

  /// Fond `surface-container` sans bordure, pour la Popup quantité.
  final bool filled;

  /// Saisie de l'utilisateur.
  final ValueChanged<String>? onChanged;

  /// Validation du clavier.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(
        filled ? KadiRadius.sm : KadiRadius.xs,
      ),
      borderSide: filled ? BorderSide.none : BorderSide(color: scheme.outline),
    );
    final decimal = unit.decimals > 0;

    return SizedBox(
      height: KadiSpacing.touchTarget,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        // Toujours avec virgule : Android ne change pas de clavier quand la
        // puce d'unité change pendant la saisie.
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: decimal
            ? [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                _DecimalFormatter(unit.decimals),
              ]
            : [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_maxDigits),
              ],
        textAlign: TextAlign.end,
        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          // Le thème global n'a pas de bordure : le Champ quantité en a une,
          // sauf rempli.
          filled: filled,
          fillColor: scheme.surfaceContainer,
          border: border,
          enabledBorder: border,
          focusedBorder: filled
              ? border
              : border.copyWith(
                  // Jamais d'argile sur un état (C6).
                  borderSide: BorderSide(color: scheme.onSurface, width: 2),
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
