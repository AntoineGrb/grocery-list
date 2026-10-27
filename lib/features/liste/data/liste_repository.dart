import 'package:drift/drift.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:uuid/uuid.dart';

/// Sources d'une contribution (AD-4, AD-5).
abstract final class ContributionSource {
  static const weekSelection = 'week_selection';
  static const ajout = 'ajout';
  static const edition = 'edition';
}

/// Ligne active non cochée de la Liste, avec sa quantité calculée.
class ListeItem {
  const ListeItem({
    required this.lineId,
    required this.articleId,
    required this.name,
    required this.rayon,
    required this.unit,
    required this.quantity,
  });

  final String lineId;
  final String articleId;
  final String name;
  final Rayon rayon;
  final Unit? unit;

  /// Somme des contributions actives ; nulle sans quantité (AD-4).
  final int? quantity;
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

  /// Lignes actives non cochées, dans l'ordre d'ajout (AD-4). Une ligne dont
  /// l'article est supprimé compte comme supprimée (AD-7).
  Stream<List<ListeItem>> watchUnchecked() {
    final l = _db.listLines;
    final a = _db.articles;
    final c = _db.listContributions;
    final quantity = c.quantity.sum();

    final query =
        _db.select(l).join([
            innerJoin(a, a.id.equalsExp(l.articleId) & a.deletedAt.isNull()),
            leftOuterJoin(c, c.lineId.equalsExp(l.id) & c.deletedAt.isNull()),
          ])
          ..where(l.deletedAt.isNull() & l.checkedAt.isNull())
          ..addColumns([quantity])
          ..groupBy([l.id])
          ..orderBy([OrderingTerm.asc(l.addedAt), OrderingTerm.asc(l.id)]);

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
    );
  }
}
