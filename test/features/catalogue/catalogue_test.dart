import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
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
      test('« $query » trouve Lait, Crèmerie', () async {
        final hits = await repo.watchSearch(query).first;
        expect(hits.map((a) => a.name), ['Lait']);
        expect(hits.single.rayon, Rayon.cremerie);
        expect(hits.single.pictoKey, 'lait');
      });
    }

    test('« oeufs » trouve Œufs', () async {
      final hits = await repo.watchSearch('oeufs').first;
      expect(hits.map((a) => a.name), ['Œufs']);
    });

    for (final query in ['', '   ', 'pesto']) {
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
      expect(await repo.watchSearch('lait').first, isEmpty);
    });

    test('début de nom en premier', () async {
      // « o » : Oignons et Œufs commencent par o, Tomates le contient.
      final hits = await repo.watchSearch('o').first;
      expect(hits.take(2).map((a) => a.name).toSet(), {'Oignons', 'Œufs'});
    });
  });
}
