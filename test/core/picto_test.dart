import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/pictos/phosphor_table.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/features/reglages/ui/picto_grid_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Correspondance choisie par Antoine (dossier de l'epic).
const _mappingPath =
    '_bmad-output/initiative-grocery-list/tickets/epic-reglages-et-sauvegarde/'
    'pictos-phosphor.json';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('PictoResolver : matrice', () {
    test('clé connue : camembert → cheese', () {
      expect(PictoResolver.iconNameFor('camembert', Rayon.cremerie), 'cheese');
    });

    test('clé à repli : oignons → repli Fruits et légumes, leaf', () {
      expect(PictoResolver.iconNameFor('oignons', Rayon.fruitsLegumes), 'leaf');
    });

    test('corrections d’Antoine : lait, jus d’orange, lardons', () {
      expect(PictoResolver.iconNameFor('lait', Rayon.cremerie), 'jar');
      expect(
        PictoResolver.iconNameFor('jus-d-orange', Rayon.boissons),
        'pint-glass',
      );
      expect(
        PictoResolver.iconNameFor('lardons', Rayon.viandePoisson),
        'hamburger',
      );
    });

    test('article créé (« Kombucha », Boissons) : repli Boissons', () {
      expect(
        PictoResolver.iconNameFor('kombucha', Rayon.boissons),
        PictoResolver.fallbackFor(Rayon.boissons),
      );
      expect(PictoResolver.fallbackFor(Rayon.boissons), 'pint-glass');
    });

    test('hors catalogue (`article`, Divers) : repli Divers', () {
      expect(PictoResolver.iconNameFor('article', Rayon.divers), 'package');
      expect(PictoResolver.iconNameFor('', Rayon.divers), 'package');
    });

    test('picto choisi : le nom d’icône est résolu tel quel', () {
      expect(
        PictoResolver.iconNameFor('orange', Rayon.fruitsLegumes),
        'orange',
      );
      expect(
        PictoResolver.iconFor('orange', Rayon.fruitsLegumes),
        phosphorIcons['orange'],
      );
    });

    test('clé inconnue stockée (`zzz`) : repli du rayon', () {
      for (final rayon in Rayon.values) {
        expect(
          PictoResolver.iconNameFor('zzz', rayon),
          pictoRayonFallbacks[rayon.code],
        );
      }
    });
  });

  group('correspondance', () {
    test('la table du code est exactement pictos-phosphor.json', () {
      final json = _readJson(_mappingPath);
      expect(pictoRayonFallbacks, Map<String, String>.from(json['rayons']));
      expect(pictoArticleIcons, Map<String, String?>.from(json['articles']));
    });

    test('chaque rayon a un repli, chaque valeur est une icône du pack', () {
      for (final rayon in Rayon.values) {
        expect(
          phosphorIcons,
          contains(PictoResolver.fallbackFor(rayon)),
          reason: rayon.code,
        );
      }
      for (final icon in pictoArticleIcons.values.nonNulls) {
        expect(phosphorIcons, contains(icon), reason: icon);
      }
    });

    test('chaque picto_key de articles.json résout vers une icône', () {
      final articles =
          (_readJson('assets/seed/articles.json')['articles'] as List)
              .cast<Map<String, dynamic>>();
      expect(articles, hasLength(208));
      for (final a in articles) {
        final key = a['picto_key'] as String;
        final rayon = Rayon.fromCode(a['rayon'] as String);
        expect(pictoArticleIcons, contains(key), reason: key);
        expect(PictoResolver.iconFor(key, rayon), isNotNull, reason: key);
      }
    });
  });

  group('grille : recherche', () {
    test('vide : toutes les icônes, correspondance et replis compris', () {
      final all = pictoGridMatches('');
      expect(all, hasLength(phosphorIcons.length));
      expect(all, containsAll(pictoRayonFallbacks.values.toSet()));
      expect(all, containsAll(pictoArticleIcons.values.nonNulls.toSet()));
    });

    test('par nom anglais : « orange » → orange, orange-slice', () {
      expect(
        pictoGridMatches('orange'),
        containsAll(['orange', 'orange-slice']),
      );
      expect(pictoGridMatches('Cheese'), contains('cheese'));
    });

    test('par nom d’article : « Camembert », « crème », « jus d’orange »', () {
      expect(pictoGridMatches('Camembert'), ['cheese']);
      expect(pictoGridMatches('crème'), contains('jar'));
      expect(pictoGridMatches('jus d’orange'), contains('pint-glass'));
    });

    test('sans résultat : vide', () {
      expect(pictoGridMatches('zzzz'), isEmpty);
    });
  });

  group('Picto', () {
    Future<void> pumpPicto(WidgetTester tester, Widget picto) =>
        tester.pumpWidget(
          MaterialApp(
            theme: KadiTheme.light,
            home: Scaffold(body: Center(child: picto)),
          ),
        );

    testWidgets('icône Phosphor teintée de l’accent du rayon, 24 dp, '
        'jamais de rond neutre, exclue de la sémantique', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPicto(
        tester,
        const Picto(pictoKey: 'camembert', rayon: Rayon.cremerie),
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(Picto), matching: find.byType(Icon)),
      );
      final context = tester.element(find.byType(Picto));
      expect(icon.icon, phosphorIcons['cheese']);
      expect(icon.size, 24);
      expect(icon.color, KadiColors.of(context).rayon(Rayon.cremerie).accent);
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      expect(tester.getSize(find.byType(Picto)), const Size.square(24));
      // Rien de lu : ni libellé, ni nœud propre au Picto.
      final pictoChild = tester.widget(
        find
            .descendant(
              of: find.byType(Picto),
              matching: find.byType(ExcludeSemantics),
            )
            .first,
      );
      expect((pictoChild as ExcludeSemantics).excluding, isTrue);
      expect(find.bySemanticsLabel(RegExp('cheese')), findsNothing);
      handle.dispose();
    });

    testWidgets('repli de la Carte recette à 44 dp', (tester) async {
      await pumpPicto(
        tester,
        const Picto(pictoKey: 'article', rayon: Rayon.divers, size: 44),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, phosphorIcons['package']);
      expect(icon.size, 44);
    });
  });
}
