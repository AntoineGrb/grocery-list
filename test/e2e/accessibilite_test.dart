import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:kadi/features/liste/ui/item_edit_sheet.dart';
import 'package:kadi/features/liste/ui/quantity_popup.dart';
import 'package:kadi/features/liste/ui/quantity_tag.dart';
import 'package:kadi/features/liste/ui/row_highlight.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:kadi/features/reglages/ui/article_lines.dart';
import 'package:kadi/features/reglages/ui/article_sheet.dart';
import 'package:kadi/features/reglages/ui/articles_screen.dart';
import 'package:kadi/features/reglages/ui/frequents_screen.dart';
import 'package:kadi/features/reglages/ui/parcours_screen.dart';
import 'package:kadi/features/reglages/ui/picto_grid_sheet.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e_harness.dart';

/// Contrôle d'une surface : [surface] nomme celle qui est affichée.
typedef SurfaceCheck = Future<void> Function(String surface);

final _quantityTag = find.byWidgetPredicate(
  (w) => w is QuantityTag && w.emptyLabel == StringsFr.quantite,
);

/// Ferme la feuille, la popup ou le dialogue du dessus (geste retour).
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Parcourt toutes les surfaces de l'app par les gestes, en appelant
/// [check] sur chacune, l'app ouverte sur la Liste vide.
Future<void> _visitSurfaces(WidgetTester tester, SurfaceCheck check) async {
  // Recettes.
  await openTab(tester, StringsFr.tabRecettes);
  await check('Recettes');

  // Revue.
  await tapRecipeCard(tester, 'Pâtes carbonara');
  await openRevue(tester, 1);
  expect(find.byType(RevueScreen), findsOneWidget);
  await check('Revue');

  // Liste.
  await tapAndSettle(tester, ajouterALaListe);
  await letSnackBarClose(tester);
  await check('Liste');

  // Section Cochés dépliée.
  await checkItem(tester, 'Lardons');
  await tapAndSettle(tester, find.text(StringsFr.cochesTitre(1)));
  expect(find.byType(CheckedSection), findsOneWidget);
  await check('Liste, Section Cochés dépliée');

  // Feuille d'édition (appui long).
  await tester.ensureVisible(itemRow('Pâtes'));
  await tester.pumpAndSettle();
  await tester.longPress(itemRow('Pâtes'));
  await tester.pumpAndSettle();
  expect(find.byType(ItemEditSheet), findsOneWidget);
  await check('Feuille d’édition');
  await _pressBack(tester);
  expect(find.byType(ItemEditSheet), findsNothing);

  // Panneau + et Popup quantité.
  await openAddSheet(tester);
  await check('Liste avec Panneau +');
  await tapAndSettle(tester, _quantityTag);
  expect(find.byType(QuantityPopup), findsOneWidget);
  await check('Popup quantité');
  await _pressBack(tester);
  expect(find.byType(QuantityPopup), findsNothing);
  await closeAddSheet(tester);

  // Fiche recette et popup d'ajout d'ingrédient.
  await openTab(tester, StringsFr.tabRecettes);
  await editRecipe(tester, 'Chili con carne');
  await check('Fiche recette');
  await openIngredientSheet(tester);
  await tester.enterText(ingredientSheetField, 'riz');
  await tester.pumpAndSettle();
  await check('Popup d’ajout d’ingrédient');
  await closeIngredientSheet(tester);
  await backFromFiche(tester);

  // Paramètres et sous-écrans.
  await openParametres(tester);
  await check('Paramètres');
  await tapParametre(tester, StringsFr.parcours);
  expect(find.byType(ParcoursScreen), findsOneWidget);
  await check('Paramètres › Parcours');
  await tapAndSettle(tester, find.byType(BackButton));

  await tapParametre(tester, StringsFr.articlesTitre);
  expect(find.byType(ArticlesScreen), findsOneWidget);
  await check('Paramètres › Articles');
  await tester.enterText(
    find.descendant(
      of: find.byType(ArticlesScreen),
      matching: find.byType(TextField),
    ),
    'lait',
  );
  await tester.pumpAndSettle();
  await tapAndSettle(
    tester,
    find.byWidgetPredicate((w) => w is ArticleLine && w.article.name == 'Lait'),
  );
  expect(find.byType(ArticleSheet), findsOneWidget);
  await check('Fiche article');
  await tapAndSettle(tester, find.byKey(const ValueKey('picto-button')));
  expect(find.byType(PictoGridSheet), findsOneWidget);
  await check('Grille de pictos');
  await _pressBack(tester);
  expect(find.byType(PictoGridSheet), findsNothing);
  await _pressBack(tester);
  expect(find.byType(ArticleSheet), findsNothing);
  await tapAndSettle(tester, find.byType(BackButton));

  await tapParametre(tester, StringsFr.frequentsTitre);
  expect(find.byType(FrequentsScreen), findsOneWidget);
  await check('Paramètres › Fréquents');
  await tapAndSettle(tester, find.byType(BackButton));
}

void accessibilite() {
  group('Plancher d’accessibilité', () {
    testBothThemes('chaque surface : cibles de 48 dp, cibles nommées, '
        'contraste du texte', (tester) async {
      phone(tester, size: const Size(412, 914));
      final handle = tester.ensureSemantics();
      await pumpE2e(tester);
      final visited = <String>[];
      await _visitSurfaces(tester, (surface) async {
        visited.add(surface);
        for (final (name, guideline) in [
          ('androidTapTargetGuideline', androidTapTargetGuideline),
          ('labeledTapTargetGuideline', labeledTapTargetGuideline),
          ('textContrastGuideline', textContrastGuideline),
        ]) {
          final result = await guideline.evaluate(tester);
          expect(
            result.passed,
            isTrue,
            reason: '$surface, $name :\n${result.reason}',
          );
        }
      });
      expect(visited, hasLength(15));
      handle.dispose();
    });

    testBothThemes('police ×2 sur 360 dp : aucune surface ne déborde', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      phone(tester, size: const Size(360, 800));
      await pumpE2e(tester);
      final visited = <String>[];
      await _visitSurfaces(tester, (surface) async {
        visited.add(surface);
        expect(tester.takeException(), isNull, reason: surface);
      });
      expect(visited, hasLength(15));
    });

    testBothThemes('animations désactivées : une coche et un ajout du '
        'panneau aboutissent sans attente d’animation', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      phone(tester, size: const Size(412, 914));
      await pumpE2e(tester);
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(Scaffold).first),
        ),
        isTrue,
      );

      // Un ajout du panneau : la ligne est là dès les premières images.
      await openAddSheet(tester);
      await tester.enterText(addField, 'Lait');
      await tester.pump();
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (var i = 0; i < 5 && itemRow('Lait').evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(itemRow('Lait'), findsOneWidget);
      // Dès son apparition : opaque, sans surlignage.
      final highlight = find.ancestor(
        of: itemRow('Lait'),
        matching: find.byType(RowHighlight),
      );
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .descendant(
                    of: highlight,
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(of: highlight, matching: find.byType(ColoredBox))
                  .first,
            )
            .color
            .a,
        0,
      );
      await tester.pumpAndSettle();
      await closeAddSheet(tester);

      // Une coche : la ligne rejoint Cochés sans délai.
      await tester.tap(
        find.descendant(of: itemRow('Lait'), matching: find.byType(Checkbox)),
      );
      await tester.pump();
      await tester.pump();
      expect(itemRow('Lait'), findsNothing);
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}

void main() => accessibilite();
