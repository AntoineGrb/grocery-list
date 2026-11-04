import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:uuid/uuid.dart';

import 'frequent_id.dart';
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

  /// Réconcilie les articles après la fusion d'une sauvegarde (AD-9), à
  /// appeler dans la transaction de l'import : parmi les articles actifs de
  /// même nom normalisé (AD-17), un seul est gardé, celui qui existait
  /// localement avant l'import (absent de [inserted], les ids insérés par la
  /// fusion), sinon le plus petit id. Il entre au catalogue si l'un des
  /// autres y était ; les autres sont supprimés logiquement.
  ///
  /// Le fréquent actif d'un article supprimé passe sur l'article gardé :
  /// sous l'id dérivé de celui-ci ([frequentId], AD-17), inséré ou réactivé
  /// à la même position ; si l'article gardé a déjà un fréquent actif, ce
  /// fréquent en double est seulement supprimé logiquement.
  ///
  /// Rend l'article gardé de chaque article supprimé (id supprimé → id
  /// gardé), pour que `liste` et `recettes` y reportent leurs références.
  Future<Map<String, String>> reconcileImportedArticles(
    Set<String> inserted,
  ) async {
    final active = await (_db.select(
      _db.articles,
    )..where((a) => a.deletedAt.isNull())).get();
    final byName = <String, List<Article>>{};
    for (final a in active) {
      byName.putIfAbsent(a.normalizedName, () => []).add(a);
    }

    final replaced = <String, String>{};
    for (final group in byName.values) {
      if (group.length < 2) continue;
      group.sort((x, y) {
        final byOrigin =
            (inserted.contains(x.id) ? 1 : 0) -
            (inserted.contains(y.id) ? 1 : 0);
        return byOrigin != 0 ? byOrigin : x.id.compareTo(y.id);
      });
      final kept = group.first;
      final others = group.skip(1).toList();
      if (!kept.inCatalogue && others.any((a) => a.inCatalogue)) {
        await (_db.update(
          _db.articles,
        )..where((a) => a.id.equals(kept.id))).write(
          ArticlesCompanion(
            inCatalogue: const Value(true),
            updatedAt: Value(_clock.stamp(kept.updatedAt)),
          ),
        );
      }
      for (final other in others) {
        final stamp = _clock.stamp(other.updatedAt);
        await (_db.update(
          _db.articles,
        )..where((a) => a.id.equals(other.id))).write(
          ArticlesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
        );
        replaced[other.id] = kept.id;
      }
    }
    if (replaced.isNotEmpty) await _moveFrequents(replaced);
    return replaced;
  }

  /// Reporte les fréquents actifs des articles supprimés [replaced] sur leur
  /// article gardé (voir [reconcileImportedArticles]).
  Future<void> _moveFrequents(Map<String, String> replaced) async {
    final moved =
        await (_db.select(_db.frequents)
              ..where(
                (f) => f.articleId.isIn(replaced.keys) & f.deletedAt.isNull(),
              )
              ..orderBy([
                (f) => OrderingTerm.asc(f.position),
                (f) => OrderingTerm.asc(f.id),
              ]))
            .get();
    for (final f in moved) {
      final keptId = replaced[f.articleId]!;
      final targetId = frequentId(keptId);
      if (targetId == f.id) {
        // Déjà sous l'id de l'article gardé : seul l'article change.
        await (_db.update(
          _db.frequents,
        )..where((x) => x.id.equals(f.id))).write(
          FrequentsCompanion(
            articleId: Value(keptId),
            updatedAt: Value(_clock.stamp(f.updatedAt)),
          ),
        );
        continue;
      }
      final target = await (_db.select(
        _db.frequents,
      )..where((x) => x.id.equals(targetId))).getSingleOrNull();
      if (target == null) {
        await _db
            .into(_db.frequents)
            .insert(
              FrequentsCompanion.insert(
                id: targetId,
                updatedAt: _clock.stamp(),
                articleId: keptId,
                position: f.position,
              ),
            );
      } else if (target.deletedAt != null) {
        await (_db.update(
          _db.frequents,
        )..where((x) => x.id.equals(targetId))).write(
          FrequentsCompanion(
            articleId: Value(keptId),
            position: Value(f.position),
            deletedAt: const Value(null),
            updatedAt: Value(_clock.stamp(target.updatedAt)),
          ),
        );
      }
      // Sinon, l'article gardé a déjà son fréquent : celui-ci est en double.
      final stamp = _clock.stamp(f.updatedAt);
      await (_db.update(_db.frequents)..where((x) => x.id.equals(f.id))).write(
        FrequentsCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
      );
    }
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
