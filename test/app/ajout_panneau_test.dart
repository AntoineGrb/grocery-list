import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajout_panneau.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
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
  late CreerEtAjouter creer;
  late PlacerLigneAjoutee placer;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    catalogue = CatalogueRepository(db, clock);
    liste = ListeRepository(db, clock);
    creer = CreerEtAjouter(db, catalogue, liste);
    placer = PlacerLigneAjoutee(db, catalogue, liste);
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

  test('Créer « piles » : article Piles (Divers, sans unité) et ligne sans '
      'quantité sous Divers', () async {
    final ajout = await creer('piles');

    expect(ajout.articleCree, isTrue);
    expect(ajout.article.name, 'Piles');
    final article = (await activePiles()).single;
    expect(article.id, ajout.article.id);
    expect(article.rayon, 'divers');
    expect(article.unit, isNull);
    expect(article.normalizedName, 'piles');

    final line = await (db.select(
      db.listLines,
    )..where((l) => l.id.equals(ajout.lineId))).getSingle();
    expect(line.articleId, article.id);
    expect(line.rayon, 'divers');
    expect(line.unit, isNull);
    final contribution = await (db.select(
      db.listContributions,
    )..where((c) => c.id.equals(ajout.contributionId))).getSingle();
    expect(contribution.lineId, line.id);
    expect(contribution.source, ContributionSource.ajout);
    expect(contribution.quantity, isNull);

    final item = (await liste.watchUnchecked().first).single;
    expect(item.name, 'Piles');
    expect(item.rayon, Rayon.divers);
    expect(item.quantity, isNull);
  });

  test('Créer un nom déjà pris : Lait ajouté, aucun article créé', () async {
    final before = await db.select(db.articles).get();
    final ajout = await creer('LAIT');

    expect(ajout.articleCree, isFalse);
    expect(ajout.article.id, SeedIds.lait);
    expect(await db.select(db.articles).get(), before);
    expect((await liste.watchUnchecked().first).single.articleId, SeedIds.lait);
  });

  test(
    'échec de l’ajout : l’article n’est pas créé, rien n’est écrit',
    () async {
      await db.customStatement(
        'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      final articlesBefore = await db.select(db.articles).get();

      await expectLater(creer('piles'), throwsA(anything));

      expect(await db.select(db.articles).get(), articlesBefore);
      expect(await activePiles(), isEmpty);
      expect(await db.select(db.listLines).get(), isEmpty);
      expect(await db.select(db.listContributions).get(), isEmpty);
    },
  );

  test('rayon d’un article créé : Piles créé, Entretien → ligne et article '
      'en Entretien', () async {
    final ajout = await creer('piles');
    now = 2000;
    await placer(
      ajout.lineId,
      ajout.article.id,
      Rayon.entretien,
      articleCree: ajout.articleCree,
    );

    final article = (await activePiles()).single;
    expect(article.rayon, 'entretien');
    expect(article.updatedAt, greaterThanOrEqualTo(2000));
    final item = (await liste.watchUnchecked().first).single;
    expect(item.rayon, Rayon.entretien);
    // Trouvé ensuite en Entretien.
    final hit = (await catalogue.watchSearch('piles').first).single;
    expect(hit.rayon, Rayon.entretien);
  });

  test('rayon d’un article existant : Lait, Épicerie salée → seule la ligne '
      'change, l’article reste en Crèmerie', () async {
    final added = await liste.addArticle(SeedIds.lait);
    final articleBefore = await (db.select(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).getSingle();

    now = 2000;
    await placer(added.lineId, SeedIds.lait, Rayon.epicerieSalee);

    final item = (await liste.watchUnchecked().first).single;
    expect(item.rayon, Rayon.epicerieSalee);
    final articleAfter = await (db.select(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).getSingle();
    expect(articleAfter, articleBefore);
    expect(articleAfter.rayon, 'cremerie');
  });

  test(
    'échec du rayon de l’article : la ligne ne change pas non plus',
    () async {
      final ajout = await creer('piles');
      await db.customStatement(
        'CREATE TRIGGER no_rayon BEFORE UPDATE OF rayon ON articles '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await expectLater(
        placer(
          ajout.lineId,
          ajout.article.id,
          Rayon.entretien,
          articleCree: true,
        ),
        throwsA(anything),
      );

      expect((await liste.watchUnchecked().first).single.rayon, Rayon.divers);
      expect((await activePiles()).single.rayon, 'divers');
    },
  );
}
