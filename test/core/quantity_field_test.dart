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
  Unit unit, {
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
    test('préremplissage : g et ml tels quels, pièces entières, vide sans '
        'quantité', () {
      expect(quantityFieldText(500, Unit.g), '500');
      expect(quantityFieldText(250, Unit.ml), '250');
      expect(quantityFieldText(2000, Unit.piece), '2');
      expect(quantityFieldText(1500, Unit.piece), '2');
      expect(quantityFieldText(1400, Unit.piece), '1');
      expect(quantityFieldText(250, Unit.piece), '1');
      expect(quantityFieldText(null, Unit.g), '');
    });

    test('saisie : g et ml entiers, pièces ×1000, vide ou 0 sans '
        'quantité', () {
      expect(quantityFromFieldText('300', Unit.g), 300);
      expect(quantityFromFieldText(' 15 ', Unit.ml), 15);
      expect(quantityFromFieldText('3', Unit.piece), 3000);
      expect(quantityFromFieldText('', Unit.g), isNull);
      expect(quantityFromFieldText('0', Unit.piece), isNull);
    });
  });

  testWidgets('prérempli, suffixe d’unité, bordure outline, 48 dp', (
    tester,
  ) async {
    final controller = TextEditingController(text: '500');
    addTearDown(controller.dispose);
    await _pump(tester, controller, Unit.g);

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
    await _pump(tester, controller, Unit.g);

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
      Unit.piece,
      onSubmitted: (v) => submitted = v,
    );
    expect(find.text(StringsFr.unitePieces), findsOneWidget);

    await tester.enterText(find.byType(TextField), '3,5-a');
    expect(controller.text, '35');
    await tester.enterText(find.byType(TextField), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, '3');
    expect(quantityFromFieldText(controller.text, Unit.piece), 3000);
  });
}
