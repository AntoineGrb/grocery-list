import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
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

/// Nom refusé : un autre article actif porte déjà ce nom normalisé (AD-17).
class ArticleNameTakenException implements Exception {
  const ArticleNameTakenException();

  @override
  String toString() => 'ArticleNameTakenException';
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
    // Un article hors catalogue garde le repli de son rayon (EXPERIENCE,
    // Picto), même quand le pack de pictos connaît son nom.
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

  /// Seule écriture d'un article existant (Fiche article de Paramètres ›
  /// Articles, rayon d'un fréquent de Paramètres › Fréquents), en une
  /// transaction : nom [cleanName] et son `normalized_name`, [rayon] et
  /// [unit] par défaut (`null` = sans) ; [pictoKey], le nom d'une icône
  /// choisie dans la Fiche article, devient la `picto_key` (`null` = ne
  /// change pas) ; `in_catalogue` ne change pas. Les lignes de liste et les
  /// ingrédients existants ne bougent pas : la modification vaut pour les
  /// ajouts suivants (AD-15).
  ///
  /// Un rayon changé passe le fréquent actif de l'article en dernier
  /// (`position` = max des positions actives + 1, AD-17), dans la même
  /// transaction. Rien n'est écrit si aucune valeur ne change.
  ///
  /// Lève une [ArticleNameTakenException] si un autre article actif, au
  /// catalogue ou non, porte ce nom normalisé, une [ArgumentError] pour un
  /// nom vide et une [StateError] si l'article est absent ou supprimé : rien
  /// n'est écrit.
  Future<CatalogueArticle> updateArticle(
    String articleId, {
    required String name,
    required Rayon rayon,
    required Unit? unit,
    String? pictoKey,
  }) => _db.transaction(
    () => _update(
      articleId,
      name: name,
      rayon: rayon,
      unit: unit,
      pictoKey: pictoKey,
    ),
  );

