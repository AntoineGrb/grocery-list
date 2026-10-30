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
  late AjouterTexte ajouter;
  late PlacerLigneAjoutee placer;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    catalogue = CatalogueRepository(db, clock);
    liste = ListeRepository(db, clock);
    ajouter = AjouterTexte(db, catalogue, liste);
    placer = PlacerLigneAjoutee(liste);
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
    expect(await liste.watchUnchecked().first, hasLength(1));
    expect(await liste.watchChecked().first, hasLength(1));
  });

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

  test('rayon d’une ligne ajoutée : Lait, Épicerie salée → seule la ligne '
      'change, l’article reste en Crèmerie', () async {
    final added = await liste.addArticle(SeedIds.lait);
    final articleBefore = await (db.select(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).getSingle();

    now = 2000;
    await placer(added.lineId, Rayon.epicerieSalee);

    final item = (await liste.watchUnchecked().first).single;
    expect(item.rayon, Rayon.epicerieSalee);
    final articleAfter = await (db.select(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).getSingle();
    expect(articleAfter, articleBefore);
  });
}
