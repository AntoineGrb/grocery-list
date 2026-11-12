import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';

import '../helpers/navigation.dart';

import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:kadi/features/reglages/ui/parcours_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/panneau.dart';
import '../helpers/pump_app.dart';
import '../helpers/recettes.dart';
import '../helpers/test_db.dart';

/// Pain de mie, Boulangerie, de `assets/seed/articles.json`.
const _painDeMie = 'd9124fc2-74ce-4473-b570-de840dd0fd48';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Rayons des En-têtes de rayon affichés, de haut en bas.
List<Rayon> _headers(WidgetTester tester) => [
  for (final h in tester.widgetList<RayonHeader>(find.byType(RayonHeader)))
    h.rayon,
];

Finder _routeHandle(Rayon rayon) => find.descendant(
  of: find.byWidgetPredicate((w) => w is RouteRow && w.rayon == rayon),
  matching: find.byType(ReorderableDragStartListener),
);

/// Ouvre Paramètres › Parcours depuis la Liste, glisse Boulangerie (2e) en
/// premier par sa poignée, puis revient à la Liste.
Future<void> _boulangerieEnPremier(WidgetTester tester) async {
  await _tap(tester, parametresTab);
  await _tap(tester, find.text(StringsFr.parcours));
  final height = tester
      .getSize(
        find.byWidgetPredicate(
          (w) => w is RouteRow && w.rayon == Rayon.fruitsLegumes,
        ),
      )
      .height;
  final gesture = await tester.startGesture(
    tester.getCenter(_routeHandle(Rayon.boulangerie)),
  );
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(Offset(0, -0.25 * height));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
  expect(
    tester.widgetList<RouteRow>(find.byType(RouteRow)).first.rayon,
    Rayon.boulangerie,
  );

  await _tap(tester, find.byType(BackButton));
  await _tap(tester, listeTab);
  expect(find.byType(ListeScreen), findsOneWidget);
}

void main() {
  testWidgets('Tomates et Pain dans la Liste : Boulangerie glissé en premier '
      'dans Parcours, la Liste, la Revue et les Ajouts fréquents suivent, '
      'sans relance', (tester) async {
    tallPhone(tester);
    final db = await pumpKadi(tester);
    final clock = Clock();
    final liste = ListeRepository(db, clock);
    await liste.addArticle(SeedIds.tomates);
    await liste.addArticle(_painDeMie);
    // Une recette à valider avec les deux rayons, pour la Revue.
    final recettes = RecettesRepository(db, clock);
    await recettes.saveDraft(
      const RecipeDraft(
        recipeId: 'tartines',
        name: 'Tartines',
        ingredients: [
          RecipeDraftIngredient(
            id: 'tartines-tomates',
            articleId: SeedIds.tomates,
          ),
          RecipeDraftIngredient(id: 'tartines-pain', articleId: _painDeMie),
        ],
      ),
    );
    await recettes.select('tartines');
    await tester.pumpAndSettle();

    // Ordre par défaut : Fruits et légumes avant Boulangerie.
    expect(_headers(tester), [Rayon.fruitsLegumes, Rayon.boulangerie]);

    await _boulangerieEnPremier(tester);

    // Liste : Pain au-dessus de Tomates.
    expect(_headers(tester), [Rayon.boulangerie, Rayon.fruitsLegumes]);
    expect(
      tester.getTopLeft(find.widgetWithText(ItemRow, 'Pain de mie')).dy,
      lessThan(tester.getTopLeft(find.widgetWithText(ItemRow, 'Tomates')).dy),
    );

    // Revue : Boulangerie en tête.
    await openTab(tester, StringsFr.tabRecettes);
    await openRevue(tester, 1);
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(revueRayons(tester), [Rayon.boulangerie, Rayon.fruitsLegumes]);
    await _tap(tester, find.byType(BackButton));

    // Ajouts fréquents du Panneau + : les fréquents de Boulangerie d'abord.
    await openTab(tester, StringsFr.tabListe);
    await _tap(tester, find.byType(FloatingActionButton));
    expect(find.byType(AddSheet), findsOneWidget);
    await showFrequents(tester);
    final frequents = tester
        .widgetList<FrequentChip>(find.byType(FrequentChip))
        .map((r) => r.article)
        .toList();
    // Baguettes et Pain de mie, puis les fruits et légumes.
    expect(frequents.map((a) => a.rayon).take(3), [
      Rayon.boulangerie,
      Rayon.boulangerie,
      Rayon.fruitsLegumes,
    ]);
  });
}
