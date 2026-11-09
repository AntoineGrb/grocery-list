import 'package:material_ui/material_ui.dart';

import '../strings/strings_fr.dart';
import '../theme/kadi_theme.dart';
import '../theme/kadi_tokens.dart';
import '../units/unit.dart';
import 'quantity_field.dart';
import 'sheet_handle.dart';

/// Quantité choisie dans le Module quantité ; [value] nulle : sans quantité.
typedef QuantityEdit = ({StoredQuantity? value});

/// Ordre des segments du choix d'unité.
const quantityUnits = [
  InputUnit.piece,
  InputUnit.g,
  InputUnit.kg,
  InputUnit.ml,
  InputUnit.l,
];

/// État pur du Module quantité (README redesign §4.3) : un nombre en
/// millièmes de l'unité de saisie [unit]. Pas de 50 en g et ml, de 1 en
/// pièce, de 0,5 en kg et L ; minimum 0. Changer d'unité remet à 0.
class QuantityStepper {
  QuantityStepper({required this.unit, this.milli = 0});

  /// Préchargé avec [quantity] stockée en [stored] (lue dans son unité de
  /// saisie), sinon 0 en [initialUnit].
  factory QuantityStepper.of(
    int? quantity,
    Unit? stored, {
    required InputUnit initialUnit,
  }) {
    if (quantity == null || stored == null || quantity <= 0) {
      return QuantityStepper(unit: initialUnit);
    }
    final unit = InputUnit.of(stored);
    return QuantityStepper(unit: unit, milli: quantity * 1000 ~/ unit.factor);
  }

  InputUnit unit;

  /// Nombre affiché, en millièmes de [unit] : 2 pièces = 2000.
  int milli;

  /// Plafond : 6 chiffres avant la virgule.
  static const _max = 999999 * 1000;

  static int stepOf(InputUnit unit) => switch (unit) {
    InputUnit.g || InputUnit.ml => 50 * 1000,
    InputUnit.piece => 1000,
    InputUnit.kg || InputUnit.l => 500,
  };

  /// Valeurs rapides de [unit], en millièmes.
  static List<int> picksOf(InputUnit unit) => switch (unit) {
    InputUnit.g => const [100000, 250000, 500000, 750000],
    InputUnit.kg || InputUnit.l => const [500, 1000, 1500, 2000],
    InputUnit.piece => const [1000, 2000, 3000, 6000],
    InputUnit.ml => const [100000, 200000, 250000, 500000],
  };

  void increment() => milli = (milli + stepOf(unit)).clamp(0, _max);

  void decrement() => milli = (milli - stepOf(unit)).clamp(0, _max);

  void selectUnit(InputUnit next) {
    if (next == unit) return;
    unit = next;
    milli = 0;
  }

  /// Saisie libre au clavier : [text] lu en [unit] ; illisible ou vide : 0.
  void setText(String text) {
    final stored = storedQuantity(text, unit);
    milli = stored == null ? 0 : stored.quantity * 1000 ~/ unit.factor;
  }

  /// Quantité à écrire ; 0 efface (`null`, sans quantité).
  StoredQuantity? get value => milli <= 0
      ? null
      : (quantity: milli * unit.factor ~/ 1000, unit: unit.stored);

  /// Nombre affiché : virgule décimale, sans zéros de fin.
  String get numberLabel => numberText(milli);

  /// Texte de [milli] millièmes : 1500 → « 1,5 », 2000 → « 2 ».
  static String numberText(int milli) {
    final whole = milli ~/ 1000;
    final fraction = (milli % 1000)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole,$fraction';
  }

  /// Unité après le nombre : pièce ou pièces selon le nombre.
  String get unitLabel => unitText(unit, milli);

  static String unitText(InputUnit unit, int milli) => switch (unit) {
    InputUnit.piece =>
      milli >= 2000 ? StringsFr.unitePieces : StringsFr.unitePiece,
    InputUnit.g => StringsFr.uniteG,
    InputUnit.kg => StringsFr.uniteKg,
    InputUnit.ml => StringsFr.uniteMl,
    InputUnit.l => StringsFr.puceUniteL,
  };

  /// Libellé d'une valeur rapide : « 2 pièces », « 0,5 kg ».
  static String pickLabel(InputUnit unit, int milli) =>
      '${numberText(milli)} ${unitText(unit, milli)}';
}

/// Libellé d'un segment du choix d'unité.
String unitSegmentLabel(InputUnit unit) => switch (unit) {
  InputUnit.piece => StringsFr.puceUnitePiece,
  InputUnit.g => StringsFr.puceUniteG,
  InputUnit.kg => StringsFr.puceUniteKg,
  InputUnit.ml => StringsFr.puceUniteMl,
  InputUnit.l => StringsFr.puceUniteL,
};

