import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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

final _unused = LazyDatabase(
  () => throw UnsupportedError('base jamais ouverte'),
);
