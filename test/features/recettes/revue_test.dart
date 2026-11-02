import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

RevueSource _source(
  String selection,
  String article, {
  Rayon rayon = Rayon.divers,
  int? quantity,
  Unit? unit,
}) => RevueSource(
  selectionId: selection,
  articleId: article,
  name: article,
  pictoKey: article.toLowerCase(),
  rayon: rayon,
  quantity: quantity,
  unit: unit,
);

Revue _build(List<RevueSource> ingredients, {List<Rayon>? routeOrder}) =>
    buildRevue(
      selectionIds: {for (final i in ingredients) i.selectionId}.toList(),
      ingredients: ingredients,
      routeOrder: routeOrder ?? Rayon.values,
    );

/// Une entrée par ligne : « rayon : nom quantité unité », rayon par rayon.
List<String> _summary(Revue revue) => [
  for (final g in revue.groups)
    for (final l in g.lines)
      '${g.rayon.code} : ${l.name} ${l.quantity} ${l.unit?.code}',
];

void main() {
  test('même article, même unité : une ligne, quantités additionnées, '
      'chaque part gardée', () {
    final revue = _build([
      _source('carbonara', 'Lardons', quantity: 200, unit: Unit.g),
      _source('quiche', 'Lardons', quantity: 200, unit: Unit.g),
    ]);
    expect(_summary(revue), ['divers : Lardons 400 g']);
    final line = revue.groups.single.lines.single;
    expect(
      [for (final c in line.contributions) c.selectionId],
      ['carbonara', 'quiche'],
    );
  });

  test('même article, deux unités : deux lignes, jamais de somme', () {
    final revue = _build([
      _source('a', 'Tomates', quantity: 500, unit: Unit.g),
      _source('b', 'Tomates', quantity: 2000, unit: Unit.piece),
    ]);
    expect(_summary(revue), [
      'divers : Tomates 500 g',
      'divers : Tomates 2000 piece',
    ]);
  });

  test('sans quantité puis chiffré : une ligne chiffrée', () {
    final revue = _build([
      _source('a', 'Oignons'),
      _source('b', 'Oignons', quantity: 2000, unit: Unit.piece),
    ]);
    expect(_summary(revue), ['divers : Oignons 2000 piece']);
    expect(revue.groups.single.lines.single.contributions, hasLength(2));
  });

  test('chiffré puis sans quantité : une ligne chiffrée', () {
    final revue = _build([
      _source('a', 'Oignons', quantity: 1000, unit: Unit.piece),
      _source('b', 'Oignons'),
    ]);
    expect(_summary(revue), ['divers : Oignons 1000 piece']);
  });

  test('sans quantité seul : une ligne sans quantité', () {
    final revue = _build([_source('a', 'Poivre'), _source('b', 'Poivre')]);
    expect(_summary(revue), ['divers : Poivre null null']);
  });

  test('rayons dans l’ordre du parcours, lignes dans l’ordre de première '
      'apparition', () {
    final revue = _build(
      [
        _source(
          'a',
          'Pâtes',
          rayon: Rayon.epicerieSalee,
          quantity: 500,
          unit: Unit.g,
        ),
        _source(
          'a',
          'Lardons',
          rayon: Rayon.viandePoisson,
          quantity: 200,
          unit: Unit.g,
        ),
        _source('a', 'Poivre', rayon: Rayon.epicerieSalee),
        _source(
          'b',
          'Riz',
          rayon: Rayon.epicerieSalee,
          quantity: 300,
          unit: Unit.g,
        ),
      ],
      routeOrder: [
        Rayon.viandePoisson,
        ...Rayon.values.where((r) => r != Rayon.viandePoisson),
      ],
    );
    expect(_summary(revue), [
      'viande-poisson : Lardons 200 g',
      'epicerie-salee : Pâtes 500 g',
      'epicerie-salee : Poivre null null',
      'epicerie-salee : Riz 300 g',
    ]);
    expect(revue.selectionIds, ['a', 'b']);
  });
}