/// Ouvre le Module quantité (README redesign §4.3), un seul module pour la
/// Fiche recette, la Revue et le Panneau +. En-tête : [leading] (picto ou
/// puce de rayon), [title] et, à droite, [caption].
///
/// Préchargé avec [quantity] en [unit] ; sans quantité, l'unité
/// [initialUnit]. OK rend la quantité choisie (`value` nulle pour 0, « sans
/// quantité ») ; voile ou retour : `null`, rien à écrire.
Future<QuantityEdit?> showQuantitySheet(
  BuildContext context, {
  required String title,
  required Widget leading,
  String? caption,
  int? quantity,
  Unit? unit,
  required InputUnit initialUnit,
}) => showModalBottomSheet<QuantityEdit>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  builder: (_) => QuantitySheet(
    title: title,
    leading: leading,
    caption: caption,
    stepper: QuantityStepper.of(quantity, unit, initialUnit: initialUnit),
  ),
);

/// Contenu du Module quantité ; voir [showQuantitySheet].
class QuantitySheet extends StatefulWidget {
  const QuantitySheet({
    super.key,
    required this.title,
    required this.leading,
    required this.stepper,
    this.caption,
  });

  final String title;
  final Widget leading;
  final String? caption;
  final QuantityStepper stepper;

  @override
  State<QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<QuantitySheet> {
  late final QuantityStepper _q = widget.stepper;
  final _numberFocus = FocusNode();
  TextEditingController? _typing;

  @override
  void dispose() {
    _numberFocus.dispose();
    _typing?.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    _stopTyping();
    setState(change);
  }

  /// Tap sur le grand nombre : saisie libre au clavier numérique.
  void _startTyping() {
    final text = _q.milli == 0 ? '' : _q.numberLabel;
    setState(() {
      _typing = TextEditingController(text: text)
        ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _numberFocus.requestFocus();
    });
  }

  void _stopTyping() {
    final typing = _typing;
    if (typing == null) return;
    _q.setText(typing.text);
    _typing = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => typing.dispose());
  }

  void _ok() {
    _stopTyping();
    Navigator.of(context).pop<QuantityEdit>((value: _q.value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final typing = _typing;

    Widget roundButton(IconData icon, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: onTap,
          // Rond de 40 dp dans une cible de 48.
          child: Padding(
            padding: const EdgeInsets.all(KadiSpacing.s1),
            child: Material(
              color: scheme.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, size: 22, color: scheme.onSurface),
                ),
              ),
            ),
          ),
        );

    final number = typing == null
        ? Semantics(
            button: true,
            liveRegion: true,
            label: '${_q.numberLabel} ${_q.unitLabel}',
            excludeSemantics: true,
            onTap: _startTyping,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _startTyping,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _q.numberLabel,
                        key: const Key('quantity-sheet-number'),
                        style: KadiText.bigNumber.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: KadiSpacing.s2),
                  Text(
                    _q.unitLabel,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        : TextField(
            key: const Key('quantity-sheet-input'),
            controller: typing,
            focusNode: _numberFocus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(
              decimal: _q.unit.decimals > 0,
            ),
            inputFormatters: [DecimalQuantityFormatter(_q.unit.decimals)],
            style: KadiText.bigNumber.copyWith(color: scheme.onSurface),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              suffixText: _q.unitLabel,
              suffixStyle: text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onSubmitted: (_) => setState(_stopTyping),
          );

    final segments = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(KadiRadius.full),
      ),
      child: Row(
        children: [
          for (final (i, unit) in quantityUnits.indexed) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: _Choice(
                label: unitSegmentLabel(unit),
                semanticLabel: StringsFr.uniteDe(unitSegmentLabel(unit)),
                selected: unit == _q.unit,
                height: 30,
                radius: KadiRadius.full,
                idle: Colors.transparent,
                onTap: () => _update(() => _q.selectUnit(unit)),
              ),
            ),
          ],
        ],
      ),
    );

    final picks = Row(
      children: [
        for (final (i, milli) in QuantityStepper.picksOf(_q.unit).indexed) ...[
          if (i > 0) const SizedBox(width: KadiSpacing.s2),
          Expanded(
            child: _Choice(
              label: QuantityStepper.pickLabel(_q.unit, milli),
              selected: typing == null && milli == _q.milli,
              height: 36,
              radius: KadiRadius.tag,
              idle: scheme.surface,
              onTap: () => _update(() => _q.milli = milli),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),
              Row(
                children: [
                  widget.leading,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (widget.caption case final caption?)
                    Text(
                      caption,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KadiSpacing.s4),
              Row(
                children: [
                  roundButton(
                    Icons.remove,
                    StringsFr.moins,
                    () => _update(_q.decrement),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: number),
                  const SizedBox(width: 14),
                  roundButton(
                    Icons.add,
                    StringsFr.plus,
                    () => _update(_q.increment),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              segments,
              const SizedBox(height: 10),
              picks,
              const SizedBox(height: KadiSpacing.s4),
              FilledButton(
                onPressed: _ok,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KadiSpacing.touchTarget),
                ),
                child: const Text(StringsFr.ok),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segment d'unité ou valeur rapide : choisi à l'encre (C6), jamais en
/// argile.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.height,
    required this.radius,
    required this.idle,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final double height;
  final double radius;
  final Color idle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? scheme.onSurface : idle,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected ? scheme.surface : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
