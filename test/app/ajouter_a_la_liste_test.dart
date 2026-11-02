import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/test_db.dart';

/// Écrit les contributions, puis échoue en validant les sélections.
class _FailingRecettesRepository extends RecettesRepository {
  _FailingRecettesRepository(super.db, super.clock);

  @override
  Future<void> markValidated(List<String> selectionIds) async {
    await super.markValidated(selectionIds);
    throw StateError('échec simulé');
  }
}

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository liste;
  late RecettesRepository recettes;
  late AjouterALaListe ajouter;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    liste = ListeRepository(db, clock);
    recettes = RecettesRepository(db, clock);
    ajouter = AjouterALaListe(db, liste, recettes);
  });
  tearDown(() => db.close());

  Future<Revue> revueOf(List<String> recipeIds) async {
    for (final id in recipeIds) {
      await recettes.select(id);
    }
    final pending = await recettes.pendingSelections();
    return buildRevue(
      selectionIds: pending.selectionIds,
      ingredients: pending.ingredients,
      routeOrder: Rayon.values,
    );
  }

  Future<Map<String, String>> selectionByRecipe() async => {
    for (final s in await db.select(db.weekSelections).get()) s.recipeId: s.id,
  };

  test('Carbonara + Quiche : une contribution par ingrédient et par '
      'sélection, fusionnées en lignes ; sélections validées', () async {
    final revue = await revueOf([
      SeedRecipeIds.carbonara,
      SeedRecipeIds.quiche,
    ]);
    now = 2000;
    await ajouter(revue);

    final ids = await selectionByRecipe();
    final contributions = await db.select(db.listContributions).get();
    expect(contributions, hasLength(10));
    expect(
      contributions.every((c) => c.source == ContributionSource.weekSelection),
      isTrue,
    );
    expect(
      contributions.where(
        (c) => c.weekSelectionId == ids[SeedRecipeIds.carbonara],
      ),
      hasLength(5),
    );
    expect(
      contributions.where(
        (c) => c.weekSelectionId == ids[SeedRecipeIds.quiche],
      ),
      hasLength(5),
    );

    final items = await liste.watchUnchecked().first;
    final byName = {for (final i in items) i.name: i};
    expect(items, hasLength(8));
    expect(
      (byName['Lardons']!.quantity, byName['Lardons']!.unit),
      (400, Unit.g),
    );
    expect(
      (byName['Œufs']!.quantity, byName['Œufs']!.unit),
      (6000, Unit.piece),
    );
    expect((byName['Poivre']!.quantity, byName['Poivre']!.unit), (null, null));
    expect(byName['Lardons']!.rayon, Rayon.viandePoisson);

    final selections = await db.select(db.weekSelections).get();
    expect(selections.every((s) => s.validatedAt != null), isTrue);
    expect(selections.every((s) => s.deletedAt == null), isTrue);
    expect((await recettes.pendingSelections()).selectionIds, isEmpty);
  });

  test('ensuite, Ratatouille : la Revue n’en montre que les ingrédients, '
      'Oignons et Poivrons fusionnés avec la liste', () async {
    await ajouter(await revueOf([SeedRecipeIds.chili]));
    final revue = await revueOf([SeedRecipeIds.ratatouille]);
    expect(
      {
        for (final g in revue.groups)
          for (final l in g.lines) l.name,
      },
      {
        'Courgettes',
        'Aubergines',
        'Poivrons',
        'Tomates',
        'Oignons',
        'Huile d\'olive',
        'Herbes de Provence',
      },
    );
    await ajouter(revue);
    final byName = {
      for (final i in await liste.watchUnchecked().first) i.name: i,
    };
    expect(byName['Oignons']!.quantity, 3000);
    expect(byName['Poivrons']!.quantity, 3000);
  });

  test('ligne déjà cochée : nouvelle ligne non cochée (AD-4)', () async {
    final checked = await liste.addArticle(
      SeedIds.lardons,
      quantity: 100,
      unit: Unit.g,
    );
    await liste.check(checked.lineId);

    await ajouter(await revueOf([SeedRecipeIds.carbonara]));

    final lardons = (await liste.watchUnchecked().first).singleWhere(
      (i) => i.articleId == SeedIds.lardons,
    );
    expect(lardons.lineId, isNot(checked.lineId));
    expect(lardons.quantity, 200);
    expect((await liste.watchChecked().first).single.lineId, checked.lineId);
  });

  test('Revue sans ligne : les sélections sont quand même validées', () async {
    await recettes.select(SeedRecipeIds.chili);
    final pending = await recettes.pendingSelections();
    await ajouter(Revue(selectionIds: pending.selectionIds, groups: const []));
    expect(await db.select(db.listContributions).get(), isEmpty);
    expect(
      (await db.select(db.weekSelections).getSingle()).validatedAt,
      isNotNull,
    );
  });

  group('brouillon de la Revue', () {
    RevueLine lineOf(Revue revue, String articleId) =>
        [for (final g in revue.groups) ...g.lines]
            .singleWhere((l) => l.articleId == articleId);

    test('Pâtes décochées, Œufs 6 → 4, Lardons 400 → 300 : ni Pâtes ni '
        'ligne manuelle, parts au prorata', () async {
      final revue = await revueOf([
        SeedRecipeIds.carbonara,
        SeedRecipeIds.quiche,
      ]);
      final oeufs = lineOf(revue, SeedIds.oeufs);
      final lardons = lineOf(revue, SeedIds.lardons);
      expect(oeufs.quantity, 6000);
      await ajouter(
        revue,
        draft: RevueDraft(
          unchecked: {lineOf(revue, SeedIds.pates).key},
          corrections: {oeufs.key: 4000, lardons.key: 300},
        ),
      );

      final ids = await selectionByRecipe();
      final contributions = await db.select(db.listContributions).get();
      final articleOf = {
        for (final l in await db.select(db.listLines).get()) l.id: l.articleId,
      };
      Map<String?, int?> partsOf(String articleId) => {
        for (final c in contributions)
          if (articleOf[c.lineId] == articleId) c.weekSelectionId: c.quantity,
      };
      expect(contributions, hasLength(9));
      expect(partsOf(SeedIds.pates), isEmpty);
      expect(partsOf(SeedIds.oeufs), {
        ids[SeedRecipeIds.carbonara]: 2000,
        ids[SeedRecipeIds.quiche]: 2000,
      });
      expect(partsOf(SeedIds.lardons), {
        ids[SeedRecipeIds.carbonara]: 150,
        ids[SeedRecipeIds.quiche]: 150,
      });

      final items = await liste.watchUnchecked().first;
      final byName = {for (final i in items) i.name: i};
      expect(byName.containsKey('Pâtes'), isFalse);
      expect(
        (byName['Œufs']!.quantity, byName['Œufs']!.unit),
        (4000, Unit.piece),
      );
      expect(byName['Lardons']!.quantity, 300);
      // Une correction de Revue ne rend jamais une ligne manuelle.
      expect(
        (await db.select(db.listLines).get()).every((l) => l.manualAt == null),
        isTrue,
      );
      final selections = await db.select(db.weekSelections).get();
      expect(selections.every((s) => s.validatedAt != null), isTrue);
    });

    test(
      'tout décoché : rien n’est écrit, les sélections sont validées',
      () async {
        final revue = await revueOf([SeedRecipeIds.carbonara]);
        await ajouter(
          revue,
          draft: RevueDraft(
            unchecked: {
              for (final g in revue.groups)
                for (final l in g.lines) l.key,
            },
          ),
        );
        expect(await db.select(db.listLines).get(), isEmpty);
        expect(await db.select(db.listContributions).get(), isEmpty);
        expect(
          (await db.select(db.weekSelections).getSingle()).validatedAt,
          isNotNull,
        );
        expect((await recettes.pendingSelections()).selectionIds, isEmpty);
      },
    );
  });

  test('échec : rien n’est écrit', () async {
    final revue = await revueOf([SeedRecipeIds.carbonara]);
    final selectionsBefore = await db.select(db.weekSelections).get();
    final failing = AjouterALaListe(
      db,
      liste,
      _FailingRecettesRepository(db, clock),
    );

    await expectLater(failing(revue), throwsStateError);

    expect(await db.select(db.listLines).get(), isEmpty);
    expect(await db.select(db.listContributions).get(), isEmpty);
    expect(await db.select(db.weekSelections).get(), selectionsBefore);
  });
}
