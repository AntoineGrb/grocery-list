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

  test('drapeau de premier lancement : levé à l’insertion, baissé par '
      'l’horloge ; sans ligne, rien d’écrit', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    var now = 1000;
    final repo = SettingsRepository(db, Clock(now: () => now));

    await repo.setFirstLaunch(true);
    expect(await db.select(db.settings).get(), isEmpty);

    await repo.insertDefaults(seedVersions: const {}, firstLaunch: true);
    var row = await db.select(db.settings).getSingle();
    expect((row.firstLaunch, row.updatedAt), (true, 0));

    await repo.setFirstLaunch(false);
    row = await db.select(db.settings).getSingle();
    expect((row.firstLaunch, row.updatedAt), (false, 1000));
    expect((await repo.read()).firstLaunch, isFalse);

    // Déjà baissé : rien d'écrit.
    now = 2000;
    await repo.setFirstLaunch(false);
    expect((await db.select(db.settings).getSingle()).updatedAt, 1000);

    // Levé avec les seed_version, en une écriture.
    await repo.setSeedVersions(const {'recettes': 2}, raiseFirstLaunch: true);
    row = await db.select(db.settings).getSingle();
    expect((row.firstLaunch, row.updatedAt), (true, 2000));
  });
}
