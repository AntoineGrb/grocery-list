import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

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
    required this.pictoKey,
    required this.rayon,
    required this.unit,
    required this.contributions,
  });

  final String articleId;
  final String name;
  final String pictoKey;
  final Rayon rayon;

  /// Unité de la ligne ; nulle : sans quantité.
  final Unit? unit;

  /// Parts des recettes, dans l'ordre des recettes puis `position`.
  final List<RevueContribution> contributions;

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

  /// Premier ingrédient de la ligne : article, nom, picto et rayon.
  final RevueSource source;
  Unit? unit;
  final contributions = <RevueContribution>[];

  RevueLine build() => RevueLine(
    articleId: source.articleId,
    name: source.name,
    pictoKey: source.pictoKey,
    rayon: source.rayon,
    unit: unit,
    contributions: List.unmodifiable(contributions),
  );
}
