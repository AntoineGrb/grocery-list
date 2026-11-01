import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/features/liste/ui/row_highlight.dart';
import 'package:material_ui/material_ui.dart';

const _color = Color(0xFF123456);

Widget _app(RowHighlight highlight, {bool disableAnimations = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topCenter, child: highlight),
      ),
    );

RowHighlight _highlight({bool arriving = false, int replays = 0}) =>
    RowHighlight(
      color: _color,
      arriving: arriving,
      replays: replays,
      child: const SizedBox(height: 48),
    );

double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

Offset _slide(WidgetTester tester) =>
    tester.widget<SlideTransition>(find.byType(SlideTransition)).position.value;

double _background(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byType(ColoredBox)).color.a;

void main() {
  testWidgets('sans arrivée : rien ne s’anime, aucun fond', (tester) async {
    await tester.pumpWidget(_app(_highlight()));

    expect(tester.hasRunningAnimations, isFalse);
    expect(_opacity(tester), 1);
    expect(_slide(tester), Offset.zero);
    expect(_background(tester), 0);
  });

  testWidgets('arrivée : fondu et glissement, fond plein qui s’efface sur '
      'environ 1,2 s, sans changer la hauteur', (tester) async {
    await tester.pumpWidget(_app(_highlight(arriving: true)));

    expect(_opacity(tester), 0);
    expect(_slide(tester).dy, greaterThan(0));
    expect(_background(tester), 1);
    expect(tester.getSize(find.byType(RowHighlight)).height, 48);

    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester), 1);
    expect(_slide(tester), Offset.zero);
    expect(_background(tester), 1);

    await tester.pump(const Duration(milliseconds: 500));
    expect(_background(tester), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 450));
    expect(_background(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('compteur qui change : le surlignage seul, rejouable', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_highlight()));

    for (final replays in [1, 2]) {
      await tester.pumpWidget(_app(_highlight(replays: replays)));
      expect(_background(tester), 1);
      expect(_opacity(tester), 1);
      expect(_slide(tester), Offset.zero);
      await tester.pumpAndSettle();
      expect(_background(tester), 0);
    }
  });

  testWidgets('même compteur : rien ne se rejoue', (tester) async {
    await tester.pumpWidget(_app(_highlight(replays: 1)));
    await tester.pumpWidget(_app(_highlight(replays: 1)));

    expect(tester.hasRunningAnimations, isFalse);
    expect(_background(tester), 0);
  });

  testWidgets('animations coupées : ni fondu ni surlignage', (tester) async {
    await tester.pumpWidget(
      _app(_highlight(arriving: true), disableAnimations: true),
    );

    expect(tester.hasRunningAnimations, isFalse);
    expect(_opacity(tester), 1);
    expect(_slide(tester), Offset.zero);
    expect(_background(tester), 0);

    await tester.pumpWidget(
      _app(_highlight(replays: 1), disableAnimations: true),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(_background(tester), 0);
  });
}
