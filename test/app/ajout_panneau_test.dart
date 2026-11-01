import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajout_panneau.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';

import '../helpers/test_db.dart';

/// Id de l'article Piles fourni, supprimé pour que « piles » soit absent.
const _pilesFourni = '647841c6-7cff-40f4-a8dd-69d7e781eb8b';

void main() {
  late AppDatabase db;
  late Clock clock;
  late CatalogueRepository catalogue;
  late ListeRepository liste;
  late AjouterTexte ajouter;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    catalogue = CatalogueRepository(db, clock);
    liste = ListeRepository(db, clock);
    ajouter = AjouterTexte(db, catalogue, liste);
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(_pilesFourni))).write(
      const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
    );
  });
  tearDown(() => db.close());

  Future<List<Article>> activePiles() =>
      (db.select(db.articles)..where(
            (a) => a.normalizedName.equals('piles') & a.deletedAt.isNull(),
          ))
          .get();

  test('« piles » inconnu : article hors catalogue Piles (Divers, sans '
      'unité) et ligne sans quantité sous Divers', () async {
    final result = await ajouter('piles');

    expect(result.ajoute, isTrue);
    expect(result.article.name, 'Piles');
    final article = (await activePiles()).single;
    expect(article.id, result.article.id);
    expect(article.rayon, 'divers');
    expect(article.unit, isNull);
    expect(article.inCatalogue, isFalse);

    final line = (await db.select(db.listLines).get()).single;
    expect(line.articleId, article.id);
    expect(line.rayon, 'divers');
    expect(line.unit, isNull);
    final contribution = (await db.select(db.listContributions).get()).single;
    expect(contribution.lineId, line.id);
    expect(contribution.source, ContributionSource.ajout);
    expect(contribution.quantity, isNull);

    final item = (await liste.watchUnchecked().first).single;
    expect(item.name, 'Piles');
    expect(item.rayon, Rayon.divers);
    expect(item.quantity, isNull);
    expect(result.lineId, item.lineId);
    // Jamais dans la recherche.
    expect(await catalogue.watchSearch('pil').first, isEmpty);
  });

  test('« LAIT » : le Lait du catalogue ajouté sous Crèmerie, aucun article '
      'créé', () async {
    final before = await db.select(db.articles).get();
    final result = await ajouter('LAIT');

    expect(result.ajoute, isTrue);
    expect(result.article.id, SeedIds.lait);
    expect(await db.select(db.articles).get(), before);
    final item = (await liste.watchUnchecked().first).single;
    expect(item.articleId, SeedIds.lait);
    expect(item.rayon, Rayon.cremerie);
  });

  test('déjà dans la liste : rien n’est écrit, ni ajouté ni retiré', () async {
    await ajouter('piles');
    final lines = await db.select(db.listLines).get();
    final contributions = await db.select(db.listContributions).get();
    final articles = await db.select(db.articles).get();
    final stamp = clock.last;

    now = 2000;
    final result = await ajouter(' PILES ');

    expect(result.ajoute, isFalse);
    expect(result.article.id, articles.firstWhere((a) => !a.inCatalogue).id);
    expect(result.lineId, lines.single.id);
    expect(await db.select(db.listLines).get(), lines);
    expect(await db.select(db.listContributions).get(), contributions);
    expect(await db.select(db.articles).get(), articles);
    expect(clock.last, stamp);
  });

  test('ligne cochée seulement : ajouté sur une nouvelle ligne', () async {
    final added = await liste.addArticle(SeedIds.lait);
    await liste.check(added.lineId);

    final result = await ajouter('lait');

    expect(result.ajoute, isTrue);
    expect(result.lineId, isNot(added.lineId));
    expect(await liste.watchUnchecked().first, hasLength(1));
    expect(await liste.watchChecked().first, hasLength(1));
  });

  test(
    'article sur deux lignes : la plus ancienne non cochée est rendue',
    () async {
      final oldest = await liste.addArticle(
        SeedIds.lait,
        quantity: 500,
        unit: Unit.ml,
      );
      now = 2000;
      await liste.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);

      final result = await ajouter('lait');

      expect(result.ajoute, isFalse);
      expect(result.lineId, oldest.lineId);
    },
  );

  test(
    'texte libre réutilisé : Piles retiré puis retapé, même article',
    () async {
      final first = await ajouter('piles');
      await liste.removeArticle(first.article.id);

      final second = await ajouter('Piles');

      expect(second.ajoute, isTrue);
      expect(second.article.id, first.article.id);
      expect(await activePiles(), hasLength(1));
      expect(
        (await liste.watchUnchecked().first).single.articleId,
        first.article.id,
      );
    },
  );

  test('texte vide : refusé, rien n’est écrit', () async {
    await expectLater(ajouter('   '), throwsArgumentError);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(clock.last, 0);
  });

  test(
    'échec de l’ajout : l’article n’est pas créé, rien n’est écrit',
    () async {
      await db.customStatement(
        'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      final articlesBefore = await db.select(db.articles).get();

      await expectLater(ajouter('piles'), throwsA(anything));

      expect(await db.select(db.articles).get(), articlesBefore);
      expect(await activePiles(), isEmpty);
      expect(await db.select(db.listLines).get(), isEmpty);
      expect(await db.select(db.listContributions).get(), isEmpty);
    },
  );

  group('avec les tags', () {
    Future<ListLine> line(String lineId) => (db.select(
      db.listLines,
    )..where((l) => l.id.equals(lineId))).getSingle();

    Future<List<ListContribution>> activeContributions(String lineId) =>
        (db.select(
          db.listContributions,
        )..where((c) => c.lineId.equals(lineId) & c.deletedAt.isNull())).get();

    Future<Article> article(String id) =>
        (db.select(db.articles)..where((a) => a.id.equals(id))).getSingle();

    test('texte libre : quantité en contribution ajout, ligne non manuelle, '
        'rayon sur la seule ligne', () async {
      final result = await ajouter(
        'piles',
        quantity: 4000,
        unit: Unit.piece,
        rayon: Rayon.entretien,
      );

      expect(result.ajoute, isTrue);
      final added = await line(result.lineId);
      expect(added.rayon, Rayon.entretien.code);
      expect(added.unit, 'piece');
      expect(added.manualAt, isNull);
      final contribution = (await activeContributions(result.lineId)).single;
      expect(contribution.source, ContributionSource.ajout);
      expect(contribution.quantity, 4000);
      expect(contribution.unit, 'piece');

      final piles = (await activePiles()).single;
      expect(piles.rayon, 'divers');
      expect(piles.unit, isNull);
    });

    test('pas de mémoire : retirée puis rajoutée, Piles repart de Divers, sans '
        'quantité', () async {
      final first = await ajouter(
        'piles',
        quantity: 4000,
        unit: Unit.piece,
        rayon: Rayon.entretien,
      );
      await liste.removeArticle(first.article.id);

      final second = await ajouter('piles');

      expect(second.article.id, first.article.id);
      final added = await line(second.lineId);
      expect(added.rayon, 'divers');
      expect(added.unit, isNull);
      expect(
        (await activeContributions(second.lineId)).single.quantity,
        isNull,
      );
    });

    test('article du catalogue : ligne sous Boissons, l’article reste en '
        'Crèmerie et le prochain ajout y revient', () async {
      final before = await article(SeedIds.lait);

      final first = await ajouter('lait', rayon: Rayon.boissons);

      expect((await line(first.lineId)).rayon, Rayon.boissons.code);
      expect(await article(SeedIds.lait), before);

      await liste.removeArticle(SeedIds.lait);
      final second = await ajouter('lait');
      expect((await line(second.lineId)).rayon, Rayon.cremerie.code);
    });

    test('présent à 1 pièce, tag 2 : une seule ligne, remplacée à 2 par '
        'l’édition (manuelle)', () async {
      final added = await liste.addArticle(
        SeedIds.lait,
        quantity: 1000,
        unit: Unit.piece,
      );

      final result = await ajouter('lait', quantity: 2000, unit: Unit.piece);

      expect(result.ajoute, isFalse);
      expect(result.lineId, added.lineId);
      final item = (await liste.watchUnchecked().first).single;
      expect(item.quantity, 2000);
      final edited = await line(added.lineId);
      expect(edited.manualAt, isNotNull);
      expect(edited.rayon, Rayon.cremerie.code);
      expect(
        (await activeContributions(added.lineId)).single.source,
        ContributionSource.edition,
      );
    });

    test('présent, rayon seul : ligne déplacée, quantité et contributions '
        'intactes, ligne non manuelle, article inchangé', () async {
      final added = await liste.addArticle(
        SeedIds.lait,
        quantity: 1000,
        unit: Unit.piece,
      );
      final contributions = await activeContributions(added.lineId);
      final before = await article(SeedIds.lait);

      final result = await ajouter('lait', rayon: Rayon.boissons);

      expect(result.ajoute, isFalse);
      final moved = await line(added.lineId);
      expect(moved.rayon, Rayon.boissons.code);
      expect(moved.manualAt, isNull);
      expect(await activeContributions(added.lineId), contributions);
      expect(await article(SeedIds.lait), before);
    });

    test('présent sur deux lignes : la plus ancienne remplacée, fusion dans '
        'l’unité du tag comprise', () async {
      final oldest = await liste.addArticle(
        SeedIds.lait,
        quantity: 500,
        unit: Unit.ml,
      );
      now = 2000;
      await liste.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);

      final result = await ajouter(
        'lait',
        quantity: 1000,
        unit: Unit.piece,
        rayon: Rayon.boissons,
      );

      expect(result.lineId, oldest.lineId);
      final item = (await liste.watchUnchecked().first).single;
      expect(item.lineId, oldest.lineId);
      expect(item.unit, Unit.piece);
      expect(item.quantity, 3000);
      expect(item.rayon, Rayon.boissons);
    });

    test('ligne cochée seulement : les tags vont sur une nouvelle ligne, '
        'jamais sur la cochée', () async {
      final added = await liste.addArticle(SeedIds.lait);
      await liste.check(added.lineId);
      final checked = await line(added.lineId);

      final result = await ajouter(
        'lait',
        quantity: 2000,
        unit: Unit.piece,
        rayon: Rayon.boissons,
      );

      expect(result.ajoute, isTrue);
      expect(result.lineId, isNot(added.lineId));
      expect((await line(result.lineId)).rayon, Rayon.boissons.code);
      expect(await line(added.lineId), checked);
    });

    test(
      'rayon impossible à écrire : tout est annulé, article compris',
      () async {
        await db.customStatement(
          'CREATE TRIGGER no_rayon BEFORE UPDATE OF rayon ON list_lines '
          "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
        );

        await expectLater(
          ajouter('piles', rayon: Rayon.entretien),
          throwsA(anything),
        );

        expect(await activePiles(), isEmpty);
        expect(await db.select(db.listLines).get(), isEmpty);
        expect(await db.select(db.listContributions).get(), isEmpty);
      },
    );

    test('remplacement impossible : quantité et rayon restent', () async {
      final added = await liste.addArticle(
        SeedIds.lait,
        quantity: 1000,
        unit: Unit.piece,
      );
      final lines = await db.select(db.listLines).get();
      final contributions = await db.select(db.listContributions).get();
      await db.customStatement(
        'CREATE TRIGGER no_rayon BEFORE UPDATE OF rayon ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await expectLater(
        ajouter(
          'lait',
          quantity: 2000,
          unit: Unit.piece,
          rayon: Rayon.boissons,
        ),
        throwsA(anything),
      );

      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.listContributions).get(), contributions);
      expect((await line(added.lineId)).manualAt, isNull);
    });

    group('AjouterArticle', () {
      late AjouterArticle ajouterArticle;
      setUp(() => ajouterArticle = AjouterArticle(db, liste));

      test(
        'quantité en contribution ajout, rayon sur la ligne seule',
        () async {
          final before = await article(SeedIds.lait);

          final added = await ajouterArticle(
            SeedIds.lait,
            quantity: 2000,
            unit: Unit.piece,
            rayon: Rayon.boissons,
          );

          final written = await line(added.lineId);
          expect(written.rayon, Rayon.boissons.code);
          expect(written.manualAt, isNull);
          final contribution = (await activeContributions(added.lineId)).single;
          expect(contribution.source, ContributionSource.ajout);
          expect(contribution.quantity, 2000);
          expect(await article(SeedIds.lait), before);
        },
      );

      test('sans tag : le rayon de l’article, sans quantité', () async {
        final added = await ajouterArticle(SeedIds.lait);

        final written = await line(added.lineId);
        expect(written.rayon, Rayon.cremerie.code);
        expect(written.unit, isNull);
      });

      test('rayon impossible à écrire : aucune ligne écrite', () async {
        await db.customStatement(
          'CREATE TRIGGER no_rayon BEFORE UPDATE OF rayon ON list_lines '
          "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
        );

        await expectLater(
          ajouterArticle(SeedIds.lait, rayon: Rayon.boissons),
          throwsA(anything),
        );

        expect(await db.select(db.listLines).get(), isEmpty);
        expect(await db.select(db.listContributions).get(), isEmpty);
      });
    });
  });
}
