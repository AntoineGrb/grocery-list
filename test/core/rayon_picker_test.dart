import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:material_ui/material_ui.dart';

/// Monte un Choix de rayon qui suit la sélection, et rend les rayons
/// choisis.
Future<List<Rayon>> _pump(WidgetTester tester, Rayon initial) async {
  final chosen = <Rayon>[];
  var selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: KadiTheme.light,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => RayonPicker(
            selected: selected,
            onSelected: (r) => setState(() {
              chosen.add(r);
              selected = r;
            }),
          ),
        ),
      ),
    ),
  );
  return chosen;
}

/// Bordure de la pastille de [rayon].
Color? _borderColor(WidgetTester tester, Rayon rayon) {
  final pastille = tester.widget<RayonPastille>(
    find.byWidgetPredicate((w) => w is RayonPastille && w.rayon == rayon),
  );
  return (pastille.border as Border?)?.top.color;
}

void main() {
  testWidgets('les 13 pastilles dans l’ordre, le rayon actuel entouré, '
      'cibles de 48 dp', (tester) async {
    await _pump(tester, Rayon.viandePoisson);

    final pastilles = tester
        .widgetList<RayonPastille>(find.byType(RayonPastille))
        .map((p) => p.rayon);
    expect(pastilles, Rayon.values);
    for (final r in Rayon.values) {
      expect(find.text(r.label), findsOneWidget);
      final size = tester.getSize(find.byKey(ValueKey(r)));
      expect(size.height, greaterThanOrEqualTo(KadiSpacing.touchTarget));
      expect(size.width, greaterThanOrEqualTo(KadiSpacing.touchTarget));
    }
    expect(
      _borderColor(tester, Rayon.viandePoisson),
      KadiPalette.light.onSurface,
    );
    expect(_borderColor(tester, Rayon.platsPrepares), Colors.transparent);
  });

  testWidgets('tap : rayon choisi, la sélection suit', (tester) async {
    final chosen = await _pump(tester, Rayon.viandePoisson);

    await tester.tap(find.text(Rayon.platsPrepares.label));
    await tester.pump();

    expect(chosen, [Rayon.platsPrepares]);
    expect(
      _borderColor(tester, Rayon.platsPrepares),
      KadiPalette.light.onSurface,
    );
    expect(_borderColor(tester, Rayon.viandePoisson), Colors.transparent);
  });

  testWidgets('TalkBack : boutons lus par leur nom parlé, sélectionné ou '
      'non', (tester) async {
    final handle = tester.ensureSemantics();
    final chosen = await _pump(tester, Rayon.viandePoisson);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Viande et poisson')),
      isSemantics(
        label: 'Viande et poisson',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Plats préparés')),
      isSemantics(
        label: 'Plats préparés',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Fruits et légumes'));
    await tester.pump();
    expect(chosen, [Rayon.fruitsLegumes]);
    handle.dispose();
  });
}
