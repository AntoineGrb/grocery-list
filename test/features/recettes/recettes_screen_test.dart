import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/ui/quantity_tag.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/recettes/state/revue.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/recipe_row.dart';
import 'package:kadi/features/recettes/ui/revue_row.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/recettes.dart';
import '../../helpers/test_db.dart';

const _nbsp = ' ';

/// Échoue toujours, sans rien écrire.
class _FailingAjouter implements AjouterALaListe {
  @override
  Future<void> call(
    Revue revue, {
    RevueDraft draft = const RevueDraft(),
  }) async => throw StateError('échec simulé');
}

/// Ouvre l'onglet Recettes.
Future<void> _openRecettes(WidgetTester tester) =>
    openTab(tester, StringsFr.tabRecettes);

/// Ouvre l'onglet Liste.
Future<void> _openListe(WidgetTester tester) =>
    openTab(tester, StringsFr.tabListe);

Finder get _ajouterButton => revueAddButton;

/// Ouvre la Revue de Pâtes carbonara et Quiche lorraine, sur un téléphone
/// haut où toute la Revue et toute la Liste sont bâties.
Future<AppDatabase> _openCarbonaraQuiche(WidgetTester tester) async {
  tallPhone(tester);
  final db = await pumpKadi(tester);
  await _openRecettes(tester);
  await tapRecipeCard(tester, 'Pâtes carbonara');
  await tapRecipeCard(tester, 'Quiche lorraine');
  await openRevue(tester, 2);
  return db;
}

/// Rayons des En-têtes de rayon visibles, de haut en bas.
List<Rayon> _headers(WidgetTester tester) {
  final headers = find.byType(RayonHeader);
  final list = [for (final e in headers.evaluate()) e.widget as RayonHeader];
  list.sort(
    (a, b) => tester
        .getTopLeft(find.byWidget(a))
        .dy
        .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
  );
  return [for (final h in list) h.rayon];
}

