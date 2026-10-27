import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/units/unit.dart';

/// Espace insécable entre le nombre et l'unité.
String _q(String s) => s.replaceAll(' ', ' ');

void main() {
  group('formatQuantity (AD-6)', () {
    final cases = <(int?, Unit?, String)>[
      // Sans quantité.
      (null, null, ''),
      (0, Unit.g, ''),
      (null, Unit.g, ''),
      (300, null, ''),
      // Grammes.
      (300, Unit.g, '300 g'),
      (500, Unit.g, '500 g'),
      (999, Unit.g, '999 g'),
      (1000, Unit.g, '1 kg'),
      (1500, Unit.g, '1,5 kg'),
      (1234, Unit.g, '1,23 kg'),
      (1205, Unit.g, '1,21 kg'),
      (1999, Unit.g, '2 kg'),
      (12000, Unit.g, '12 kg'),
      // Millilitres.
      (200, Unit.ml, '20 cl'),
      (250, Unit.ml, '25 cl'),
      (400, Unit.ml, '40 cl'),
      (15, Unit.ml, '15 ml'),
      (995, Unit.ml, '995 ml'),
      (1000, Unit.ml, '1 l'),
      (1500, Unit.ml, '1,5 l'),
      (2250, Unit.ml, '2,25 l'),
      // Pièces, en millièmes.
      (1000, Unit.piece, '1 pièce'),
      (2000, Unit.piece, '2 pièces'),
      (6000, Unit.piece, '6 pièces'),
      (500, Unit.piece, '½ pièce'),
      (250, Unit.piece, '¼ pièce'),
      (750, Unit.piece, '¾ pièce'),
      (1500, Unit.piece, '1 ½ pièce'),
      (2500, Unit.piece, '2 ½ pièces'),
      (1333, Unit.piece, '1,33 pièce'),
      (2100, Unit.piece, '2,1 pièces'),
    ];

    for (final (quantity, unit, expected) in cases) {
      test('$quantity ${unit?.code} → « $expected »', () {
        expect(formatQuantity(quantity, unit), _q(expected));
      });
    }

    test('espace insécable entre le nombre et l’unité', () {
      expect(formatQuantity(500, Unit.g), '500 g');
    });
  });

  test('unitKey : l’unité, ou « - » sans quantité', () {
    expect(unitKey(Unit.g), 'g');
    expect(unitKey(Unit.piece), 'piece');
    expect(unitKey(null), '-');
  });
}
