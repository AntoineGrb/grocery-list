import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';

void main() {
  test('updated_at = max(maintenant, ancien + 1)', () {
    final clock = Clock(now: () => 1000);
    expect(clock.stamp(), 1000);
    expect(clock.stamp(5000), 5001);
  });

  test('ne recule jamais, même si l’horloge système recule', () {
    var now = 1000;
    final clock = Clock(now: () => now);
    expect(clock.stamp(), 1000);
    now = 500;
    expect(clock.stamp(), 1001);
    expect(clock.stamp(), 1002);
  });
}
