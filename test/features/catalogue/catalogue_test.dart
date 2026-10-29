import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

import '../../helpers/test_db.dart';

void main() {
  group('normalizeName', () {
    test('espaces retirés, minuscules, sans accents', () {
      expect(normalizeName('  Lait '), 'lait');
      expect(normalizeName('LAIT'), 'lait');
      expect(normalizeName('lâit'), 'lait');
      expect(normalizeName('Œufs'), 'oeufs');
      expect(normalizeName('Crème fraîche'), 'cremefraiche');
      expect(normalizeName('Épicerie'), 'epicerie');
    });
  });

  group('CatalogueRepository.watchSearch', () {
    late AppDatabase db;
    late CatalogueRepository repo;

    setUp(() async {
      db = await seededDatabase();
      repo = CatalogueRepository(db);
    });
    tearDown(() => db.close());

    for (final query in ['lait', 'LAIT', 'lâit']) {
      test('« $query » trouve Lait, Crèmerie, en premier', () async {
        final hits = await repo.watchSearch(query).first;
        expect(hits.first.name, 'Lait');
        expect(hits.first.rayon, Rayon.cremerie);
        expect(hits.first.pictoKey, 'lait');
      });
    }

    test('« oeufs » trouve Œufs', () async {
      final hits = await repo.watchSearch('oeufs').first;
      expect(hits.map((a) => a.name), ['Œufs']);
    });

    for (final query in ['', '   ', 'kumquat']) {
      test('« $query » : aucun résultat', () async {
        expect(await repo.watchSearch(query).first, isEmpty);
      });
    }

    test('un article supprimé ne sort pas', () async {
      await (db.update(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lait))).write(
        const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
      );
      final hits = await repo.watchSearch('lait').first;
      expect(hits.map((a) => a.id), isNot(contains(SeedIds.lait)));
    });

    test('début de nom en premier', () async {
      // « o » : Oignons et Œufs commencent par o, Tomates le contient.
      final names = (await repo.watchSearch('o').first)
          .map((a) => a.name)
          .toList();
      final starts = names.where((n) => normalizeName(n).startsWith('o'));
      expect(names.take(starts.length), starts);
      expect(starts, containsAll(['Oignons', 'Œufs']));
      expect(names.skip(starts.length), contains('Tomates'));
    });

    for (final (query, name, rayon) in [
      ('cou', 'Courgettes', Rayon.fruitsLegumes),
      ('beurre', 'Beurre', Rayon.cremerie),
      ('baguette', 'Baguettes', Rayon.boulangerie),
      ('jambon', 'Jambon', Rayon.viandePoisson),
      ('papier', 'Papier toilette', Rayon.hygiene),
      ('pates', 'Pâtes', Rayon.epicerieSalee),
      ('cafe', 'Café', Rayon.epicerieSucree),
      ('frites', 'Frites', Rayon.surgeles),
      ('quiche', 'Quiche', Rayon.platsPrepares),
      ('eau plate', 'Eau plate', Rayon.boissons),
      ('lessive', 'Lessive', Rayon.entretien),
      ('couches', 'Couches', Rayon.bebeAnimaux),
      ('piles', 'Piles', Rayon.divers),
    ]) {
      test('« $query » trouve $name, ${rayon.code}', () async {
        final hits = await repo.watchSearch(query).first;
        final hit = hits.singleWhere((a) => a.name == name);
        expect(hit.rayon, rayon);
      });
    }

    test('« cou » : Courgettes parmi d’autres articles', () async {
      final hits = await repo.watchSearch('cou').first;
      expect(hits.length, greaterThan(1));
    });
  });

  group('CatalogueRepository.watchFrequents (AD-2)', () {
    late AppDatabase db;
    late CatalogueRepository repo;

    setUp(() async {
      db = await seededDatabase();
      repo = CatalogueRepository(db);
    });
    tearDown(() => db.close());

    /// Ids des articles fréquents, dans l'ordre de `position`.
    Future<List<String>> byPosition() async {
      final rows = await (db.select(
        db.frequents,
      )..orderBy([(f) => OrderingTerm.asc(f.position)])).get();
      return [for (final f in rows) f.articleId];
    }

    test('contenu fourni : 31 fréquents, par position', () async {
      final frequents = await repo.watchFrequents().first;
      expect(frequents, hasLength(31));
      expect(frequents.map((a) => a.id), await byPosition());
      final lait = frequents.singleWhere((a) => a.id == SeedIds.lait);
      expect(lait.name, 'Lait');
      expect(lait.rayon, Rayon.cremerie);
    });

    test('un fréquent dont l’article est supprimé et un fréquent supprimé : '
        'exclus, les autres par position', () async {
      final expected = (await byPosition())
        ..remove(SeedIds.lait)
        ..remove(SeedIds.tomates);
      await (db.update(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lait))).write(
        const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
      );
      await (db.update(
        db.frequents,
      )..where((f) => f.id.equals(frequentId(SeedIds.tomates)))).write(
        const FrequentsCompanion(deletedAt: Value(1), updatedAt: Value(1)),
      );

      final frequents = await repo.watchFrequents().first;
      expect(frequents.map((a) => a.id), expected);
      expect(frequents, hasLength(29));
    });

    test('tous les fréquents supprimés : aucun', () async {
      await db
          .update(db.frequents)
          .write(
            const FrequentsCompanion(deletedAt: Value(1), updatedAt: Value(1)),
          );
      expect(await repo.watchFrequents().first, isEmpty);
    });
  });
}
