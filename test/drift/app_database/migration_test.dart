import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';

import 'generated/schema.dart';

/// Un test par étape de migration (AD-14). v1 : la base créée par l'app est
/// exactement le schéma figé dans `drift_schemas/app_database/`.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 : schéma créé conforme au dump', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 1);
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
