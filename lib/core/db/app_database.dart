import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.steps.dart';
import 'tables/articles.dart';
import 'tables/frequents.dart';
import 'tables/list_contributions.dart';
import 'tables/list_lines.dart';
import 'tables/settings.dart';

export 'tables/articles.dart';
export 'tables/frequents.dart';
export 'tables/list_contributions.dart';
export 'tables/list_lines.dart';
export 'tables/settings.dart';

part 'app_database.g.dart';

/// La base unique de Kadi (AD-1). Toutes les tables sont définies dans
/// `tables/`.
@DriftDatabase(
  tables: [Articles, Frequents, ListLines, ListContributions, Settings],
)
class AppDatabase extends _$AppDatabase {
  /// Base de l'app, ouverte par `driftDatabase` de drift_flutter.
  AppDatabase() : super(driftDatabase(name: 'kadi'));

  /// Base sur un exécuteur fourni (tests sur Drift en mémoire).
  AppDatabase.forTesting(super.executor);

  /// Un seul `schemaVersion` (AD-14) ; chaque story qui change le schéma
  /// l'incrémente, ajoute une étape de migration non destructive et
  /// `dart run drift_dev make-migrations`.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2 : articles hors catalogue (AD-17) ; les articles existants
      // restent au catalogue (défaut vrai).
      from1To2: (m, schema) async {
        await m.addColumn(schema.articles, schema.articles.inCatalogue);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
