import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
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

  group('quantités et fusion (AD-4, AD-6)', () {
    Future<List<ListLine>> tomatesLines() =>
        (db.select(db.listLines)
              ..where((l) => l.articleId.equals(SeedIds.tomates))
              ..orderBy([(l) => OrderingTerm.asc(l.addedAt)]))
            .get();

    test(
      'même unité : une ligne g, deux contributions, quantité 500',
      () async {
        await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
        now = 2000;
        await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);

        final lines = await tomatesLines();
        expect(lines, hasLength(1));
        expect(lines.single.unit, 'g');
        final contributions = await db.select(db.listContributions).get();
        expect(contributions, hasLength(2));
        expect(
          contributions.map((c) => c.quantity),
          unorderedEquals([300, 200]),
        );
        expect(contributions.every((c) => c.unit == 'g'), isTrue);
        expect(contributions.every((c) => c.lineId == lines.single.id), isTrue);
        expect(
          contributions.every((c) => c.source == ContributionSource.ajout),
          isTrue,
        );

        final item = (await repo.watchUnchecked().first).single;
        expect(item.unit, Unit.g);
        expect(item.quantity, 500);
      },
    );

    test('autre unité : seconde ligne piece, quantité 2000', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      now = 2000;
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);

      final lines = await tomatesLines();
      expect(lines.map((l) => l.unit), ['g', 'piece']);
      final items = await repo.watchUnchecked().first;
      expect(items.map((i) => (i.unit, i.quantity)), [
        (Unit.g, 500),
        (Unit.piece, 2000),
      ]);
    });

    test('ligne sans quantité adoptée : elle prend g et un nouvel '
        'updated_at', () async {
      await repo.addArticle(SeedIds.tomates);
      now = 2000;
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);

      final line = (await tomatesLines()).single;
      expect(line.unit, 'g');
      expect(line.addedAt, 1000);
      expect(line.updatedAt, 2000);
      expect(await db.select(db.listContributions).get(), hasLength(2));

      final item = (await repo.watchUnchecked().first).single;
      expect(item.unit, Unit.g);
      expect(item.quantity, 300);
    });

    test('sans quantité sur une ligne chiffrée : même ligne, '
        'toujours 300', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      now = 2000;
      await repo.addArticle(SeedIds.tomates);

      final line = (await tomatesLines()).single;
      expect(line.unit, 'g');
      final contributions = await db.select(db.listContributions).get();
      expect(contributions, hasLength(2));
      expect(contributions.every((c) => c.lineId == line.id), isTrue);

      final item = (await repo.watchUnchecked().first).single;
      expect(item.quantity, 300);
    });

    test('quantité 0 : traitée comme sans quantité', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 0, unit: Unit.g);

      final line = (await tomatesLines()).single;
      expect(line.unit, isNull);
      final c = await db.select(db.listContributions).getSingle();
      expect(c.quantity, isNull);
      expect(c.unit, isNull);
      expect((await repo.watchUnchecked().first).single.quantity, isNull);
    });

    test('ligne cochée : nouvelle ligne non cochée g, la cochée '
        'inchangée', () async {
      await db
          .into(db.listLines)
          .insert(
            ListLinesCompanion.insert(
              id: 'cochee',
              updatedAt: 500,
              articleId: SeedIds.tomates,
              rayon: 'fruits-legumes',
              unit: const Value('g'),
              addedAt: 500,
              checkedAt: const Value(600),
            ),
          );
      await db
          .into(db.listContributions)
          .insert(
            ListContributionsCompanion.insert(
              id: 'c-cochee',
              updatedAt: 500,
              lineId: 'cochee',
              source: ContributionSource.ajout,
              quantity: const Value(300),
              unit: const Value('g'),
            ),
          );
      final before = await (db.select(
        db.listLines,
      )..where((l) => l.id.equals('cochee'))).getSingle();

      await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);

      final lines = await tomatesLines();
      expect(lines, hasLength(2));
      final added = lines.singleWhere((l) => l.id != 'cochee');
      expect(added.unit, 'g');
      expect(added.checkedAt, isNull);
      expect(lines.singleWhere((l) => l.id == 'cochee'), before);
      expect(
        await (db.select(
          db.listContributions,
        )..where((c) => c.lineId.equals('cochee'))).get(),
        hasLength(1),
      );

      final item = (await repo.watchUnchecked().first).single;
      expect(item.lineId, added.id);
      expect(item.quantity, 200);
    });

    for (final (label, quantity, unit) in <(String, int?, Unit?)>[
      ('quantité sans unité', 300, null),
      ('unité sans quantité', null, Unit.g),
      ('quantité négative', -100, Unit.g),
    ]) {
      test(
        'entrée incohérente ($label) : ArgumentError, rien d’écrit',
        () async {
          await expectLater(
            repo.addArticle(SeedIds.tomates, quantity: quantity, unit: unit),
            throwsArgumentError,
          );
          expect(await db.select(db.listLines).get(), isEmpty);
          expect(await db.select(db.listContributions).get(), isEmpty);
        },
      );
    }

    test('contribution supprimée : somme des seules actives', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      now = 2000;
      await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);
      await (db.update(
        db.listContributions,
      )..where((c) => c.quantity.equals(300))).write(
        const ListContributionsCompanion(
          deletedAt: Value(3000),
          updatedAt: Value(3000),
        ),
      );

      final item = (await repo.watchUnchecked().first).single;
      expect(item.quantity, 200);
    });
  });
}
