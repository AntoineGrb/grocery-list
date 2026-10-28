import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository repo;
  late Undo undo;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    repo = ListeRepository(db, clock);
    undo = Undo(db, clock);
  });
  tearDown(() => db.close());

  Future<ListLine> line(String id) =>
      (db.select(db.listLines)..where((l) => l.id.equals(id))).getSingle();

  /// Coche la ligne de Lait puis enregistre son état d'avant : Annuler la
  /// décochera.
  Future<(ListLine, UndoEntry)> checkLaitUndoable() async {
    await repo.addArticle(SeedIds.lait);
    final before = await db.select(db.listLines).getSingle();
    now = 2000;
    await repo.check(before.id);
    final entry = undo.record([UndoRow.before(db.listLines, before)]);
    return (before, entry);
  }

  test(
    'Annuler : état d’avant réécrit, updated_at neuf, une seule fois',
    () async {
      final (before, entry) = await checkLaitUndoable();
      final checked = await line(before.id);
      expect(checked.checkedAt, 2000);

      now = 3000;
      expect(await undo.undo(entry), isTrue);

      final restored = await line(before.id);
      expect(restored.checkedAt, isNull);
      expect(restored.deletedAt, isNull);
      expect(restored.addedAt, before.addedAt);
      expect(restored.updatedAt, greaterThan(checked.updatedAt));

      // L'emplacement est vide : un second Annuler ne fait rien.
      expect(await undo.undo(entry), isFalse);
    },
  );

  test('Annuler réécrit aussi une colonne remise à nul (deleted_at)', () async {
    await repo.addArticle(SeedIds.lait);
    final before = await db.select(db.listLines).getSingle();
    final stamp = clock.stamp();
    await (db.update(db.listLines)..where((l) => l.id.equals(before.id))).write(
      ListLinesCompanion(deletedAt: Value(stamp)),
    );
    final entry = undo.record([UndoRow.before(db.listLines, before)]);

    expect(await undo.undo(entry), isTrue);
    expect((await line(before.id)).deletedAt, isNull);
  });

  test(
    'écriture entre-temps : Annuler rend false et ne restaure rien',
    () async {
      await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
      await repo.addArticle(SeedIds.riz);
      final cleared = await db.select(db.listLines).get();
      for (final l in cleared) {
        await repo.check(l.id);
      }
      now = 2000;
      final entry = (await TerminerLesCourses(db, repo, undo)())!;

      now = 3000;
      await repo.addArticle(SeedIds.tomates);

      expect(await undo.undo(entry), isFalse);
      for (final l in cleared) {
        expect((await line(l.id)).deletedAt, isNotNull);
      }
      final active = await (db.select(
        db.listLines,
      )..where((l) => l.deletedAt.isNull())).get();
      expect(active, hasLength(1));
      expect(active.single.articleId, SeedIds.tomates);
      expect(active.single.id, isNot(isIn([for (final l in cleared) l.id])));
      expect(active.single.checkedAt, isNull);
      expect(await repo.watchChecked().first, isEmpty);
    },
  );

  test('fin du snackbar : clear(entrée) puis Annuler rend false', () async {
    final (before, entry) = await checkLaitUndoable();
    undo.clear(entry);

    expect(await undo.undo(entry), isFalse);
    expect((await line(before.id)).checkedAt, 2000);
  });

  test(
    'nouvelle action : A remplacée par B ; clear(A) ne vide pas B',
    () async {
      final (before, a) = await checkLaitUndoable();
      final b = undo.record([UndoRow.before(db.listLines, before)]);

      expect(await undo.undo(a), isFalse);
      undo.clear(a);
      expect(await undo.undo(b), isTrue);
      expect((await line(before.id)).checkedAt, isNull);
    },
  );

  test('clear() sans entrée vide l’emplacement', () async {
    final (_, entry) = await checkLaitUndoable();
    undo.clear();
    expect(await undo.undo(entry), isFalse);
  });

  test('ligne créée par l’action : Annuler la supprime logiquement', () async {
    await repo.addArticle(SeedIds.lait);
    final created = await db.select(db.listLines).getSingle();
    final entry = undo.record([UndoRow.absent(db.listLines, created.id)]);

    now = 3000;
    expect(await undo.undo(entry), isTrue);

    final deleted = await line(created.id);
    expect(deleted.deletedAt, isNotNull);
    expect(deleted.updatedAt, deleted.deletedAt);
    expect(deleted.updatedAt, greaterThan(created.updatedAt));
    expect(await repo.watchUnchecked().first, isEmpty);
  });

  test('échec d’Annuler : lève et n’écrit rien', () async {
    final (before, _) = await checkLaitUndoable();
    // La seconde ligne est invalide (colonnes obligatoires absentes).
    final entry = undo.record([
      UndoRow.before(db.listLines, before),
      UndoRow.before(
        db.listLines,
        const ListLinesCompanion(id: Value('invalide')),
      ),
    ]);

    await expectLater(undo.undo(entry), throwsA(anything));
    final after = await line(before.id);
    expect(after.checkedAt, 2000);
    expect(await db.select(db.listLines).get(), hasLength(1));
    expect(await undo.undo(entry), isFalse);
  });
}
