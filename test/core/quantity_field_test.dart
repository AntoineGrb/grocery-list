import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  TextEditingController controller,
  InputUnit unit, {
  ValueChanged<String>? onSubmitted,
}) => tester.pumpWidget(
  MaterialApp(
    theme: KadiTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 160,
          child: QuantityField(
            controller: controller,
            unit: unit,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('conversions', () {
    test('préremplissage : g et ml tels quels, pièces entières, kg et L en '
        'décimal, vide sans quantité', () {
      expect(quantityFieldText(500, InputUnit.g), '500');
      expect(quantityFieldText(1500, InputUnit.g), '1500');
      expect(quantityFieldText(250, InputUnit.ml), '250');
      expect(quantityFieldText(2000, InputUnit.piece), '2');
      expect(quantityFieldText(1500, InputUnit.piece), '2');
      expect(quantityFieldText(1400, InputUnit.piece), '1');
      expect(quantityFieldText(250, InputUnit.piece), '1');
      expect(quantityFieldText(1500, InputUnit.kg), '1,5');
      expect(quantityFieldText(2000, InputUnit.l), '2');
      expect(quantityFieldText(1234, InputUnit.kg), '1,234');
      expect(quantityFieldText(50, InputUnit.l), '0,05');
      expect(quantityFieldText(null, InputUnit.g), '');
    });

    test('saisie : quantité et unité stockées ; vide ou 0 sans quantité', () {
      expect(quantityFromFieldText('300', InputUnit.g), (
        quantity: 300,
        unit: Unit.g,
      ));
      expect(quantityFromFieldText(' 15 ', InputUnit.ml), (
        quantity: 15,
        unit: Unit.ml,
      ));
      expect(quantityFromFieldText('3', InputUnit.piece), (
        quantity: 3000,
        unit: Unit.piece,
      ));
      expect(quantityFromFieldText('1,5', InputUnit.kg), (
        quantity: 1500,
        unit: Unit.g,
      ));
      expect(quantityFromFieldText('2', InputUnit.l), (
        quantity: 2000,
        unit: Unit.ml,
      ));
      expect(quantityFromFieldText('', InputUnit.g), isNull);
      expect(quantityFromFieldText('0', InputUnit.piece), isNull);
      expect(quantityFromFieldText('0,000', InputUnit.kg), isNull);
    });

    test('changer de puce garde le nombre, sans les décimales refusées', () {
      expect(quantityTextForUnit('300', InputUnit.kg), '300');
      expect(quantityTextForUnit('1,5', InputUnit.l), '1,5');
      expect(quantityTextForUnit('1,5', InputUnit.g), '1');
      expect(quantityTextForUnit('1,5', InputUnit.piece), '1');
      expect(quantityTextForUnit('', InputUnit.g), '');
    });
  });

  testWidgets('prérempli, suffixe d’unité, bordure outline, 48 dp', (
    tester,
  ) async {
    final controller = TextEditingController(text: '500');
    addTearDown(controller.dispose);
    await _pump(tester, controller, InputUnit.g);

    expect(find.text('500'), findsOneWidget);
    expect(find.text(StringsFr.uniteG), findsOneWidget);
    expect(tester.getSize(find.byType(QuantityField)).height, 48);
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    final border = decoration.enabledBorder! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(KadiRadius.xs));
    expect(border.borderSide.color, KadiPalette.light.outline);
    expect(
      tester.widget<Text>(find.text(StringsFr.uniteG)).style?.color,
      KadiPalette.light.onSurfaceVariant,
    );
  });

  testWidgets('vide et sans focus : l’unité reste visible', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, InputUnit.g);

    expect(find.text(StringsFr.uniteG), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(StringsFr.uniteG),
        matching: find.byType(AnimatedOpacity),
      ),
      findsNothing,
    );
  });

  testWidgets('suffixe pièces ; chiffres seulement ; validation', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    await _pump(
      tester,
      controller,
      InputUnit.piece,
      onSubmitted: (v) => submitted = v,
    );
    expect(find.text(StringsFr.unitePieces), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      // Clavier à virgule pour toutes les unités ; le filtre refuse la
      // virgule en pièces.
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(find.byType(TextField), '3,5-a');
    expect(controller.text, '35');
    await tester.enterText(find.byType(TextField), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, '3');
    expect(quantityFromFieldText(controller.text, InputUnit.piece), (
      quantity: 3000,
      unit: Unit.piece,
    ));
  });

  testWidgets('kg : suffixe kg, clavier décimal, point lu en virgule, au '
      'plus 3 décimales', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, InputUnit.kg);
    expect(find.text(StringsFr.uniteKg), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(find.byType(TextField), '1.5');
    expect(controller.text, '1,5');
    await tester.enterText(find.byType(TextField), '1,2345');
    // Refusé : la saisie précédente reste.
    expect(controller.text, '1,5');
    await tester.enterText(find.byType(TextField), '1,25a');
    expect(controller.text, '1,25');
    expect(quantityFromFieldText(controller.text, InputUnit.kg), (
      quantity: 1250,
      unit: Unit.g,
    ));
  });

  testWidgets('L : suffixe l', (tester) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    await _pump(tester, controller, InputUnit.l);
    expect(find.text(StringsFr.uniteL), findsOneWidget);
  });
}
