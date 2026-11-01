import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:uuid/uuid.dart';

/// Sources d'une contribution (AD-4, AD-5).
abstract final class ContributionSource {
  static const weekSelection = 'week_selection';
  static const ajout = 'ajout';
  static const edition = 'edition';
}

/// Contribution écrite par un ajout : sa ligne et son id.
typedef AddedContribution = ({String lineId, String contributionId});

/// Ligne active de la Liste, avec sa quantité calculée.
class ListeItem {
  const ListeItem({
    required this.lineId,
    required this.articleId,
    required this.name,
    required this.rayon,
    required this.unit,
    required this.quantity,
    this.checked = false,
    this.articleUnit,
  });

  final String lineId;
  final String articleId;
  final String name;
  final Rayon rayon;
  final Unit? unit;

  /// Unité par défaut de l'article : unité du Champ quantité d'une ligne
  /// sans unité.
  final Unit? articleUnit;

  /// Somme des contributions actives ; nulle sans quantité (AD-4).
  final int? quantity;

  /// Ligne cochée (dans la Section Cochés).
  final bool checked;
}

/// Propriétaire de `list_lines` et `list_contributions` (AD-2).
class ListeRepository {
  ListeRepository(this._db, this._clock, {this._uuid = const Uuid()});

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  /// Ajoute [articleId] depuis le Panneau + : une contribution `ajout`, sans
  /// quantité par défaut, ou de [quantity] dans [unit] (AD-4, AD-6).
  ///
  /// Une quantité 0 vaut « sans quantité ». Lève une [ArgumentError] si l'une
  /// est donnée sans l'autre ou si la quantité est négative, une
  /// [StateError] si l'article est absent ou supprimé. Une transaction : un
  /// échec n'écrit rien. Rend la contribution `ajout` écrite et sa ligne.
  Future<AddedContribution> addArticle(
    String articleId, {
    int? quantity,
    Unit? unit,
  }) {
    return _db.transaction(
      () => _contribute(
        articleId: articleId,
        source: ContributionSource.ajout,
        quantity: quantity,
        unit: unit,
      ),
    );
  }

  /// Écrit une contribution de [source] pour [articleId] selon les règles de
  /// fusion d'AD-4, à appeler dans une transaction.
  ///
  /// Sans quantité, elle rejoint la plus ancienne ligne non cochée de
  /// l'article, quelle que soit son unité, sinon crée une ligne sans unité.
  /// Chiffrée, elle rejoint la ligne non cochée de son unité, sinon la ligne
  /// non cochée sans unité (qui prend l'unité), sinon crée une ligne dans son
  /// unité. Une ligne cochée n'est jamais complétée. Entre candidates :
  /// `added_at` puis `id`. Une nouvelle ligne copie le rayon de l'article
  /// (AD-15). Rend la contribution écrite et sa ligne.
  Future<AddedContribution> _contribute({
    required String articleId,
    required String source,
    int? quantity,
    Unit? unit,
  }) async {
    if (quantity != null && quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Quantité négative');
    }
    if (quantity == 0) {
      quantity = null;
      unit = null;
    }
    if ((quantity == null) != (unit == null)) {
      throw ArgumentError(
        'Quantité et unité sont nulles ensemble (AD-6) : '
        'quantity = $quantity, unit = $unit',
      );
    }

    final article =
        await (_db.select(_db.articles)
              ..where((a) => a.id.equals(articleId) & a.deletedAt.isNull()))
            .getSingleOrNull();
    if (article == null) {
      throw StateError('Article absent ou supprimé : $articleId');
    }

    final unchecked =
        await (_db.select(_db.listLines)
              ..where(
                (l) =>
                    l.articleId.equals(articleId) &
                    l.deletedAt.isNull() &
                    l.checkedAt.isNull(),
              )
              ..orderBy([
                (l) => OrderingTerm.asc(l.addedAt),
                (l) => OrderingTerm.asc(l.id),
              ]))
            .get();

    ListLine? target;
    if (unit == null) {
      target = unchecked.firstOrNull;
    } else {
      final code = unit.code;
      target = unchecked.where((l) => l.unit == code).firstOrNull;
      final unitless = unchecked.where((l) => l.unit == null).firstOrNull;
      if (target == null && unitless != null) {
        // La ligne sans quantité prend l'unité de la contribution.
        await (_db.update(
          _db.listLines,
        )..where((l) => l.id.equals(unitless.id))).write(
          ListLinesCompanion(
            unit: Value(code),
            updatedAt: Value(_clock.stamp(unitless.updatedAt)),
          ),
        );
        target = unitless;
      }
    }

    final now = _clock.stamp();
    final lineId = target?.id ?? _uuid.v4();
    if (target == null) {
      await _db
          .into(_db.listLines)
          .insert(
            ListLinesCompanion.insert(
              id: lineId,
              updatedAt: now,
              articleId: articleId,
              rayon: article.rayon,
              unit: Value(unit?.code),
              addedAt: now,
            ),
          );
    }

    final contributionId = _uuid.v4();
    await _db
        .into(_db.listContributions)
        .insert(
          ListContributionsCompanion.insert(
            id: contributionId,
            updatedAt: now,
            lineId: lineId,
            source: source,
            quantity: Value(quantity),
            unit: Value(unit?.code),
          ),
        );
    return (lineId: lineId, contributionId: contributionId);
  }

