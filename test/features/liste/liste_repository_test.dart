import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late ListeRepository repo;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    repo = ListeRepository(db, Clock(now: () => now));
  });
  tearDown(() => db.close());

  test('liste vide au départ', () async {
    expect(await repo.watchUnchecked().first, isEmpty);
  });

  test('ajout : une ligne au rayon de l’article, contribution ajout '
      'sans quantité', () async {
    await repo.addArticle(SeedIds.lait);

    final line = await db.select(db.listLines).getSingle();
    expect(line.articleId, SeedIds.lait);
    expect(line.rayon, 'cremerie');
    expect(line.unit, isNull);
    expect(line.addedAt, 1000);
    expect(line.updatedAt, 1000);
    expect(line.checkedAt, isNull);
    expect(line.manualAt, isNull);

    final c = await db.select(db.listContributions).getSingle();
    expect(c.lineId, line.id);
    expect(c.source, ContributionSource.ajout);
    expect(c.quantity, isNull);
    expect(c.unit, isNull);
    expect(c.weekSelectionId, isNull);

    final items = await repo.watchUnchecked().first;
    expect(items.single.name, 'Lait');
    expect(items.single.rayon, Rayon.cremerie);
    expect(items.single.quantity, isNull);
  });

  test('second ajout : toujours une seule ligne, deux contributions', () async {
    await repo.addArticle(SeedIds.lait);
    now = 2000;
    await repo.addArticle(SeedIds.lait);

    final lines = await db.select(db.listLines).get();
    expect(lines, hasLength(1));
    expect(lines.single.addedAt, 1000);
    expect(await db.select(db.listContributions).get(), hasLength(2));
    expect(await repo.watchUnchecked().first, hasLength(1));
  });

  test('une ligne cochée n’est jamais complétée', () async {
    await repo.addArticle(SeedIds.lait);
    await db
        .update(db.listLines)
        .write(const ListLinesCompanion(checkedAt: Value(1500)));
    await repo.addArticle(SeedIds.lait);

    expect(await db.select(db.listLines).get(), hasLength(2));
    expect(await repo.watchUnchecked().first, hasLength(1));
  });

  test('article supprimé : ajout refusé, rien d’écrit', () async {
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).write(
      const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
    );
    await expectLater(repo.addArticle(SeedIds.lait), throwsStateError);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(await db.select(db.listContributions).get(), isEmpty);
  });

  test(
    'groupes dans l’ordre du parcours, ordre d’ajout dans le rayon',
    () async {
      await repo.addArticle(SeedIds.tomates);
      now = 2000;
      await repo.addArticle(SeedIds.lait);
      now = 3000;
      await repo.addArticle(SeedIds.oeufs);

      final items = await repo.watchUnchecked().first;
      final groups = groupByRoute(items, [
        Rayon.cremerie,
        ...Rayon.values.where((r) => r != Rayon.cremerie),
      ]);
      expect(groups.map((g) => g.rayon), [Rayon.cremerie, Rayon.fruitsLegumes]);
      expect(groups.first.items.map((i) => i.name), ['Lait', 'Œufs']);
      expect(groups.first.count, 2);
    },
  );
}