  /// Création depuis la Fiche article de Paramètres › Articles, en une
  /// transaction : [createArticle], puis les valeurs de la fiche par
  /// [updateArticle] (nom [cleanName], [rayon], [unit], [pictoKey] s'il
  /// est donné). Un nom porté par un
  /// article hors catalogue le fait entrer au catalogue, même id, avec ces
  /// valeurs (AD-17).
  ///
  /// Lève une [ArticleNameTakenException] si un article du catalogue porte
  /// déjà ce nom normalisé, une [ArgumentError] pour un nom vide : rien
  /// n'est écrit.
  Future<CatalogueArticle> createCatalogueArticle(
    String name, {
    required Rayon rayon,
    required Unit? unit,
    String? pictoKey,
  }) => _db.transaction(() async {
    final cleaned = cleanName(name);
    final normalized = normalizeName(cleaned);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nom vide');
    }
    final holder = await _activeRowNamed(normalized);
    if (holder != null && holder.inCatalogue) {
      throw const ArticleNameTakenException();
    }
    final created = await createArticle(cleaned, rayon: rayon, unit: unit);
    return _update(
      created.id,
      name: cleaned,
      rayon: rayon,
      unit: unit,
      pictoKey: pictoKey,
    );
  });

  /// Voir [updateArticle], à appeler dans une transaction.
  Future<CatalogueArticle> _update(
    String articleId, {
    required String name,
    required Rayon rayon,
    required Unit? unit,
    String? pictoKey,
  }) async {
    final row =
        await (_db.select(_db.articles)
              ..where((a) => a.id.equals(articleId) & a.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) throw StateError('Article absent : $articleId');
    final cleaned = cleanName(name);
    final normalized = normalizeName(cleaned);
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nom vide');
    }
    final other =
        await (_db.select(_db.articles)
              ..where(
                (a) =>
                    a.normalizedName.equals(normalized) &
                    a.deletedAt.isNull() &
                    a.id.equals(articleId).not(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (other != null) throw const ArticleNameTakenException();

    final rayonChanged = row.rayon != rayon.code;
    final newPictoKey = pictoKey ?? row.pictoKey;
    if (row.name == cleaned &&
        row.normalizedName == normalized &&
        !rayonChanged &&
        row.unit == unit?.code &&
        row.pictoKey == newPictoKey) {
      return _toModel(row);
    }
    await (_db.update(
      _db.articles,
    )..where((a) => a.id.equals(articleId))).write(
      ArticlesCompanion(
        name: Value(cleaned),
        normalizedName: Value(normalized),
        rayon: Value(rayon.code),
        unit: Value(unit?.code),
        pictoKey: Value(newPictoKey),
        updatedAt: Value(_clock.stamp(row.updatedAt)),
      ),
    );
    if (rayonChanged) await _moveFrequentLast(articleId);
    return CatalogueArticle(
      id: row.id,
      name: cleaned,
      rayon: rayon,
      unit: unit,
      pictoKey: newPictoKey,
    );
  }

  /// Passe le fréquent actif de [articleId], s'il existe, en dernier :
  /// `position` = max des positions actives + 1 (AD-17).
  Future<void> _moveFrequentLast(String articleId) async {
    final frequent =
        await (_db.select(_db.frequents)
              ..where(
                (f) => f.articleId.equals(articleId) & f.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (frequent == null) return;
    await (_db.update(
      _db.frequents,
    )..where((f) => f.id.equals(frequent.id))).write(
      FrequentsCompanion(
        position: Value(await _nextFrequentPosition()),
        updatedAt: Value(_clock.stamp(frequent.updatedAt)),
      ),
    );
  }

  /// Position d'un fréquent passé en dernier : max des positions actives
  /// + 1, 0 sans fréquent actif (AD-17).
  Future<int> _nextFrequentPosition() async {
    final maxPosition = _db.frequents.position.max();
    final max =
        await (_db.selectOnly(_db.frequents)
              ..addColumns([maxPosition])
              ..where(_db.frequents.deletedAt.isNull()))
            .map((r) => r.read(maxPosition))
            .getSingle();
    return max == null ? 0 : max + 1;
  }

  /// Ajoute l'article [articleId] aux fréquents (Paramètres › Fréquents), en
  /// une transaction : en dernier (`position` = max des positions actives
  /// + 1), donc en dernier de son rayon (AD-17). Le fréquent prend l'id
  /// dérivé de l'article ([frequentId]) ; s'il existe supprimé, il est
  /// réactivé, même id. Déjà fréquent : rien n'est écrit.
  ///
  /// Lève une [StateError] si l'article est absent ou supprimé : rien n'est
  /// écrit.
  Future<void> addFrequent(String articleId) =>
      _db.transaction(() => _addFrequent(articleId));

  /// Crée au catalogue l'article [name] ([createArticle] : Divers, sans
  /// unité ; un nom porté par un article hors catalogue le fait entrer au
  /// catalogue, même id) puis l'ajoute aux fréquents ([addFrequent]), en
  /// une transaction. Rend l'article. Lève une [ArgumentError] pour un nom
  /// vide : rien n'est écrit.
  Future<CatalogueArticle> createFrequentArticle(String name) =>
      _db.transaction(() async {
        final article = await createArticle(name);
        await _addFrequent(article.id);
        return article;
      });

  /// Voir [addFrequent], à appeler dans une transaction.
  Future<void> _addFrequent(String articleId) async {
    final article =
        await (_db.select(_db.articles)
              ..where((a) => a.id.equals(articleId) & a.deletedAt.isNull()))
            .getSingleOrNull();
    if (article == null) throw StateError('Article absent : $articleId');
    final active =
        await (_db.select(_db.frequents)
              ..where(
                (f) => f.articleId.equals(articleId) & f.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (active != null) return;

    final id = frequentId(articleId);
    final position = await _nextFrequentPosition();
    final previous = await (_db.select(
      _db.frequents,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    if (previous == null) {
      await _db
          .into(_db.frequents)
          .insert(
            FrequentsCompanion.insert(
              id: id,
              updatedAt: _clock.stamp(),
              articleId: articleId,
              position: position,
            ),
          );
      return;
    }
    await (_db.update(_db.frequents)..where((f) => f.id.equals(id))).write(
      FrequentsCompanion(
        articleId: Value(articleId),
        position: Value(position),
        deletedAt: const Value(null),
        updatedAt: Value(_clock.stamp(previous.updatedAt)),
      ),
    );
  }

  /// Retire l'article [articleId] des fréquents (Paramètres › Fréquents) :
  /// son fréquent actif est supprimé logiquement, dans une transaction
  /// (AD-7). Rend son état d'avant pour Annuler (AD-10), qui le remet à la
  /// même position ; sans fréquent actif, rien n'est écrit et la liste est
  /// vide.
  Future<List<UndoRow>> removeFrequent(
    String articleId,
  ) => _db.transaction(() async {
    final frequents =
        await (_db.select(_db.frequents)..where(
              (f) => f.articleId.equals(articleId) & f.deletedAt.isNull(),
            ))
            .get();
    for (final f in frequents) {
      final stamp = _clock.stamp(f.updatedAt);
      await (_db.update(_db.frequents)..where((x) => x.id.equals(f.id))).write(
        FrequentsCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
      );
    }
    return [for (final f in frequents) UndoRow.before(_db.frequents, f)];
  });

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
  /// Enfin, un fréquent importé ([insertedFrequents], les ids de fréquents
  /// insérés par la fusion) ou reporté dont la position est déjà prise dans
  /// son rayon passe en dernier, comme tout fréquent ajouté ou déplacé
  /// (AD-17) : voir [_separateFrequentPositions].
  ///
  /// Rend l'article gardé de chaque article supprimé (id supprimé → id
  /// gardé), pour que `liste` et `recettes` y reportent leurs références.
  Future<Map<String, String>> reconcileImportedArticles(
    Set<String> inserted, {
    Set<String> insertedFrequents = const {},
  }) async {
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
    final moved = replaced.isEmpty
        ? const <String>{}
        : await _moveFrequents(replaced);
    await _separateFrequentPositions({...insertedFrequents, ...moved});
    return replaced;
  }

  /// Départage les fréquents actifs (d'article actif) de même rayon et de
  /// même `position`, à appeler dans la transaction de l'import : dans
  /// chaque groupe, un seul garde sa position, celui qui était là avant
  /// l'import (absent de [arrived], les fréquents importés ou reportés),
  /// sinon le plus petit id. Les autres passent en dernier (max des
  /// positions actives + 1, AD-17), dans l'ordre de leur position puis de
  /// leur id : leur ordre relatif est gardé.
  Future<void> _separateFrequentPositions(Set<String> arrived) async {
    final f = _db.frequents;
    final a = _db.articles;
    final rows = await (_db.select(f).join([
      innerJoin(a, a.id.equalsExp(f.articleId) & a.deletedAt.isNull()),
    ])..where(f.deletedAt.isNull())).get();
    final groups = <(Rayon, int), List<Frequent>>{};
    for (final row in rows) {
      final frequent = row.readTable(f);
      final rayon = Rayon.tryFromCode(row.readTable(a).rayon) ?? Rayon.divers;
      groups.putIfAbsent((rayon, frequent.position), () => []).add(frequent);
    }
    final last = <Frequent>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((x, y) {
        final byOrigin =
            (arrived.contains(x.id) ? 1 : 0) - (arrived.contains(y.id) ? 1 : 0);
        return byOrigin != 0 ? byOrigin : x.id.compareTo(y.id);
      });
      last.addAll(group.skip(1));
    }
    if (last.isEmpty) return;
    last.sort((x, y) {
      final byPosition = x.position - y.position;
      return byPosition != 0 ? byPosition : x.id.compareTo(y.id);
    });
    var position = await _nextFrequentPosition();
    for (final frequent in last) {
      await (_db.update(
        _db.frequents,
      )..where((x) => x.id.equals(frequent.id))).write(
        FrequentsCompanion(
          position: Value(position++),
          updatedAt: Value(_clock.stamp(frequent.updatedAt)),
        ),
      );
    }
  }

  /// Reporte les fréquents actifs des articles supprimés [replaced] sur leur
  /// article gardé (voir [reconcileImportedArticles]). Rend les ids des
  /// fréquents reportés, actifs sur l'article gardé.
  Future<Set<String>> _moveFrequents(Map<String, String> replaced) async {
    final reported = <String>{};
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
        reported.add(f.id);
        continue;
      }
      final target = await (_db.select(
        _db.frequents,
      )..where((x) => x.id.equals(targetId))).getSingleOrNull();
      if (target == null || target.deletedAt != null) {
        reported.add(targetId);
      }
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
    return reported;
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

  /// Tous les articles actifs du catalogue, par ordre alphabétique du nom
  /// normalisé ; un article hors catalogue n'en sort jamais (AD-17).
  Stream<List<CatalogueArticle>> watchCatalogue() {
    final select = _db.select(_db.articles)
      ..where((a) => a.deletedAt.isNull() & a.inCatalogue.equals(true))
      ..orderBy([
        (a) => OrderingTerm.asc(a.normalizedName),
        (a) => OrderingTerm.asc(a.id),
      ]);
    return select.watch().map(
      (rows) => rows.map(_toModel).toList(growable: false),
    );
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
