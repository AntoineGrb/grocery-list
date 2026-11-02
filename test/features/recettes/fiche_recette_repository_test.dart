import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';

import '../../helpers/test_db.dart';

/// Lecture et écriture de la Fiche recette (R1, AD-7).
void main() {
  late AppDatabase db;
  late RecettesRepository repo;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    repo = RecettesRepository(db, Clock(now: () => now));
  });
  tearDown(() => db.close());

  Future<Recipe?> recipe(String id) =>
      (db.select(db.recipes)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<List<RecipeIngredient>> ingredients(String recipeId) =>
      (db.select(db.recipeIngredients)
            ..where((i) => i.recipeId.equals(recipeId))
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .get();

  RecipeDraftIngredient ing(
    String id,
    String articleId, [
    int? quantity,
    Unit? unit,
  ]) => RecipeDraftIngredient(
    id: id,
    articleId: articleId,
    quantity: quantity,
    unit: unit,
  );

  group('lecture', () {
    test('Chili con carne : nom, ingrédients actifs par position, unités de '
        'l’ingrédient et de l’article', () async {
      final sheet = (await repo.readSheet(SeedRecipeIds.chili))!;
      expect(sheet.name, 'Chili con carne');
      expect(
        [
          for (final i in sheet.ingredients)
            (i.name, i.quantity, i.unit, i.articleUnit),
        ],
        [
          ('Viande hachée', 500, Unit.g, Unit.g),
          ('Oignons', 2000, Unit.piece, Unit.piece),
          ('Tomates concassées', 400, Unit.g, Unit.g),
          ('Poivrons', 1000, Unit.piece, Unit.piece),
          ('Riz', 300, Unit.g, Unit.g),
        ],
      );
      expect(sheet.ingredients.first.rayon, Rayon.viandePoisson);
    });

    test('ingrédient supprimé ou article supprimé : absent ; recette '
        'absente ou supprimée : nulle', () async {
      await (db.update(db.articles)..where((a) => a.id.equals(SeedIds.riz)))
          .write(const ArticlesCompanion(deletedAt: Value(5)));
      await (db.update(db.recipeIngredients)..where(
            (i) =>
                i.recipeId.equals(SeedRecipeIds.chili) &
                i.articleId.equals(SeedIds.oignons),
          ))
          .write(const RecipeIngredientsCompanion(deletedAt: Value(5)));
      final sheet = (await repo.readSheet(SeedRecipeIds.chili))!;
      expect(sheet.ingredients.map((i) => i.name), [
        'Viande hachée',
        'Tomates concassées',
        'Poivrons',
      ]);

      expect(await repo.readSheet('absente'), isNull);
      await (db.update(db.recipes)
            ..where((r) => r.id.equals(SeedRecipeIds.chili)))
          .write(const RecipesCompanion(deletedAt: Value(5)));
      expect(await repo.readSheet(SeedRecipeIds.chili), isNull);
    });
  });

  group('écriture', () {
    test(
      'nouvelle recette : insérée avec ses ingrédients en position, '
      'horloge et ids du brouillon ; sa carte prend le picto du premier',
      () async {
        final id = repo.newId();
        now = 2000;
        final written = await repo.saveDraft(
          RecipeDraft(
            recipeId: id,
            name: '  Chili   maison ',
            ingredients: [
              ing('i1', SeedIds.tomates, 500, Unit.g),
              ing('i2', SeedIds.oignons, 2000, Unit.piece),
              ing('i3', SeedIds.poivre),
            ],
          ),
        );
        expect(written, isTrue);
        final row = (await recipe(id))!;
        expect(row.name, 'Chili maison');
        expect(row.updatedAt, greaterThanOrEqualTo(2000));
        expect(row.deletedAt, isNull);
        expect(
          [
            for (final i in await ingredients(id))
              (i.id, i.articleId, i.position, i.quantity, i.unit),
          ],
          [
            ('i1', SeedIds.tomates, 0, 500, 'g'),
            ('i2', SeedIds.oignons, 1, 2000, 'piece'),
            ('i3', SeedIds.poivre, 2, null, null),
          ],
        );
        final card = (await repo.watchCards().first).singleWhere(
          (c) => c.recipeId == id,
        );
        expect((card.pictoKey, card.rayon), ('tomates', Rayon.fruitsLegumes));
      },
    );

    test(
      'quantité sans unité, unité sans quantité ou 0 : sans quantité',
      () async {
        final id = repo.newId();
        await repo.saveDraft(
          RecipeDraft(
            recipeId: id,
            name: 'Test',
            ingredients: [
              ing('a', SeedIds.tomates, 500),
              ing('b', SeedIds.riz, null, Unit.g),
              ing('c', SeedIds.lait, 0, Unit.piece),
            ],
          ),
        );
        expect(
          (await ingredients(id))
              .every((i) => i.quantity == null && i.unit == null),
          isTrue,
        );
      },
    );

    test(
      'incomplète (sans nom, nom blanc, sans ingrédient) : rien d’écrit',
      () async {
        final before = (
          await db.select(db.recipes).get(),
          await db.select(db.recipeIngredients).get(),
        );
        for (final draft in [
          RecipeDraft(
            recipeId: 'n1',
            name: '',
            ingredients: [ing('x', SeedIds.riz)],
          ),
          RecipeDraft(
            recipeId: 'n2',
            name: '   ',
            ingredients: [ing('y', SeedIds.riz)],
          ),
          const RecipeDraft(recipeId: 'n3', name: 'Chili', ingredients: []),
        ]) {
          expect(await repo.saveDraft(draft), isFalse);
        }
        expect(await db.select(db.recipes).get(), before.$1);
        expect(await db.select(db.recipeIngredients).get(), before.$2);
      },
    );

    test('recette existante privée de nom ou de tout ingrédient : sa dernière '
        'version valide reste', () async {
      final before = (
        await recipe(SeedRecipeIds.chili),
        await ingredients(SeedRecipeIds.chili),
      );
      final sheet = (await repo.readSheet(SeedRecipeIds.chili))!;
      expect(
        await repo.saveDraft(
          RecipeDraft(
            recipeId: SeedRecipeIds.chili,
            name: '',
            ingredients: [
              for (final i in sheet.ingredients)
                ing(i.id, i.articleId, i.quantity, i.unit),
            ],
          ),
        ),
        isFalse,
      );
      expect(
        await repo.saveDraft(
          const RecipeDraft(
            recipeId: SeedRecipeIds.chili,
            name: 'Chili',
            ingredients: [],
          ),
        ),
        isFalse,
      );
      expect(await recipe(SeedRecipeIds.chili), before.$1);
      expect(await ingredients(SeedRecipeIds.chili), before.$2);
    });

    test(
      'modification : renommée, quantité changée, retiré supprimé '
      'logiquement, positions refaites, lignes inchangées non réécrites',
      () async {
        final sheet = (await repo.readSheet(SeedRecipeIds.chili))!;
        final before = {
          for (final i in await ingredients(SeedRecipeIds.chili)) i.id: i,
        };
        final [viande, oignons, tomates, poivrons, riz] = sheet.ingredients;
        now = 50000;
        final written = await repo.saveDraft(
          RecipeDraft(
            recipeId: SeedRecipeIds.chili,
            name: 'Chili',
            ingredients: [
              ing(viande.id, viande.articleId, viande.quantity, viande.unit),
              // Oignons retirés : Tomates passent en position 1.
              ing(tomates.id, tomates.articleId, 800, Unit.g),
              ing(
                poivrons.id,
                poivrons.articleId,
                poivrons.quantity,
                poivrons.unit,
              ),
              ing(riz.id, riz.articleId, riz.quantity, riz.unit),
              ing('nouveau', SeedIds.lardons, 1500, Unit.g),
            ],
          ),
        );
        expect(written, isTrue);
        expect((await recipe(SeedRecipeIds.chili))!.name, 'Chili');
        final after = {
          for (final i in await ingredients(SeedRecipeIds.chili)) i.id: i,
        };
        // Inchangée : même ligne, même `updated_at`.
        expect(after[viande.id], before[viande.id]);
        expect(after[oignons.id]!.deletedAt, isNotNull);
        expect(after[oignons.id]!.updatedAt, after[oignons.id]!.deletedAt);
        expect(
          (after[tomates.id]!.position, after[tomates.id]!.quantity),
          (1, 800),
        );
        expect(after[tomates.id]!.updatedAt, greaterThanOrEqualTo(50000));
        expect(after[poivrons.id]!.position, 2);
        expect(after[riz.id]!.position, 3);
        expect(
          (after['nouveau']!.position, after['nouveau']!.quantity),
          (4, 1500),
        );
        final reread = (await repo.readSheet(SeedRecipeIds.chili))!;
        expect(reread.ingredients.map((i) => i.name), [
          'Viande hachée',
          'Tomates concassées',
          'Poivrons',
          'Riz',
          'Lardons',
        ]);
      },
    );

    test('recette validée modifiée : ni la liste ni la sélection ne changent '
        '(R7)', () async {
      await repo.select(SeedRecipeIds.chili);
      final selection = (await db.select(db.weekSelections).getSingle());
      await db.transaction(() => repo.markValidated([selection.id]));
      final selections = await db.select(db.weekSelections).get();
      final lines = await db.select(db.listLines).get();
      final contributions = await db.select(db.listContributions).get();
      final sheet = (await repo.readSheet(SeedRecipeIds.chili))!;
      await repo.saveDraft(
        RecipeDraft(
          recipeId: SeedRecipeIds.chili,
          name: sheet.name,
          ingredients: [
            for (final i in sheet.ingredients)
              ing(i.id, i.articleId, 999, Unit.g),
          ],
        ),
      );
      expect(await db.select(db.weekSelections).get(), selections);
      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.listContributions).get(), contributions);
    });

    test('ingrédient dont l’article est supprimé : caché par la fiche, '
        'laissé tel quel par l’écriture', () async {
      await (db.update(db.articles)..where((a) => a.id.equals(SeedIds.riz)))
          .write(const ArticlesCompanion(deletedAt: Value(5)));
      final hidden = (await ingredients(SeedRecipeIds.chili))
          .singleWhere((i) => i.articleId == SeedIds.riz);
      final sheet = (await repo.readSheet(SeedRecipeIds.chili))!;
      expect(sheet.ingredients, hasLength(4));
      expect(
        await repo.saveDraft(
          RecipeDraft(
            recipeId: SeedRecipeIds.chili,
            name: 'Chili',
            ingredients: [
              for (final i in sheet.ingredients)
                ing(i.id, i.articleId, i.quantity, i.unit),
            ],
          ),
        ),
        isTrue,
      );
      expect(
        (await ingredients(SeedRecipeIds.chili))
            .singleWhere((i) => i.id == hidden.id),
        hidden,
      );
    });

    test('recette supprimée : rien d’écrit', () async {
      await (db.update(db.recipes)
            ..where((r) => r.id.equals(SeedRecipeIds.chili)))
          .write(const RecipesCompanion(deletedAt: Value(5)));
      final before = await ingredients(SeedRecipeIds.chili);
      expect(
        await repo.saveDraft(
          RecipeDraft(
            recipeId: SeedRecipeIds.chili,
            name: 'Chili',
            ingredients: [ing('z', SeedIds.riz)],
          ),
        ),
        isFalse,
      );
      expect(await ingredients(SeedRecipeIds.chili), before);
    });
  });
}
