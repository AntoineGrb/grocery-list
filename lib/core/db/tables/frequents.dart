import 'package:drift/drift.dart';

import 'articles.dart';
import 'sync_columns.dart';

/// Fréquents. Propriétaire : `catalogue` (AD-2). Un fréquent par article,
/// d'id dérivé de l'article en UUID v5 (AD-17).
class Frequents extends Table with SyncColumns {
  TextColumn get articleId => text().references(Articles, #id)();

  /// Ordre dans le rayon ; un fréquent ajouté ou déplacé passe en dernier.
  IntColumn get position => integer()();
}
