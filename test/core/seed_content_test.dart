import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';

import '../helpers/test_db.dart';

/// Contrôle du contenu réel de `assets/seed/` (contraintes de la story 1.3).
void main() {
  late List<Map<String, dynamic>> articles;
  late List<Map<String, dynamic>> frequents;

  setUpAll(() async {
    final a = jsonDecode(
      await diskAssetLoader(SeedLoader.articlesPath),
    ) as Map<String, dynamic>;
    final f = jsonDecode(
      await diskAssetLoader(SeedLoader.frequentsPath),
    ) as Map<String, dynamic>;
    expect(a['seed_version'], 2);
    expect(f['seed_version'], 1);
    articles = (a['articles'] as List).cast<Map<String, dynamic>>();
    frequents = (f['frequents'] as List).cast<Map<String, dynamic>>();
  });

  test('180 à 220 articles, 25 à 35 fréquents', () {
    expect(articles.length, inInclusiveRange(180, 220));
    expect(frequents.length, inInclusiveRange(25, 35));
  });

  test('UUID v4 distincts', () {
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = [for (final a in articles) a['id'] as String];
    expect(ids.where((id) => !v4.hasMatch(id)), isEmpty);
    expect(ids.toSet().length, ids.length);
  });

  test('les 7 articles de la story 1 sont intacts', () {
    for (final o in originalArticles) {
      final a = articles.singleWhere((a) => a['id'] == o['id']);
      expect(a, o);
    }
  });

  test('noms : majuscule initiale, normalisés distincts', () {
    final names = [for (final a in articles) a['name'] as String];
    for (final n in names) {
      expect(n, n.trim());
      expect(n.isNotEmpty && n[0] == n[0].toUpperCase(), isTrue, reason: n);
      expect(n[0].toUpperCase() != n[0].toLowerCase(), isTrue, reason: n);
    }
    final normalized = names.map(normalizeName).toList();
    expect(normalized.toSet().length, normalized.length);
  });

  test('picto_key en kebab-case ASCII, uniques', () {
    final kebab = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
    final keys = [for (final a in articles) a['picto_key'] as String];
    expect(keys.where((k) => !kebab.hasMatch(k)), isEmpty);
    expect(keys.toSet().length, keys.length);
  });

  test('rayons et unités valides, au moins 5 articles par rayon', () {
    final perRayon = <Rayon, int>{};
    for (final a in articles) {
      final rayon = Rayon.tryFromCode(a['rayon'] as String);
      expect(rayon, isNotNull, reason: '${a['name']}');
      perRayon[rayon!] = (perRayon[rayon] ?? 0) + 1;
      expect(
        a['unit'],
        anyOf(isNull, 'g', 'ml', 'piece'),
        reason: '${a['name']}',
      );
    }
    for (final r in Rayon.values.where((r) => r != Rayon.divers)) {
      expect(perRayon[r] ?? 0, greaterThanOrEqualTo(5), reason: r.code);
    }
  });

  group('recettes exemples', () {
    late List<Map<String, dynamic>> recettes;

    setUpAll(() async {
      final r = jsonDecode(
        await diskAssetLoader(SeedLoader.recettesPath),
      ) as Map<String, dynamic>;
      expect(r['seed_version'], 1);
      recettes = (r['recettes'] as List).cast<Map<String, dynamic>>();
    });

    List<Map<String, dynamic>> ingredientsOf(Map<String, dynamic> r) =>
        (r['ingredients'] as List).cast<Map<String, dynamic>>();

    test('4 recettes nommées, avec leurs ingrédients', () {
      expect(recettes.map((r) => r['name']), [
        'Pâtes carbonara',
        'Chili con carne',
        'Quiche lorraine',
        'Ratatouille',
      ]);
      for (final r in recettes) {
        expect(ingredientsOf(r), isNotEmpty, reason: '${r['name']}');
      }
      expect(recettes.map((r) => r['id']), [
        SeedRecipeIds.carbonara,
        SeedRecipeIds.chili,
        SeedRecipeIds.quiche,
        SeedRecipeIds.ratatouille,
      ]);
    });

    test('UUID v4 distincts, recettes et ingrédients', () {
      final v4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final ids = [
        for (final r in recettes) ...[
          r['id'] as String,
          for (final i in ingredientsOf(r)) i['id'] as String,
        ],
      ];
      expect(ids.where((id) => !v4.hasMatch(id)), isEmpty);
      expect(ids.toSet().length, ids.length);
    });

    test('ingrédients : articles existants, une fois par recette, unité de '
        'l’article ou sans quantité', () {
      final byId = {for (final a in articles) a['id'] as String: a};
      for (final r in recettes) {
        final articleIds = [
          for (final i in ingredientsOf(r)) i['article_id'] as String,
        ];
        expect(articleIds.toSet().length, articleIds.length);
        for (final i in ingredientsOf(r)) {
          final article = byId[i['article_id']];
          expect(article, isNotNull, reason: '${r['name']} : $i');
          final quantity = i['quantity'] as int?;
          if (quantity == null) {
            expect(i['unit'], isNull, reason: '${r['name']} : $i');
          } else {
            expect(quantity, greaterThan(0));
            expect(i['unit'], article!['unit'], reason: '${r['name']} : $i');
          }
        }
      }
    });
  });

  test('fréquents : un par article du fichier, triés par rayon', () {
    final byId = {for (final a in articles) a['id'] as String: a};
    final articleIds = [for (final f in frequents) f['article_id'] as String];
    expect(articleIds.where((id) => !byId.containsKey(id)), isEmpty);
    expect(articleIds.toSet().length, articleIds.length);
    final rayonIndexes = [
      for (final id in articleIds)
        Rayon.fromCode(byId[id]!['rayon'] as String).index,
    ];
    expect(rayonIndexes, [...rayonIndexes]..sort());
  });
}
