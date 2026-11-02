import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Clock clock;
  late RecettesRepository repo;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    repo = RecettesRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<List<WeekSelection>> selections(String recipeId) => (db.select(
    db.weekSelections,
  )..where((s) => s.recipeId.equals(recipeId))).get();

  group('cartes', () {
    test('4 recettes exemples triées par nom, picto et rayon actuels du '
        'premier ingrédient', () async {
      final cards = await repo.watchCards().first;
      expect(cards.map((c) => c.name), [
        'Chili con carne',
        'Pâtes carbonara',
        'Quiche lorraine',
        'Ratatouille',
      ]);
      final chili = cards.first;
      expect(
        (chili.pictoKey, chili.rayon),
        ('viande-hachee', Rayon.viandePoisson),
      );
      final carbonara = cards[1];
      expect(
        (carbonara.pictoKey, carbonara.rayon),
        ('pates', Rayon.epicerieSalee),
      );
      expect(cards.every((c) => !c.selected && !c.validated), isTrue);
    });

    test('rayon de l’article modifié : la carte suit ; premier ingrédient '
        'supprimé : le suivant ; recette supprimée : pas de carte', () async {
      await (db.update(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.pates))).write(
        const ArticlesCompanion(rayon: Value('divers'), updatedAt: Value(5)),
      );
      var carbonara = (await repo.watchCards().first).singleWhere(
        (c) => c.recipeId == SeedRecipeIds.carbonara,
      );
      expect(carbonara.rayon, Rayon.divers);

      await (db.update(db.recipeIngredients)..where(
            (i) =>
                i.recipeId.equals(SeedRecipeIds.carbonara) &
                i.articleId.equals(SeedIds.pates),
          ))
          .write(
            const RecipeIngredientsCompanion(
              deletedAt: Value(6),
              updatedAt: Value(6),
            ),
          );
      carbonara = (await repo.watchCards().first).singleWhere(
        (c) => c.recipeId == SeedRecipeIds.carbonara,
      );
      expect(
        (carbonara.pictoKey, carbonara.rayon),
        ('lardons', Rayon.viandePoisson),
      );

      await (db.update(
        db.recipes,
      )..where((r) => r.id.equals(SeedRecipeIds.quiche))).write(
        const RecipesCompanion(deletedAt: Value(7), updatedAt: Value(7)),
      );
      expect(
        (await repo.watchCards().first).map((c) => c.recipeId),
        isNot(contains(SeedRecipeIds.quiche)),
      );
    });

    test('recette sans ingrédient actif : repli Divers', () async {
      await (db.update(
        db.recipeIngredients,
      )..where((i) => i.recipeId.equals(SeedRecipeIds.chili))).write(
        const RecipeIngredientsCompanion(
          deletedAt: Value(6),
          updatedAt: Value(6),
        ),
      );
      final chili = (await repo.watchCards().first).singleWhere(
        (c) => c.recipeId == SeedRecipeIds.chili,
      );
      expect((chili.pictoKey, chili.rayon), ('', Rayon.divers));
    });
  });

  group('sélection (AD-16)', () {
    test(
      'sélectionner : une ligne active ; deux fois : toujours une',
      () async {
        await repo.select(SeedRecipeIds.chili);
        await repo.select(SeedRecipeIds.chili);
        final rows = await selections(SeedRecipeIds.chili);
        expect(rows, hasLength(1));
        expect((rows.single.validatedAt, rows.single.deletedAt), (null, null));
        expect(rows.single.updatedAt, greaterThanOrEqualTo(1000));
        final chili = (await repo.watchCards().first).first;
        expect((chili.selected, chili.validated), (true, false));
      },
    );

    test('désélectionner une sélection non validée : supprimée logiquement ; '
        'resélectionner : nouvelle ligne', () async {
      await repo.select(SeedRecipeIds.chili);
      now = 2000;
      await repo.deselect(SeedRecipeIds.chili);
      var rows = await selections(SeedRecipeIds.chili);
      expect(rows.single.deletedAt, 2000);
      expect(rows.single.updatedAt, 2000);
      expect((await repo.watchCards().first).first.selected, isFalse);

      await repo.select(SeedRecipeIds.chili);
      rows = await selections(SeedRecipeIds.chili);
      expect(rows, hasLength(2));
      expect(rows.where((s) => s.deletedAt == null), hasLength(1));
    });

    test('désélectionner une sélection validée : rien n’est écrit', () async {
      await repo.select(SeedRecipeIds.chili);
      final id = (await selections(SeedRecipeIds.chili)).single.id;
      await db.transaction(() => repo.markValidated([id]));
      final before = await db.select(db.weekSelections).get();

      await repo.deselect(SeedRecipeIds.chili);
      expect(await db.select(db.weekSelections).get(), before);
      final chili = (await repo.watchCards().first).first;
      expect((chili.selected, chili.validated), (true, true));
    });

    test('recette supprimée : pas de sélection', () async {
      await (db.update(
        db.recipes,
      )..where((r) => r.id.equals(SeedRecipeIds.chili))).write(
        const RecipesCompanion(deletedAt: Value(7), updatedAt: Value(7)),
      );
      await repo.select(SeedRecipeIds.chili);
      expect(await selections(SeedRecipeIds.chili), isEmpty);
    });
  });

  group('sélections à valider', () {
    test('seules les sélections non validées, ingrédients dans l’ordre des '
        'recettes puis position', () async {
      await repo.select(SeedRecipeIds.quiche);
      await repo.select(SeedRecipeIds.carbonara);
      await repo.select(SeedRecipeIds.chili);
      final chili = (await selections(SeedRecipeIds.chili)).single.id;
      await db.transaction(() => repo.markValidated([chili]));

      final pending = await repo.pendingSelections();
      final carbonara = (await selections(SeedRecipeIds.carbonara)).single.id;
      final quiche = (await selections(SeedRecipeIds.quiche)).single.id;
      expect(pending.selectionIds, [carbonara, quiche]);
      expect(
        [
          for (final i in pending.ingredients)
            (i.selectionId, i.name, i.quantity, i.unit),
        ],
        [
          (carbonara, 'Pâtes', 500, Unit.g),
          (carbonara, 'Lardons', 200, Unit.g),
          (carbonara, 'Œufs', 3000, Unit.piece),
          (carbonara, 'Parmesan', 60, Unit.g),
          (carbonara, 'Poivre', null, null),
          (quiche, 'Pâte feuilletée', 1000, Unit.piece),
          (quiche, 'Lardons', 200, Unit.g),
          (quiche, 'Œufs', 3000, Unit.piece),
          (quiche, 'Crème fraîche', 200, Unit.ml),
          (quiche, 'Emmental râpé', 100, Unit.g),
        ],
      );
    });

    test('rien de sélectionné : vide', () async {
      final pending = await repo.pendingSelections();
      expect(pending.selectionIds, isEmpty);
      expect(pending.ingredients, isEmpty);
    });

    test('validées : validated_at et updated_at par l’horloge', () async {
      await repo.select(SeedRecipeIds.chili);
      await repo.select(SeedRecipeIds.quiche);
      final ids = [
        (await selections(SeedRecipeIds.chili)).single.id,
        (await selections(SeedRecipeIds.quiche)).single.id,
      ];
      now = 3000;
      await db.transaction(() => repo.markValidated(ids));
      final rows = await db.select(db.weekSelections).get();
      expect(rows.every((s) => s.validatedAt == 3000), isTrue);
      expect(rows.every((s) => s.updatedAt == 3000), isTrue);
      expect((await repo.pendingSelections()).selectionIds, isEmpty);
    });
  });
}
