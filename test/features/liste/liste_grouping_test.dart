import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_panel.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/liste/ui/row_highlight.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/panneau.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

/// Pain de mie, Boulangerie, de `assets/seed/articles.json`.
const _painDeMie = 'd9124fc2-74ce-4473-b570-de840dd0fd48';

Finder _row(String name) => find.widgetWithText(ItemRow, name);

Finder _highlight(String name) =>
    find.ancestor(of: _row(name), matching: find.byType(RowHighlight));

/// Noms des lignes non cochées, de haut en bas.
List<String> _uncheckedOrder(WidgetTester tester, List<String> names) {
  final sorted = [...names]
    ..sort(
      (a, b) => tester
          .getTopLeft(_row(a))
          .dy
          .compareTo(tester.getTopLeft(_row(b)).dy),
    );
  return sorted;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Ouvre Paramètres par ⚙, bascule « Grouper par rayon », revient à la Liste.
Future<void> _toggleGrouping(WidgetTester tester) async {
  await _tap(tester, find.byType(SettingsAction));
  await _tap(tester, find.text(StringsFr.grouperParRayon));
  await _tap(tester, find.byType(BackButton));
}

/// Monte Kadi avec Lait (Crèmerie), Tomates (F&L) et Pain de mie
/// (Boulangerie), ajoutés dans cet ordre.
Future<(AppDatabase, ListeRepository)> _pumpWithThree(
  WidgetTester tester,
) async {
  final db = await pumpKadi(tester);
  // Une seule horloge : les `added_at` se suivent strictement.
  final repo = ListeRepository(db, Clock());
  await repo.addArticle(SeedIds.lait);
  await repo.addArticle(SeedIds.tomates);
  await repo.addArticle(_painDeMie);
  await tester.pumpAndSettle();
  return (db, repo);
}

const _three = ['Lait', 'Tomates', 'Pain de mie'];

void main() {
  test('ungrouped : un seul groupe sans rayon, ordre reçu ; vide sans '
      'groupe', () {
    ListeItem item(String id, Rayon rayon) => ListeItem(
      lineId: id,
      articleId: id,
      name: id,
      rayon: rayon,
      unit: null,
      quantity: null,
    );
    final items = [
      item('lait', Rayon.cremerie),
      item('tomates', Rayon.fruitsLegumes),
      item('pain', Rayon.boulangerie),
    ];
    final groups = ungrouped(items);
    expect(groups, hasLength(1));
    expect(groups.single.rayon, isNull);
    expect(groups.single.items.map((i) => i.lineId), [
      'lait',
      'tomates',
      'pain',
    ]);
    expect(ungrouped(const []), isEmpty);
  });

  testWidgets('Grouper off par ⚙ : ordre d’ajout, sans En-tête ; on de '
      'nouveau : En-têtes revenus, ordre du parcours', (tester) async {
    await _pumpWithThree(tester);

    // Par défaut : groupé, dans l'ordre du parcours.
    expect(find.byType(RayonHeader), findsNWidgets(3));
    expect(_uncheckedOrder(tester, _three), ['Tomates', 'Pain de mie', 'Lait']);

    await _toggleGrouping(tester);
    expect(find.byType(ListeScreen), findsOneWidget);
    expect(find.byType(RayonHeader), findsNothing);
    expect(_uncheckedOrder(tester, _three), ['Lait', 'Tomates', 'Pain de mie']);
    // La case et le surlignage gardent la couleur du rayon de la ligne.
    expect(
      tester.widget<RowHighlight>(_highlight('Lait')).color,
      KadiColors.of(tester.element(_row('Lait')))
          .rayon(Rayon.cremerie)
          .pastille,
    );

    await _toggleGrouping(tester);
    expect(find.byType(RayonHeader), findsNWidgets(3));
    expect(_uncheckedOrder(tester, _three), ['Tomates', 'Pain de mie', 'Lait']);
  });

  testWidgets('Grouper off : basculement immédiat, Section Cochés inchangée', (
    tester,
  ) async {
    final (db, repo) = await _pumpWithThree(tester);
    final lait = await repo.firstUnchecked(SeedIds.lait);
    await repo.check(lait!.lineId);
    await tester.pumpAndSettle();
    expect(find.byType(CheckedSection), findsOneWidget);

    await SettingsRepository(db, Clock()).setGroupByRayon(false);
    await tester.pumpAndSettle();

    expect(find.byType(RayonHeader), findsNothing);
    expect(_uncheckedOrder(tester, ['Tomates', 'Pain de mie']), [
      'Tomates',
      'Pain de mie',
    ]);
    expect(find.byType(CheckedSection), findsOneWidget);
    expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
  });

  testWidgets('Panneau + ouvert, Grouper off : une ligne ajoutée est montrée '
      'et surlignée', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 914);
    addTearDown(tester.view.reset);
    final (db, _) = await _pumpWithThree(tester);
    await SettingsRepository(db, Clock()).setGroupByRayon(false);
    await tester.pumpAndSettle();

    await _tap(tester, find.byType(FloatingActionButton));
    expect(find.byType(AddSheet), findsOneWidget);
    await showFrequents(tester);

    final frequent = find.widgetWithText(FrequentChip, 'Oignons');
    await tester.scrollUntilVisible(
      frequent,
      100,
      scrollable: find
          .descendant(
            of: find.descendant(
              of: find.byType(AddSheet),
              matching: find.byType(ListView),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await _tap(tester, frequent);

    expect(find.byType(RayonHeader), findsNothing);
    expect(_row('Oignons'), findsOneWidget);
    expect(tester.widget<RowHighlight>(_highlight('Oignons')).arriving, isTrue);
    final ListePanel panel = ProviderScope.containerOf(
      tester.element(find.byType(ListeScreen)),
      listen: false,
    ).read(listePanelProvider);
    expect(
      tester.getBottomLeft(_row('Oignons')).dy,
      lessThanOrEqualTo(panel.top! + 1),
    );
    // Dernière ajoutée : sous les trois autres.
    expect(_uncheckedOrder(tester, [..._three, 'Oignons']).last, 'Oignons');
  });
}
