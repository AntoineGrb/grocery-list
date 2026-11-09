import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';

import '../data/recettes_repository.dart';

/// Part d'une recette dans une Ligne de Revue : sa sélection et sa quantité
/// d'origine. Ajouter à la liste en écrit une contribution chacune (AD-4).
class RevueContribution {
  const RevueContribution({
    required this.selectionId,
    this.quantity,
    this.unit,
  });

  final String selectionId;

  /// Quantité stockée (AD-6), nulle avec [unit].
  final int? quantity;
  final Unit? unit;
}

/// Ligne de Revue : un article dans une unité, ou sans quantité.
class RevueLine {
  const RevueLine({
    required this.articleId,
    required this.name,
    required this.rayon,
    required this.unit,
    required this.contributions,
    this.articleUnit,
  });

  final String articleId;
  final String name;
  final Rayon rayon;

  /// Unité de la ligne ; nulle : sans quantité.
  final Unit? unit;

  /// Unité par défaut de l'article (`articles.unit`), nulle sans unité.
  final Unit? articleUnit;

  /// Parts des recettes, dans l'ordre des recettes puis `position`.
  final List<RevueContribution> contributions;

  /// Clé stable de la ligne dans sa Revue : article et unité (une ligne par
  /// article et par unité, AD-4).
  String get key => '$articleId|${unitKey(unit)}';

  /// Unité du Champ quantité : celle de la ligne, sinon l'unité par défaut
  /// de l'article, sinon la pièce. Jamais changée en Revue.
  Unit get fieldUnit => unit ?? articleUnit ?? Unit.piece;

  /// Somme des quantités chiffrées ; nulle sans unité.
  int? get quantity {
    if (unit == null) return null;
    var sum = 0;
    for (final c in contributions) {
      sum += c.quantity ?? 0;
    }
    return sum == 0 ? null : sum;
  }
}

/// Un rayon de la Revue et ses lignes, dans l'ordre de première apparition.
class RevueGroup {
  const RevueGroup(this.rayon, this.lines);

  final Rayon rayon;
  final List<RevueLine> lines;
}

/// Instantané de la Revue (brouillon d'écran, AD-1) : les sélections qu'elle
/// valide et ses lignes groupées par rayon.
class Revue {
  const Revue({required this.selectionIds, required this.groups});

  /// Sélections validées par Ajouter à la liste, même sans ligne (AD-16).
  final List<String> selectionIds;
  final List<RevueGroup> groups;
}

/// Construit la Revue des [ingredients] (ordre des recettes puis `position`)
/// des sélections [selectionIds], groupée par rayon actuel de l'article dans
/// l'ordre [routeOrder].
///
/// Fusion alignée sur AD-4 : par article, une ligne par unité. Un ingrédient
/// chiffré rejoint la ligne de son unité, sinon la ligne sans quantité de
/// l'article, qui prend son unité, sinon une nouvelle ligne. Un ingrédient
/// sans quantité rejoint la première ligne de l'article, sinon une nouvelle
/// ligne sans quantité. Aucune conversion entre unités (AD-6).
Revue buildRevue({
  required List<String> selectionIds,
  required List<RevueSource> ingredients,
  required List<Rayon> routeOrder,
}) {
  final lines = <_LineBuilder>[];
  final byArticle = <String, List<_LineBuilder>>{};
  for (final source in ingredients) {
    final articleLines = byArticle.putIfAbsent(source.articleId, () => []);
    final unit = source.unit;
    _LineBuilder? target;
    if (unit == null) {
      target = articleLines.firstOrNull;
    } else {
      target =
          articleLines.where((l) => l.unit == unit).firstOrNull ??
          articleLines.where((l) => l.unit == null).firstOrNull;
      target?.unit = unit;
    }
    if (target == null) {
      target = _LineBuilder(source, unit);
      articleLines.add(target);
      lines.add(target);
    }
    target.contributions.add(
      RevueContribution(
        selectionId: source.selectionId,
        quantity: source.quantity,
        unit: source.unit,
      ),
    );
  }

  return Revue(
    selectionIds: List.unmodifiable(selectionIds),
    groups: [
      for (final (rayon, group) in groupByRayon(
        lines,
        (line) => line.source.rayon,
        routeOrder,
      ))
        RevueGroup(rayon, [for (final line in group) line.build()]),
    ],
  );
}

class _LineBuilder {
  _LineBuilder(this.source, this.unit);

  /// Premier ingrédient de la ligne : article, nom et rayon.
  final RevueSource source;
  Unit? unit;
  final contributions = <RevueContribution>[];

