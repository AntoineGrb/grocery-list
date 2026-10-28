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

  group('cocher et décocher (AD-4)', () {
    Future<ListLine> lineOf(String id) =>
        (db.select(db.listLines)..where((l) => l.id.equals(id))).getSingle();

    Future<List<ListLine>> activeTomates() =>
        (db.select(db.listLines)..where(
              (l) => l.articleId.equals(SeedIds.tomates) & l.deletedAt.isNull(),
            ))
            .get();

    test('cocher : checked_at et updated_at fixés, la ligne passe dans '
        'watchChecked avec 500 g', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      final id = (await repo.watchUnchecked().first).single.lineId;
      now = 2000;

      await repo.check(id);

      final line = await lineOf(id);
      expect(line.checkedAt, 2000);
      expect(line.updatedAt, 2000);
      expect(line.addedAt, 1000);
      expect(await repo.watchUnchecked().first, isEmpty);
      final checked = (await repo.watchChecked().first).single;
      expect(checked.lineId, id);
      expect(checked.checked, isTrue);
      expect(checked.unit, Unit.g);
      expect(checked.quantity, 500);
    });

    test('décocher sans jumeau : checked_at nul, retour à sa place '
        'd’ajout', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      now = 2000;
      await repo.addArticle(SeedIds.riz, quantity: 300, unit: Unit.g);
      final tomates = (await repo.watchUnchecked().first).first.lineId;
      now = 3000;
      await repo.check(tomates);
      now = 4000;

      await repo.uncheck(tomates);

      final line = await lineOf(tomates);
      expect(line.checkedAt, isNull);
      expect(line.deletedAt, isNull);
      expect(line.updatedAt, 4000);
      expect(line.addedAt, 1000);
      expect(await repo.watchChecked().first, isEmpty);
      final items = await repo.watchUnchecked().first;
      expect(items.map((i) => i.name), ['Tomates', 'Riz']);
      expect(items.first.checked, isFalse);
      expect(items.first.quantity, 500);
    });

    test('décocher avec jumeau : contributions reportées, la cochée '
        'supprimée, une ligne de 500 g', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      final cochee = (await repo.watchUnchecked().first).single.lineId;
      now = 2000;
      await repo.check(cochee);
      now = 3000;
      await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);
      final jumeau = (await repo.watchUnchecked().first).single.lineId;
      expect(jumeau, isNot(cochee));
      now = 4000;

      await repo.uncheck(cochee);

      final old = await lineOf(cochee);
      expect(old.deletedAt, greaterThanOrEqualTo(4000));
      expect(old.updatedAt, old.deletedAt);
      final contributions = await db.select(db.listContributions).get();
      expect(contributions, hasLength(2));
      expect(contributions.every((c) => c.lineId == jumeau), isTrue);
      expect(contributions.every((c) => c.deletedAt == null), isTrue);
      final moved = contributions.singleWhere((c) => c.quantity == 300);
      expect(moved.updatedAt, greaterThanOrEqualTo(4000));

      expect((await activeTomates()).single.id, jumeau);
      final item = (await repo.watchUnchecked().first).single;
      expect(item.lineId, jumeau);
      expect(item.unit, Unit.g);
      expect(item.quantity, 500);
      expect(await repo.watchChecked().first, isEmpty);
    });

    test('jumeau sans quantité : fusion dans la non cochée', () async {
      await repo.addArticle(SeedIds.tomates);
      final cochee = (await repo.watchUnchecked().first).single.lineId;
      now = 2000;
      await repo.check(cochee);
      now = 3000;
      await repo.addArticle(SeedIds.tomates);
      final jumeau = (await repo.watchUnchecked().first).single.lineId;
      now = 4000;

      await repo.uncheck(cochee);

      expect((await activeTomates()).single.id, jumeau);
      final contributions = await db.select(db.listContributions).get();
      expect(contributions.every((c) => c.lineId == jumeau), isTrue);
      final item = (await repo.watchUnchecked().first).single;
      expect(item.quantity, isNull);
      expect(await repo.watchChecked().first, isEmpty);
    });

    test('unité différente : pas de fusion, deux lignes g et pièce', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      final cochee = (await repo.watchUnchecked().first).single.lineId;
      now = 2000;
      await repo.check(cochee);
      now = 3000;
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      now = 4000;

      await repo.uncheck(cochee);

      expect(await activeTomates(), hasLength(2));
      final items = await repo.watchUnchecked().first;
      expect(items.map((i) => (i.unit, i.quantity)), [
        (Unit.g, 500),
        (Unit.piece, 2000),
      ]);
      expect((await lineOf(cochee)).checkedAt, isNull);
    });

    test('idempotence : rien n’est écrit, aucune erreur', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      now = 2000;
      await repo.addArticle(SeedIds.riz, quantity: 300, unit: Unit.g);
      final items = await repo.watchUnchecked().first;
      final tomates = items.first.lineId;
      final riz = items.last.lineId;
      now = 3000;
      await repo.check(tomates);
      await (db.update(db.listLines)..where((l) => l.id.equals(riz))).write(
        const ListLinesCompanion(
          deletedAt: Value(3500),
          updatedAt: Value(3500),
        ),
      );
      final linesBefore = await db.select(db.listLines).get();
      final contributionsBefore = await db.select(db.listContributions).get();
      now = 4000;

      await repo.check(tomates); // déjà cochée
      await repo.check(riz); // supprimée
      await repo.uncheck(riz); // supprimée
      await repo.check('inconnu');
      await repo.uncheck('inconnu');
      await repo.uncheck(tomates);
      now = 5000;
      await repo.uncheck(tomates); // déjà décochée

      final linesAfter = await db.select(db.listLines).get();
      expect(
        linesAfter.where((l) => l.id != tomates),
        linesBefore.where((l) => l.id != tomates),
      );
      expect((await lineOf(tomates)).updatedAt, 4000);
      expect(await db.select(db.listContributions).get(), contributionsBefore);
    });

    test('ordre des cochés : le dernier coché en tête', () async {
      await repo.addArticle(SeedIds.tomates);
      now = 2000;
      await repo.addArticle(SeedIds.riz);
      final items = await repo.watchUnchecked().first;
      now = 3000;
      await repo.check(items.first.lineId);
      now = 4000;
      await repo.check(items.last.lineId);

      final checked = await repo.watchChecked().first;
      expect(checked.map((i) => i.name), ['Riz', 'Tomates']);
      expect(checked.every((i) => i.checked), isTrue);
    });
  });
}
