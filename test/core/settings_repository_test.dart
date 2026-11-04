import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
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

  group('setters des Paramètres', () {
    late AppDatabase db;
    late SettingsRepository repo;
    var now = 0;

    setUp(() async {
      db = memoryDatabase();
      now = 1000;
      repo = SettingsRepository(db, Clock(now: () => now));
      await repo.insertDefaults(seedVersions: const {});
    });
    tearDown(() => db.close());

    Future<SettingsRow> row() => db.select(db.settings).getSingle();

    test(
      'Écran allumé : écrit, horodaté ; valeur égale, rien d’écrit',
      () async {
        await repo.setKeepScreenOn(true);
        var r = await row();
        expect((r.keepScreenOn, r.updatedAt), (true, 1000));
        expect((await repo.read()).keepScreenOn, isTrue);

        now = 2000;
        await repo.setKeepScreenOn(true);
        expect((await row()).updatedAt, 1000);

        // L'horloge recule : updated_at avance quand même (AD-7).
        now = 500;
        await repo.setKeepScreenOn(false);
        r = await row();
        expect((r.keepScreenOn, r.updatedAt), (false, 1001));
      },
    );

    test('Grouper par rayon : écrit, horodaté ; valeur égale, rien '
        'd’écrit', () async {
      await repo.setGroupByRayon(true);
      expect((await row()).updatedAt, 0);

      await repo.setGroupByRayon(false);
      var r = await row();
      expect((r.groupByRayon, r.updatedAt), (false, 1000));
      expect((await repo.read()).groupByRayon, isFalse);

      now = 3000;
      await repo.setGroupByRayon(true);
      r = await row();
      expect((r.groupByRayon, r.updatedAt), (true, 3000));
    });

    test(
      'ordre du parcours : écrit, horodaté ; ordre égal, rien d’écrit',
      () async {
        await repo.setRouteOrder(Rayon.values);
        expect((await row()).updatedAt, 0);

        final reversed = Rayon.values.reversed.toList();
        await repo.setRouteOrder(reversed);
        final r = await row();
        expect(r.updatedAt, 1000);
        expect((await repo.read()).routeOrder, reversed);

        now = 2000;
        await repo.setRouteOrder(reversed);
        expect((await row()).updatedAt, 1000);
      },
    );

    test('ordre du parcours : 12 rayons ou un doublon refusés, rien '
        'd’écrit', () async {
      expect(
        () => repo.setRouteOrder(Rayon.values.skip(1).toList()),
        throwsArgumentError,
      );
      expect(
        () => repo.setRouteOrder([Rayon.divers, ...Rayon.values.skip(1)]),
        throwsArgumentError,
      );
      final r = await row();
      expect(r.updatedAt, 0);
      expect((await repo.read()).routeOrder, Rayon.values);
    });

    test('sans ligne de réglages, rien d’écrit', () async {
      final empty = memoryDatabase();
      addTearDown(empty.close);
      final r = SettingsRepository(empty, Clock());
      await r.setKeepScreenOn(true);
      await r.setGroupByRayon(false);
      await r.setRouteOrder(Rayon.values.reversed.toList());
      expect(await empty.select(empty.settings).get(), isEmpty);
    });
  });
}