  RevueLine build() => RevueLine(
    articleId: source.articleId,
    name: source.name,
    rayon: source.rayon,
    unit: unit,
    articleUnit: source.articleUnit,
    contributions: List.unmodifiable(contributions),
  );
}

/// Brouillon d'écran de la Revue (AD-1), jamais persisté : ce qu'Antoine a
/// décoché et corrigé, par [RevueLine.key].
class RevueDraft {
  const RevueDraft({
    this.unchecked = const {},
    this.corrections = const {},
    this.units = const {},
  });

  /// Clés des lignes décochées : rien n'en est écrit.
  final Set<String> unchecked;

  /// Quantité stockée saisie dans l'unité du champ ([RevueLine.fieldUnit]),
  /// par clé de ligne ; nulle : champ vidé, « sans quantité ».
  final Map<String, int?> corrections;

  /// Unité stockée d'une correction quand le Module quantité en a changé
  /// (V2), par clé de ligne ; absente : [RevueLine.fieldUnit].
  final Map<String, Unit> units;
}

/// Contribution `week_selection` à écrire par Ajouter à la liste.
class RevueWrite {
  const RevueWrite({
    required this.articleId,
    required this.selectionId,
    this.quantity,
    this.unit,
  });

  final String articleId;
  final String selectionId;

  /// Quantité stockée (AD-6), nulle avec [unit].
  final int? quantity;
  final Unit? unit;

  @override
  bool operator ==(Object other) =>
      other is RevueWrite &&
      other.articleId == articleId &&
      other.selectionId == selectionId &&
      other.quantity == quantity &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(articleId, selectionId, quantity, unit);

  @override
  String toString() =>
      'RevueWrite($articleId, $selectionId, $quantity ${unit?.code})';
}

/// Contributions à écrire depuis [revue] et son [draft], dans l'ordre de la
/// Revue :
///
/// - ligne décochée : aucune ;
/// - ligne non corrigée, ou corrigée à sa valeur d'origine : ses parts
///   d'origine ;
/// - champ vidé : toutes ses parts sans quantité ;
/// - corrigée à V : V réparti entre ses parts au prorata de leurs quantités
///   d'origine (poids égaux si aucune n'en a), arrondi vers le bas dans
///   l'unité (pièce entière pour les pièces), la dernière part absorbant le
///   reste : la somme écrite vaut exactement V. Une part de 0 s'écrit sans
///   quantité (AD-4).
List<RevueWrite> revueWrites(Revue revue, RevueDraft draft) {
  final writes = <RevueWrite>[];
  for (final group in revue.groups) {
    for (final line in group.lines) {
      final key = line.key;
      if (draft.unchecked.contains(key)) continue;
      final unitChanged =
          draft.units.containsKey(key) && draft.units[key] != line.unit;
      final corrected =
          draft.corrections.containsKey(key) &&
          (draft.corrections[key] != line.quantity || unitChanged);
      if (!corrected) {
        for (final c in line.contributions) {
          writes.add(
            RevueWrite(
              articleId: line.articleId,
              selectionId: c.selectionId,
              quantity: c.quantity,
              unit: c.unit,
            ),
          );
        }
        continue;
      }
      final total = draft.corrections[key];
      final unit = draft.units[key] ?? line.fieldUnit;
      final shares = total == null
          ? [for (final _ in line.contributions) 0]
          : prorata(total, [
              for (final c in line.contributions) c.quantity ?? 0,
            ], step: unit == Unit.piece ? InputUnit.piece.factor : 1);
      for (final (i, c) in line.contributions.indexed) {
        final share = shares[i];
        writes.add(
          RevueWrite(
            articleId: line.articleId,
            selectionId: c.selectionId,
            quantity: share > 0 ? share : null,
            unit: share > 0 ? unit : null,
          ),
        );
      }
    }
  }
  return writes;
}

/// Répartit [total] selon [weights] (poids égaux s'ils sont tous nuls),
/// chaque part sauf la dernière arrondie vers le bas au multiple de [step],
/// la dernière prenant le reste : la somme vaut exactement [total].
List<int> prorata(int total, List<int> weights, {int step = 1}) {
  if (weights.isEmpty) return const [];
  final effective = weights.every((w) => w <= 0)
      ? [for (final _ in weights) 1]
      : [for (final w in weights) w < 0 ? 0 : w];
  final sum = effective.fold(0, (a, b) => a + b);
  final shares = <int>[];
  var given = 0;
  for (var i = 0; i < effective.length - 1; i++) {
    final share = total * effective[i] ~/ sum ~/ step * step;
    shares.add(share);
    given += share;
  }
  shares.add(total - given);
  return shares;
}
