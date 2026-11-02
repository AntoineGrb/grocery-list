import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/recettes/state/revue.dart';
import 'package:kadi/features/recettes/ui/recipe_card.dart';
import 'package:kadi/features/recettes/ui/revue_row.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

const _nbsp = ' ';

/// Échoue toujours, sans rien écrire.
class _FailingAjouter implements AjouterALaListe {
  @override
  Future<void> call(Revue revue) async => throw StateError('échec simulé');
}

/// Ouvre l'onglet Recettes.
Future<void> _openRecettes(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(StringsFr.tabRecettes),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _card(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(RecipeCard));

Future<void> _tapCard(WidgetTester tester, String name) async {
  await tester.ensureVisible(_card(name));
  await tester.tap(_card(name));
  await tester.pumpAndSettle();
}

Finder _valider(int n) =>
    find.widgetWithText(FilledButton, StringsFr.validerN(n));

Future<void> _validate(WidgetTester tester, int n) async {
  await tester.tap(_valider(n));
  await tester.pumpAndSettle();
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
  testWidgets('installation neuve : les 4 recettes exemples en cartes sur 2 '
      'colonnes, chacune avec son picto', (tester) async {
    await pumpKadi(tester);
    await _openRecettes(tester);

    expect(find.byType(RecipeCard), findsNWidgets(4));
    expect(find.text(StringsFr.recettesVide), findsNothing);
    final chili = tester.getRect(_card('Chili con carne'));
    final carbonara = tester.getRect(_card('Pâtes carbonara'));
    final quiche = tester.getRect(_card('Quiche lorraine'));
    final ratatouille = tester.getRect(_card('Ratatouille'));
    // Rangées de deux cartes de même hauteur, triées par nom.
    expect(chili.top, carbonara.top);
    expect(chili.height, carbonara.height);
    expect(chili.left, lessThan(carbonara.left));
    expect(quiche.top, greaterThan(chili.bottom));
    expect(quiche.top, ratatouille.top);
    expect(chili.width, carbonara.width);
    // Le picto de repli de l'ingrédient principal, 44 dp.
    final chiliPicto = find.descendant(
      of: _card('Chili con carne'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == KadiSpacing.recipePicto &&
            w.height == KadiSpacing.recipePicto,
      ),
    );
    expect(chiliPicto, findsOneWidget);
    // Aucun Bouton d'action sans sélection.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('sans recette : message d’état vide', (tester) async {
    await pumpKadi(
      tester,
      assetOverrides: {SeedLoader.recettesPath: emptyRecettesFile()},
    );
    await _openRecettes(tester);
    expect(find.text(StringsFr.recettesVide), findsOneWidget);
    expect(find.byType(RecipeCard), findsNothing);
  });

  testWidgets('sélectionner, désélectionner : coche, bordure et Valider (n)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    await _tapCard(tester, 'Chili con carne');
    expect(
      find.bySemanticsLabel('Chili con carne, sélectionnée'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _card('Chili con carne'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(_valider(1), findsOneWidget);
    expect(await db.select(db.weekSelections).get(), hasLength(1));

    await _tapCard(tester, 'Ratatouille');
    expect(_valider(2), findsOneWidget);

    // Désélection d'une recette non validée, par TalkBack.
    tester.semantics.tap(
      find.semantics.byLabel('Chili con carne, sélectionnée'),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    expect(_valider(1), findsOneWidget);
    await _tapCard(tester, 'Ratatouille');
    expect(find.byType(FilledButton), findsNothing);
    handle.dispose();
  });

  testWidgets('Carbonara + Quiche : Valider (2), Revue, Ajouter à la liste, '
      'Liste prête ; puis Ratatouille seule en Revue', (tester) async {
    // Téléphone haut : toute la Revue et toute la Liste sont bâties.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);
    await _tapCard(tester, 'Pâtes carbonara');
    await _tapCard(tester, 'Quiche lorraine');
    await _validate(tester, 2);

    // Revue : plein écran, sans Barre de navigation, flèche retour.
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(find.text(StringsFr.revue), findsOneWidget);
    expect(find.text(StringsFr.revueConsigne), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    // Groupée par rayon dans l'ordre du parcours (par défaut), tout coché.
    expect(_headers(tester), [
      Rayon.viandePoisson,
      Rayon.cremerie,
      Rayon.epicerieSalee,
    ]);
    expect(find.byType(RevueRow), findsNWidgets(8));
    expect(find.text('Lardons'), findsOneWidget);
    expect(find.text('400${_nbsp}g'), findsOneWidget);
    expect(find.text('Œufs'), findsOneWidget);
    expect(find.text('6${_nbsp}pièces'), findsOneWidget);
    expect(find.text('Poivre'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Lardons, 400${_nbsp}g, Viande et poisson'),
      ),
      isSemantics(
        label: 'Lardons, 400${_nbsp}g, Viande et poisson',
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    expect(find.bySemanticsLabel('Poivre, Épicerie salée'), findsOneWidget);
    expect(
      tester
          .widgetList<Checkbox>(
            find.descendant(
              of: find.byType(RevueRow),
              matching: find.byType(Checkbox),
            ),
          )
          .every((c) => c.value == true),
      isTrue,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
    );
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
    expect(
      find.bySemanticsLabel('Pâtes carbonara, sélectionnée'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Quiche lorraine, sélectionnée'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);

    // Une carte validée ne change pas (story 3).
    await _tapCard(tester, 'Pâtes carbonara');
    expect(
      find.bySemanticsLabel('Pâtes carbonara, sélectionnée'),
      findsOneWidget,
    );
    expect(await db.select(db.weekSelections).get(), selections);

    // Ratatouille seule en Revue.
    await _tapCard(tester, 'Ratatouille');
    await _validate(tester, 1);
    expect(find.byType(RevueRow), findsNWidgets(7));
    expect(find.text('Courgettes'), findsOneWidget);
    expect(find.text('Lardons'), findsNothing);
    expect(find.text('Œufs'), findsNothing);
    handle.dispose();
  });

  testWidgets('retour depuis la Revue : rien n’est validé ni ajouté', (
    tester,
  ) async {
    final db = await pumpKadi(tester);
    await _openRecettes(tester);
    await _tapCard(tester, 'Chili con carne');
    await _validate(tester, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(_valider(1), findsOneWidget);
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
    await _tapCard(tester, 'Chili con carne');
    await _validate(tester, 1);

    await tester.tap(
      find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
    );
    await tester.pumpAndSettle();

    expect(find.text(StringsFr.ajoutImpossible), findsOneWidget);
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
          )
          .onPressed,
      isNotNull,
    );
    expect(await db.select(db.listLines).get(), isEmpty);
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

      final chili = tester.getRect(_card('Chili con carne'));
      final carbonara = tester.getRect(_card('Pâtes carbonara'));
      expect(chili.height, carbonara.height);
      final name = tester.widget<Text>(find.text('Pâtes carbonara'));
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);

      await _tapCard(tester, 'Pâtes carbonara');
      await _validate(tester, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(RevueScreen), findsOneWidget);
      final button = tester.getSize(
        find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
      );
      expect(button.height, greaterThanOrEqualTo(KadiSpacing.touchTarget));
    });
  }
}
