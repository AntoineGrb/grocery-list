import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';

import '../helpers/test_db.dart';

/// Vide la liste puis échoue, dans la transaction de l'action.
class _FailingListeRepository extends ListeRepository {
  _FailingListeRepository(super.db, super.clock);

  @override
  Future<List<UndoRow>> clearList() async {
    await super.clearList();
    throw StateError('échec simulé');
  }
}

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository repo;
  late Undo undo;
  late TerminerLesCourses terminer;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    repo = ListeRepository(db, clock);
    undo = Undo(db, clock);
    terminer = TerminerLesCourses(db, repo, undo);
  });
  tearDown(() => db.close());

  /// Tomates 500 g et Riz cochées ; une ligne Lait déjà supprimée.
  Future<void> tomatesRizCochesLaitSupprime() async {
    await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
    await repo.addArticle(SeedIds.riz);
    await repo.addArticle(SeedIds.lait);
    now = 1500;
    final stamp = clock.stamp();
    await (db.update(
      db.listLines,
    )..where((l) => l.articleId.equals(SeedIds.lait))).write(
      ListLinesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
    );
    now = 2000;
    for (final item in await repo.watchUnchecked().first) {
      await repo.check(item.lineId);
    }
  }

  test('Terminer : lignes actives et contributions supprimées, Lait '
      'inchangée', () async {
    await tomatesRizCochesLaitSupprime();
    final laitBefore = await (db.select(
      db.listLines,
    )..where((l) => l.articleId.equals(SeedIds.lait))).get();
    expect(laitBefore.every((l) => l.deletedAt != null), isTrue);
    final activeBefore = await (db.select(
      db.listLines,
    )..where((l) => l.deletedAt.isNull())).get();
    expect(activeBefore, hasLength(2));

    now = 3000;
    final entry = await terminer();
    expect(entry, isNotNull);

    expect(await repo.watchUnchecked().first, isEmpty);
    expect(await repo.watchChecked().first, isEmpty);
    for (final l in activeBefore) {
      final after = await (db.select(
        db.listLines,
      )..where((x) => x.id.equals(l.id))).getSingle();
      expect(after.deletedAt, isNotNull);
      expect(after.updatedAt, after.deletedAt);
      expect(after.updatedAt, greaterThan(l.updatedAt));
    }
    final contributions = await (db.select(
      db.listContributions,
    )..where((c) => c.lineId.isIn([for (final l in activeBefore) l.id]))).get();
    expect(contributions, hasLength(2));
    expect(contributions.every((c) => c.deletedAt != null), isTrue);

    final laitAfter = await (db.select(
      db.listLines,
    )..where((l) => l.articleId.equals(SeedIds.lait))).get();
    expect(
      [for (final l in laitAfter) (l.id, l.updatedAt, l.deletedAt)],
      [for (final l in laitBefore) (l.id, l.updatedAt, l.deletedAt)],
    );
  });

  test('Annuler juste après Terminer : liste restaurée telle quelle', () async {
    await tomatesRizCochesLaitSupprime();
    final linesBefore = await db.select(db.listLines).get();
    final contributionsBefore = await db.select(db.listContributions).get();
    final checkedBefore = await repo.watchChecked().first;

    now = 3000;
    final entry = (await terminer())!;
    final linesCleared = await db.select(db.listLines).get();
    final actionStamp = linesCleared
        .map((l) => l.updatedAt)
        .reduce((a, b) => a > b ? a : b);

    now = 4000;
    expect(await undo.undo(entry), isTrue);

    final linesAfter = {
      for (final l in await db.select(db.listLines).get()) l.id: l,
    };
    for (final b in linesBefore) {
      final a = linesAfter[b.id]!;
      expect(a.deletedAt, b.deletedAt);
      expect(a.checkedAt, b.checkedAt);
      expect(a.addedAt, b.addedAt);
      expect(a.unit, b.unit);
      if (b.deletedAt == null) {
        expect(a.updatedAt, greaterThan(actionStamp));
      } else {
        // Lait reste supprimée, non touchée.
        expect(a.updatedAt, b.updatedAt);
      }
    }
    final contributionsAfter = {
      for (final c in await db.select(db.listContributions).get()) c.id: c,
    };
    final clearedLineIds = {
      for (final l in linesBefore)
        if (l.deletedAt == null) l.id,
    };
    for (final b in contributionsBefore) {
      final a = contributionsAfter[b.id]!;
      expect(a.deletedAt, b.deletedAt);
      expect(a.quantity, b.quantity);
      expect(a.lineId, b.lineId);
      if (clearedLineIds.contains(b.lineId)) {
        expect(a.updatedAt, greaterThan(actionStamp));
      } else {
        // La contribution de Lait (ligne déjà supprimée) n'est pas touchée.
        expect(a.updatedAt, b.updatedAt);
      }
    }

    final checkedAfter = await repo.watchChecked().first;
    expect(
      [for (final i in checkedAfter) (i.lineId, i.name, i.quantity, i.unit)],
      [for (final i in checkedBefore) (i.lineId, i.name, i.quantity, i.unit)],
    );
    expect(await repo.watchUnchecked().first, isEmpty);
  });

  test('liste vide : rien n’est écrit ni enregistré, rend null', () async {
    expect(await terminer(), isNull);
    expect(clock.last, 0);
    expect(await db.select(db.listLines).get(), isEmpty);

    // Vider une liste déjà vidée : l'emplacement garde l'entrée précédente,
    // toujours applicable puisque rien n'a été écrit.
    await repo.addArticle(SeedIds.lait);
    final cleared = (await terminer())!;
    final linesBefore = await db.select(db.listLines).get();
    final last = clock.last;

    expect(await terminer(), isNull);
    expect(clock.last, last);
    expect(await db.select(db.listLines).get(), linesBefore);
    expect(await undo.undo(cleared), isTrue);
    expect(await repo.watchUnchecked().first, hasLength(1));
  });

  test('échec de l’action : rien n’est écrit, rien n’est enregistré', () async {
    await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
    await repo.addArticle(SeedIds.riz);
    final linesBefore = await db.select(db.listLines).get();
    final contributionsBefore = await db.select(db.listContributions).get();
    final failing = TerminerLesCourses(
      db,
      _FailingListeRepository(db, clock),
      undo,
    );

    await expectLater(failing(), throwsStateError);

    expect(await db.select(db.listLines).get(), linesBefore);
    expect(await db.select(db.listContributions).get(), contributionsBefore);
    expect(await repo.watchUnchecked().first, hasLength(2));
  });
}
