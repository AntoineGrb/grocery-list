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
  Unit? articleUnit,
}) => RevueSource(
  selectionId: selection,
  articleId: article,
  name: article,
  pictoKey: article.toLowerCase(),
  rayon: rayon,
  quantity: quantity,
  unit: unit,
  articleUnit: articleUnit,
);

/// La ligne de [article] de [revue].
RevueLine _line(Revue revue, String article) =>
    [for (final g in revue.groups) ...g.lines]
        .singleWhere((l) => l.articleId == article);

/// Une entrée par contribution écrite : « article sélection quantité unité ».
List<String> _writes(Revue revue, RevueDraft draft) => [
  for (final w in revueWrites(revue, draft))
    '${w.articleId} ${w.selectionId} ${w.quantity} ${w.unit?.code}',
];

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

  group('ligne : clé et unité du champ', () {
    test('clé = article et unité, stable', () {
      final revue = _build([
        _source('a', 'Tomates', quantity: 500, unit: Unit.g),
        _source('b', 'Tomates', quantity: 2000, unit: Unit.piece),
        _source('a', 'Poivre'),
      ]);
      final keys = [
        for (final g in revue.groups)
          for (final l in g.lines) l.key,
      ];
      expect(keys, ['Tomates|g', 'Tomates|piece', 'Poivre|-']);
    });

    test('unité du champ : celle de la ligne, sinon celle de l’article, '
        'sinon la pièce', () {
      final revue = _build([
        _source('a', 'Lait', quantity: 500, unit: Unit.ml, articleUnit: Unit.g),
        _source('a', 'Farine', articleUnit: Unit.g),
        _source('a', 'Poivre'),
      ]);
      expect(_line(revue, 'Lait').fieldUnit, Unit.ml);
      expect(_line(revue, 'Farine').fieldUnit, Unit.g);
      expect(_line(revue, 'Poivre').fieldUnit, Unit.piece);
    });
  });

  group('contributions à écrire (brouillon, AD-4)', () {
    final carbonaraQuiche = _build([
      _source('carbonara', 'Pâtes', quantity: 500, unit: Unit.g),
      _source('carbonara', 'Lardons', quantity: 200, unit: Unit.g),
      _source('carbonara', 'Œufs', quantity: 4000, unit: Unit.piece),
      _source('quiche', 'Lardons', quantity: 300, unit: Unit.g),
      _source('quiche', 'Œufs', quantity: 4000, unit: Unit.piece),
    ]);
    String key(String article) => _line(carbonaraQuiche, article).key;

    test('sans brouillon : les parts d’origine', () {
      expect(_writes(carbonaraQuiche, const RevueDraft()), [
        'Pâtes carbonara 500 g',
        'Lardons carbonara 200 g',
        'Lardons quiche 300 g',
        'Œufs carbonara 4000 piece',
        'Œufs quiche 4000 piece',
      ]);
    });

    test('Pâtes décochées : aucune contribution, rien d’autre ne change', () {
      expect(_writes(carbonaraQuiche, RevueDraft(unchecked: {key('Pâtes')})), [
        'Lardons carbonara 200 g',
        'Lardons quiche 300 g',
        'Œufs carbonara 4000 piece',
        'Œufs quiche 4000 piece',
      ]);
    });

    test('Œufs 4 + 4 corrigé à 6 : 3 et 3 pièces', () {
      final draft = RevueDraft(corrections: {key('Œufs'): 6000});
      expect(
        _writes(carbonaraQuiche, draft).where((w) => w.startsWith('Œufs')),
        ['Œufs carbonara 3000 piece', 'Œufs quiche 3000 piece'],
      );
    });

    test('Œufs 4 + 4 corrigé à 7 : 3 et 4, la dernière absorbe le reste', () {
      final draft = RevueDraft(corrections: {key('Œufs'): 7000});
      expect(
        _writes(carbonaraQuiche, draft).where((w) => w.startsWith('Œufs')),
        ['Œufs carbonara 3000 piece', 'Œufs quiche 4000 piece'],
      );
    });

    test('Lardons 200 + 300 corrigé à 400 : 160 g et 240 g', () {
      final draft = RevueDraft(corrections: {key('Lardons'): 400});
      expect(
        _writes(carbonaraQuiche, draft).where((w) => w.startsWith('Lardons')),
        ['Lardons carbonara 160 g', 'Lardons quiche 240 g'],
      );
    });

    test('champ vidé : toutes les parts sans quantité', () {
      final draft = RevueDraft(corrections: {key('Lardons'): null});
      expect(
        _writes(carbonaraQuiche, draft).where((w) => w.startsWith('Lardons')),
        ['Lardons carbonara null null', 'Lardons quiche null null'],
      );
    });

    test('valeur retapée identique : les parts d’origine', () {
      final draft = RevueDraft(
        corrections: {key('Lardons'): 500, key('Œufs'): 8000},
      );
      expect(
        _writes(carbonaraQuiche, draft),
        _writes(carbonaraQuiche, const RevueDraft()),
      );
    });

    test('tout décoché : aucune contribution', () {
      final draft = RevueDraft(
        unchecked: {key('Pâtes'), key('Lardons'), key('Œufs')},
        corrections: {key('Lardons'): 100},
      );
      expect(revueWrites(carbonaraQuiche, draft), isEmpty);
    });

    test('décochée puis recochée (absente du brouillon) : écrite', () {
      expect(
        _writes(carbonaraQuiche, RevueDraft(unchecked: {key('Œufs')})),
        hasLength(3),
      );
    });

    test('Poivre sans quantité dans deux recettes, saisi 2 : poids égaux, '
        'dans la pièce sans unité d’article', () {
      final revue = _build([_source('a', 'Poivre'), _source('b', 'Poivre')]);
      final draft = RevueDraft(corrections: {_line(revue, 'Poivre').key: 2000});
      expect(_writes(revue, draft), [
        'Poivre a 1000 piece',
        'Poivre b 1000 piece',
      ]);
    });

    test('sans quantité d’origine, saisi dans l’unité de l’article', () {
      final revue = _build([
        _source('a', 'Farine', articleUnit: Unit.g),
        _source('b', 'Farine', articleUnit: Unit.g),
      ]);
      final draft = RevueDraft(corrections: {_line(revue, 'Farine').key: 2});
      expect(_writes(revue, draft), ['Farine a 1 g', 'Farine b 1 g']);
    });

    test('une part sans quantité d’origine reçoit sa part : 0, donc sans '
        'quantité', () {
      final revue = _build([
        _source('a', 'Oignons'),
        _source('b', 'Oignons', quantity: 2000, unit: Unit.piece),
      ]);
      final draft = RevueDraft(
        corrections: {_line(revue, 'Oignons').key: 3000},
      );
      expect(_writes(revue, draft), [
        'Oignons a null null',
        'Oignons b 3000 piece',
      ]);
    });

    test('ligne sans quantité laissée vide : inchangée', () {
      final revue = _build([_source('a', 'Poivre')]);
      final draft = RevueDraft(corrections: {_line(revue, 'Poivre').key: null});
      expect(_writes(revue, draft), ['Poivre a null null']);
    });
  });

  group('prorata : la somme écrite vaut exactement V', () {
    final cases = <(List<int>, int, int)>[
      ([4000, 4000], 7000, 1000),
      ([4000, 4000], 1000, 1000),
      ([3000, 3000, 3000], 10000, 1000),
      ([1000, 2000, 4000], 5000, 1000),
      ([200, 300], 400, 1),
      ([1, 1, 1], 100, 1),
      ([333, 333, 334], 7, 1),
      ([0, 0, 0], 5000, 1000),
      ([0, 500], 999, 1),
      ([999999, 1], 999999, 1),
      ([60, 100, 200, 500], 1234, 1),
      ([1500, 500], 3000, 1000),
    ];
    for (final (weights, total, step) in cases) {
      test('$weights → $total (pas $step)', () {
        final shares = prorata(total, weights, step: step);
        expect(shares, hasLength(weights.length));
        expect(shares.fold(0, (a, b) => a + b), total);
        expect(shares.every((s) => s >= 0), isTrue);
        for (final s in shares.take(shares.length - 1)) {
          expect(s % step, 0);
        }
      });
    }

    test('de 1 à 50 pièces sur trois parts inégales', () {
      for (var v = 1; v <= 50; v++) {
        final shares = prorata(v * 1000, [1000, 3000, 2000], step: 1000);
        expect(shares.fold(0, (a, b) => a + b), v * 1000);
        expect(shares.every((s) => s % 1000 == 0 && s >= 0), isTrue);
      }
    });
  });
}
