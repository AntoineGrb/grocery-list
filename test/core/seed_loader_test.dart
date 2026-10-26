import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

import '../helpers/test_db.dart';

Map<String, Object?> _article(String id, String name, String rayon) => {
  'id': id,
  'name': name,
  'rayon': rayon,
  'unit': 'g',
  'picto_key': 'x',
};

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test(
    'premier démarrage : 7 articles et réglages par défaut à updated_at 0',
    () async {
      await seedLoader(db).run();

      final articles = await db.select(db.articles).get();
      expect(articles.map((a) => a.name).toSet(), {
        'Lait',
        'Œufs',
        'Tomates',
        'Courgettes',
        'Oignons',
        'Riz',
        'Lardons',
      });
      expect(articles.every((a) => a.updatedAt == 0), isTrue);
      expect(articles.every((a) => a.deletedAt == null), isTrue);
      for (final a in articles) {
        expect(a.normalizedName, normalizeName(a.name));
      }
      final lait = articles.singleWhere((a) => a.id == SeedIds.lait);
      expect(
        (lait.rayon, lait.unit, lait.pictoKey),
        ('cremerie', 'piece', 'lait'),
      );

      final settings = await db.select(db.settings).getSingle();
      expect(settings.id, SettingsRepository.rowId);
      expect(settings.updatedAt, 0);
      expect(settings.routeOrder.split(',').length, 13);
      expect(jsonDecode(settings.seedVersions), {'articles': 1});
    },
  );

  test('les UUID fournis sont des v4 distincts', () async {
    final json = jsonDecode(
      await diskAssetLoader('assets/seed/articles.json'),
    ) as Map<String, dynamic>;
    final ids = [
      for (final a in json['articles'] as List) (a as Map)['id'] as String,
    ];
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(ids.every(v4.hasMatch), isTrue);
    expect(ids.toSet().length, ids.length);
  });

  test('redémarrage : rien inséré ni modifié, supprimés compris', () async {
    await seedLoader(db).run();
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).write(
      const ArticlesCompanion(
        name: Value('Lait demi-écrémé'),
        updatedAt: Value(10),
      ),
    );
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.riz))).write(
      const ArticlesCompanion(deletedAt: Value(20), updatedAt: Value(20)),
    );
    final before = await db.select(db.articles).get();
    final settingsBefore = await db.select(db.settings).getSingle();

    await seedLoader(db).run();

    expect(await db.select(db.articles).get(), before);
    expect(await db.select(db.settings).getSingle(), settingsBefore);
  });

  test(
    'nouvelle version : insère les seuls UUID absents, sans mise à jour',
    () async {
      await seedLoader(db).run();
      await (db.update(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lait))).write(
        const ArticlesCompanion(
          name: Value('Lait entier'),
          updatedAt: Value(10),
        ),
      );

      final v2 = jsonEncode({
        'seed_version': 2,
        'articles': [
          _article(SeedIds.lait, 'Lait', 'cremerie'),
          _article(
            '7d1c2f0e-3b8a-4c5d-9e6f-0a1b2c3d4e5f',
            'Pâtes',
            'epicerie-salee',
          ),
        ],
      });
      await seedLoader(
        db,
        clock: Clock(now: () => 5000),
        loadAsset: (_) async => v2,
      ).run();

      final articles = await db.select(db.articles).get();
      expect(articles.length, 8);
      expect(
        articles.singleWhere((a) => a.id == SeedIds.lait).name,
        'Lait entier',
      );
      final settings = await db.select(db.settings).getSingle();
      expect(jsonDecode(settings.seedVersions), {'articles': 2});
      expect(settings.updatedAt, 5000);
    },
  );

  test('fichier invalide : erreur et rien d’écrit', () async {
    final bad = jsonEncode({
      'seed_version': 1,
      'articles': [
        _article(SeedIds.lait, 'Lait', 'cremerie'),
        _article(SeedIds.riz, 'Riz', 'rayon-inconnu'),
      ],
    });
    await expectLater(
      seedLoader(db, loadAsset: (_) async => bad).run(),
      throwsFormatException,
    );
    expect(await db.select(db.articles).get(), isEmpty);
    expect(await db.select(db.settings).get(), isEmpty);
  });

  test('échec pendant l’écriture : la transaction est annulée', () async {
    // Les articles s'insèrent, puis l'insertion des réglages échoue.
    await db.customStatement(
      'CREATE TRIGGER boom BEFORE INSERT ON settings '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    await expectLater(seedLoader(db).run(), throwsA(anything));
    expect(await db.select(db.articles).get(), isEmpty);
  });
}
