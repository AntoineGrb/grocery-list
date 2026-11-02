import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/failing_clear_selections.dart';
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
  late RecettesRepository recettes;
  late Undo undo;
  late TerminerLesCourses terminer;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    repo = ListeRepository(db, clock);
    recettes = RecettesRepository(db, clock);
    undo = Undo(db, clock);
    terminer = TerminerLesCourses(db, repo, recettes, undo);
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

  group('sélection de la semaine (R10)', () {
    /// Sélectionne [recipeIds], puis Ajouter à la liste depuis leur Revue.
    Future<void> validate(List<String> recipeIds) async {
      for (final id in recipeIds) {
        await recettes.select(id);
      }
      final pending = await recettes.pendingSelections();
      await AjouterALaListe(db, repo, recettes)(
        buildRevue(
          selectionIds: pending.selectionIds,
          ingredients: pending.ingredients,
          routeOrder: Rayon.values,
        ),
      );
    }

    Future<void> checkAll() async {
      for (final item in await repo.watchUnchecked().first) {
        await repo.check(item.lineId);
      }
    }

    /// Les trois tables, `updated_at` exclu.
    Future<List<Map<String, dynamic>>> snapshot() async => [
      for (final l in await db.select(db.listLines).get())
        l.toJson()..remove('updatedAt'),
      for (final c in await db.select(db.listContributions).get())
        c.toJson()..remove('updatedAt'),
      for (final s in await db.select(db.weekSelections).get())
        s.toJson()..remove('updatedAt'),
    ];

    test('deux recettes validées, tout coché : liste vide, sélections '
        'supprimées logiquement, cartes désélectionnées', () async {
      await validate([SeedRecipeIds.carbonara, SeedRecipeIds.quiche]);
      await checkAll();
      final before = await db.select(db.weekSelections).get();
      expect(before, hasLength(2));
      now = 5000;

      expect(await terminer(), isNotNull);

      expect(await repo.watchUnchecked().first, isEmpty);
      expect(await repo.watchChecked().first, isEmpty);
      for (final b in before) {
        final a = await (db.select(
          db.weekSelections,
        )..where((s) => s.id.equals(b.id))).getSingle();
        expect(a.deletedAt, isNotNull);
        expect(a.updatedAt, a.deletedAt);
        expect(a.updatedAt, greaterThan(b.updatedAt));
        expect(a.validatedAt, b.validatedAt);
      }
      final cards = await recettes.watchCards().first;
      expect(cards.every((c) => !c.selected && !c.validated), isTrue);
      expect((await recettes.pendingSelections()).selectionIds, isEmpty);
    });

    test('sélection non validée et sélection déjà supprimée : la première '
        'supprimée, la seconde inchangée', () async {
      await validate([SeedRecipeIds.carbonara]);
      await checkAll();
      await recettes.select(SeedRecipeIds.chili);
      await recettes.deselect(SeedRecipeIds.chili);
      await recettes.select(SeedRecipeIds.ratatouille);
      final deleted = (await db.select(db.weekSelections).get()).singleWhere(
        (s) => s.deletedAt != null,
      );

      await terminer();

      final after = await db.select(db.weekSelections).get();
      expect(after.every((s) => s.deletedAt != null), isTrue);
      expect(after.singleWhere((s) => s.id == deleted.id), deleted);
    });

    test('Annuler juste après : lignes cochées, contributions et sélections '
        'validées exactement comme avant', () async {
      await validate([SeedRecipeIds.carbonara, SeedRecipeIds.quiche]);
      await checkAll();
      final before = await snapshot();
      final checkedBefore = await repo.watchChecked().first;
      now = 5000;

      final entry = (await terminer())!;
      expect(await snapshot(), isNot(before));
      now = 6000;
      expect(await undo.undo(entry), isTrue);

      expect(await snapshot(), before);
      expect(
        [for (final i in await repo.watchChecked().first) i.lineId],
        [for (final i in checkedBefore) i.lineId],
      );
      final cards = await recettes.watchCards().first;
      final selected = {
        for (final c in cards)
          if (c.selected) c.recipeId: c.validated,
      };
      expect(selected, {
        SeedRecipeIds.carbonara: true,
        SeedRecipeIds.quiche: true,
      });
      // Pas de « Valider » : aucune sélection à valider.
      expect((await recettes.pendingSelections()).selectionIds, isEmpty);
    });

    test('autre écriture entre-temps : Annuler sans effet', () async {
      await validate([SeedRecipeIds.carbonara]);
      await checkAll();
      final entry = (await terminer())!;
      await recettes.select(SeedRecipeIds.chili);
      final after = await snapshot();

      expect(await undo.undo(entry), isFalse);
      expect(await snapshot(), after);
    });

    test('liste vide mais une sélection : supprimée, entrée Annuler', () async {
      await recettes.select(SeedRecipeIds.chili);
      final before = await snapshot();

      final entry = await terminer();

      expect(entry, isNotNull);
      expect(
        (await db.select(db.weekSelections).getSingle()).deletedAt,
        isNotNull,
      );
      expect(await undo.undo(entry!), isTrue);
      expect(await snapshot(), before);
    });

    test('échec à la suppression des sélections : rien n’est écrit', () async {
      await validate([SeedRecipeIds.carbonara]);
      await checkAll();
      final before = await snapshot();
      final failing = TerminerLesCourses(
        db,
        repo,
        FailingClearSelectionsRepository(db, clock),
        undo,
      );

      await expectLater(failing(), throwsStateError);

      expect(await snapshot(), before);
    });
  });

  test('échec de l’action : rien n’est écrit, rien n’est enregistré', () async {
    await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
    await repo.addArticle(SeedIds.riz);
    final linesBefore = await db.select(db.listLines).get();
    final contributionsBefore = await db.select(db.listContributions).get();
    final failing = TerminerLesCourses(
      db,
      _FailingListeRepository(db, clock),
      recettes,
      undo,
    );

    await expectLater(failing(), throwsStateError);

    expect(await db.select(db.listLines).get(), linesBefore);
    expect(await db.select(db.listContributions).get(), contributionsBefore);
    expect(await repo.watchUnchecked().first, hasLength(2));
  });
}
