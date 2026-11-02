import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository repo;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    repo = ListeRepository(db, clock);
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

  group('supprimer et corriger (AD-4, AD-5, AD-15)', () {
    Future<ListLine> lineOf(String id) =>
        (db.select(db.listLines)..where((l) => l.id.equals(id))).getSingle();

    Future<List<ListContribution>> contributionsOf(String id) => (db.select(
      db.listContributions,
    )..where((c) => c.lineId.equals(id))).get();

    Future<ListContribution> activeOf(String id) async =>
        (await contributionsOf(id)).where((c) => c.deletedAt == null).single;

    Future<String> lineIdOf(String name) async => [
      ...await repo.watchUnchecked().first,
      ...await repo.watchChecked().first,
    ].singleWhere((i) => i.name == name).lineId;

    test('supprimer : ligne et contributions supprimées logiquement, état '
        'd’avant de chaque ligne touchée, absente des deux flux', () async {
      await repo.addArticle(SeedIds.riz, quantity: 1000, unit: Unit.g);
      await repo.addArticle(SeedIds.riz, quantity: 500, unit: Unit.g);
      final id = await lineIdOf('Riz');
      now = 2000;

      final rows = await repo.removeLine(id);

      final line = await lineOf(id);
      expect(line.deletedAt, 2000);
      expect(line.updatedAt, 2000);
      final contributions = await contributionsOf(id);
      expect(contributions, hasLength(2));
      expect(contributions.every((c) => c.deletedAt == 2000), isTrue);
      expect(rows, hasLength(3));
      expect(rows.where((r) => r.table == db.listLines), hasLength(1));
      expect(rows.where((r) => r.table == db.listContributions), hasLength(2));
      expect(await repo.watchUnchecked().first, isEmpty);
      expect(await repo.watchChecked().first, isEmpty);
    });

    test('annuler la suppression : Riz revient à sa place, 1,5 kg, cochée '
        'ou non comme avant', () async {
      await repo.addArticle(SeedIds.tomates);
      now = 1500;
      await repo.addArticle(SeedIds.riz, quantity: 1000, unit: Unit.g);
      await repo.addArticle(SeedIds.riz, quantity: 500, unit: Unit.g);
      final id = await lineIdOf('Riz');
      now = 2000;
      await repo.check(id);
      final before = await lineOf(id);
      final undo = Undo(db, clock);
      now = 3000;

      final entry = undo.record(await repo.removeLine(id));
      expect(await repo.watchChecked().first, isEmpty);
      now = 4000;
      expect(await undo.undo(entry), isTrue);

      final item = (await repo.watchChecked().first).single;
      expect(item.lineId, id);
      expect(item.checked, isTrue);
      expect(item.rayon, Rayon.epicerieSalee);
      expect((item.unit, item.quantity), (Unit.g, 1500));
      final after = await lineOf(id);
      expect(after.deletedAt, isNull);
      expect(after.addedAt, before.addedAt);
      expect(after.checkedAt, before.checkedAt);
      expect(after.updatedAt, greaterThan(3000));
      expect(
        (await contributionsOf(id)).every((c) => c.deletedAt == null),
        isTrue,
      );

      // Une ligne non cochée revient aussi, non cochée.
      final tomates = await lineIdOf('Tomates');
      final entry2 = undo.record(await repo.removeLine(tomates));
      expect(await repo.watchUnchecked().first, isEmpty);
      expect(await undo.undo(entry2), isTrue);
      expect((await repo.watchUnchecked().first).single.lineId, tomates);
    });

    test('corriger : anciennes contributions supprimées, une contribution '
        'edition 300 g, manual_at fixé', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);
      final id = await lineIdOf('Tomates');
      now = 2000;

      await repo.setQuantity(id, 300, unit: Unit.g);

      final contributions = await contributionsOf(id);
      expect(contributions, hasLength(3));
      final active = await activeOf(id);
      expect(active.source, ContributionSource.edition);
      expect((active.quantity, active.unit), (300, 'g'));
      final ajouts = contributions.where(
        (c) => c.source == ContributionSource.ajout,
      );
      expect(ajouts, hasLength(2));
      expect(ajouts.every((c) => c.deletedAt == 2000), isTrue);
      final line = await lineOf(id);
      expect(line.manualAt, 2000);
      expect(line.updatedAt, 2000);
      expect(line.unit, 'g');
      final item = (await repo.watchUnchecked().first).single;
      expect((item.unit, item.quantity), (Unit.g, 300));
    });

    test('ligne sans quantité : elle prend l’unité saisie', () async {
      await repo.addArticle(SeedIds.lardons);
      final id = await lineIdOf('Lardons');
      final item = (await repo.watchUnchecked().first).single;
      expect(item.unit, isNull);
      expect(item.articleUnit, Unit.g);
      now = 2000;

      await repo.setQuantity(id, 300, unit: Unit.g);

      final line = await lineOf(id);
      expect(line.unit, 'g');
      expect(line.manualAt, 2000);
      final active = await activeOf(id);
      expect(active.source, ContributionSource.edition);
      expect((active.quantity, active.unit), (300, 'g'));
      final after = (await repo.watchUnchecked().first).single;
      expect((after.unit, after.quantity), (Unit.g, 300));
    });

    for (final (input, unit) in [
      (null, null),
      (0, null),
      (null, Unit.piece),
      (0, Unit.g),
    ]) {
      test('vider ($input, ${unit?.code}) : contribution edition sans '
          'quantité, ligne sans unité, manual_at fixé', () async {
        await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
        final id = await lineIdOf('Tomates');
        now = 2000;

        await repo.setQuantity(id, input, unit: unit);

        final line = await lineOf(id);
        expect(line.unit, isNull);
        expect(line.manualAt, 2000);
        final active = await activeOf(id);
        expect(active.source, ContributionSource.edition);
        expect(active.quantity, isNull);
        expect(active.unit, isNull);
        final item = (await repo.watchUnchecked().first).single;
        expect(item.quantity, isNull);
        expect(item.unit, isNull);
      });
    }

    test('pièces : contribution edition 3000 piece', () async {
      await repo.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
      final id = await lineIdOf('Lait');
      now = 2000;

      await repo.setQuantity(id, 3000, unit: Unit.piece);

      final active = await activeOf(id);
      expect(active.source, ContributionSource.edition);
      expect((active.quantity, active.unit), (3000, 'piece'));
      expect((await lineOf(id)).unit, 'piece');
    });

    test('vider puis ressaisir dans la même feuille : l’unité du champ est '
        'gardée (ml), pas celle de l’article (pièce)', () async {
      await repo.addArticle(SeedIds.lait, quantity: 500, unit: Unit.ml);
      final id = await lineIdOf('Lait');
      now = 2000;

      await repo.setQuantity(id, null, unit: Unit.ml);
      expect((await lineOf(id)).unit, isNull);
      now = 3000;
      await repo.setQuantity(id, 400, unit: Unit.ml);

      expect((await lineOf(id)).unit, 'ml');
      final active = await activeOf(id);
      expect((active.quantity, active.unit), (400, 'ml'));
      final item = (await repo.watchUnchecked().first).single;
      expect((item.unit, item.quantity), (Unit.ml, 400));
    });

    test('changer d’unité sans jumeau : Tomates 500 g → 3 pièces, même '
        'ligne, manuelle', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      final id = await lineIdOf('Tomates');
      final before = await lineOf(id);
      now = 2000;

      await repo.setQuantity(id, 3000, unit: Unit.piece);

      final line = await lineOf(id);
      expect(line.unit, 'piece');
      expect(line.manualAt, 2000);
      expect(line.addedAt, before.addedAt);
      final active = await activeOf(id);
      expect(active.source, ContributionSource.edition);
      expect((active.quantity, active.unit), (3000, 'piece'));
      final item = (await repo.watchUnchecked().first).single;
      expect(formatQuantity(item.quantity, item.unit), '3 pièces');
    });

    test('changer d’unité avec jumeau : Tomates 300 g et 2 pièces, la ligne '
        'pièces → 200 g : une seule ligne « 500 g », la ligne éditée, '
        'manuelle ; le jumeau supprimé logiquement', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      now = 1500;
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      final items = await repo.watchUnchecked().first;
      final grammes = items.singleWhere((i) => i.unit == Unit.g).lineId;
      final pieces = items.singleWhere((i) => i.unit == Unit.piece).lineId;
      final twinContribution = (await contributionsOf(grammes)).single;
      now = 2000;

      await repo.setQuantity(pieces, 200, unit: Unit.g);

      final item = (await repo.watchUnchecked().first).single;
      expect(item.lineId, pieces);
      expect(item.checked, isFalse);
      expect((item.unit, item.quantity), (Unit.g, 500));
      expect(formatQuantity(item.quantity, item.unit), '500 g');
      final line = await lineOf(pieces);
      expect(line.addedAt, 1500);
      expect(line.manualAt, 2000);
      expect(line.unit, 'g');
      final twin = await lineOf(grammes);
      expect(twin.deletedAt, 2000);
      expect(twin.updatedAt, 2000);
      // La contribution du jumeau passe sur la ligne éditée, active.
      final moved = (await contributionsOf(pieces))
          .singleWhere((c) => c.id == twinContribution.id);
      expect(moved.deletedAt, isNull);
      expect(moved.quantity, 300);
      expect(moved.updatedAt, 2000);
      expect(await contributionsOf(grammes), isEmpty);
      final active = [
        for (final c in await contributionsOf(pieces))
          if (c.deletedAt == null) c,
      ];
      expect(
        active.map((c) => (c.source, c.quantity)),
        unorderedEquals([
          (ContributionSource.ajout, 300),
          (ContributionSource.edition, 200),
        ]),
      );
    });

    test('vider avec une ligne sans quantité du même article : fusion dans '
        'la ligne éditée', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      final grammes = await lineIdOf('Tomates');
      now = 1500;
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      final pieces = (await repo.watchUnchecked().first)
          .singleWhere((i) => i.unit == Unit.piece)
          .lineId;
      now = 2000;
      // La ligne pièces devient sans quantité : deux lignes, g et « - ».
      await repo.setQuantity(pieces, null);
      expect(await repo.watchUnchecked().first, hasLength(2));
      now = 3000;

      await repo.setQuantity(grammes, null, unit: Unit.g);

      final item = (await repo.watchUnchecked().first).single;
      expect(item.lineId, grammes);
      expect(item.quantity, isNull);
      expect(item.unit, isNull);
      expect((await lineOf(pieces)).deletedAt, 3000);
      final line = await lineOf(grammes);
      expect(line.addedAt, 1000);
      expect(line.manualAt, 3000);
    });

    test('ligne cochée : changer d’unité ne fusionne jamais', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      final cochee = await lineIdOf('Tomates');
      now = 1500;
      await repo.check(cochee);
      now = 1600;
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      now = 2000;

      await repo.setQuantity(cochee, 4000, unit: Unit.piece);

      expect(await repo.watchUnchecked().first, hasLength(1));
      final checked = (await repo.watchChecked().first).single;
      expect(checked.lineId, cochee);
      expect((checked.unit, checked.quantity), (Unit.piece, 4000));
    });

    test('saisie en kg : Riz sans quantité, « 1,5 » kg → 1500 g, lu '
        '« 1,5 kg »', () async {
      await repo.addArticle(SeedIds.riz);
      final id = await lineIdOf('Riz');
      final value = storedQuantity('1,5', InputUnit.kg)!;

      await repo.setQuantity(id, value.quantity, unit: value.unit);

      expect((await lineOf(id)).unit, 'g');
      final item = (await repo.watchUnchecked().first).single;
      expect((item.unit, item.quantity), (Unit.g, 1500));
      expect(formatQuantity(item.quantity, item.unit), '1,5 kg');
    });

    test('saisie en L : Lait, « 2 » L → 2000 ml, lu « 2 l »', () async {
      await repo.addArticle(SeedIds.lait);
      final id = await lineIdOf('Lait');
      final value = storedQuantity('2', InputUnit.l)!;

      await repo.setQuantity(id, value.quantity, unit: value.unit);

      final item = (await repo.watchUnchecked().first).single;
      expect((item.unit, item.quantity), (Unit.ml, 2000));
      expect(formatQuantity(item.quantity, item.unit), '2 l');
    });

    test('échec : rien n’est écrit, jumeau compris', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      now = 1500;
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      final pieces = (await repo.watchUnchecked().first)
          .singleWhere((i) => i.unit == Unit.piece)
          .lineId;
      final linesBefore = await db.select(db.listLines).get();
      final contributionsBefore = await db.select(db.listContributions).get();
      await db.customStatement(
        'CREATE TRIGGER no_manual BEFORE UPDATE OF manual_at ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      now = 2000;

      await expectLater(
        repo.setQuantity(pieces, 200, unit: Unit.g),
        throwsA(anything),
      );

      expect(await db.select(db.listLines).get(), linesBefore);
      expect(await db.select(db.listContributions).get(), contributionsBefore);
    });

    test('inchangée : rien n’est écrit, manual_at reste nul', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);
      await repo.addArticle(SeedIds.lardons);
      final tomates = await lineIdOf('Tomates');
      final lardons = await lineIdOf('Lardons');
      final linesBefore = await db.select(db.listLines).get();
      final contributionsBefore = await db.select(db.listContributions).get();
      now = 2000;

      await repo.setQuantity(tomates, 500, unit: Unit.g);
      await repo.setQuantity(lardons, null);
      await repo.setQuantity(lardons, 0, unit: Unit.g);

      expect(await db.select(db.listLines).get(), linesBefore);
      expect(await db.select(db.listContributions).get(), contributionsBefore);
      expect((await lineOf(tomates)).manualAt, isNull);
    });

    test('rayon : seule la ligne change, l’article reste ; la ligne passe '
        'sous Plats préparés', () async {
      await repo.addArticle(SeedIds.lardons, quantity: 200, unit: Unit.g);
      final id = await lineIdOf('Lardons');
      Future<Article> lardons() => (db.select(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lardons))).getSingle();
      final articleBefore = await lardons();
      now = 2000;

      await repo.setRayon(id, Rayon.platsPrepares);

      final line = await lineOf(id);
      expect(line.rayon, 'plats-prepares');
      expect(line.updatedAt, 2000);
      expect(line.manualAt, isNull);
      expect(await lardons(), articleBefore);
      final items = await repo.watchUnchecked().first;
      expect(items.single.rayon, Rayon.platsPrepares);
      expect(items.single.quantity, 200);
      expect(
        groupByRoute(items, Rayon.values).single.rayon,
        Rayon.platsPrepares,
      );

      // Même rayon : rien n'est écrit.
      now = 3000;
      await repo.setRayon(id, Rayon.platsPrepares);
      expect((await lineOf(id)).updatedAt, 2000);
    });

    test('ligne cochée : corriger, changer de rayon, supprimer', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      final id = await lineIdOf('Tomates');
      now = 2000;
      await repo.check(id);
      now = 3000;

      await repo.setQuantity(id, 300, unit: Unit.g);
      await repo.setRayon(id, Rayon.divers);

      final item = (await repo.watchChecked().first).single;
      expect(item.quantity, 300);
      expect(item.rayon, Rayon.divers);
      expect(item.checked, isTrue);
      expect(await repo.removeLine(id), isNotEmpty);
      expect(await repo.watchChecked().first, isEmpty);
    });

    test('ligne absente : rien n’est écrit, suppression rend une liste '
        'vide', () async {
      await repo.addArticle(SeedIds.riz, quantity: 300, unit: Unit.g);
      final id = await lineIdOf('Riz');
      await repo.removeLine(id);
      final linesBefore = await db.select(db.listLines).get();
      final contributionsBefore = await db.select(db.listContributions).get();
      now = 5000;

      expect(await repo.removeLine(id), isEmpty);
      expect(await repo.removeLine('inconnu'), isEmpty);
      await repo.setQuantity(id, 200, unit: Unit.g);
      await repo.setQuantity('inconnu', 200, unit: Unit.g);
      await repo.setRayon(id, Rayon.divers);
      await repo.setRayon('inconnu', Rayon.divers);

      expect(await db.select(db.listLines).get(), linesBefore);
      expect(await db.select(db.listContributions).get(), contributionsBefore);
    });

    test('entrée invalide : quantité négative refusée, rien n’est '
        'écrit', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      final id = await lineIdOf('Tomates');
      final linesBefore = await db.select(db.listLines).get();
      final contributionsBefore = await db.select(db.listContributions).get();

      await expectLater(repo.setQuantity(id, -1), throwsArgumentError);

      expect(await db.select(db.listLines).get(), linesBefore);
      expect(await db.select(db.listContributions).get(), contributionsBefore);
    });

    test('quantité sans unité : refusée, rien n’est écrit', () async {
      await repo.addArticle(SeedIds.lardons);
      final id = await lineIdOf('Lardons');

      await expectLater(repo.setQuantity(id, 300), throwsArgumentError);

      expect((await lineOf(id)).manualAt, isNull);
      expect((await activeOf(id)).source, ContributionSource.ajout);
    });
  });
  group('dans la liste et retirer depuis le Panneau + (AD-4, AD-10)', () {
    Future<List<ListLine>> linesOf(String articleId) => (db.select(
      db.listLines,
    )..where((l) => l.articleId.equals(articleId))).get();

    Future<List<ListContribution>> contributionsOfLines(List<String> lineIds) =>
        (db.select(
          db.listContributions,
        )..where((c) => c.lineId.isIn(lineIds))).get();

    /// Lait coché (2 pièces), puis Lait 500 g + 200 g et Lait 1 pièce, non
    /// cochés. Rend l'id de la ligne cochée.
    Future<String> laitTroisLignes() async {
      await repo.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
      final checkedId = (await linesOf(SeedIds.lait)).single.id;
      await repo.check(checkedId);
      now = 1500;
      await repo.addArticle(SeedIds.lait, quantity: 500, unit: Unit.g);
      await repo.addArticle(SeedIds.lait, quantity: 200, unit: Unit.g);
      await repo.addArticle(SeedIds.lait, quantity: 1000, unit: Unit.piece);
      return checkedId;
    }

    test('liste vide : aucun article dans la liste', () async {
      expect(await repo.watchInListArticleIds().first, isEmpty);
    });

    test('Lait avec une ligne non cochée : dans la liste', () async {
      await repo.addArticle(SeedIds.lait);
      await repo.addArticle(SeedIds.riz, quantity: 500, unit: Unit.g);
      expect(await repo.watchInListArticleIds().first, {
        SeedIds.lait,
        SeedIds.riz,
      });
    });

    test('Lait avec sa seule ligne cochée : pas dans la liste', () async {
      await repo.addArticle(SeedIds.lait);
      await repo.check((await linesOf(SeedIds.lait)).single.id);
      expect(await repo.watchInListArticleIds().first, isEmpty);
    });

    test('ligne supprimée ou article supprimé : pas dans la liste', () async {
      await repo.addArticle(SeedIds.lait);
      await repo.addArticle(SeedIds.riz);
      await repo.removeLine((await linesOf(SeedIds.lait)).single.id);
      await (db.update(db.articles)..where((a) => a.id.equals(SeedIds.riz)))
          .write(const ArticlesCompanion(deletedAt: Value(1)));
      expect(await repo.watchInListArticleIds().first, isEmpty);
    });

    test('le flux suit la liste dans les deux sens', () async {
      final states = <Set<String>>[];
      final sub = repo.watchInListArticleIds().listen(states.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.addArticle(SeedIds.lait);
      await pumpEventQueue();
      await repo.removeArticle(SeedIds.lait);
      await pumpEventQueue();
      expect(states, [
        <String>{},
        {SeedIds.lait},
        <String>{},
      ]);
    });

    test('retirer Lait en g et en pièces, plus une ligne cochée : les deux '
        'lignes non cochées et leurs contributions supprimées logiquement, la '
        'cochée intacte', () async {
      final checkedId = await laitTroisLignes();
      final checkedBefore = (await linesOf(SeedIds.lait))
          .singleWhere((l) => l.id == checkedId);
      now = 2000;

      final rows = await repo.removeArticle(SeedIds.lait);

      final lines = await linesOf(SeedIds.lait);
      final removed = lines.where((l) => l.id != checkedId).toList();
      expect(removed, hasLength(2));
      for (final l in removed) {
        expect(l.deletedAt, 2000);
        expect(l.updatedAt, 2000);
      }
      final removedContributions = await contributionsOfLines([
        for (final l in removed) l.id,
      ]);
      expect(removedContributions, hasLength(3));
      expect(removedContributions.every((c) => c.deletedAt == 2000), isTrue);

      expect(lines.singleWhere((l) => l.id == checkedId), checkedBefore);
      final checkedContribution = (await contributionsOfLines([checkedId]))
          .single;
      expect(checkedContribution.deletedAt, isNull);

      expect(rows, hasLength(5));
      expect(rows.where((r) => r.table == db.listLines), hasLength(2));
      expect(rows.where((r) => r.table == db.listContributions), hasLength(3));
      expect(await repo.watchUnchecked().first, isEmpty);
      expect((await repo.watchChecked().first).single.lineId, checkedId);
      expect(await repo.watchInListArticleIds().first, isEmpty);
    });

    test('retirer un article sans ligne non cochée : rien n’est écrit, liste '
        'rendue vide', () async {
      await repo.addArticle(SeedIds.lait);
      await repo.check((await linesOf(SeedIds.lait)).single.id);
      final linesBefore = await db.select(db.listLines).get();
      final contributionsBefore = await db.select(db.listContributions).get();

      expect(await repo.removeArticle(SeedIds.lait), isEmpty);
      expect(await repo.removeArticle(SeedIds.riz), isEmpty);

      expect(await db.select(db.listLines).get(), linesBefore);
      expect(await db.select(db.listContributions).get(), contributionsBefore);
    });

    test('annuler juste après le retrait : les deux lignes reviennent telles '
        'quelles', () async {
      await laitTroisLignes();
      final itemsBefore = await repo.watchUnchecked().first;
      final linesBefore = await linesOf(SeedIds.lait);
      final undo = Undo(db, clock);
      now = 2000;

      final entry = undo.record(await repo.removeArticle(SeedIds.lait));
      now = 3000;
      expect(await undo.undo(entry), isTrue);

      final items = await repo.watchUnchecked().first;
      expect(
        [for (final i in items) (i.lineId, i.unit, i.quantity, i.rayon)],
        [for (final i in itemsBefore) (i.lineId, i.unit, i.quantity, i.rayon)],
      );
      expect(
        [for (final i in items) (i.unit, i.quantity)],
        [(Unit.g, 700), (Unit.piece, 1000)],
      );
      final linesAfter = await linesOf(SeedIds.lait);
      for (final before in linesBefore) {
        final after = linesAfter.singleWhere((l) => l.id == before.id);
        expect(after.deletedAt, isNull);
        expect(after.addedAt, before.addedAt);
        expect(after.checkedAt, before.checkedAt);
        expect(after.unit, before.unit);
      }
      expect(
        (await db.select(db.listContributions).get()).every(
          (c) => c.deletedAt == null,
        ),
        isTrue,
      );
      expect(await repo.watchInListArticleIds().first, {SeedIds.lait});
    });
  });

  test('fréquents en liste plate : rayons dans l’ordre du parcours, puis '
      'position dans un rayon', () {
    CatalogueArticle article(String id, Rayon rayon) => CatalogueArticle(
      id: id,
      name: id,
      rayon: rayon,
      unit: null,
      pictoKey: id,
    );
    final frequents = [
      article('lait', Rayon.cremerie),
      article('pommes', Rayon.fruitsLegumes),
      article('beurre', Rayon.cremerie),
      article('pain', Rayon.boulangerie),
    ];
    String ids(List<CatalogueArticle> articles) =>
        articles.map((a) => a.id).join(' ');

    expect(
      ids(
        frequentsInRoute(frequents, [
          Rayon.fruitsLegumes,
          Rayon.boulangerie,
          Rayon.cremerie,
        ]),
      ),
      'pommes pain lait beurre',
    );
    // Parcours modifié : Crèmerie avant Fruits & légumes.
    expect(
      ids(
        frequentsInRoute(frequents, [
          Rayon.cremerie,
          Rayon.surgeles,
          Rayon.fruitsLegumes,
          Rayon.boulangerie,
        ]),
      ),
      'lait beurre pommes pain',
    );
    expect(frequentsInRoute(const [], Rayon.values), isEmpty);
  });

  group('ajout et crayon du Panneau + (AD-4)', () {
    Future<ListLine> lineOf(String id) =>
        (db.select(db.listLines)..where((l) => l.id.equals(id))).getSingle();
    Future<ListContribution> contributionOf(String id) => (db.select(
      db.listContributions,
    )..where((c) => c.id.equals(id))).getSingle();

    test('ajout : rend la contribution ajout et sa ligne', () async {
      final added = await repo.addArticle(SeedIds.oeufs);
      final c = await contributionOf(added.contributionId);
      expect(c.lineId, added.lineId);
      expect(c.source, ContributionSource.ajout);
      expect((await lineOf(added.lineId)).articleId, SeedIds.oeufs);
    });

    test('firstUnchecked : la plus ancienne ligne non cochée, avec sa '
        'quantité ; null hors liste', () async {
      expect(await repo.firstUnchecked(SeedIds.tomates), isNull);
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      final first = (await repo.watchUnchecked().first).single;
      now = 2000;
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      await repo.addArticle(SeedIds.lait);

      final item = await repo.firstUnchecked(SeedIds.tomates);
      expect(item!.lineId, first.lineId);
      expect((item.unit, item.quantity), (Unit.piece, 2000));
      expect(item.name, 'Tomates');
      expect(item.articleUnit, Unit.g);
      expect(item.checked, isFalse);

      // Cochée : la suivante ; toutes cochées : null.
      await repo.check(first.lineId);
      final next = await repo.firstUnchecked(SeedIds.tomates);
      expect((next!.unit, next.quantity), (Unit.g, 300));
      await repo.check(next.lineId);
      expect(await repo.firstUnchecked(SeedIds.tomates), isNull);
    });

    test('firstUnchecked : à added_at égal, le plus petit id', () async {
      await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
      await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
      await db
          .update(db.listLines)
          .write(const ListLinesCompanion(addedAt: Value(1000)));
      final lines = await db.select(db.listLines).get();
      expect(lines, hasLength(2));
      final smallest = (lines.map((l) => l.id).toList()..sort()).first;

      expect((await repo.firstUnchecked(SeedIds.tomates))!.lineId, smallest);
    });
  });

  group('contribution de recette (AD-4)', () {
    test('une contribution week_selection par appel, fusionnée avec la '
        'ligne de son unité', () async {
      await repo.addArticle(SeedIds.lardons, quantity: 100, unit: Unit.g);
      await db.transaction(() async {
        await repo.addRecipeContribution(
          SeedIds.lardons,
          weekSelectionId: 'selection-1',
          quantity: 200,
          unit: Unit.g,
        );
        await repo.addRecipeContribution(
          SeedIds.lardons,
          weekSelectionId: 'selection-2',
          quantity: 200,
          unit: Unit.g,
        );
      });

      final items = await repo.watchUnchecked().first;
      expect(items, hasLength(1));
      expect((items.single.quantity, items.single.unit), (500, Unit.g));
      final contributions = await (db.select(
        db.listContributions,
      )..where((c) => c.source.equals(ContributionSource.weekSelection))).get();
      expect(contributions.map((c) => c.weekSelectionId).toSet(), {
        'selection-1',
        'selection-2',
      });
      expect(
        contributions.every((c) => c.lineId == items.single.lineId),
        isTrue,
      );
    });

    test('sans quantité : rejoint la ligne de l’article ; ligne cochée : '
        'nouvelle ligne', () async {
      final checked = await repo.addArticle(
        SeedIds.oeufs,
        quantity: 6000,
        unit: Unit.piece,
      );
      await repo.check(checked.lineId);
      final added = await repo.addRecipeContribution(
        SeedIds.oeufs,
        weekSelectionId: 'selection-1',
        quantity: 3000,
        unit: Unit.piece,
      );
      expect(added.lineId, isNot(checked.lineId));
      final poivre = await repo.addRecipeContribution(
        SeedIds.oeufs,
        weekSelectionId: 'selection-2',
      );
      expect(poivre.lineId, added.lineId);
      final line = (await repo.watchUnchecked().first).single;
      expect(
        (line.quantity, line.unit, line.rayon),
        (3000, Unit.piece, Rayon.cremerie),
      );
    });
  });

  group('retrait d’une sélection (AD-4, AD-5)', () {
    Future<AddedContribution> recipe(
      String articleId,
      String selectionId, {
      int? quantity,
      Unit? unit,
    }) => db.transaction(
      () => repo.addRecipeContribution(
        articleId,
        weekSelectionId: selectionId,
        quantity: quantity,
        unit: unit,
      ),
    );

    Future<List<UndoRow>> remove(String selectionId) =>
        db.transaction(() => repo.removeSelectionContributions(selectionId));

    Future<ListLine> lineOf(String id) =>
        (db.select(db.listLines)..where((l) => l.id.equals(id))).getSingle();

    Future<ListContribution> contributionOf(String id) => (db.select(
      db.listContributions,
    )..where((c) => c.id.equals(id))).getSingle();

    test('quantités fusionnées : Tomates 300 g (Chili) + 200 g (Quiche), '
        'Chili retiré : « Tomates 200 g »', () async {
      final chili = await recipe(
        SeedIds.tomates,
        'chili',
        quantity: 300,
        unit: Unit.g,
      );
      final quiche = await recipe(
        SeedIds.tomates,
        'quiche',
        quantity: 200,
        unit: Unit.g,
      );
      final lineBefore = await lineOf(chili.lineId);
      now = 2000;

      final rows = await remove('chili');

      final item = (await repo.watchUnchecked().first).single;
      expect(
        (item.lineId, item.quantity, item.unit),
        (chili.lineId, 200, Unit.g),
      );
      final removed = await contributionOf(chili.contributionId);
      expect((removed.deletedAt, removed.updatedAt), (2000, 2000));
      expect((await contributionOf(quiche.contributionId)).deletedAt, isNull);
      // La ligne garde une contribution chiffrée : elle ne change pas.
      expect(await lineOf(chili.lineId), lineBefore);
      expect(rows, hasLength(1));
      expect(rows.single.table, db.listContributions);
    });

    test('ligne seule : supprimée logiquement, état d’avant rendu', () async {
      final chili = await recipe(
        SeedIds.viandeHachee,
        'chili',
        quantity: 500,
        unit: Unit.g,
      );
      now = 2000;

      final rows = await remove('chili');

      final line = await lineOf(chili.lineId);
      expect((line.deletedAt, line.updatedAt), (2000, 2000));
      expect(await repo.watchUnchecked().first, isEmpty);
      expect(rows.where((r) => r.table == db.listLines), hasLength(1));
      expect(rows.where((r) => r.table == db.listContributions), hasLength(1));
    });

    test('ligne cochée : rien ne change, rien n’est écrit', () async {
      final chili = await recipe(
        SeedIds.riz,
        'chili',
        quantity: 300,
        unit: Unit.g,
      );
      await repo.check(chili.lineId);
      final lines = await db.select(db.listLines).get();
      final contributions = await db.select(db.listContributions).get();
      final last = clock.last;

      expect(await remove('chili'), isEmpty);

      expect(clock.last, last);
      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.listContributions).get(), contributions);
      final item = (await repo.watchChecked().first).single;
      expect((item.quantity, item.unit), (300, Unit.g));
    });

    test('ligne corrigée à la main : garde sa quantité et ses '
        'contributions', () async {
      final ajout = await repo.addArticle(
        SeedIds.lardons,
        quantity: 100,
        unit: Unit.g,
      );
      await repo.setQuantity(ajout.lineId, 250, unit: Unit.g);
      final chili = await recipe(
        SeedIds.lardons,
        'chili',
        quantity: 200,
        unit: Unit.g,
      );
      expect(chili.lineId, ajout.lineId);
      final lines = await db.select(db.listLines).get();
      final contributions = await db.select(db.listContributions).get();

      expect(await remove('chili'), isEmpty);

      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.listContributions).get(), contributions);
      expect((await repo.watchUnchecked().first).single.quantity, 450);
    });

    test('mêlée à un ajout sans quantité : ligne gardée, sans quantité ni '
        'unité ; une contribution chiffrée suivante la rejoint', () async {
      final chili = await recipe(
        SeedIds.riz,
        'chili',
        quantity: 300,
        unit: Unit.g,
      );
      final ajout = await repo.addArticle(SeedIds.riz);
      expect(ajout.lineId, chili.lineId);
      now = 2000;

      final rows = await remove('chili');

      final line = await lineOf(chili.lineId);
      expect((line.deletedAt, line.unit, line.updatedAt), (null, null, 2000));
      final item = (await repo.watchUnchecked().first).single;
      expect((item.quantity, item.unit), (null, null));
      expect(rows.where((r) => r.table == db.listLines), hasLength(1));

      final next = await repo.addArticle(
        SeedIds.riz,
        quantity: 2000,
        unit: Unit.piece,
      );
      expect(next.lineId, chili.lineId);
      final after = (await repo.watchUnchecked().first).single;
      expect((after.quantity, after.unit), (2000, Unit.piece));
    });

    test('seules les contributions actives de cette sélection ; une '
        'contribution déjà supprimée ne bouge pas', () async {
      final first = await recipe(
        SeedIds.oignons,
        'chili',
        quantity: 2000,
        unit: Unit.piece,
      );
      await (db.update(
        db.listContributions,
      )..where((c) => c.id.equals(first.contributionId))).write(
        const ListContributionsCompanion(
          deletedAt: Value(1500),
          updatedAt: Value(1500),
        ),
      );
      final kept = await recipe(
        SeedIds.oignons,
        'ratatouille',
        quantity: 1000,
        unit: Unit.piece,
      );
      final deletedBefore = await contributionOf(first.contributionId);

      expect(await remove('chili'), isEmpty);
      expect(await contributionOf(first.contributionId), deletedBefore);
      expect((await contributionOf(kept.contributionId)).deletedAt, isNull);
      expect(await remove('inconnue'), isEmpty);
    });

    test('article qui a déjà une ligne sans unité : la ligne garde son unité, '
        'sans quantité ; une seule ligne sans unité (AD-4)', () async {
      final a = await recipe(
        SeedIds.lardons,
        'carbonara',
        quantity: 200,
        unit: Unit.g,
      );
      final b = await repo.addArticle(
        SeedIds.lardons,
        quantity: 2000,
        unit: Unit.piece,
      );
      expect(b.lineId, isNot(a.lineId));
      await repo.setQuantity(b.lineId, null);
      expect((await lineOf(b.lineId)).unit, isNull);
      final ajout = await repo.addArticle(SeedIds.lardons);
      expect(ajout.lineId, a.lineId);
      now = 2000;

      await remove('carbonara');

      final unitless =
          await (db.select(db.listLines)..where(
                (l) =>
                    l.articleId.equals(SeedIds.lardons) &
                    l.deletedAt.isNull() &
                    l.checkedAt.isNull() &
                    l.unit.isNull(),
              ))
              .get();
      expect(unitless.map((l) => l.id), [b.lineId]);
      final lineA = await lineOf(a.lineId);
      expect((lineA.deletedAt, lineA.unit), (null, Unit.g.code));
      final itemA = (await repo.watchUnchecked().first).singleWhere(
        (i) => i.lineId == a.lineId,
      );
      expect(itemA.quantity, isNull);
    });

    test('Annuler : lignes et contributions exactement comme avant', () async {
      await recipe(SeedIds.tomates, 'chili', quantity: 300, unit: Unit.g);
      await recipe(SeedIds.tomates, 'quiche', quantity: 200, unit: Unit.g);
      await recipe(SeedIds.viandeHachee, 'chili', quantity: 500, unit: Unit.g);
      await recipe(SeedIds.riz, 'chili', quantity: 300, unit: Unit.g);
      await repo.addArticle(SeedIds.riz);
      Future<List<Map<String, dynamic>>> snapshot() async => [
        for (final l in await db.select(db.listLines).get())
          l.toJson()..remove('updatedAt'),
        for (final c in await db.select(db.listContributions).get())
          c.toJson()..remove('updatedAt'),
      ];
      final before = await snapshot();
      final undo = Undo(db, clock);
      now = 2000;

      final entry = undo.record(await remove('chili'));
      expect(await snapshot(), isNot(before));
      now = 3000;
      expect(await undo.undo(entry), isTrue);

      expect(await snapshot(), before);
    });
  });
}
