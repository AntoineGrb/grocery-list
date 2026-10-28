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
  });

  final String lineId;
  final String articleId;
  final String name;
  final Rayon rayon;
  final Unit? unit;

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
  /// échec n'écrit rien.
  Future<void> addArticle(String articleId, {int? quantity, Unit? unit}) {
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
  /// (AD-15).
  Future<void> _contribute({
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

    await _db
        .into(_db.listContributions)
        .insert(
          ListContributionsCompanion.insert(
            id: _uuid.v4(),
            updatedAt: now,
            lineId: lineId,
            source: source,
            quantity: Value(quantity),
            unit: Value(unit?.code),
          ),
        );
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

  Future<ListLine?> _activeLine(String lineId) =>
      (_db.select(_db.listLines)
            ..where((l) => l.id.equals(lineId) & l.deletedAt.isNull()))
          .getSingleOrNull();

  /// Lignes actives non cochées, dans l'ordre d'ajout (AD-4). Une ligne dont
  /// l'article est supprimé compte comme supprimée (AD-7).
  Stream<List<ListeItem>> watchUnchecked() => _watch(checked: false);

  /// Lignes actives cochées, la dernière cochée en tête.
  Stream<List<ListeItem>> watchChecked() => _watch(checked: true);

  Stream<List<ListeItem>> _watch({required bool checked}) {
    final l = _db.listLines;
    final a = _db.articles;
    final c = _db.listContributions;
    final quantity = c.quantity.sum();

    final query =
        _db.select(l).join([
            innerJoin(a, a.id.equalsExp(l.articleId) & a.deletedAt.isNull()),
            leftOuterJoin(c, c.lineId.equalsExp(l.id) & c.deletedAt.isNull()),
          ])
          ..where(
            l.deletedAt.isNull() &
                (checked ? l.checkedAt.isNotNull() : l.checkedAt.isNull()),
          )
          ..addColumns([quantity])
          ..groupBy([l.id])
          ..orderBy(
            checked
                ? [OrderingTerm.desc(l.checkedAt), OrderingTerm.asc(l.id)]
                : [OrderingTerm.asc(l.addedAt), OrderingTerm.asc(l.id)],
          );

    return query.watch().map(
      (rows) => [
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
    );
  }
}