void main() {
  testWidgets('installation neuve : les 4 recettes exemples en lignes, '
      'triées par nom, avec monogramme et nombre d’ingrédients', (
    tester,
  ) async {
    await pumpKadi(tester);
    await _openRecettes(tester);

    expect(find.byType(RecipeRow), findsNWidgets(4));
    expect(find.text(StringsFr.recettesVide), findsNothing);
    final tops = [
      for (final name in [
        'Chili con carne',
        'Pâtes carbonara',
        'Quiche lorraine',
        'Ratatouille',
      ])
        tester.getRect(recipeCard(name)).top,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    // Monogramme aux initiales, sur l'accent du rayon de l'ingrédient
    // principal ; nombre d'ingrédients sous le nom.
    expect(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.text('Cc'),
      ),
      findsOneWidget,
    );
    final chili = tester.widget<RecipeRow>(recipeCard('Chili con carne'));
    expect(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.text(StringsFr.nIngredients(chili.card.ingredientCount)),
      ),
      findsOneWidget,
    );
    expect(chili.card.ingredientCount, greaterThan(1));
    // Filtres, sans Bouton d'action ni FAB.
    expect(find.text(StringsFr.toutesN(4)), findsOneWidget);
    expect(find.text(StringsFr.cetteSemaineN(0)), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip(StringsFr.nouvelleRecette), findsOneWidget);
  });

  testWidgets('sans recette : message d’état vide', (tester) async {
    await pumpKadi(
      tester,
      assetOverrides: {SeedLoader.recettesPath: emptyRecettesFile()},
    );
    await _openRecettes(tester);
    expect(find.text(StringsFr.recettesVide), findsOneWidget);
    expect(find.byType(RecipeRow), findsNothing);
  });

  testWidgets('sélectionner, désélectionner : « Ajouter » puis « Ajoutée » à '
      'l’encre, et Valider n recettes', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    final scheme = Theme.of(tester.element(recipeCard('Chili con carne')))
        .colorScheme;
    BoxDecoration pill(String name) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: recipeSelectButton(name),
                    matching: find.byKey(const Key('recipe-select-button')),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(recipeSelected(tester, 'Chili con carne'), isFalse);
    expect(pill('Chili con carne').color, Colors.transparent);
    expect(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.text(StringsFr.ajouter),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(recipeSelectButton('Chili con carne')).height,
      greaterThanOrEqualTo(KadiSpacing.touchTarget),
    );

    await tapRecipeCard(tester, 'Chili con carne');
    expect(recipeSelected(tester, 'Chili con carne'), isTrue);
    // Sélection à l'encre, jamais d'argile (C6).
    expect(pill('Chili con carne').color, scheme.onSurface);
    expect(pill('Chili con carne').color, isNot(scheme.primary));
    expect(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.text(StringsFr.ajoutee),
      ),
      findsOneWidget,
    );
    expect(validerButton(1), findsOneWidget);
    expect(find.text(StringsFr.cetteSemaineN(1)), findsOneWidget);
    expect(await db.select(db.weekSelections).get(), hasLength(1));

    await tapRecipeCard(tester, 'Ratatouille');
    expect(validerButton(2), findsOneWidget);

    // Désélection d'une recette non validée, par TalkBack.
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Chili con carne')),
      ),
      isSemantics(
        label: StringsFr.retirerDeLaSemaine('Chili con carne'),
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(
      find.semantics.byLabel(StringsFr.retirerDeLaSemaine('Chili con carne')),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Chili con carne')),
      findsOneWidget,
    );
    expect(validerButton(1), findsOneWidget);
    await tapRecipeCard(tester, 'Ratatouille');
    expect(find.byType(FilledButton), findsNothing);
    // Une recette non validée se désélectionne sans snackbar.
    expect(find.byType(SnackBar), findsNothing);
    handle.dispose();
  });

  testWidgets('filtre « Cette semaine » et recherche sans accents', (
    tester,
  ) async {
    await pumpKadi(tester);
    await _openRecettes(tester);
    await tapRecipeCard(tester, 'Ratatouille');

    await tester.tap(find.text(StringsFr.cetteSemaineN(1)));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeRow), findsOneWidget);
    expect(recipeCard('Ratatouille'), findsOneWidget);
    // Désélectionnée : elle quitte le filtre, qui affiche son message.
    await tapRecipeCard(tester, 'Ratatouille');
    expect(find.byType(RecipeRow), findsNothing);
    expect(find.text(StringsFr.pasDeRecetteCetteSemaine), findsOneWidget);

    await tester.tap(find.text(StringsFr.toutesN(4)));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeRow), findsNWidgets(4));

    // « pates » trouve « Pâtes carbonara ».
    await tester.enterText(
      find.widgetWithText(TextField, StringsFr.chercherUneRecette),
      'pates',
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecipeRow), findsOneWidget);
    expect(recipeCard('Pâtes carbonara'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.aucuneRecetteTrouvee), findsOneWidget);
    await tester.tap(find.byTooltip(StringsFr.effacerLeTexte));
    await tester.pumpAndSettle();
    expect(find.byType(RecipeRow), findsNWidgets(4));
  });

  testWidgets('tap sur la ligne : ouvre la fiche sans changer la sélection', (
    tester,
  ) async {
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    await editRecipe(tester, 'Chili con carne');
    await backFromFiche(tester);
    expect(recipeSelected(tester, 'Chili con carne'), isFalse);
    expect(await db.select(db.weekSelections).get(), isEmpty);

    // + de la Barre d'application : une fiche vide.
    await tester.tap(find.byTooltip(StringsFr.nouvelleRecette));
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    await backFromFiche(tester);
  });

  testWidgets('Carbonara + Quiche : Valider 2 recettes, Revue « Qu’as-tu '
      'déjà ? » en cartes par rayon, tout gardé ; Ajouter : Liste prête ; '
      'puis Ratatouille seule en Revue', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _openCarbonaraQuiche(tester);

    // Revue : plein écran, sans Barre de navigation, flèche retour.
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(find.text(StringsFr.quAsTuDeja), findsOneWidget);
    expect(find.text(StringsFr.revueConsigneV2), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    // Une carte par rayon dans l'ordre du parcours, tout gardé.
    expect(revueRayons(tester), [
      Rayon.viandePoisson,
      Rayon.cremerie,
      Rayon.epicerieSalee,
    ]);
    expect(find.byType(RevueRow), findsNWidgets(8));
    expect(allRevueKept(tester), isTrue);
    expect(revueQuantity(tester, 'Lardons'), '400${_nbsp}g');
    expect(revueQuantity(tester, 'Œufs'), '6${_nbsp}pièces');
    // Poivre sans quantité : la balance.
    expect(
      find.bySemanticsLabel(StringsFr.ajouterUneQuantiteA('Poivre')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Lardons, 400${_nbsp}g, Viande et poisson'),
      ),
      isSemantics(
        label: 'Lardons, 400${_nbsp}g, Viande et poisson',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    expect(find.text(StringsFr.ajouterNArticles(8)), findsOneWidget);

    await tester.tap(revueAddButton);
    await tester.pumpAndSettle();

    // La Liste, triée par rayon, avec son avis.
    expect(find.byType(RevueScreen), findsNothing);
    expect(find.text(StringsFr.listePrete), findsOneWidget);
    expect(find.byType(ItemRow), findsNWidgets(8));
    expect(_headers(tester), [
      Rayon.viandePoisson,
      Rayon.cremerie,
      Rayon.epicerieSalee,
    ]);
    expect(
      find.bySemanticsLabel('Lardons, 400${_nbsp}g, Viande et poisson'),
      findsOneWidget,
    );
    final selections = await db.select(db.weekSelections).get();
    expect(selections.every((s) => s.validatedAt != null), isTrue);

    // De retour sur Recettes : toujours sélectionnées, sans Valider.
    await _openRecettes(tester);
    expect(recipeSelected(tester, 'Pâtes carbonara'), isTrue);
    expect(recipeSelected(tester, 'Quiche lorraine'), isTrue);
    expect(find.byType(FilledButton), findsNothing);

    // Ratatouille seule en Revue.
    await tapRecipeCard(tester, 'Ratatouille');
    await openRevue(tester, 1);
    expect(find.byType(RevueRow), findsNWidgets(7));
    expect(find.text('Courgettes'), findsOneWidget);
    expect(find.text('Lardons'), findsNothing);
    handle.dispose();
  });

  testWidgets('Pâtes « J’ai ! », Œufs 6 → 4 par le Module quantité, '
      'Ajouter : la Liste sans Pâtes, avec « Œufs 4 pièces »', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _openCarbonaraQuiche(tester);

    await toggleRevueRow(tester, 'Pâtes');
    expect(revueKept(tester, 'Pâtes'), isFalse);
    // « J'ai ! » : nom barré, sans tag ; le compteur et le bouton suivent.
    final pates = tester.widget<Text>(
      find.descendant(of: revueRowOf('Pâtes'), matching: find.text('Pâtes')),
    );
    expect(pates.style?.decoration, TextDecoration.lineThrough);
    expect(
      find.descendant(
        of: revueRowOf('Pâtes'),
        matching: find.text(StringsFr.jAi),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: revueRowOf('Pâtes'),
        matching: find.byType(QuantityTag),
      ),
      findsNothing,
    );
    expect(find.text(StringsFr.ajouterNArticles(7)), findsOneWidget);

    await setRevueQuantity(tester, 'Œufs', '4');
    expect(revueQuantity(tester, 'Œufs'), '4${_nbsp}pièces');
    // Rien d'écrit avant « Ajouter ».
    expect(await db.select(db.listLines).get(), isEmpty);

    await tester.tap(revueAddButton);
    await tester.pumpAndSettle();
    expect(find.byType(ItemRow), findsNWidgets(7));
    expect(find.widgetWithText(ItemRow, 'Pâtes'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('^Œufs, 4${_nbsp}pièces')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('tout « J’ai ! » : « Ajouter à la liste », la Liste ne change '
      'pas, Valider disparaît', (tester) async {
    final db = await _openCarbonaraQuiche(tester);
    for (final row in tester.widgetList<RevueRow>(find.byType(RevueRow))) {
      await toggleRevueRow(tester, row.line.name);
    }
    expect(find.text(StringsFr.ajouterALaListe), findsOneWidget);
    await tester.tap(revueAddButton);
    await tester.pumpAndSettle();
    expect(await db.select(db.listLines).get(), isEmpty);
    await _openRecettes(tester);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('retour après « J’ai ! » et correction : rien n’est écrit, '
      '« Valider 2 recettes » toujours là, Revue rouverte toute gardée', (
    tester,
  ) async {
    final db = await _openCarbonaraQuiche(tester);
    await toggleRevueRow(tester, 'Pâtes');
    await setRevueQuantity(tester, 'Œufs', '4');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(validerButton(2), findsOneWidget);
    await openRevue(tester, 2);
    expect(allRevueKept(tester), isTrue);
    expect(revueQuantity(tester, 'Œufs'), '6${_nbsp}pièces');
  });

  testWidgets('TalkBack : la ligne bascule par son tap ; le tag est un '
      'bouton à part, qui ne bascule pas la ligne', (tester) async {
    final handle = tester.ensureSemantics();
    await _openCarbonaraQuiche(tester);

    tester.semantics.tap(
      find.semantics.byLabel('Lardons, 400${_nbsp}g, Viande et poisson'),
    );
    await tester.pumpAndSettle();
    expect(revueKept(tester, 'Lardons'), isFalse);
    expect(
      find.bySemanticsLabel('Lardons, ${StringsFr.jAi}, Viande et poisson'),
      findsOneWidget,
    );
    await toggleRevueRow(tester, 'Lardons');

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(StringsFr.quantiteDe('Œufs', '6${_nbsp}pièces')),
      ),
      isSemantics(
        label: StringsFr.quantiteDe('Œufs', '6${_nbsp}pièces'),
        isButton: true,
        hasTapAction: true,
      ),
    );
    await setRevueQuantity(tester, 'Œufs', '5');
    expect(revueKept(tester, 'Œufs'), isTrue);
    handle.dispose();
  });

  testWidgets('retour depuis la Revue : rien n’est validé ni ajouté', (
    tester,
  ) async {
    final db = await pumpKadi(tester);
    await _openRecettes(tester);
    await tapRecipeCard(tester, 'Chili con carne');
    await openRevue(tester, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(validerButton(1), findsOneWidget);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(
      (await db.select(db.weekSelections).getSingle()).validatedAt,
      isNull,
    );
  });

  testWidgets('échec de l’ajout : snackbar, la Revue reste', (tester) async {
    final db = await pumpKadi(
      tester,
      overrides: [ajouterALaListeProvider.overrideWithValue(_FailingAjouter())],
    );
    await _openRecettes(tester);
    await tapRecipeCard(tester, 'Chili con carne');
    await openRevue(tester, 1);

    await tester.tap(revueAddButton);
    await tester.pumpAndSettle();

    expect(find.text(StringsFr.ajoutImpossible), findsOneWidget);
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(tester.widget<FilledButton>(revueAddButton).onPressed, isNotNull);
    expect(await db.select(db.listLines).get(), isEmpty);
  });

  group('désélectionner une recette validée (R6)', () {
    final undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);
    final carbonaraRetiree = StringsFr.ingredientsRetires('Pâtes carbonara');
    const lardons400 = 'Lardons, 400${_nbsp}g, Viande et poisson';
    const lardons200 = 'Lardons, 200${_nbsp}g, Viande et poisson';

    /// Carbonara et Quiche validées (Lardons 400 g dans la Liste), puis
    /// retour sur Recettes.
    Future<AppDatabase> validatedCarbonaraQuiche(WidgetTester tester) async {
      final db = await _openCarbonaraQuiche(tester);
      await tester.tap(_ajouterButton);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(lardons400), findsOneWidget);
      await _openRecettes(tester);
      return db;
    }

    Future<void> letSnackBarClose(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('toucher Carbonara validée : plus de coche, « Lardons 200 g » '
        'dans la Liste, snackbar annoncé ; Annuler : resélectionnée sans '
        'Valider, « Lardons 400 g »', (tester) async {
      final handle = tester.ensureSemantics();
      await validatedCarbonaraQuiche(tester);

      // Par TalkBack : la carte est activable et relue après le tap.
      tester.semantics.tap(
        find.semantics.byLabel(StringsFr.retirerDeLaSemaine('Pâtes carbonara')),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Pâtes carbonara')),
        findsOneWidget,
      );
      expect(recipeSelected(tester, 'Pâtes carbonara'), isFalse);
      expect(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Quiche lorraine')),
        findsOneWidget,
      );
      expect(
        carbonaraRetiree,
        'Ingrédients de «${_nbsp}Pâtes carbonara$_nbsp» retirés de la liste',
      );
      expect(find.text(carbonaraRetiree), findsOneWidget);
      expect(undoAction, findsOneWidget);
      // Snackbar annoncé par TalkBack (région dynamique).
      expect(
        tester.getSemantics(find.text(carbonaraRetiree)),
        isSemantics(isLiveRegion: true),
      );
      // Aucune recette à valider : pas de Bouton d'action.
      expect(find.byType(FilledButton), findsNothing);

      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons200), findsOneWidget);
      expect(find.text('Pâtes'), findsNothing);
      expect(find.text('Poivre'), findsNothing);

      await _openRecettes(tester);
      expect(undoAction, findsOneWidget);
      await tester.tap(undoAction);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Pâtes carbonara')),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons400), findsOneWidget);
      expect(find.text('Pâtes'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('snackbar au-dessus de « Valider (1) » ; ensuite, Ratatouille '
        'validée : la Revue n’en montre que les ingrédients (Flux 5)', (
      tester,
    ) async {
      await validatedCarbonaraQuiche(tester);
      await tapRecipeCard(tester, 'Ratatouille');
      await tapRecipeCard(tester, 'Pâtes carbonara');

      expect(find.text(carbonaraRetiree), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(SnackBar)).dy,
        lessThanOrEqualTo(tester.getTopLeft(validerButton(1)).dy),
      );

      await openRevue(tester, 1);
      expect(find.byType(RevueScreen), findsOneWidget);
      expect(find.byType(RevueRow), findsNWidgets(7));
      expect(find.text('Courgettes'), findsOneWidget);
      expect(find.text('Lardons'), findsNothing);
      expect(find.text('Pâtes'), findsNothing);
    });

    testWidgets('tap sur la coche de Carbonara validée : même désélection, '
        'un seul snackbar ; Annuler la resélectionne', (tester) async {
      await validatedCarbonaraQuiche(tester);
      await tapRecipeCard(tester, 'Pâtes carbonara');

      expect(recipeSelected(tester, 'Pâtes carbonara'), isFalse);
      expect(find.text(carbonaraRetiree), findsOneWidget);
      expect(undoAction, findsOneWidget);
      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons200), findsOneWidget);

      await _openRecettes(tester);
      await tester.tap(undoAction);
      await tester.pumpAndSettle();
      expect(recipeSelected(tester, 'Pâtes carbonara'), isTrue);
      expect(find.byType(FilledButton), findsNothing);
      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons400), findsOneWidget);
    });

    testWidgets('fin du snackbar : plus d’Annuler, la carte reste '
        'désélectionnée', (tester) async {
      final db = await validatedCarbonaraQuiche(tester);
      await tapRecipeCard(tester, 'Pâtes carbonara');
      await letSnackBarClose(tester);

      expect(find.text(carbonaraRetiree), findsNothing);
      expect(
        (await db.select(db.weekSelections).get()).where(
          (s) => s.deletedAt == null,
        ),
        hasLength(1),
      );
    });

    testWidgets('échec : snackbar d’erreur, rien d’écrit, carte toujours '
        'sélectionnée', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await validatedCarbonaraQuiche(tester);
      final lines = await db.select(db.listLines).get();
      final selections = await db.select(db.weekSelections).get();
      await db.customStatement(
        'CREATE TRIGGER no_deselect BEFORE UPDATE OF deleted_at ON '
        "week_selections BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await tapRecipeCard(tester, 'Pâtes carbonara');

      expect(find.text(StringsFr.modificationImpossible), findsOneWidget);
      expect(find.text(carbonaraRetiree), findsNothing);
      expect(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Pâtes carbonara')),
        findsOneWidget,
      );
      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.weekSelections).get(), selections);
      await letSnackBarClose(tester);
      handle.dispose();
    });
  });

  group('Nouvelle liste (R8) et Terminer les courses (R10)', () {
    final garder = find.widgetWithText(TextButton, StringsFr.garder);
    final effacer = find.widgetWithText(
      TextButton,
      StringsFr.effacerEtRecommencer,
    );

    /// Coche la ligne de la Liste de [name].
    Future<void> checkOnListe(WidgetTester tester, String name) async {
      final box = find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(ItemRow)),
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(box.first);
      await tester.tap(box.first);
      await tester.pumpAndSettle();
    }

    /// Carbonara et Quiche validées, Lardons cochés dans la Liste, Chili
    /// sélectionnée non validée ; Recettes ouverte.
    Future<AppDatabase> semaineEnCours(WidgetTester tester) async {
      final db = await _openCarbonaraQuiche(tester);
      await tester.tap(_ajouterButton);
      await tester.pumpAndSettle();
      await checkOnListe(tester, 'Lardons');
      await _openRecettes(tester);
      await tapRecipeCard(tester, 'Chili con carne');
      expect(validerButton(1), findsOneWidget);
      return db;
    }

    Future<void> openDialog(WidgetTester tester) async {
      await recettesMenu(tester, StringsFr.nouvelleListe);
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    /// Les trois tables touchées par Nouvelle liste.
    Future<List<Object>> snapshot(AppDatabase db) async => [
      ...await db.select(db.listLines).get(),
      ...await db.select(db.listContributions).get(),
      ...await db.select(db.weekSelections).get(),
    ];

    testWidgets('dans le menu ⋮ de la Barre d’application, lu « Plus '
        'd’options » ; dialogue avec ses textes et couleurs', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpKadi(tester);
      await _openRecettes(tester);

      final menu = find.byTooltip(StringsFr.plusDOptions);
      expect(
        find.descendant(of: find.byType(AppBar), matching: menu),
        findsOneWidget,
      );
      final size = tester.getSize(menu);
      expect(size.height, greaterThanOrEqualTo(KadiSpacing.touchTarget));
      expect(size.width, greaterThanOrEqualTo(KadiSpacing.touchTarget));
      final scheme = Theme.of(tester.element(menu)).colorScheme;

      // Toujours visible, même sans sélection ni liste.
      await openDialog(tester);
      expect(find.text(StringsFr.nouvelleListeTitre), findsOneWidget);
      expect(find.text(StringsFr.nouvelleListeTexte), findsOneWidget);
      expect(garder, findsOneWidget);
      expect(effacer, findsOneWidget);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, scheme.surfaceContainer);
      Color? colorOf(Finder button) => tester
          .widget<RichText>(
            find.descendant(of: button, matching: find.byType(RichText)),
          )
          .text
          .style
          ?.color;
      expect(colorOf(garder), scheme.onSurface);
      expect(colorOf(effacer), scheme.error);
      expect(
        tester.getSize(garder).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );

      // Déjà vide : rien à effacer, pas d'erreur.
      await tester.tap(effacer);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      handle.dispose();
    });

    testWidgets('Effacer et recommencer : aucune carte sélectionnée, pas de '
        '« Valider », pas d’Annuler, la Liste vide', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await semaineEnCours(tester);

      await openDialog(tester);
      await tester.tap(effacer);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      for (final name in [
        'Chili con carne',
        'Pâtes carbonara',
        'Quiche lorraine',
        'Ratatouille',
      ]) {
        expect(
          find.bySemanticsLabel(StringsFr.ajouterALaSemaine(name)),
          findsOneWidget,
        );
      }
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(RecipeRow), findsNWidgets(4));
      final selections = await db.select(db.weekSelections).get();
      expect(selections.every((s) => s.deletedAt != null), isTrue);

      await _openListe(tester);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.byType(ItemRow), findsNothing);
      expect(find.textContaining('Cochés'), findsNothing);
      handle.dispose();
    });

    testWidgets('Garder, retour Android, tap hors du dialogue : rien ne '
        'change', (tester) async {
      final db = await semaineEnCours(tester);
      final before = await snapshot(db);

      await openDialog(tester);
      await tester.tap(garder);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await openDialog(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await openDialog(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      expect(await snapshot(db), before);
      expect(recipeSelected(tester, 'Pâtes carbonara'), isTrue);
      expect(validerButton(1), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // Toujours sur Recettes.
      expect(find.byType(RecipeRow), findsNWidgets(4));
    });

    testWidgets('échec : snackbar d’erreur sur Recettes, rien d’écrit', (
      tester,
    ) async {
      final db = await semaineEnCours(tester);
      final before = await snapshot(db);
      await db.customStatement(
        'CREATE TRIGGER no_clear BEFORE UPDATE OF deleted_at ON '
        "week_selections BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await openDialog(tester);
      await tester.tap(effacer);
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.nouvelleListeImpossible), findsOneWidget);
      expect(await snapshot(db), before);
      expect(validerButton(1), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('police ×2 sur 360 dp : action et dialogue entiers, sans '
        'débordement', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await pumpKadi(tester);
      await _openRecettes(tester);
      expect(tester.takeException(), isNull);
      final menu = find.byTooltip(StringsFr.plusDOptions);
      expect(menu.hitTestable(), findsOneWidget);
      expect(tester.getRect(menu).right, lessThanOrEqualTo(360));

      await openDialog(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(StringsFr.nouvelleListeTexte), findsOneWidget);
      expect(garder.hitTestable(), findsOneWidget);
      expect(effacer.hitTestable(), findsOneWidget);
      await tester.tap(garder);
      await tester.pumpAndSettle();
    });

    testWidgets('Liste → Terminer les courses : cartes désélectionnées ; '
        'Annuler : lignes cochées et cartes de nouveau sélectionnées, sans '
        '« Valider »', (tester) async {
      final handle = tester.ensureSemantics();
      await _openCarbonaraQuiche(tester);
      await tester.tap(_ajouterButton);
      await tester.pumpAndSettle();
      final names = [
        for (final row in tester.widgetList<ItemRow>(find.byType(ItemRow)))
          row.item.name,
      ];
      expect(names, hasLength(8));
      for (final name in names) {
        await checkOnListe(tester, name);
      }
      final terminer = find.widgetWithText(
        FilledButton,
        StringsFr.terminerLesCourses,
      );
      await tester.tap(terminer);
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.text(StringsFr.coursesTerminees), findsOneWidget);

      await _openRecettes(tester);
      expect(
        find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Pâtes carbonara')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(StringsFr.ajouterALaSemaine('Quiche lorraine')),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);

      await _openListe(tester);
      await tester.tap(find.widgetWithText(SnackBarAction, StringsFr.annuler));
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.listeVide), findsNothing);
      expect(find.text(StringsFr.cochesTitre(8)), findsOneWidget);
      expect(terminer, findsOneWidget);

      await _openRecettes(tester);
      expect(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Pâtes carbonara')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(StringsFr.retirerDeLaSemaine('Quiche lorraine')),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      handle.dispose();
    });
  });

  for (final scale in [1.3, 2.0, 3.0]) {
    testWidgets('police ×$scale sur 360 dp : cartes et Revue sans '
        'débordement ni troncature', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await pumpKadi(tester);
      await _openRecettes(tester);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        recipeSelectButton('Pâtes carbonara'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final name = tester.widget<Text>(find.text('Pâtes carbonara'));
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);
      // Le bouton de sélection reste entier, à droite du nom.
      final select = tester.getRect(recipeSelectButton('Pâtes carbonara'));
      expect(select.right, lessThanOrEqualTo(360));
      expect(
        tester.getRect(find.text('Pâtes carbonara')).right,
        lessThanOrEqualTo(select.left),
      );

      await tapRecipeCard(tester, 'Pâtes carbonara');
      expect(recipeSelected(tester, 'Pâtes carbonara'), isTrue);
      await tapRecipeCard(tester, 'Pâtes carbonara');
      await tapRecipeCard(tester, 'Pâtes carbonara');
      await openRevue(tester, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(RevueScreen), findsOneWidget);
      final button = tester.getSize(revueAddButton);
      expect(button.height, greaterThanOrEqualTo(KadiSpacing.touchTarget));

      // Ligne de Revue : nom entier, tag et Module quantité sans
      // débordement.
      await tester.scrollUntilVisible(
        revueRowOf('Œufs'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(RevueScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final eggName = tester.widget<Text>(
        find.descendant(of: revueRowOf('Œufs'), matching: find.text('Œufs')),
      );
      expect(eggName.maxLines, isNull);
      expect(eggName.overflow, isNull);
      await setRevueQuantity(tester, 'Œufs', '999999');
      expect(tester.takeException(), isNull);
      expect(tester.getRect(revueRowOf('Œufs')).right, lessThanOrEqualTo(360));
    });
  }
}
