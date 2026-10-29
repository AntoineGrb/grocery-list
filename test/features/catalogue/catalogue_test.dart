import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
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
      repo = CatalogueRepository(db, Clock());
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
      repo = CatalogueRepository(db, Clock());
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

  group('création d’un article (AD-17)', () {
    late AppDatabase db;
    late Clock clock;
    late CatalogueRepository repo;
    var now = 1000;

    /// Id de l'article Piles fourni.
    const pilesId = '647841c6-7cff-40f4-a8dd-69d7e781eb8b';

    setUp(() async {
      db = await seededDatabase();
      now = 1000;
      clock = Clock(now: () => now);
      repo = CatalogueRepository(db, clock);
      // « piles » absent du catalogue : l'article fourni est supprimé.
      await (db.update(db.articles)..where((a) => a.id.equals(pilesId))).write(
        const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
      );
    });
    tearDown(() => db.close());

    Future<List<Article>> activeNamed(String normalized) =>
        (db.select(db.articles)..where(
              (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
            ))
            .get();

    for (final query in ['LAIT', 'lait', ' lâit ']) {
      test(
        'correspondance exacte : « $query » trouve Lait, pas de Créer',
        () async {
          final hits = await repo.watchSearch(query).first;
          expect(hits.first.id, SeedIds.lait);
          expect(CatalogueRepository.hasExactMatch(hits, query), isTrue);
        },
      );
    }

    test(
      'sans correspondance exacte : « lai » trouve Lait, Créer proposé',
      () async {
        final hits = await repo.watchSearch('lai').first;
        expect(hits.map((a) => a.id), contains(SeedIds.lait));
        expect(CatalogueRepository.hasExactMatch(hits, 'lai'), isFalse);
      },
    );

    test('aucun résultat : « piles » (supprimé) et « zzz »', () async {
      for (final query in ['piles', 'zzz']) {
        final hits = await repo.watchSearch(query).first;
        expect(hits, isEmpty);
        expect(CatalogueRepository.hasExactMatch(hits, query), isFalse);
      }
    });

    test('créer « piles » : Piles, normalisé piles, Divers, sans unité, '
        'picto piles, UUID v4, updated_at de l’horloge', () async {
      final article = await db.transaction(() => repo.createArticle('piles'));

      expect(article.name, 'Piles');
      expect(article.rayon, Rayon.divers);
      expect(article.unit, isNull);
      expect(article.pictoKey, 'piles');
      expect(article.id, isNot(pilesId));
      expect(
        article.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );

      final row = (await activeNamed('piles')).single;
      expect(row.id, article.id);
      expect(row.name, 'Piles');
      expect(row.normalizedName, 'piles');
      expect(row.rayon, 'divers');
      expect(row.unit, isNull);
      expect(row.pictoKey, 'piles');
      expect(row.updatedAt, 1000);
      expect(row.deletedAt, isNull);

      // Trouvé ensuite par la recherche, en correspondance exacte.
      final hits = await repo.watchSearch('piles').first;
      expect(hits.single.id, article.id);
      expect(CatalogueRepository.hasExactMatch(hits, 'Piles'), isTrue);
    });

    test('nom nettoyé : espaces de bord et doublés retirés, majuscule '
        'initiale ; clé de picto en [a-z0-9]', () async {
      final article = await repo.createArticle('  œufs   de   caille ');
      expect(article.name, 'Œufs de caille');
      expect(article.pictoKey, 'oeufsdecaille');
      final row = (await activeNamed('oeufsdecaille')).single;
      expect(row.name, 'Œufs de caille');

      final symbols = await repo.createArticle('%%');
      expect(symbols.name, '%%');
      expect(symbols.pictoKey, 'article');
    });

    test('rayon et unité explicites : écrits tels quels', () async {
      final article = await repo.createArticle(
        'piles',
        rayon: Rayon.entretien,
        unit: Unit.piece,
      );
      expect(article.rayon, Rayon.entretien);
      expect(article.unit, Unit.piece);
      final row = (await activeNamed('piles')).single;
      expect(row.rayon, 'entretien');
      expect(row.unit, 'piece');
    });

    test('nom vide : refusé, rien n’est écrit', () async {
      final before = await db.select(db.articles).get();
      await expectLater(repo.createArticle('   '), throwsArgumentError);
      expect(await db.select(db.articles).get(), before);
    });

    for (final name in ['Lait', 'lait', 'LÂIT ']) {
      test(
        'nom déjà pris (« $name ») : aucun nouvel article, Lait rendu',
        () async {
          final before = await db.select(db.articles).get();
          final article = await repo.createArticle(name);
          expect(article.id, SeedIds.lait);
          expect(article.name, 'Lait');
          expect(article.rayon, Rayon.cremerie);
          expect(await db.select(db.articles).get(), before);
          expect(clock.last, 0);
        },
      );
    }

    test('créer deux fois : un seul article actif', () async {
      final first = await repo.createArticle('piles');
      final second = await repo.createArticle('PILES');
      expect(second.id, first.id);
      expect(await activeNamed('piles'), hasLength(1));
    });

    test('rayon d’un article : rayon et updated_at changent ; même rayon ou '
        'article supprimé : rien n’est écrit', () async {
      final piles = await repo.createArticle('piles');
      now = 2000;
      await repo.setArticleRayon(piles.id, Rayon.entretien);
      var row = (await activeNamed('piles')).single;
      expect(row.rayon, 'entretien');
      expect(row.updatedAt, 2000);

      now = 3000;
      await repo.setArticleRayon(piles.id, Rayon.entretien);
      await repo.setArticleRayon(pilesId, Rayon.hygiene);
      row = (await activeNamed('piles')).single;
      expect(row.updatedAt, 2000);
      final seeded = await (db.select(
        db.articles,
      )..where((a) => a.id.equals(pilesId))).getSingle();
      expect(seeded.rayon, 'divers');
    });
  });
}
