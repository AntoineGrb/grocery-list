import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:uuid/uuid.dart';

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
  CatalogueRepository(this._db, this._clock, {this._uuid = const Uuid()});

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  /// Nom d'un article créé depuis la saisie [input] : sans espaces de bord
  /// ni espaces doublés, première lettre en majuscule (« piles » → « Piles »).
  static String cleanName(String input) {
    final words = input.trim().split(RegExp(r'\s+'));
    final name = words.join(' ');
    if (name.isEmpty) return name;
    final first = name.runes.first;
    return String.fromCharCode(first).toUpperCase() +
        name.substring(String.fromCharCode(first).length);
  }

  /// Article actif de même nom normalisé que [name], s'il existe (AD-17),
  /// au catalogue ou hors catalogue.
  Future<CatalogueArticle?> findByName(String name) async {
    final row = await _activeRowNamed(normalizeName(name));
    return row == null ? null : _toModel(row);
  }

  Future<Article?> _activeRowNamed(String normalized) {
    if (normalized.isEmpty) return Future.value();
    return (_db.select(_db.articles)
          ..where(
            (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Création au catalogue (AD-17), à appeler dans une transaction : nom
  /// nettoyé ([cleanName]), [rayon] (Divers par défaut), [unit] (sans par
  /// défaut), `picto_key` = nom normalisé réduit à `[a-z0-9]` (`article` si
  /// vide), id UUID v4.
  ///
  /// Si un article actif porte déjà ce nom normalisé, aucun article n'est
  /// créé et cet article est rendu : un nom normalisé reste unique parmi les
  /// articles actifs. Hors catalogue, il y entre (`in_catalogue` vrai, même
  /// id) ; son rayon et son unité ne changent pas. Lève une [ArgumentError]
  /// pour un nom vide.
  Future<CatalogueArticle> createArticle(
    String name, {
    Rayon rayon = Rayon.divers,
    Unit? unit,
  }) async {
    final cleaned = cleanName(name);
    final normalized = normalizeName(cleaned);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nom vide');
    }
    final existing = await _activeRowNamed(normalized);
    if (existing != null) {
      if (!existing.inCatalogue) {
        await (_db.update(
          _db.articles,
        )..where((a) => a.id.equals(existing.id))).write(
          ArticlesCompanion(
            inCatalogue: const Value(true),
            updatedAt: Value(_clock.stamp(existing.updatedAt)),
          ),
        );
      }
      return _toModel(existing);
    }
    return _insert(cleaned, normalized, rayon: rayon, unit: unit);
  }

  /// Article du texte [name] validé par Entrée dans le Panneau + (AD-17) :
  /// l'article actif de ce nom normalisé, au catalogue ou non ; sinon un
  /// nouvel article hors catalogue (Divers, sans unité, nom [cleanName],
  /// `picto_key` comme [createArticle]), absent de la recherche. Une
  /// transaction ; lève une [ArgumentError] pour un nom vide.
  Future<CatalogueArticle> resolveTypedArticle(String name) {
    return _db.transaction(() async {
      final cleaned = cleanName(name);
      final normalized = normalizeName(cleaned);
      if (normalized.isEmpty) {
        throw ArgumentError.value(name, 'name', 'Nom vide');
      }
      final existing = await _activeRowNamed(normalized);
      if (existing != null) return _toModel(existing);
      return _insert(cleaned, normalized, inCatalogue: false);
    });
  }

  Future<CatalogueArticle> _insert(
    String cleaned,
    String normalized, {
    Rayon rayon = Rayon.divers,
    Unit? unit,
    bool inCatalogue = true,
  }) async {
    // Un article hors catalogue garde le repli neutre (EXPERIENCE, Picto),
    // même quand un pack de pictos connaît son nom.
    final pictoKey = inCatalogue
        ? normalized.replaceAll(RegExp('[^a-z0-9]'), '')
        : '';
    final row = ArticlesCompanion.insert(
      id: _uuid.v4(),
      updatedAt: _clock.stamp(),
      name: cleaned,
      normalizedName: normalized,
      rayon: rayon.code,
      unit: Value(unit?.code),
      pictoKey: pictoKey.isEmpty ? 'article' : pictoKey,
      inCatalogue: Value(inCatalogue),
    );
    await _db.into(_db.articles).insert(row);
    return CatalogueArticle(
      id: row.id.value,
      name: cleaned,
      rayon: rayon,
      unit: unit,
      pictoKey: row.pictoKey.value,
    );
  }

  /// Change le rayon par défaut de l'article [articleId], à appeler dans une
  /// transaction : seuls `rayon` et `updated_at` changent ; les lignes
  /// existantes ne bougent pas (AD-15). Rien n'est écrit si l'article est
  /// absent, supprimé ou déjà dans ce rayon.
  Future<void> setArticleRayon(String articleId, Rayon rayon) async {
    final article =
        await (_db.select(_db.articles)
              ..where((a) => a.id.equals(articleId) & a.deletedAt.isNull()))
            .getSingleOrNull();
    if (article == null || article.rayon == rayon.code) return;
    await (_db.update(
      _db.articles,
    )..where((a) => a.id.equals(articleId))).write(
      ArticlesCompanion(
        rayon: Value(rayon.code),
        updatedAt: Value(_clock.stamp(article.updatedAt)),
      ),
    );
  }

  /// Articles actifs du catalogue dont le nom normalisé contient [query]
  /// normalisé ; un article hors catalogue n'en sort jamais (AD-17).
  ///
  /// Une recherche vide ne renvoie rien. Les noms qui commencent par la
  /// recherche passent en premier, puis l'ordre alphabétique.
  Stream<List<CatalogueArticle>> watchSearch(String query) {
    final q = normalizeName(query);
    if (q.isEmpty) return Stream.value(const []);
    final select = _db.select(_db.articles)
      ..where((a) => a.deletedAt.isNull() & a.inCatalogue.equals(true));
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

  /// Articles des fréquents actifs dont l'article est actif, par `position`
  /// (puis par id, pour un ordre stable).
  Stream<List<CatalogueArticle>> watchFrequents() {
    final f = _db.frequents;
    final a = _db.articles;
    final query =
        _db.select(f).join([
            innerJoin(a, a.id.equalsExp(f.articleId) & a.deletedAt.isNull()),
          ])
          ..where(f.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(f.position), OrderingTerm.asc(f.id)]);
    return query.watch().map(
      (rows) => [for (final row in rows) _toModel(row.readTable(a))],
    );
  }

  static CatalogueArticle _toModel(Article a) => CatalogueArticle(
    id: a.id,
    name: a.name,
    rayon: Rayon.tryFromCode(a.rayon) ?? Rayon.divers,
    unit: Unit.tryFromCode(a.unit),
    pictoKey: a.pictoKey,
  );
}
