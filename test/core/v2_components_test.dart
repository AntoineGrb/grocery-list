import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/ui/quantity_sheet.dart';
import 'package:kadi/core/ui/quantity_tag.dart';
import 'package:kadi/core/ui/rayon_menu.dart';
import 'package:kadi/core/ui/recipe_monogram.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

/// Monte [child] sous le thème clair de Kadi.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: KadiTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('recipeInitials', () {
    test('plusieurs mots : 2e mot significatif en minuscule', () {
      expect(recipeInitials('Chili con carne'), 'Cc');
      expect(recipeInitials('Pâtes carbonara'), 'Pc');
      expect(recipeInitials('Quiche lorraine'), 'Ql');
      expect(recipeInitials('Curry de lentilles'), 'Cl');
      expect(recipeInitials('Saumon au four'), 'Sf');
      expect(recipeInitials('Gratin d’aubergines'), 'Ga');
    });

    test('un seul mot : ses 2 premières lettres', () {
      expect(recipeInitials('Ratatouille'), 'Ra');
      expect(recipeInitials('  œufs  '), 'Œu');
    });

    test('mots vides seuls ou nom vide', () {
      expect(recipeInitials('Pâtes à la'), 'Pâ');
      expect(recipeInitials(''), '');
      expect(recipeInitials('  '), '');
    });
  });

  group('QuantityStepper', () {
    test('pas : 50 en g, 1 en pièce, 0,5 en kg ; jamais sous 0', () {
      final g = QuantityStepper(unit: InputUnit.g)..increment();
      expect(g.value, (quantity: 50, unit: Unit.g));
      final p = QuantityStepper(unit: InputUnit.piece)
        ..increment()
        ..increment();
      expect(p.value, (quantity: 2000, unit: Unit.piece));
      expect(p.unitLabel, StringsFr.unitePieces);
      final kg = QuantityStepper(unit: InputUnit.kg)
        ..increment()
        ..increment()
        ..increment();
      expect(kg.numberLabel, '1,5');
      expect(kg.value, (quantity: 1500, unit: Unit.g));
      kg
        ..decrement()
        ..decrement()
        ..decrement()
        ..decrement();
      expect(kg.milli, 0);
      expect(kg.value, isNull);
    });

    test('préchargé depuis la quantité stockée, dans son unité', () {
      final q = QuantityStepper.of(1500, Unit.g, initialUnit: InputUnit.piece);
      expect(q.unit, InputUnit.g);
      expect(q.numberLabel, '1500');
      final empty = QuantityStepper.of(null, null, initialUnit: InputUnit.ml);
      expect(empty.unit, InputUnit.ml);
      expect(empty.milli, 0);
    });

    test('changer d’unité remet le nombre à 0', () {
      final q = QuantityStepper(unit: InputUnit.g, milli: 250000)
        ..selectUnit(InputUnit.kg);
      expect(q.milli, 0);
      expect(q.unit, InputUnit.kg);
    });

    test('saisie libre et valeurs rapides', () {
      final q = QuantityStepper(unit: InputUnit.l)..setText('0,75');
      expect(q.value, (quantity: 750, unit: Unit.ml));
      expect(QuantityStepper.pickLabel(InputUnit.piece, 1000), '1 pièce');
      expect(QuantityStepper.pickLabel(InputUnit.piece, 6000), '6 pièces');
      expect(QuantityStepper.pickLabel(InputUnit.kg, 500), '0,5 kg');
    });
  });

  group('Module quantité', () {
    Future<List<QuantityEdit?>> open(
      WidgetTester tester, {
      int? quantity,
      Unit? unit,
    }) async {
      final results = <QuantityEdit?>[];
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showQuantitySheet(
                context,
                title: 'Oignons',
                leading: const SizedBox.square(dimension: 24),
                quantity: quantity,
                unit: unit,
                initialUnit: InputUnit.piece,
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('+ puis OK écrit la quantité', (tester) async {
      final results = await open(tester);
      expect(find.text('Oignons'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(StringsFr.plus));
      await tester.tap(find.bySemanticsLabel(StringsFr.plus));
      await tester.pump();
      expect(find.text('2'), findsWidgets);
      await tester.tap(find.text(StringsFr.ok));
      await tester.pumpAndSettle();
      expect(results.single?.value, (quantity: 2000, unit: Unit.piece));
    });

    testWidgets('une valeur rapide puis OK', (tester) async {
      final results = await open(tester);
      await tester.tap(find.bySemanticsLabel(StringsFr.uniteDe('g')));
      await tester.pump();
      await tester.tap(find.text('250 g'));
      await tester.tap(find.text(StringsFr.ok));
      await tester.pumpAndSettle();
      expect(results.single?.value, (quantity: 250, unit: Unit.g));
    });

    testWidgets('0 puis OK efface la quantité', (tester) async {
      final results = await open(tester, quantity: 1000, unit: Unit.piece);
      await tester.tap(find.bySemanticsLabel(StringsFr.moins));
      await tester.tap(find.text(StringsFr.ok));
      await tester.pumpAndSettle();
      expect(results.single, isNotNull);
      expect(results.single!.value, isNull);
    });

    testWidgets('le voile ferme sans rien écrire', (tester) async {
      final results = await open(tester, quantity: 1000, unit: Unit.piece);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(results.single, isNull);
    });

    testWidgets('tap sur le nombre : saisie libre au clavier', (tester) async {
      final results = await open(tester);
      await tester.tap(find.byKey(const Key('quantity-sheet-number')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('quantity-sheet-input')),
        '4',
      );
      await tester.tap(find.text(StringsFr.ok));
      await tester.pumpAndSettle();
      expect(results.single?.value, (quantity: 4000, unit: Unit.piece));
    });
  });

  testWidgets('tag quantité : valeur ou balance, lu par TalkBack', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuantityTag(
            name: 'Tomates',
            rayon: Rayon.fruitsLegumes,
            quantity: 500,
            unit: Unit.g,
            onTap: () => taps++,
          ),
          QuantityTag(
            name: 'Poivrons',
            rayon: Rayon.fruitsLegumes,
            quantity: null,
            unit: null,
            onTap: () => taps++,
          ),
        ],
      ),
    );
    expect(find.text(formatQuantity(500, Unit.g)), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel(StringsFr.ajouterUneQuantiteA('Poivrons')),
    );
    await tester.tap(
      find.bySemanticsLabel(
        StringsFr.quantiteDe('Tomates', formatQuantity(500, Unit.g)),
      ),
    );
    expect(taps, 2);
  });

  testWidgets('menu des rayons : ordre donné, ✓ sur le courant', (
    tester,
  ) async {
    final controller = MenuController();
    Rayon? picked;
    await _pump(
      tester,
      RayonMenuAnchor(
        controller: controller,
        route: const [Rayon.boissons, Rayon.divers, Rayon.cremerie],
        current: Rayon.divers,
        onSelected: (r) => picked = r,
        width: 280,
        child: TextButton(
          onPressed: controller.open,
          child: const Text('rayon'),
        ),
      ),
    );
    await tester.tap(find.text('rayon'));
    await tester.pumpAndSettle();
    final labels = [
      for (final r in [Rayon.boissons, Rayon.divers, Rayon.cremerie])
        tester.getTopLeft(find.text(r.label)).dy,
    ];
    expect(labels, orderedEquals([...labels]..sort()));
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text(Rayon.cremerie.label));
    await tester.pumpAndSettle();
    expect(picked, Rayon.cremerie);
  });

  testWidgets('monogramme : initiales, neutre sans rayon', (tester) async {
    await _pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RecipeMonogram(name: 'Chili con carne', rayon: Rayon.viandePoisson),
          RecipeMonogram(name: '', rayon: null, size: MonogramSize.large),
        ],
      ),
    );
    expect(find.text('Cc'), findsOneWidget);
  });
}
