import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_screen_awake.dart';
import 'e2e_harness.dart';

final _terminer = find.widgetWithText(
  FilledButton,
  StringsFr.terminerLesCourses,
);

/// État de départ, par les gestes : le Chili con carne validé (Oignons,
/// Poivrons, Viande hachée, Tomates concassées, Riz), puis l'onglet Liste.
Future<void> _listeDuChili(WidgetTester tester) async {
  await openTab(tester, StringsFr.tabRecettes);
  await tapRecipeCard(tester, 'Chili con carne');
  await openRevue(tester, 1);
  await tapAndSettle(tester, ajouterALaListe);
  await letSnackBarClose(tester);
  expect(shownItems(tester), [
    'Oignons',
    'Poivrons',
    'Viande hachée',
    'Tomates concassées',
    'Riz',
  ]);
}

void flux2AuMagasin() {
  group('Flux 2 — Au magasin à une main', () {
    testBothThemes('Écran allumé, coches du pouce rayon par rayon, Riz '
        'décoché dans Cochés : ★ « Terminer les courses » apparaît sans '
        'vidage automatique ; Terminer vide liste et sélection', (
      tester,
    ) async {
      phone(tester);
      final awake = FakeScreenAwake();
      final db = await pumpE2e(tester, screenAwake: awake);
      // État de départ : Écran allumé actif.
      await SettingsRepository(db, Clock()).setKeepScreenOn(true);
      await tester.pumpAndSettle();
      await _listeDuChili(tester);

      // 1. Sur la Liste, l'écran ne se met pas en veille.
      expect(awake.enabled, isTrue);

      // 2-3. Coches dans l'ordre du parcours ; un rayon coché disparaît.
      await checkItem(tester, 'Oignons');
      expect(itemRow('Oignons'), findsNothing);
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      // Section repliée : la ligne n'y est pas affichée.
      expect(itemRow('Oignons', inSection: true), findsNothing);
      await checkItem(tester, 'Poivrons');
      expect(rayonHeader(StringsFr.rayonFruitsLegumes), findsNothing);
      await checkItem(tester, 'Viande hachée');
      expect(rayonHeader(StringsFr.rayonViandePoisson), findsNothing);

      // 4. Riz coché par erreur : Cochés déplié, Riz décoché, il revient
      // dans Épicerie salée.
      await checkItem(tester, 'Riz');
      await tapAndSettle(tester, find.text(StringsFr.cochesTitre(4)));
      expect(itemRow('Riz', inSection: true), findsOneWidget);
      await checkItem(tester, 'Riz', inSection: true);
      expect(itemRow('Riz', inSection: true), findsNothing);
      expect(shownHeaders(tester), [StringsFr.rayonEpicerieSalee]);
      expect(shownItems(tester), ['Tomates concassées', 'Riz']);
      expect(_terminer, findsNothing);

      // 5. Le dernier article.
      await checkItem(tester, 'Tomates concassées');
      expect(_terminer, findsNothing);
      await checkItem(tester, 'Riz');

      // 6. ★ « Terminer les courses » apparaît ; la liste ne s'est pas
      // vidée toute seule.
      expect(_terminer, findsOneWidget, reason: '★');
      expect(find.byType(CheckedSection), findsOneWidget, reason: '★');
      expect(find.text(StringsFr.cochesTitre(5)), findsOneWidget, reason: '★');
      expect(find.text(StringsFr.listeVide), findsNothing, reason: '★');
      expect(awake.enabled, isTrue);

      // 7. Terminer : liste et sélection vidées.
      await tapAndSettle(tester, _terminer);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.text(StringsFr.coursesTerminees), findsOneWidget);
      expect(undoAction, findsOneWidget);
      await openTab(tester, StringsFr.tabRecettes);
      expect(
        find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Chili con carne')),
        findsOneWidget,
      );
      // Hors de la Liste, l'écran peut de nouveau se mettre en veille.
      expect(awake.enabled, isFalse);
    });

    testBothThemes('Échec : Riz introuvable laissé non coché, « Terminer » '
        'absent ; glissé vers la gauche, il part avec Annuler', (tester) async {
      phone(tester);
      await pumpE2e(tester);
      await _listeDuChili(tester);
      for (final name in [
        'Oignons',
        'Poivrons',
        'Viande hachée',
        'Tomates concassées',
      ]) {
        await checkItem(tester, name);
      }
      expect(_terminer, findsNothing);
      expect(itemRow('Riz'), findsOneWidget);

      await tester.drag(itemRow('Riz'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(itemRow('Riz'), findsNothing);
      expect(find.text(StringsFr.retireDeLaListe('Riz')), findsOneWidget);
      expect(undoAction, findsOneWidget);

      await tapAndSettle(tester, undoAction);
      expect(itemRow('Riz'), findsOneWidget);
      expect(_terminer, findsNothing);
    });

    testBothThemes('Échec : Riz laissé non coché, Nouvelle liste efface '
        'tout', (tester) async {
      phone(tester);
      await pumpE2e(tester);
      await _listeDuChili(tester);
      await checkItem(tester, 'Oignons');

      await openTab(tester, StringsFr.tabRecettes);
      await recettesMenu(tester, StringsFr.nouvelleListe);
      await tapAndSettle(tester, find.text(StringsFr.effacerEtRecommencer));
      expect(
        find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Chili con carne')),
        findsOneWidget,
      );
      await openTab(tester, StringsFr.tabListe);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.byType(CheckedSection), findsNothing);
    });
  });
}

void main() => flux2AuMagasin();
