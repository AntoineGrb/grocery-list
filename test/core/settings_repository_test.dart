import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';

import '../helpers/test_db.dart';

void main() {
  test('ordre du parcours : 13 codes, inconnus ignorés, manquants ajoutés', () {
    final order = SettingsRepository.decodeRouteOrder(
      'divers,inconnu,cremerie,divers',
    );
    expect(order.length, 13);
    expect(order.take(2), [Rayon.divers, Rayon.cremerie]);
    expect(order.toSet().length, 13);
  });

  test('les codes de rayon sont ceux d’AD-11', () {
    expect(Rayon.values.map((r) => r.code), [
      'fruits-legumes',
      'boulangerie',
      'viande-poisson',
      'cremerie',
      'epicerie-salee',
      'epicerie-sucree',
      'surgeles',
      'plats-prepares',
      'boissons',
      'hygiene',
      'entretien',
      'bebe-animaux',
      'divers',
    ]);
  });

  test('sans ligne, les réglages par défaut sont lus', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final s = await SettingsRepository(db, Clock()).read();
    expect(s.routeOrder, Rayon.values);
    expect(s.groupByRayon, isTrue);
    expect(s.keepScreenOn, isFalse);
    expect(s.firstLaunch, isFalse);
  });
}
