import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/recettes_screen.dart';
import 'package:kadi/features/recettes/ui/recipe_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/recettes.dart';
import '../../helpers/test_db.dart';

/// Ouvre la fiche de [name] par sa ligne.
Future<void> _edit(WidgetTester tester, String name) =>
    editRecipe(tester, name);

/// Poubelle de la Fiche recette, présente pour une recette en base.
Finder get _deleteButton => ficheDeleteButton;

/// « Supprimer la recette » par la poubelle de la fiche, confirmé.
Future<void> _delete(WidgetTester tester) => deleteFromFiche(tester);

Finder get _undoAction =>
    find.widgetWithText(SnackBarAction, StringsFr.annuler);

Finder get _welcome => find.text(StringsFr.recettesAccueil);

Future<Recipe> _recipe(AppDatabase db, String id) =>
    (db.select(db.recipes)..where((r) => r.id.equals(id))).getSingle();

/// Lignes, contributions, sélections : ce que la suppression ne touche pas.
Future<List<Object>> _listAndSelections(AppDatabase db) async => [
  ...await db.select(db.listLines).get(),
  ...await db.select(db.listContributions).get(),
  ...await db.select(db.weekSelections).get(),
];

void main() {
  group('premier lancement (R11, AD-13)', () {
    testWidgets('installation neuve : la Liste, puis Recettes et sa ligne '
        'd’accueil au-dessus des cartes, drapeau baissé ; relance : la Liste, '
        'sans ligne d’accueil', (tester) async {
      tallPhone(tester);
      final handle = tester.ensureSemantics();
      final db = await pumpKadi(tester, firstLaunch: true);

      expect(find.byType(ListeScreen), findsOneWidget);
      await openTab(tester, StringsFr.tabRecettes);
      expect(find.byType(RecettesScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.byType(RecipeRow), findsNWidgets(4));
      expect(_welcome, findsOneWidget);
      expect(
        tester.getBottomLeft(_welcome).dy,
        lessThan(tester.getTopLeft(recipeCard('Chili con carne')).dy),
      );
      // Lue par TalkBack, non interactive.
      expect(
        tester.getSemantics(_welcome),
        isSemantics(
          label: StringsFr.recettesAccueil,
          isButton: false,
          hasTapAction: false,
        ),
      );
      expect((await db.select(db.settings).getSingle()).firstLaunch, isFalse);

      // Dans la session : la ligne reste en passant par la Liste.
      await openTab(tester, StringsFr.tabListe);
      await openTab(tester, StringsFr.tabRecettes);
      expect(_welcome, findsOneWidget);

      // Relance de l'app sur la même base.
      await pumpKadi(tester, database: db);
      expect(find.byType(ListeScreen), findsOneWidget);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await openTab(tester, StringsFr.tabRecettes);
      expect(find.byType(RecipeRow), findsNWidgets(4));
      expect(_welcome, findsNothing);
      handle.dispose();
    });

    testWidgets('lancement ordinaire : la Liste, Recettes sans ligne '
        'd’accueil', (tester) async {
      await pumpKadi(tester);
      expect(find.byType(ListeScreen), findsOneWidget);
      await openTab(tester, StringsFr.tabRecettes);
      expect(find.byType(RecipeRow), findsNWidgets(4));
      expect(_welcome, findsNothing);
    });

    testWidgets('tout supprimer : message d’état vide et FAB +, plus de ligne '
        'd’accueil, même après Annuler', (tester) async {
      tallPhone(tester);
      final db = await pumpKadi(tester, firstLaunch: true);
      await openTab(tester, StringsFr.tabRecettes);
      expect(_welcome, findsOneWidget);

      for (final name in [
        'Chili con carne',
        'Pâtes carbonara',
        'Quiche lorraine',
        'Ratatouille',
      ]) {
        await _edit(tester, name);
        await _delete(tester);
        expect(find.text(StringsFr.recetteSupprimee(name)), findsOneWidget);
      }

      expect(find.byType(RecipeRow), findsNothing);
      expect(find.text(StringsFr.recettesVide), findsOneWidget);
      expect(find.byTooltip(StringsFr.nouvelleRecette), findsOneWidget);
      expect(_welcome, findsNothing);

      // Annuler rend la dernière : la ligne d'accueil ne revient pas.
      await tester.tap(_undoAction);
      await tester.pumpAndSettle();
      expect(recipeCard('Ratatouille'), findsOneWidget);
      expect(_welcome, findsNothing);
      expect(
        await (db.select(db.recipes)..where((r) => r.deletedAt.isNull())).get(),
        hasLength(1),
      );
    });
  });

  group('supprimer une recette (R1, R7)', () {
    testWidgets('Chili validé : carte disparue, liste identique, snackbar '
        'annoncé ; Annuler : la carte revient, sélectionnée', (tester) async {
      tallPhone(tester);
      final handle = tester.ensureSemantics();
      final db = await pumpKadi(tester);
      await openTab(tester, StringsFr.tabRecettes);
      await tapRecipeCard(tester, 'Chili con carne');
      await openRevue(tester, 1);
      await tester.tap(revueAddButton);
      await tester.pumpAndSettle();
      expect(find.text('Poivrons'), findsOneWidget);
      final before = await _listAndSelections(db);

      await openTab(tester, StringsFr.tabRecettes);
      await _edit(tester, 'Chili con carne');
      await _delete(tester);

      expect(find.byType(FicheRecetteScreen), findsNothing);
      expect(recipeCard('Chili con carne'), findsNothing);
      expect(find.byType(RecipeRow), findsNWidgets(3));
      const message = 'Recette supprimée : Chili con carne';
      expect(StringsFr.recetteSupprimee('Chili con carne'), message);
      expect(find.text(message), findsOneWidget);
      expect(_undoAction, findsOneWidget);
      expect(
        tester.getSemantics(find.text(message)),
        isSemantics(isLiveRegion: true),
      );
      expect((await _recipe(db, SeedRecipeIds.chili)).deletedAt, isNotNull);
      expect(await _listAndSelections(db), before);

      await openTab(tester, StringsFr.tabListe);
      expect(find.text('Poivrons'), findsOneWidget);
      await openTab(tester, StringsFr.tabRecettes);

      await tester.tap(_undoAction);
      await tester.pumpAndSettle();
      expect(recipeCard('Chili con carne'), findsOneWidget);
      expect(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Chili con carne')),
        findsOneWidget,
      );
      // Validée : pas de « Valider ».
      expect(find.byType(FilledButton), findsNothing);
      expect((await _recipe(db, SeedRecipeIds.chili)).deletedAt, isNull);
      expect(await _listAndSelections(db), before);
      handle.dispose();
    });

    testWidgets('recette sélectionnée non validée : « Valider » part avec '
        'elle et revient avec Annuler', (tester) async {
      tallPhone(tester);
      await pumpKadi(tester);
      await openTab(tester, StringsFr.tabRecettes);
      await tapRecipeCard(tester, 'Quiche lorraine');
      expect(
        find.widgetWithText(FilledButton, StringsFr.validerN(1)),
        findsOneWidget,
      );

      await _edit(tester, 'Quiche lorraine');
      await _delete(tester);
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(_undoAction);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, StringsFr.validerN(1)),
        findsOneWidget,
      );
    });

    testWidgets('poubelle de la fiche, 48 dp, lue « Supprimer la recette », '
        'dialogue de confirmation ; absente d’une fiche neuve tant qu’elle '
        'n’est pas enregistrée', (tester) async {
      tallPhone(tester);
      final handle = tester.ensureSemantics();
      await pumpKadi(tester);
      await openTab(tester, StringsFr.tabRecettes);

      await _edit(tester, 'Chili con carne');
      expect(_deleteButton, findsOneWidget);
      expect(
        tester.getSize(_deleteButton).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );
      expect(
        tester.getSemantics(_deleteButton),
        isSemantics(
          tooltip: StringsFr.supprimerLaRecette,
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.supprimerLaRecetteTitre), findsOneWidget);
      expect(
        find.text(StringsFr.supprimerLaRecetteTexte('Chili con carne')),
        findsOneWidget,
      );
      // Garder : rien ne change.
      await tester.tap(find.widgetWithText(TextButton, StringsFr.garder));
      await tester.pumpAndSettle();
      expect(find.byType(FicheRecetteScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Fiche neuve : pas de bouton tant qu'elle n'est pas enregistrée.
      await tester.tap(find.byTooltip(StringsFr.nouvelleRecette));
      await tester.pumpAndSettle();
      expect(_deleteButton, findsNothing);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(FicheRecetteScreen),
              matching: find.byType(TextField),
            )
            .first,
        'Omelette',
      );
      await tester.pumpAndSettle();
      expect(_deleteButton, findsNothing);
      handle.dispose();
    });

    testWidgets('fiche neuve enregistrée, rouverte, puis supprimée : Annuler '
        'la rend', (tester) async {
      tallPhone(tester);
      final db = await pumpKadi(tester);
      await openTab(tester, StringsFr.tabRecettes);
      await tester.tap(find.byTooltip(StringsFr.nouvelleRecette));
      await tester.pumpAndSettle();
      await tester.enterText(ficheNameField, 'Omelette');
      await tester.pumpAndSettle();
      await addIngredientBySheet(tester, 'œufs', 'Œufs');
      // Pas en base avant « Enregistrer » : pas de bouton.
      expect(_deleteButton, findsNothing);
      await saveFiche(tester);
      await _edit(tester, 'Omelette');
      expect(_deleteButton, findsOneWidget);

      await _delete(tester);
      expect(find.text(StringsFr.recetteSupprimee('Omelette')), findsOneWidget);
      expect(recipeCard('Omelette'), findsNothing);
      await tester.tap(_undoAction);
      await tester.pumpAndSettle();
      expect(recipeCard('Omelette'), findsOneWidget);
      expect(
        (await (db.select(
          db.recipes,
        )..where((r) => r.name.equals('Omelette'))).getSingle()).deletedAt,
        isNull,
      );
    });

    testWidgets('échec : snackbar d’erreur, la fiche reste, rien d’écrit', (
      tester,
    ) async {
      tallPhone(tester);
      final db = await pumpKadi(tester);
      await openTab(tester, StringsFr.tabRecettes);
      final before = await db.select(db.recipes).get();
      await db.customStatement(
        'CREATE TRIGGER no_delete BEFORE UPDATE OF deleted_at ON recipes '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await _edit(tester, 'Chili con carne');
      await _delete(tester);

      expect(find.text(StringsFr.suppressionImpossible), findsOneWidget);
      expect(find.byType(FicheRecetteScreen), findsOneWidget);
      expect(_undoAction, findsNothing);
      expect(await db.select(db.recipes).get(), before);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('police ×$scale sur 360 dp : ligne d’accueil et bouton '
          'entiers, sans débordement', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tallPhone(tester, const Size(360, 800));
        await pumpKadi(tester, firstLaunch: true);
        await openTab(tester, StringsFr.tabRecettes);
        expect(tester.takeException(), isNull);
        final welcome = tester.widget<Text>(_welcome);
        expect(welcome.maxLines, isNull);
        expect(welcome.overflow, isNull);

        await _edit(tester, 'Chili con carne');
        expect(tester.takeException(), isNull);
        await tester.tap(_deleteButton);
        await tester.pumpAndSettle();
        final label = tester.widget<Text>(
          find.text(StringsFr.supprimerLaRecetteTitre),
        );
        expect(label.maxLines, isNull);
        expect(label.overflow, isNull);
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(TextButton, StringsFr.garder));
        await tester.pumpAndSettle();

        await _delete(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.text(StringsFr.recetteSupprimee('Chili con carne')),
          findsOneWidget,
        );
      });
    }
  });
}