  /// Coche la ligne [lineId] : `checked_at` et `updated_at` fixés. Rien
  /// n'est écrit si la ligne est absente, supprimée ou déjà cochée.
  Future<void> check(String lineId) {
    return _db.transaction(() async {
      final line = await _activeLine(lineId);
      if (line == null || line.checkedAt != null) return;
      final stamp = _clock.stamp(line.updatedAt);
      await (_db.update(
        _db.listLines,
      )..where((l) => l.id.equals(lineId))).write(
        ListLinesCompanion(checkedAt: Value(stamp), updatedAt: Value(stamp)),
      );
    });
  }

  /// Décoche la ligne [lineId] (AD-4). Si une autre ligne active non cochée
  /// du même article et de même `unit_key` existe (le jumeau), les
  /// contributions actives de la ligne passent sur le jumeau et la ligne est
  /// supprimée logiquement ; sinon `checked_at` est remis à nul et la ligne
  /// reprend sa place d'ajout. Rien n'est écrit si la ligne est absente,
  /// supprimée ou non cochée.
  Future<void> uncheck(String lineId) {
    return _db.transaction(() async {
      final line = await _activeLine(lineId);
      if (line == null || line.checkedAt == null) return;

      final unit = line.unit;
      final twin =
          await (_db.select(_db.listLines)
                ..where(
                  (l) =>
                      l.articleId.equals(line.articleId) &
                      l.id.equals(line.id).not() &
                      l.deletedAt.isNull() &
                      l.checkedAt.isNull() &
                      (unit == null ? l.unit.isNull() : l.unit.equals(unit)),
                )
                ..orderBy([
                  (l) => OrderingTerm.asc(l.addedAt),
                  (l) => OrderingTerm.asc(l.id),
                ])
                ..limit(1))
              .getSingleOrNull();

      if (twin == null) {
        await (_db.update(
          _db.listLines,
        )..where((l) => l.id.equals(lineId))).write(
          ListLinesCompanion(
            checkedAt: const Value(null),
            updatedAt: Value(_clock.stamp(line.updatedAt)),
          ),
        );
        return;
      }

      final contributions = await (_db.select(
        _db.listContributions,
      )..where((c) => c.lineId.equals(lineId) & c.deletedAt.isNull())).get();
      for (final c in contributions) {
        await (_db.update(
          _db.listContributions,
        )..where((x) => x.id.equals(c.id))).write(
          ListContributionsCompanion(
            lineId: Value(twin.id),
            updatedAt: Value(_clock.stamp(c.updatedAt)),
          ),
        );
      }
      final stamp = _clock.stamp(line.updatedAt);
      await (_db.update(
        _db.listLines,
      )..where((l) => l.id.equals(lineId))).write(
        ListLinesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
      );
    });
  }

