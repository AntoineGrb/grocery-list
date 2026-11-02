import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

import '../helpers/test_db.dart';

Map<String, Object?> _article(String id, String name, String rayon) => {
  'id': id,
  'name': name,
  'rayon': rayon,
  'unit': 'g',
  'picto_key': 'x',
};

String _frequentsFile(int version, List<String> articleIds) => jsonEncode({
  'seed_version': version,
  'frequents': [
    for (final id in articleIds) {'article_id': id},
  ],
});

/// Les `article_id` de `assets/seed/frequents.json`, dans l'ordre du fichier.
Future<List<String>> _realFrequentArticleIds() async {
  final json = jsonDecode(
    await diskAssetLoader(SeedLoader.frequentsPath),
  ) as Map<String, dynamic>;
  return [
    for (final f in json['frequents'] as List)
      (f as Map)['article_id'] as String,
  ];
}

Future<int> _realArticleCount() async {
  final json = jsonDecode(
    await diskAssetLoader(SeedLoader.articlesPath),
  ) as Map<String, dynamic>;
  return (json['articles'] as List).length;
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  group('frequentId', () {
    test('UUID v5 stable et déterministe', () {
      final id = frequentId(SeedIds.lait);
      // Valeur figée : ne doit jamais changer (fusion à l'import, AD-9).
      expect(id, frequentId(SeedIds.lait));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
      );
      expect(id, _laitFrequentId);
      expect(frequentId(SeedIds.riz), isNot(id));
    });
  });

  test('installation neuve : articles et fréquents à updated_at 0', () async {
    await seedLoader(db).run();

    final articles = await db.select(db.articles).get();
    expect(articles.length, await _realArticleCount());
    expect(articles.every((a) => a.updatedAt == 0), isTrue);
    expect(articles.every((a) => a.deletedAt == null), isTrue);
    for (final a in articles) {
      expect(a.normalizedName, normalizeName(a.name));
    }
    for (final o in originalArticles) {
      final a = articles.singleWhere((a) => a.id == o['id']);
      expect(
        (a.name, a.rayon, a.unit, a.pictoKey),
        (o['name'], o['rayon'], o['unit'], o['picto_key']),
      );
    }

    final expectedArticleIds = await _realFrequentArticleIds();
    final frequents = await (db.select(
      db.frequents,
    )..orderBy([(f) => OrderingTerm(expression: f.position)])).get();
    expect(frequents.map((f) => f.articleId), expectedArticleIds);
    for (final (i, f) in frequents.indexed) {
      expect(f.id, frequentId(f.articleId));
      expect(f.position, i);
      expect(f.updatedAt, 0);
      expect(f.deletedAt, isNull);
    }

    final settings = await db.select(db.settings).getSingle();
    expect(settings.id, SettingsRepository.rowId);
    expect(settings.updatedAt, 0);
    expect(settings.routeOrder.split(',').length, 13);
    expect(jsonDecode(settings.seedVersions), {
      'articles': 2,
      'frequents': 1,
      'recettes': 1,
    });
    expect(settings.firstLaunch, isFalse);
  });

  test('montée de version depuis la v1 : rien d’écrasé ni de recréé', () async {
    // Base de la story 1 : les 7 articles, pas de fichier de fréquents
    // (version 0, rien inséré).
    final v1 = jsonEncode({'seed_version': 1, 'articles': originalArticles});
    await seedLoader(
      db,
      loadAsset: assetLoaderWith({
        SeedLoader.articlesPath: v1,
        SeedLoader.frequentsPath: _frequentsFile(0, const []),
        SeedLoader.recettesPath: emptyRecettesFile(0),
      }),
    ).run();
    expect(await db.select(db.articles).get(), hasLength(7));
    expect(await db.select(db.frequents).get(), isEmpty);
    expect(
      jsonDecode((await db.select(db.settings).getSingle()).seedVersions),
      {'articles': 1},
    );

    // Antoine renomme Lait, supprime Riz et a une liste en cours.
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).write(
      const ArticlesCompanion(
        name: Value('Lait demi-écrémé'),
        normalizedName: Value('laitdemiecreme'),
        updatedAt: Value(10),
      ),
    );
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.riz))).write(
      const ArticlesCompanion(deletedAt: Value(20), updatedAt: Value(20)),
    );
    await db
        .into(db.listLines)
        .insert(
          ListLinesCompanion.insert(
            id: 'ligne-1',
            updatedAt: 30,
            articleId: SeedIds.tomates,
            rayon: 'fruits-legumes',
            addedAt: 30,
          ),
        );
    final linesBefore = await db.select(db.listLines).get();

    await seedLoader(db, clock: Clock(now: () => 5000)).run();

    final articles = await db.select(db.articles).get();
    expect(articles.length, await _realArticleCount());
    final lait = articles.singleWhere((a) => a.id == SeedIds.lait);
    expect((lait.name, lait.updatedAt), ('Lait demi-écrémé', 10));
    final riz = articles.singleWhere((a) => a.id == SeedIds.riz);
    expect((riz.deletedAt, riz.updatedAt), (20, 20));
    expect(articles.where((a) => a.updatedAt == 0).length, articles.length - 2);
    // Le fréquent de Riz est inséré : son article est en base (supprimé).
    expect(
      (await db.select(db.frequents).get()).map((f) => f.articleId).toSet(),
      (await _realFrequentArticleIds()).toSet(),
    );
    expect(await db.select(db.listLines).get(), linesBefore);
    // Les recettes exemples arrivent sur un téléphone qui tournait l'epic 1 ;
    // l'ingrédient Riz (article supprimé) compte comme présent.
    expect(await db.select(db.recipes).get(), hasLength(4));
    final chiliIngredients = await (db.select(
      db.recipeIngredients,
    )..where((i) => i.recipeId.equals(SeedRecipeIds.chili))).get();
    expect(chiliIngredients.map((i) => i.articleId), contains(SeedIds.riz));
    final settings = await db.select(db.settings).getSingle();
    expect(jsonDecode(settings.seedVersions), {
      'articles': 2,
      'frequents': 1,
      'recettes': 1,
    });
    expect(settings.updatedAt, 5000);
    expect(settings.firstLaunch, isFalse);
  });

  test('redémarrage : rien inséré ni modifié, supprimés compris', () async {
    await seedLoader(db).run();
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.lait))).write(
      const ArticlesCompanion(
        name: Value('Lait demi-écrémé'),
        updatedAt: Value(10),
      ),
    );
    await (db.update(
      db.articles,
    )..where((a) => a.id.equals(SeedIds.riz))).write(
      const ArticlesCompanion(deletedAt: Value(20), updatedAt: Value(20)),
    );
    await (db.update(
      db.frequents,
    )..where((f) => f.id.equals(frequentId(SeedIds.lait)))).write(
      const FrequentsCompanion(deletedAt: Value(30), updatedAt: Value(30)),
    );
    final before = await db.select(db.articles).get();
    final frequentsBefore = await db.select(db.frequents).get();
    final settingsBefore = await db.select(db.settings).getSingle();

    await seedLoader(db).run();

    expect(await db.select(db.articles).get(), before);
    expect(await db.select(db.frequents).get(), frequentsBefore);
    expect(await db.select(db.settings).getSingle(), settingsBefore);
  });

  test('fréquent supprimé : pas recréé par une version supérieure', () async {
    await seedLoader(db).run();
    final laitFrequent = frequentId(SeedIds.lait);
    await (db.update(
      db.frequents,
    )..where((f) => f.id.equals(laitFrequent))).write(
      const FrequentsCompanion(deletedAt: Value(30), updatedAt: Value(30)),
    );
    final before = await db.select(db.frequents).get();
    final v1Ids = await _realFrequentArticleIds();
    expect(v1Ids, isNot(contains(SeedIds.courgettes)));

    await seedLoader(
      db,
      loadAsset: assetLoaderWith({
        SeedLoader.frequentsPath: _frequentsFile(2, [
          ...v1Ids,
          SeedIds.courgettes,
        ]),
      }),
    ).run();

    // Le fréquent absent (Courgettes) est inséré ; les présents, inchangés.
    final courgettesFrequent = frequentId(SeedIds.courgettes);
    final after = await db.select(db.frequents).get();
    expect(after.where((f) => f.id != courgettesFrequent).toList(), before);
    final courgettes = after.singleWhere((f) => f.id == courgettesFrequent);
    expect(
      (courgettes.articleId, courgettes.position, courgettes.deletedAt),
      (SeedIds.courgettes, v1Ids.length, null),
    );
    final lait = await (db.select(
      db.frequents,
    )..where((f) => f.id.equals(laitFrequent))).getSingle();
    expect((lait.deletedAt, lait.updatedAt), (30, 30));
    expect(
      jsonDecode((await db.select(db.settings).getSingle()).seedVersions),
      {'articles': 2, 'frequents': 2, 'recettes': 1},
    );
  });

  test('article d’un fréquent absent : ce fréquent est sauté', () async {
    // Un « Beurre » actif existe déjà : l'article fourni est sauté, donc son
    // fréquent aussi, sans erreur de clé étrangère.
    const userBeurre = '11111111-1111-4111-8111-111111111111';
    await db
        .into(db.articles)
        .insert(
          ArticlesCompanion.insert(
            id: userBeurre,
            updatedAt: 1,
            name: 'beurre',
            normalizedName: 'beurre',
            rayon: 'cremerie',
            pictoKey: 'beurre',
          ),
        );

    await seedLoader(db).run();

    final articles = await db.select(db.articles).get();
    final beurres = articles.where((a) => a.normalizedName == 'beurre');
    expect(beurres.map((a) => a.id), [userBeurre]);
    expect(articles.length, await _realArticleCount());

    final frequentArticleIds = (await db.select(db.frequents).get())
        .map((f) => f.articleId)
        .toSet();
    final expected = (await _realFrequentArticleIds()).toSet();
    final articleIds = articles.map((a) => a.id).toSet();
    expect(frequentArticleIds, expected.intersection(articleIds));
    expect(frequentArticleIds.length, expected.length - 1);
    expect(frequentArticleIds, contains(SeedIds.lait));
  });

  test(
    'nouvelle version : insère les seuls UUID absents, sans mise à jour',
    () async {
      await seedLoader(db).run();
      final count = (await db.select(db.articles).get()).length;
      await (db.update(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lait))).write(
        const ArticlesCompanion(
          name: Value('Lait entier'),
          updatedAt: Value(10),
        ),
      );

      final v3 = jsonEncode({
        'seed_version': 3,
        'articles': [
          _article(SeedIds.lait, 'Lait', 'cremerie'),
          _article(
            '7d1c2f0e-3b8a-4c5d-9e6f-0a1b2c3d4e5f',
            'Kumquats',
            'fruits-legumes',
          ),
        ],
      });
      await seedLoader(
        db,
        clock: Clock(now: () => 5000),
        loadAsset: assetLoaderWith({
          SeedLoader.articlesPath: v3,
          SeedLoader.frequentsPath: _frequentsFile(1, [SeedIds.lait]),
        }),
      ).run();

      final articles = await db.select(db.articles).get();
      expect(articles.length, count + 1);
      expect(
        articles.singleWhere((a) => a.id == SeedIds.lait).name,
        'Lait entier',
      );
      final settings = await db.select(db.settings).getSingle();
      expect(jsonDecode(settings.seedVersions), {
        'articles': 3,
        'frequents': 1,
        'recettes': 1,
      });
      expect(settings.updatedAt, 5000);
    },
  );

  test('article fourni nommé comme un article hors catalogue : inséré, les '
      'lignes lui sont reportées, l’article hors catalogue supprimé', () async {
    await seedLoader(db).run();
    const typedId = '33333333-3333-4333-8333-333333333333';
    const kumquatsId = '7d1c2f0e-3b8a-4c5d-9e6f-0a1b2c3d4e5f';
    await db
        .into(db.articles)
        .insert(
          ArticlesCompanion.insert(
            id: typedId,
            updatedAt: 100,
            name: 'Kumquats',
            normalizedName: 'kumquats',
            rayon: 'divers',
            pictoKey: 'kumquats',
            inCatalogue: const Value(false),
          ),
        );
    for (final (id, checkedAt) in [('l1', null), ('l2', 150)]) {
      await db
          .into(db.listLines)
          .insert(
            ListLinesCompanion.insert(
              id: id,
              updatedAt: 200,
              articleId: typedId,
              rayon: 'entretien',
              addedAt: 120,
              checkedAt: Value(checkedAt),
            ),
          );
    }

    final v3 = jsonEncode({
      'seed_version': 3,
      'articles': [_article(kumquatsId, ' KUMQUATS', 'fruits-legumes')],
    });
    await seedLoader(
      db,
      clock: Clock(now: () => 5000),
      loadAsset: assetLoaderWith({
        SeedLoader.articlesPath: v3,
        SeedLoader.frequentsPath: _frequentsFile(3, [kumquatsId]),
      }),
    ).run();

    final kumquats = await (db.select(
      db.articles,
    )..where((a) => a.id.equals(kumquatsId))).getSingle();
    expect(kumquats.inCatalogue, isTrue);
    expect(kumquats.updatedAt, 0);
    expect(kumquats.rayon, 'fruits-legumes');
    final typed = await (db.select(
      db.articles,
    )..where((a) => a.id.equals(typedId))).getSingle();
    expect(typed.deletedAt, greaterThanOrEqualTo(5000));
    expect(typed.updatedAt, typed.deletedAt);

    final lines = await (db.select(
      db.listLines,
    )..orderBy([(l) => OrderingTerm.asc(l.id)])).get();
    expect([for (final l in lines) l.articleId], [kumquatsId, kumquatsId]);
    expect(lines.every((l) => l.updatedAt >= 5000), isTrue);
    // Rien d'autre ne change sur les lignes.
    expect([for (final l in lines) l.rayon], ['entretien', 'entretien']);
    expect([for (final l in lines) l.checkedAt], [null, 150]);
    expect(lines.every((l) => l.deletedAt == null), isTrue);

    // Le fréquent de l'article fourni est inséré.
    final frequents = await (db.select(
      db.frequents,
    )..where((f) => f.articleId.equals(kumquatsId))).get();
    expect(frequents, hasLength(1));
    // Un seul article actif de ce nom.
    final active =
        await (db.select(db.articles)..where(
              (a) => a.normalizedName.equals('kumquats') & a.deletedAt.isNull(),
            ))
            .get();
    expect(active.single.id, kumquatsId);
  });

  test('article fourni nommé comme un article du catalogue : sauté', () async {
    await seedLoader(db).run();
    const otherId = '44444444-4444-4444-8444-444444444444';
    final before = await db.select(db.articles).get();

    final v3 = jsonEncode({
      'seed_version': 3,
      'articles': [_article(otherId, 'LAIT', 'cremerie')],
    });
    await seedLoader(
      db,
      loadAsset: assetLoaderWith({
        SeedLoader.articlesPath: v3,
        SeedLoader.frequentsPath: _frequentsFile(1, []),
      }),
    ).run();

    expect(await db.select(db.articles).get(), before);
  });

  group('recettes exemples', () {
    test('installation neuve : 4 recettes et leurs ingrédients, à '
        'updated_at 0', () async {
      await seedLoader(db).run();

      final recipes = await db.select(db.recipes).get();
      expect(recipes.map((r) => r.id).toSet(), {
        SeedRecipeIds.carbonara,
        SeedRecipeIds.chili,
        SeedRecipeIds.quiche,
        SeedRecipeIds.ratatouille,
      });
      expect(recipes.every((r) => r.updatedAt == 0), isTrue);
      expect(recipes.every((r) => r.photo == null), isTrue);
      final carbonara = recipes.singleWhere(
        (r) => r.id == SeedRecipeIds.carbonara,
      );
      expect(carbonara.name, 'Pâtes carbonara');

      final ingredients =
          await (db.select(db.recipeIngredients)
                ..where((i) => i.recipeId.equals(SeedRecipeIds.carbonara))
                ..orderBy([(i) => OrderingTerm.asc(i.position)]))
              .get();
      expect(
        [for (final i in ingredients) (i.articleId, i.quantity, i.unit)],
        [
          (SeedIds.pates, 500, 'g'),
          (SeedIds.lardons, 200, 'g'),
          (SeedIds.oeufs, 3000, 'piece'),
          (_parmesan, 60, 'g'),
          (SeedIds.poivre, null, null),
        ],
      );
      expect([for (final i in ingredients) i.position], [0, 1, 2, 3, 4]);
      expect(
        (await db.select(db.recipeIngredients).get()).every(
          (i) => i.updatedAt == 0,
        ),
        isTrue,
      );
      expect(await db.select(db.weekSelections).get(), isEmpty);
    });

    test('redémarrage et version supérieure : recette modifiée ou supprimée '
        'jamais réécrite ni recréée', () async {
      await seedLoader(db).run();
      await (db.update(
        db.recipes,
      )..where((r) => r.id.equals(SeedRecipeIds.chili))).write(
        const RecipesCompanion(
          name: Value('Chili maison'),
          updatedAt: Value(10),
        ),
      );
      await (db.update(
        db.recipes,
      )..where((r) => r.id.equals(SeedRecipeIds.quiche))).write(
        const RecipesCompanion(deletedAt: Value(20), updatedAt: Value(20)),
      );
      await (db.update(db.recipeIngredients)..where(
            (i) =>
                i.recipeId.equals(SeedRecipeIds.carbonara) &
                i.articleId.equals(SeedIds.poivre),
          ))
          .write(
            const RecipeIngredientsCompanion(
              deletedAt: Value(30),
              updatedAt: Value(30),
            ),
          );
      final recipesBefore = await db.select(db.recipes).get();
      final ingredientsBefore = await db.select(db.recipeIngredients).get();

      await seedLoader(db).run();
      expect(await db.select(db.recipes).get(), recipesBefore);
      expect(await db.select(db.recipeIngredients).get(), ingredientsBefore);

      final file = await diskAssetLoader(SeedLoader.recettesPath);
      final v2 = (jsonDecode(file) as Map<String, dynamic>)
        ..['seed_version'] = 2;
      await seedLoader(
        db,
        loadAsset: assetLoaderWith({SeedLoader.recettesPath: jsonEncode(v2)}),
      ).run();
      expect(await db.select(db.recipes).get(), recipesBefore);
      expect(await db.select(db.recipeIngredients).get(), ingredientsBefore);
      expect(
        jsonDecode((await db.select(db.settings).getSingle()).seedVersions),
        {'articles': 2, 'frequents': 1, 'recettes': 2},
      );
    });

    test('ingrédient dont l’article est absent : sauté ; recette sans '
        'ingrédient : sautée', () async {
      final file = jsonEncode({
        'seed_version': 1,
        'recettes': [
          {
            'id': _recipeA,
            'name': 'Riz au lait',
            'ingredients': [
              _ingredient(_ingredientA1, SeedIds.riz, 200, 'g'),
              _ingredient(_ingredientA2, _unknownArticle, 1000, 'piece'),
              _ingredient(_ingredientA3, SeedIds.lait, 1000, 'piece'),
            ],
          },
          {
            'id': _recipeB,
            'name': 'Mystère',
            'ingredients': [
              _ingredient(_ingredientB1, _unknownArticle, null, null),
            ],
          },
        ],
      });
      await seedLoader(
        db,
        loadAsset: assetLoaderWith({SeedLoader.recettesPath: file}),
      ).run();

      expect((await db.select(db.recipes).get()).map((r) => r.id), [_recipeA]);
      final ingredients = await (db.select(
        db.recipeIngredients,
      )..orderBy([(i) => OrderingTerm.asc(i.position)])).get();
      expect(
        [for (final i in ingredients) (i.id, i.position)],
        [(_ingredientA1, 0), (_ingredientA3, 2)],
      );
    });

    for (final (label, ingredient, name) in [
      ('UUID en double', _ingredient(_recipeA, SeedIds.riz, null, null), 'A'),
      (
        'recette sans nom',
        _ingredient(_ingredientA1, SeedIds.riz, null, null),
        '  ',
      ),
      (
        'quantité sans unité',
        _ingredient(_ingredientA1, SeedIds.riz, 200, null),
        'A',
      ),
      ('unité inconnue', _ingredient(_ingredientA1, SeedIds.riz, 2, 'kg'), 'A'),
    ]) {
      test('fichier de recettes invalide ($label) : rien d’écrit', () async {
        await expectLater(
          seedLoader(
            db,
            loadAsset: assetLoaderWith({
              SeedLoader.recettesPath: jsonEncode({
                'seed_version': 1,
                'recettes': [
                  {
                    'id': _recipeA,
                    'name': name,
                    'ingredients': [ingredient],
                  },
                ],
              }),
            }),
          ).run(),
          throwsFormatException,
        );
        expect(await db.select(db.articles).get(), isEmpty);
        expect(await db.select(db.recipes).get(), isEmpty);
        expect(await db.select(db.settings).get(), isEmpty);
      });
    }
  });

  test('fichier d’articles invalide : erreur et rien d’écrit', () async {
    final bad = jsonEncode({
      'seed_version': 1,
      'articles': [
        _article(SeedIds.lait, 'Lait', 'cremerie'),
        _article(SeedIds.riz, 'Riz', 'rayon-inconnu'),
      ],
    });
    await expectLater(
      seedLoader(
        db,
        loadAsset: assetLoaderWith({SeedLoader.articlesPath: bad}),
      ).run(),
      throwsFormatException,
    );
    expect(await db.select(db.articles).get(), isEmpty);
    expect(await db.select(db.settings).get(), isEmpty);
  });

  for (final (label, articleIds) in [
    ('article absent d’articles.json', [SeedIds.lait, _unknownArticle]),
    ('fréquent en double', [SeedIds.lait, SeedIds.riz, SeedIds.lait]),
  ]) {
    test('fichier de fréquents invalide ($label) : rien d’écrit', () async {
      await expectLater(
        seedLoader(
          db,
          loadAsset: assetLoaderWith({
            SeedLoader.frequentsPath: _frequentsFile(1, articleIds),
          }),
        ).run(),
        throwsFormatException,
      );
      expect(await db.select(db.articles).get(), isEmpty);
      expect(await db.select(db.frequents).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
    });
  }

  test('échec pendant l’écriture : la transaction est annulée', () async {
    // Articles et fréquents s'insèrent, puis l'insertion des réglages échoue.
    await db.customStatement(
      'CREATE TRIGGER boom BEFORE INSERT ON settings '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    await expectLater(seedLoader(db).run(), throwsA(anything));
    expect(await db.select(db.articles).get(), isEmpty);
    expect(await db.select(db.frequents).get(), isEmpty);
  });
}

const _unknownArticle = '22222222-2222-4222-8222-222222222222';
const _parmesan = '6ef25bed-155f-4462-8218-58d665ed0dab';
const _recipeA = '55555555-5555-4555-8555-555555555551';
const _recipeB = '55555555-5555-4555-8555-555555555552';
const _ingredientA1 = '66666666-6666-4666-8666-666666666661';
const _ingredientA2 = '66666666-6666-4666-8666-666666666662';
const _ingredientA3 = '66666666-6666-4666-8666-666666666663';
const _ingredientB1 = '66666666-6666-4666-8666-666666666664';

Map<String, Object?> _ingredient(
  String id,
  String articleId,
  int? quantity,
  String? unit,
) => {'id': id, 'article_id': articleId, 'quantity': quantity, 'unit': unit};

/// `frequentId(SeedIds.lait)`, figé.
const _laitFrequentId = '1265e470-f634-566b-a103-339309569e28';
