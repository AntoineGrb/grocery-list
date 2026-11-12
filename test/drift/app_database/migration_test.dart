import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

/// Un test par étape de migration (AD-14). Chaque version est figée dans
/// `drift_schemas/app_database/`.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v2 : schéma créé conforme au dump', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('v3 : schéma créé conforme au dump', () async {
    final schema = await verifier.schemaAt(3);
    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('v4 : schéma créé conforme au dump', () async {
    final schema = await verifier.schemaAt(4);
    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  for (final from in [1, 2, 3]) {
    test('v$from → v4 : schéma conforme au dump', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });
  }

  test('v3 → v4 : réglages gardés, thème qui suit le téléphone', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.settings,
          v3.SettingsCompanion.insert(
            id: 'settings',
            updatedAt: 7,
            routeOrder: 'boulangerie,cremerie',
            groupByRayon: 0,
            keepScreenOn: 1,
            firstLaunch: 0,
            seedVersions: '{"articles":1}',
          ),
        );
      },
      validateItems: (newDb) async {
        final row = await newDb.select(newDb.settings).getSingle();
        expect(row.id, 'settings');
        expect(row.updatedAt, 7);
        expect(row.routeOrder, 'boulangerie,cremerie');
        expect(row.groupByRayon, 0);
        expect(row.keepScreenOn, 1);
        expect(row.seedVersions, '{"articles":1}');
        expect(row.themeMode, 'system');
      },
    );
  });

  for (final from in [1, 2]) {
    test('v$from → v3 : schéma conforme au dump', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    });
  }

  test('v2 → v3 : articles, lignes et contributions intacts, tables de '
      'recettes créées vides', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.articles, [
          v2.ArticlesCompanion.insert(
            id: _laitId,
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            unit: const Value('piece'),
            pictoKey: 'lait',
          ),
          v2.ArticlesCompanion.insert(
            id: _pilesId,
            updatedAt: 12,
            name: 'Piles',
            normalizedName: 'piles',
            rayon: 'divers',
            pictoKey: 'piles',
            inCatalogue: const Value(0),
          ),
        ]);
        batch.insertAll(oldDb.listLines, [
          v2.ListLinesCompanion.insert(
            id: _lineId,
            updatedAt: 20,
            articleId: _laitId,
            rayon: 'cremerie',
            unit: const Value('piece'),
            addedAt: 20,
          ),
          v2.ListLinesCompanion.insert(
            id: _checkedLineId,
            updatedAt: 31,
            articleId: _pilesId,
            rayon: 'entretien',
            addedAt: 21,
            checkedAt: const Value(30),
            manualAt: const Value(25),
          ),
        ]);
        batch.insertAll(oldDb.listContributions, [
          v2.ListContributionsCompanion.insert(
            id: _contributionId,
            updatedAt: 20,
            lineId: _lineId,
            source: 'ajout',
            quantity: const Value(2000),
            unit: const Value('piece'),
          ),
          v2.ListContributionsCompanion.insert(
            id: _editionId,
            updatedAt: 25,
            lineId: _checkedLineId,
            source: 'edition',
          ),
        ]);
      },
      validateItems: (newDb) async {
        final articles = await (newDb.select(
          newDb.articles,
        )..orderBy([(a) => OrderingTerm.asc(a.id)])).get();
        expect(articles, [
          const v3.ArticlesData(
            id: _laitId,
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            unit: 'piece',
            pictoKey: 'lait',
            inCatalogue: 1,
          ),
          const v3.ArticlesData(
            id: _pilesId,
            updatedAt: 12,
            name: 'Piles',
            normalizedName: 'piles',
            rayon: 'divers',
            pictoKey: 'piles',
            inCatalogue: 0,
          ),
        ]);
        expect(
          await (newDb.select(
            newDb.listLines,
          )..orderBy([(l) => OrderingTerm.asc(l.id)])).get(),
          [
            const v3.ListLinesData(
              id: _lineId,
              updatedAt: 20,
              articleId: _laitId,
              rayon: 'cremerie',
              unit: 'piece',
              addedAt: 20,
            ),
            const v3.ListLinesData(
              id: _checkedLineId,
              updatedAt: 31,
              articleId: _pilesId,
              rayon: 'entretien',
              addedAt: 21,
              checkedAt: 30,
              manualAt: 25,
            ),
          ],
        );
        expect(
          await (newDb.select(
            newDb.listContributions,
          )..orderBy([(c) => OrderingTerm.asc(c.id)])).get(),
          [
            const v3.ListContributionsData(
              id: _contributionId,
              updatedAt: 20,
              lineId: _lineId,
              source: 'ajout',
              quantity: 2000,
              unit: 'piece',
            ),
            const v3.ListContributionsData(
              id: _editionId,
              updatedAt: 25,
              lineId: _checkedLineId,
              source: 'edition',
            ),
          ],
        );
        expect(await newDb.select(newDb.recipes).get(), isEmpty);
        expect(await newDb.select(newDb.recipeIngredients).get(), isEmpty);
        expect(await newDb.select(newDb.weekSelections).get(), isEmpty);
      },
    );
  });

  test('v1 → v3 : articles et liste conservés, tables de recettes '
      'créées vides', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 3,
      createOld: v1.DatabaseAtV1.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.articles,
          v1.ArticlesCompanion.insert(
            id: _laitId,
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            pictoKey: 'lait',
          ),
        );
        batch.insert(
          oldDb.listLines,
          v1.ListLinesCompanion.insert(
            id: _lineId,
            updatedAt: 20,
            articleId: _laitId,
            rayon: 'cremerie',
            addedAt: 20,
          ),
        );
        batch.insert(
          oldDb.listContributions,
          v1.ListContributionsCompanion.insert(
            id: _contributionId,
            updatedAt: 20,
            lineId: _lineId,
            source: 'ajout',
          ),
        );
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.articles).get(), [
          const v3.ArticlesData(
            id: _laitId,
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            pictoKey: 'lait',
            inCatalogue: 1,
          ),
        ]);
        expect(await newDb.select(newDb.listLines).get(), [
          const v3.ListLinesData(
            id: _lineId,
            updatedAt: 20,
            articleId: _laitId,
            rayon: 'cremerie',
            addedAt: 20,
          ),
        ]);
        expect(await newDb.select(newDb.listContributions).get(), [
          const v3.ListContributionsData(
            id: _contributionId,
            updatedAt: 20,
            lineId: _lineId,
            source: 'ajout',
          ),
        ]);
        expect(await newDb.select(newDb.recipes).get(), isEmpty);
        expect(await newDb.select(newDb.recipeIngredients).get(), isEmpty);
        expect(await newDb.select(newDb.weekSelections).get(), isEmpty);
      },
    );
  });

  test('v1 → v2 : schéma conforme au dump', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('v1 → v2 : articles et liste conservés, articles existants au '
      'catalogue (in_catalogue vrai)', () async {
    const laitId = 'a0000000-0000-4000-8000-000000000001';
    const pilesId = 'a0000000-0000-4000-8000-000000000002';
    const lineId = 'b0000000-0000-4000-8000-000000000001';
    const contributionId = 'c0000000-0000-4000-8000-000000000001';

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.articles, [
          v1.ArticlesCompanion.insert(
            id: laitId,
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            unit: const Value('piece'),
            pictoKey: 'lait',
          ),
          v1.ArticlesCompanion.insert(
            id: pilesId,
            updatedAt: 12,
            deletedAt: const Value(13),
            name: 'Piles',
            normalizedName: 'piles',
            rayon: 'divers',
            pictoKey: 'piles',
          ),
        ]);
        batch.insert(
          oldDb.listLines,
          v1.ListLinesCompanion.insert(
            id: lineId,
            updatedAt: 20,
            articleId: laitId,
            rayon: 'cremerie',
            addedAt: 20,
          ),
        );
        batch.insert(
          oldDb.listContributions,
          v1.ListContributionsCompanion.insert(
            id: contributionId,
            updatedAt: 20,
            lineId: lineId,
            source: 'ajout',
          ),
        );
      },
      validateItems: (newDb) async {
        final articles = await (newDb.select(
          newDb.articles,
        )..orderBy([(a) => OrderingTerm.asc(a.id)])).get();
        expect(articles, [
          const v2.ArticlesData(
            id: laitId,
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            unit: 'piece',
            pictoKey: 'lait',
            inCatalogue: 1,
          ),
          const v2.ArticlesData(
            id: pilesId,
            updatedAt: 12,
            deletedAt: 13,
            name: 'Piles',
            normalizedName: 'piles',
            rayon: 'divers',
            pictoKey: 'piles',
            inCatalogue: 1,
          ),
        ]);
        expect(await newDb.select(newDb.listLines).get(), [
          const v2.ListLinesData(
            id: lineId,
            updatedAt: 20,
            articleId: laitId,
            rayon: 'cremerie',
            addedAt: 20,
          ),
        ]);
        expect(await newDb.select(newDb.listContributions).get(), [
          const v2.ListContributionsData(
            id: contributionId,
            updatedAt: 20,
            lineId: lineId,
            source: 'ajout',
          ),
        ]);
      },
    );
  });

  test('v1 → v2 : un article existant sort encore dans la recherche', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb
        .into(oldDb.articles)
        .insert(
          v1.ArticlesCompanion.insert(
            id: 'a0000000-0000-4000-8000-000000000001',
            updatedAt: 0,
            name: 'Lait',
            normalizedName: 'lait',
            rayon: 'cremerie',
            pictoKey: 'lait',
          ),
        );
    await oldDb.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    final hits = await CatalogueRepository(
      db,
      Clock(),
    ).watchSearch('lai').first;
    expect(hits.map((a) => a.name), ['Lait']);
    await db.close();
  });

  test('schemaVersion figé à la dernière version du dump', () {
    final db = AppDatabase.forTesting(DatabaseConnection(_unused));
    expect(db.schemaVersion, GeneratedHelper.versions.last);
  });
}

const _laitId = 'a0000000-0000-4000-8000-000000000001';
const _pilesId = 'a0000000-0000-4000-8000-000000000002';
const _lineId = 'b0000000-0000-4000-8000-000000000001';
const _checkedLineId = 'b0000000-0000-4000-8000-000000000002';
const _contributionId = 'c0000000-0000-4000-8000-000000000001';
const _editionId = 'c0000000-0000-4000-8000-000000000002';

final _unused = LazyDatabase(
  () => throw UnsupportedError('base jamais ouverte'),
);