  /// Vide la liste, à appeler dans une transaction : toutes les lignes
  /// actives, cochées ou non, et leurs contributions actives sont supprimées
  /// logiquement (AD-7). Rend leur état d'avant pour Annuler (AD-10) ; une
  /// liste vide n'écrit rien et rend une liste vide.
  Future<List<UndoRow>> clearList() async {
    final lines = await (_db.select(
      _db.listLines,
    )..where((l) => l.deletedAt.isNull())).get();
    if (lines.isEmpty) return const [];
    final lineIds = [for (final l in lines) l.id];
    final contributions = await (_db.select(
      _db.listContributions,
    )..where((c) => c.lineId.isIn(lineIds) & c.deletedAt.isNull())).get();

    // Un seul horodatage, postérieur à chaque ancien `updated_at`.
    final previous = [
      for (final l in lines) l.updatedAt,
      for (final c in contributions) c.updatedAt,
    ].reduce((a, b) => a > b ? a : b);
    final stamp = _clock.stamp(previous);

    await (_db.update(
      _db.listContributions,
    )..where((c) => c.id.isIn([for (final c in contributions) c.id]))).write(
      ListContributionsCompanion(
        deletedAt: Value(stamp),
        updatedAt: Value(stamp),
      ),
    );
    await (_db.update(_db.listLines)..where((l) => l.id.isIn(lineIds))).write(
      ListLinesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
    );

    return [
      for (final l in lines) UndoRow.before(_db.listLines, l),
      for (final c in contributions) UndoRow.before(_db.listContributions, c),
    ];
  }

  /// Supprime la ligne [lineId], cochée ou non (glisser, Feuille d'édition,
  /// TalkBack) : la ligne et ses contributions actives sont supprimées
  /// logiquement, dans une transaction (AD-7). Rend leur état d'avant pour
  /// Annuler (AD-10) ; une ligne absente ou supprimée n'écrit rien et rend une
  /// liste vide.
  Future<List<UndoRow>> removeLine(String lineId) {
    return _db.transaction(() async {
      final line = await _activeLine(lineId);
      if (line == null) return const <UndoRow>[];
      final contributions = await _activeContributions(lineId);

      final stamp = _clock.stamp(_latest(line, contributions));
      await _deleteContributions(contributions, stamp);
      await (_db.update(
        _db.listLines,
      )..where((l) => l.id.equals(lineId))).write(
        ListLinesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
      );

      return [
        UndoRow.before(_db.listLines, line),
        for (final c in contributions) UndoRow.before(_db.listContributions, c),
      ];
    });
  }

  /// Retire [articleId] de la liste depuis le Panneau + (tap sur un article
  /// « dans la liste », AD-4) : toutes ses lignes actives non cochées et
  /// leurs contributions actives sont supprimées logiquement, dans une
  /// transaction (AD-7) ; les lignes cochées restent. Rend leur état d'avant
  /// pour Annuler (AD-10) ; sans ligne non cochée, rien n'est écrit et la
  /// liste rendue est vide.
  Future<List<UndoRow>> removeArticle(String articleId) {
    return _db.transaction(() async {
      final lines =
          await (_db.select(_db.listLines)..where(
                (l) =>
                    l.articleId.equals(articleId) &
                    l.deletedAt.isNull() &
                    l.checkedAt.isNull(),
              ))
              .get();
      if (lines.isEmpty) return const <UndoRow>[];
      final lineIds = [for (final l in lines) l.id];
      final contributions = await (_db.select(
        _db.listContributions,
      )..where((c) => c.lineId.isIn(lineIds) & c.deletedAt.isNull())).get();

      // Un seul horodatage, postérieur à chaque ancien `updated_at`.
      final previous = [
        for (final l in lines) l.updatedAt,
        for (final c in contributions) c.updatedAt,
      ].reduce((a, b) => a > b ? a : b);
      final stamp = _clock.stamp(previous);

      await _deleteContributions(contributions, stamp);
      await (_db.update(_db.listLines)..where((l) => l.id.isIn(lineIds))).write(
        ListLinesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
      );

      return [
        for (final l in lines) UndoRow.before(_db.listLines, l),
        for (final c in contributions) UndoRow.before(_db.listContributions, c),
      ];
    });
  }

