import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';

import 'normalize_name.dart';

/// Article du catalogue, tel que le lisent les écrans.
class CatalogueArticle {
  const CatalogueArticle({
    required this.id,
    required this.name,
    required this.rayon,
    required this.unit,
    required this.pictoKey,
  });

  final String id;
  final String name;
  final Rayon rayon;
  final Unit? unit;
  final String pictoKey;
}

/// Propriétaire de `articles` et `frequents` (AD-2).
class CatalogueRepository {
  CatalogueRepository(this._db);

  final AppDatabase _db;

  /// Articles actifs dont le nom normalisé contient [query] normalisé.
  ///
  /// Une recherche vide ne renvoie rien. Les noms qui commencent par la
  /// recherche passent en premier, puis l'ordre alphabétique.
  Stream<List<CatalogueArticle>> watchSearch(String query) {
    final q = normalizeName(query);
    if (q.isEmpty) return Stream.value(const []);
    final select = _db.select(_db.articles)..where((a) => a.deletedAt.isNull());
    return select.watch().map((rows) {
      final hits = rows.where((a) => a.normalizedName.contains(q)).toList()
        ..sort((a, b) {
          final pa = a.normalizedName.startsWith(q) ? 0 : 1;
          final pb = b.normalizedName.startsWith(q) ? 0 : 1;
          if (pa != pb) return pa - pb;
          return a.normalizedName.compareTo(b.normalizedName);
        });
      return hits.map(_toModel).toList(growable: false);
    });
  }

  static CatalogueArticle _toModel(Article a) => CatalogueArticle(
    id: a.id,
    name: a.name,
    rayon: Rayon.tryFromCode(a.rayon) ?? Rayon.divers,
    unit: Unit.tryFromCode(a.unit),
    pictoKey: a.pictoKey,
  );
}
