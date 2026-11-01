import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';

/// Unité préchoisie du Choix d'unité : celle de la ligne, sinon celle de
/// l'article, sinon pièce. Une ligne en g s'ouvre en g, même au-delà de
/// 1000 (kg seulement si choisi).
InputUnit initialInputUnit(ListeItem item) {
  final unit = item.unit ?? item.articleUnit;
  return unit == null ? InputUnit.piece : InputUnit.of(unit);
}

/// [quantity] et [unit] comme une seule valeur : `null` sans quantité (AD-6).
StoredQuantity? storedQuantityOf(int? quantity, Unit? unit) =>
    quantity == null || unit == null ? null : (quantity: quantity, unit: unit);

/// Saisie d'une quantité, commune à la Feuille d'édition d'article et à la
/// Popup quantité : le texte du Champ quantité et l'unité du Choix d'unité.
class QuantityInput {
  QuantityInput({required int? quantity, required this.initialUnit})
    : unit = initialUnit,
      controller = TextEditingController(
        text: quantityFieldText(quantity, initialUnit),
      );

  final InputUnit initialUnit;
  final TextEditingController controller;
  InputUnit unit;

  /// Le champ a été saisi. Sans cela, ni la puce changée, rien n'est à
  /// écrire : le texte préchargé, arrondi pour les pièces, ne réécrit pas la
  /// quantité.
  bool edited = false;

  /// Saisie ou puce changée.
  bool get touched => edited || unit != initialUnit;

  /// Quantité saisie, `null` si vide ou 0.
  StoredQuantity? get value => quantityFromFieldText(controller.text, unit);

  /// Change de puce en gardant le nombre tapé : la puce dit seulement dans
  /// quelle unité il est lu (sans les décimales qu'elle n'admet pas).
  void selectUnit(InputUnit next) {
    unit = next;
    final text = quantityTextForUnit(controller.text, next);
    if (text != controller.text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void dispose() => controller.dispose();
}

/// Libellé d'une puce du Choix d'unité : pièce, g, kg, ml, L.
String _chipLabel(InputUnit unit) => switch (unit) {
  InputUnit.piece => StringsFr.puceUnitePiece,
  InputUnit.g => StringsFr.puceUniteG,
  InputUnit.kg => StringsFr.puceUniteKg,
  InputUnit.ml => StringsFr.puceUniteMl,
  InputUnit.l => StringsFr.puceUniteL,
};

/// Choix d'unité (DESIGN `item-edit-sheet`, `quantity-popup`) : puces de choix
/// M3 pièce · g · kg · ml · L, cible de 48 dp ; la puce [selected] en contour
/// `on-surface` avec sa coche, jamais en argile. Chaque puce est lue par son
/// libellé, choisie ou non.
class UnitChoice extends StatelessWidget {
  const UnitChoice({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final InputUnit selected;
  final ValueChanged<InputUnit> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: KadiSpacing.s2,
      children: [
        for (final unit in InputUnit.values)
          ChoiceChip(
            key: ValueKey(unit),
            label: Text(_chipLabel(unit)),
            selected: unit == selected,
            onSelected: (_) => onSelected(unit),
            showCheckmark: true,
            checkmarkColor: scheme.onSurface,
            // Fond de la surface : seul le contour marque le choix.
            color: const WidgetStatePropertyAll(Colors.transparent),
            labelStyle: TextStyle(color: scheme.onSurface),
            side: BorderSide(
              color: unit == selected ? scheme.onSurface : scheme.outline,
            ),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}
