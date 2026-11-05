import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';

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
      test('« $query » trouve Lait en premier', () async {
        final hits = await repo.watchSearch(query).first;
        expect(hits.first.id, SeedIds.lait);
      });
    }

    test('aucun résultat : « piles » (supprimé) et « zzz »', () async {
      for (final query in ['piles', 'zzz']) {
        expect(await repo.watchSearch(query).first, isEmpty);
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

      expect(row.inCatalogue, isTrue);

      // Trouvé ensuite par la recherche.
      final hits = await repo.watchSearch('piles').first;
      expect(hits.single.id, article.id);
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

    test(
      'texte tapé inconnu : article hors catalogue Piles (Divers, sans '
      'unité, picto de repli « article », UUID v4), jamais dans la recherche',
      () async {
        final article = await repo.resolveTypedArticle('  piles ');

        expect(article.name, 'Piles');
        expect(article.rayon, Rayon.divers);
        expect(article.unit, isNull);
        expect(article.pictoKey, 'article');
        final row = (await activeNamed('piles')).single;
        expect(row.id, article.id);
        expect(row.inCatalogue, isFalse);
        expect(row.rayon, 'divers');
        expect(row.unit, isNull);
        expect(row.updatedAt, 1000);

        for (final query in ['pil', 'piles', 'PILES']) {
          expect(await repo.watchSearch(query).first, isEmpty);
        }
        // findByName le trouve : un nom reste unique (AD-17).
        expect((await repo.findByName('Piles'))?.id, article.id);
      },
    );

    test(
      'texte tapé du catalogue : « LAIT » rend Lait, rien n’est écrit',
      () async {
        final before = await db.select(db.articles).get();
        final article = await repo.resolveTypedArticle('LÂIT');
        expect(article.id, SeedIds.lait);
        expect(article.rayon, Rayon.cremerie);
        expect(await db.select(db.articles).get(), before);
        expect(clock.last, 0);
      },
    );

    test('texte tapé réutilisé : un seul article hors catalogue', () async {
      final first = await repo.resolveTypedArticle('piles');
      final second = await repo.resolveTypedArticle('Piles');
      expect(second.id, first.id);
      expect(await activeNamed('piles'), hasLength(1));
    });

    test('texte tapé vide : refusé, rien n’est écrit', () async {
      final before = await db.select(db.articles).get();
      await expectLater(repo.resolveTypedArticle('  '), throwsArgumentError);
      expect(await db.select(db.articles).get(), before);
    });

    test('créer un nom hors catalogue : l’article entre au catalogue, même '
        'id, rayon et unité inchangés', () async {
      final typed = await repo.resolveTypedArticle('piles');
      now = 2000;

      final created = await repo.createArticle(
        'PILES',
        rayon: Rayon.entretien,
        unit: Unit.piece,
      );

      expect(created.id, typed.id);
      final row = (await activeNamed('piles')).single;
      expect(row.id, typed.id);
      expect(row.inCatalogue, isTrue);
      expect(row.updatedAt, 2000);
      expect(row.rayon, 'divers');
      expect(row.unit, isNull);
      expect((await repo.watchSearch('pil').first).single.id, typed.id);
    });

    test('rayon d’un article : rayon et updated_at changent ; même rayon : '
        'rien n’est écrit ; article supprimé : refusé', () async {
      final piles = await repo.createArticle('piles');
      now = 2000;
      await repo.updateArticle(
        piles.id,
        name: piles.name,
        rayon: Rayon.entretien,
        unit: piles.unit,
      );
      var row = (await activeNamed('piles')).single;
      expect(row.rayon, 'entretien');
      expect(row.updatedAt, 2000);

      now = 3000;
      await repo.updateArticle(
        piles.id,
        name: piles.name,
        rayon: Rayon.entretien,
        unit: piles.unit,
      );
      await expectLater(
        repo.updateArticle(
          pilesId,
          name: 'Piles',
          rayon: Rayon.hygiene,
          unit: null,
        ),
        throwsStateError,
      );
      row = (await activeNamed('piles')).single;
      expect(row.updatedAt, 2000);
      final seeded = await (db.select(
        db.articles,
      )..where((a) => a.id.equals(pilesId))).getSingle();
      expect(seeded.rayon, 'divers');
    });
  });

  group('Paramètres › Articles : chercher, créer, modifier (AD-15, AD-17)', () {
    late AppDatabase db;
    late Clock clock;
    late CatalogueRepository repo;
    late ListeRepository liste;
    var now = 1000;

    setUp(() async {
      db = await seededDatabase();
      now = 1000;
      clock = Clock(now: () => now);
      repo = CatalogueRepository(db, clock);
      liste = ListeRepository(db, clock);
    });
    tearDown(() => db.close());

    Future<Article> article(String id) =>
        (db.select(db.articles)..where((a) => a.id.equals(id))).getSingle();

    Future<List<Article>> activeNamed(String normalized) =>
        (db.select(db.articles)..where(
              (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
            ))
            .get();

    Future<Frequent> frequentOf(String articleId) => (db.select(
      db.frequents,
    )..where((f) => f.id.equals(frequentId(articleId)))).getSingle();

    Future<ListLine> line(String id) =>
        (db.select(db.listLines)..where((l) => l.id.equals(id))).getSingle();

    test('catalogue entier : articles actifs du catalogue par ordre '
        'alphabétique du nom normalisé ; hors catalogue et supprimés '
        'exclus', () async {
      final typed = await repo.resolveTypedArticle('Physalis');
      await (db.update(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.riz))).write(
        const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
      );

      final all = await repo.watchCatalogue().first;
      final expected =
          (await (db.select(db.articles)..where(
                    (a) => a.deletedAt.isNull() & a.inCatalogue.equals(true),
                  ))
                  .get())
              .map((a) => a.normalizedName)
              .toList()
            ..sort();
      expect(all.map((a) => normalizeName(a.name)), expected);
      expect(all.map((a) => a.id), isNot(contains(typed.id)));
      expect(all.map((a) => a.id), isNot(contains(SeedIds.riz)));
      expect(all.map((a) => a.id), contains(SeedIds.tomates));
    });

    test('recherche « tom » : Tomates, Fruits & légumes', () async {
      final hits = await repo.watchSearch('tom').first;
      final tomates = hits.singleWhere((a) => a.id == SeedIds.tomates);
      expect(tomates.rayon, Rayon.fruitsLegumes);
      expect(hits.every((a) => normalizeName(a.name).contains('tom')), isTrue);
    });

    test('modifier Tomates en Épicerie salée et ml : l’article change, '
        'picto inchangé ; la ligne et l’ingrédient existants ne bougent '
        'pas ; un nouvel ajout prend le nouveau rayon', () async {
      final ingredientsBefore = await (db.select(
        db.recipeIngredients,
      )..where((i) => i.articleId.equals(SeedIds.tomates))).get();
      expect(ingredientsBefore, isNotEmpty);
      final old = await liste.addArticle(SeedIds.tomates);
      // Cochée, elle n'est jamais complétée : un nouvel ajout crée une ligne.
      await liste.check(old.lineId);
      now = 5000;

      final updated = await repo.updateArticle(
        SeedIds.tomates,
        name: 'Tomates',
        rayon: Rayon.epicerieSalee,
        unit: Unit.ml,
      );
      expect(updated.rayon, Rayon.epicerieSalee);
      expect(updated.unit, Unit.ml);
      expect(updated.pictoKey, 'tomates');

      final row = await article(SeedIds.tomates);
      expect(row.name, 'Tomates');
      expect(row.normalizedName, 'tomates');
      expect(row.rayon, 'epicerie-salee');
      expect(row.unit, 'ml');
      expect(row.pictoKey, 'tomates');
      expect(row.inCatalogue, isTrue);
      expect(row.updatedAt, greaterThanOrEqualTo(5000));

      expect((await line(old.lineId)).rayon, 'fruits-legumes');
      final added = await liste.addArticle(SeedIds.tomates);
      expect(added.lineId, isNot(old.lineId));
      expect((await line(added.lineId)).rayon, 'epicerie-salee');
      expect((await line(old.lineId)).rayon, 'fruits-legumes');
      expect(
        await (db.select(
          db.recipeIngredients,
        )..where((i) => i.articleId.equals(SeedIds.tomates))).get(),
        ingredientsBefore,
      );
    });

    test('renommer : nom nettoyé et nom normalisé écrits, trouvé sous son '
        'nouveau nom', () async {
      final updated = await repo.updateArticle(
        SeedIds.tomates,
        name: '  tomates   cerises ',
        rayon: Rayon.fruitsLegumes,
        unit: Unit.g,
      );
      expect(updated.name, 'Tomates cerises');
      final row = await article(SeedIds.tomates);
      expect(row.name, 'Tomates cerises');
      expect(row.normalizedName, 'tomatescerises');
      expect(row.pictoKey, 'tomates');
      final hits = await repo.watchSearch('cerises').first;
      expect(hits.single.id, SeedIds.tomates);
    });

    test('son propre nom dans une autre casse : accepté', () async {
      await repo.updateArticle(
        SeedIds.lait,
        name: 'LAIT',
        rayon: Rayon.cremerie,
        unit: Unit.piece,
      );
      expect((await article(SeedIds.lait)).name, 'LAIT');
    });

    test('créer « piment » : article du catalogue Piment, avec le rayon et '
        'l’unité de la fiche, trouvé ensuite par la recherche', () async {
      final created = await repo.createCatalogueArticle(
        'piment',
        rayon: Rayon.fruitsLegumes,
        unit: Unit.g,
      );
      expect(created.name, 'Piment');
      expect(created.rayon, Rayon.fruitsLegumes);
      expect(created.unit, Unit.g);
      final row = (await activeNamed('piment')).single;
      expect(row.id, created.id);
      expect(row.inCatalogue, isTrue);
      expect(row.rayon, 'fruits-legumes');
      expect(row.unit, 'g');
      expect(row.pictoKey, 'piment');
      expect((await repo.watchSearch('pim').first).single.id, created.id);
      expect(
        (await repo.watchCatalogue().first).map((a) => a.id),
        contains(created.id),
      );
    });

    test('créer un nom hors catalogue : même id, entre au catalogue avec '
        'les valeurs de la fiche', () async {
      final typed = await repo.resolveTypedArticle('physalis');
      expect(await repo.watchSearch('physalis').first, isEmpty);
      now = 2000;

      final created = await repo.createCatalogueArticle(
        'PHYSALIS',
        rayon: Rayon.fruitsLegumes,
        unit: Unit.piece,
      );
      expect(created.id, typed.id);
      final row = (await activeNamed('physalis')).single;
      expect(row.id, typed.id);
      expect(row.inCatalogue, isTrue);
      expect(row.name, 'PHYSALIS');
      expect(row.rayon, 'fruits-legumes');
      expect(row.unit, 'piece');
      expect((await repo.watchSearch('physalis').first).single.id, typed.id);
    });

    test('nom pris : Lait renommé « tomates » ou en un nom hors catalogue, '
        'ou création de « TOMATES » : refusé, rien n’est écrit', () async {
      await repo.resolveTypedArticle('Physalis');
      final before = await db.select(db.articles).get();
      final stamp = clock.last;

      for (final name in ['tomates', ' Tomâtes ', 'physalis']) {
        await expectLater(
          repo.updateArticle(
            SeedIds.lait,
            name: name,
            rayon: Rayon.boissons,
            unit: Unit.ml,
          ),
          throwsA(isA<ArticleNameTakenException>()),
          reason: name,
        );
      }
      await expectLater(
        repo.createCatalogueArticle('TOMATES', rayon: Rayon.divers, unit: null),
        throwsA(isA<ArticleNameTakenException>()),
      );
      expect(await db.select(db.articles).get(), before);
      expect(clock.last, stamp);
      expect((await frequentOf(SeedIds.lait)).deletedAt, isNull);
    });

    test('nom vide : refusé, rien n’est écrit', () async {
      final before = await db.select(db.articles).get();
      await expectLater(
        repo.updateArticle(
          SeedIds.lait,
          name: '   ',
          rayon: Rayon.cremerie,
          unit: Unit.piece,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.createCatalogueArticle('  ', rayon: Rayon.divers, unit: null),
        throwsArgumentError,
      );
      expect(await db.select(db.articles).get(), before);
    });

    test('Lait (fréquent) passé en Boissons : rayon changé, fréquent en '
        'dernier, les autres fréquents ne bougent pas', () async {
      final before = await db.select(db.frequents).get();
      final max = before
          .where((f) => f.deletedAt == null)
          .map((f) => f.position)
          .reduce((a, b) => a > b ? a : b);
      now = 4000;

      await repo.updateArticle(
        SeedIds.lait,
        name: 'Lait',
        rayon: Rayon.boissons,
        unit: Unit.piece,
      );

      expect((await article(SeedIds.lait)).rayon, 'boissons');
      final lait = await frequentOf(SeedIds.lait);
      expect(lait.position, max + 1);
      expect(lait.updatedAt, greaterThanOrEqualTo(4000));
      expect(lait.deletedAt, isNull);
      final others = (await db.select(db.frequents).get())
          .where((f) => f.articleId != SeedIds.lait)
          .toList();
      expect(others, before.where((f) => f.articleId != SeedIds.lait));

      // Le Panneau + le montre en dernier de Boissons.
      final frequents = await repo.watchFrequents().first;
      final boissons = frequents.where((a) => a.rayon == Rayon.boissons);
      expect(boissons.last.id, SeedIds.lait);
    });

    test('nom ou unité changés sans le rayon : le fréquent garde sa '
        'place', () async {
      final position = (await frequentOf(SeedIds.lait)).position;
      await repo.updateArticle(
        SeedIds.lait,
        name: 'Lait demi-écrémé',
        rayon: Rayon.cremerie,
        unit: Unit.ml,
      );
      expect((await frequentOf(SeedIds.lait)).position, position);
      expect((await article(SeedIds.lait)).unit, 'ml');
    });

    test('aucune valeur changée : rien n’est écrit', () async {
      final before = await db.select(db.articles).get();
      await repo.updateArticle(
        SeedIds.lait,
        name: ' lait ',
        rayon: Rayon.cremerie,
        unit: Unit.piece,
      );
      expect(await db.select(db.articles).get(), before);
      expect(clock.last, 0);
    });

    test('écriture qui échoue : la transaction est annulée, rien n’est '
        'écrit', () async {
      await db.customStatement(
        'CREATE TRIGGER fail_frequents BEFORE UPDATE ON frequents '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END;",
      );
      final articles = await db.select(db.articles).get();
      final frequents = await db.select(db.frequents).get();

      await expectLater(
        repo.updateArticle(
          SeedIds.lait,
          name: 'Lait',
          rayon: Rayon.boissons,
          unit: Unit.piece,
        ),
        throwsA(anything),
      );
      expect(await db.select(db.articles).get(), articles);
      expect(await db.select(db.frequents).get(), frequents);
    });
  });
}