  /// Corrige la quantité et l'unité de la ligne [lineId] depuis la Feuille
  /// d'édition (AD-5) : dans une transaction, ses contributions actives
  /// sont supprimées logiquement, une contribution `edition` de [quantity]
  /// en [unit] est insérée, la ligne prend [unit] et `manual_at` est fixé.
  ///
  /// [quantity] est déjà stockée (AD-6 : g, ml, millièmes de pièce) ; nulle
  /// ou 0 : « sans quantité » quelle que soit [unit], la ligne perd son
  /// unité. Une ligne non cochée qui prend le `unit_key` d'une autre ligne
  /// active non cochée du même article absorbe ses contributions actives et
  /// garde son `added_at`, l'autre est supprimée logiquement (AD-4) ; une
  /// ligne cochée ne fusionne jamais. Une quantité et une unité égales à
  /// celles affichées n'écrivent rien ; une ligne absente ou supprimée, ou
  /// dont l'article est supprimé, non plus. Lève une [ArgumentError] pour
  /// une quantité négative, ou chiffrée sans unité.
  Future<void> setQuantity(String lineId, int? quantity, {Unit? unit}) async {
    if (quantity != null && quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Quantité négative');
    }
    if (quantity == 0) quantity = null;
    if (quantity == null) unit = null;
    if (quantity != null && unit == null) {
      throw ArgumentError('Quantité sans unité (AD-6) : quantity = $quantity');
    }
    final code = unit?.code;

    await _db.transaction(() async {
      final line = await _activeLine(lineId);
      if (line == null) return;
      final article =
          await (_db.select(_db.articles)..where(
                (a) => a.id.equals(line.articleId) & a.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      // Une ligne dont l'article est supprimé compte comme supprimée (AD-7).
      if (article == null) return;

      final contributions = await _activeContributions(lineId);
      // Quantité affichée : somme des contributions, nulle sans unité ; une
      // ligne sans quantité affichée compte comme sans unité.
      final shown = line.unit == null
          ? null
          : contributions
                .map((c) => c.quantity)
                .nonNulls
                .fold<int?>(null, (sum, q) => (sum ?? 0) + q);
      final shownCode = shown == null ? null : line.unit;
      if (shown == quantity && shownCode == code) return;

      // Jumeaux : lignes non cochées du même article dans le nouveau
      // `unit_key`, fusionnées dans la ligne éditée (AD-5).
      final twins = line.checkedAt != null
          ? const <ListLine>[]
          : await (_db.select(_db.listLines)..where(
                  (l) =>
                      l.articleId.equals(line.articleId) &
                      l.id.equals(line.id).not() &
                      l.deletedAt.isNull() &
                      l.checkedAt.isNull() &
                      (code == null ? l.unit.isNull() : l.unit.equals(code)),
                ))
                .get();
      final twinContributions = [
        for (final twin in twins) ...await _activeContributions(twin.id),
      ];

      final stamp = _clock.stamp(
        [
          _latest(line, contributions),
          for (final twin in twins) twin.updatedAt,
          for (final c in twinContributions) c.updatedAt,
        ].reduce((a, b) => a > b ? a : b),
      );
      await _deleteContributions(contributions, stamp);
      if (twinContributions.isNotEmpty) {
        await (_db.update(_db.listContributions)..where(
              (c) => c.id.isIn([for (final c in twinContributions) c.id]),
            ))
            .write(
              ListContributionsCompanion(
                lineId: Value(lineId),
                updatedAt: Value(stamp),
              ),
            );
      }
      if (twins.isNotEmpty) {
        await (_db.update(
          _db.listLines,
        )..where((l) => l.id.isIn([for (final t in twins) t.id]))).write(
          ListLinesCompanion(deletedAt: Value(stamp), updatedAt: Value(stamp)),
        );
      }
      await _db
          .into(_db.listContributions)
          .insert(
            ListContributionsCompanion.insert(
              id: _uuid.v4(),
              updatedAt: stamp,
              lineId: lineId,
              source: ContributionSource.edition,
              quantity: Value(quantity),
              unit: Value(code),
            ),
          );
      await (_db.update(
        _db.listLines,
      )..where((l) => l.id.equals(lineId))).write(
        ListLinesCompanion(
          unit: Value(code),
          manualAt: Value(stamp),
          updatedAt: Value(stamp),
        ),
      );
    });
  }

  /// Place la ligne [lineId] dans [rayon] : seuls `list_lines.rayon` et
  /// `updated_at` changent, jamais l'article (AD-15). Rien n'est écrit si la
  /// ligne est absente, supprimée ou déjà dans ce rayon.
  Future<void> setRayon(String lineId, Rayon rayon) {
    return _db.transaction(() async {
      final line = await _activeLine(lineId);
      if (line == null || line.rayon == rayon.code) return;
      await (_db.update(
        _db.listLines,
      )..where((l) => l.id.equals(lineId))).write(
        ListLinesCompanion(
          rayon: Value(rayon.code),
          updatedAt: Value(_clock.stamp(line.updatedAt)),
        ),
      );
    });
  }

  Future<ListLine?> _activeLine(String lineId) =>
      (_db.select(_db.listLines)
            ..where((l) => l.id.equals(lineId) & l.deletedAt.isNull()))
          .getSingleOrNull();

  Future<List<ListContribution>> _activeContributions(String lineId) =>
      (_db.select(
        _db.listContributions,
      )..where((c) => c.lineId.equals(lineId) & c.deletedAt.isNull())).get();

  /// Plus récent `updated_at` de [line] et [contributions] : un seul
  /// horodatage, postérieur à chacun.
  static int _latest(ListLine line, List<ListContribution> contributions) => [
    line.updatedAt,
    for (final c in contributions) c.updatedAt,
  ].reduce((a, b) => a > b ? a : b);

  Future<void> _deleteContributions(
    List<ListContribution> contributions,
    int stamp,
  ) async {
    if (contributions.isEmpty) return;
    await (_db.update(
      _db.listContributions,
    )..where((c) => c.id.isIn([for (final c in contributions) c.id]))).write(
      ListContributionsCompanion(
        deletedAt: Value(stamp),
        updatedAt: Value(stamp),
      ),
    );
  }

  /// Lignes actives non cochées, dans l'ordre d'ajout (AD-4). Une ligne dont
  /// l'article est supprimé compte comme supprimée (AD-7).
  Stream<List<ListeItem>> watchUnchecked() => _watch(checked: false);

  /// Ids des articles « dans la liste » (AD-4) : ceux qui ont une ligne
  /// active non cochée. Une ligne cochée ou supprimée ne compte pas, ni une
  /// ligne dont l'article est supprimé (AD-7).
  Stream<Set<String>> watchInListArticleIds() {
    final l = _db.listLines;
    final a = _db.articles;
    final query =
        _db.selectOnly(l, distinct: true).join([
            innerJoin(a, a.id.equalsExp(l.articleId) & a.deletedAt.isNull()),
          ])
          ..addColumns([l.articleId])
          ..where(l.deletedAt.isNull() & l.checkedAt.isNull());
    return query.watch().map(
      (rows) => {for (final row in rows) row.read(l.articleId)!},
    );
  }

  /// Lignes actives cochées, la dernière cochée en tête.
  Stream<List<ListeItem>> watchChecked() => _watch(checked: true);

  Stream<List<ListeItem>> _watch({required bool checked}) {
    final (:query, :items) = _items(checked: checked);
    return query.watch().map(items);
  }

  /// Plus ancienne ligne active non cochée de [articleId] (`added_at`, puis
  /// `id`), celle qu'ouvre le crayon du Panneau + ; `null` s'il n'est pas
  /// dans la liste.
  Future<ListeItem?> firstUnchecked(String articleId) async {
    final (:query, :items) = _items(checked: false, articleId: articleId);
    query.limit(1);
    return items(await query.get()).firstOrNull;
  }

  /// Requête des lignes actives, cochées ou non (de [articleId] seul s'il
  /// est donné), avec leur quantité, et sa lecture en [ListeItem].
  ({
    JoinedSelectStatement<HasResultSet, dynamic> query,
    List<ListeItem> Function(List<TypedResult>) items,
  })
  _items({required bool checked, String? articleId}) {
    final l = _db.listLines;
    final a = _db.articles;
    final c = _db.listContributions;
    final quantity = c.quantity.sum();

    var filter =
        l.deletedAt.isNull() &
        (checked ? l.checkedAt.isNotNull() : l.checkedAt.isNull());
    if (articleId != null) filter = filter & l.articleId.equals(articleId);

    final query =
        _db.select(l).join([
            innerJoin(a, a.id.equalsExp(l.articleId) & a.deletedAt.isNull()),
            leftOuterJoin(c, c.lineId.equalsExp(l.id) & c.deletedAt.isNull()),
          ])
          ..where(filter)
          ..addColumns([quantity])
          ..groupBy([l.id])
          ..orderBy(
            checked
                ? [OrderingTerm.desc(l.checkedAt), OrderingTerm.asc(l.id)]
                : [OrderingTerm.asc(l.addedAt), OrderingTerm.asc(l.id)],
          );

    return (
      query: query,
      items: (rows) => [
        for (final row in rows)
          _toItem(row.readTable(l), row.readTable(a), row.read(quantity)),
      ],
    );
  }

  static ListeItem _toItem(ListLine line, Article article, int? quantity) {
    final unit = Unit.tryFromCode(line.unit);
    return ListeItem(
      lineId: line.id,
      articleId: line.articleId,
      name: article.name,
      rayon: Rayon.tryFromCode(line.rayon) ?? Rayon.divers,
      unit: unit,
      quantity: unit == null ? null : quantity,
      checked: line.checkedAt != null,
      articleUnit: Unit.tryFromCode(article.unit),
    );
  }
}
