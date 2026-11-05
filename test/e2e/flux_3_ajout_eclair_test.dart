import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/item_edit_sheet.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/liste/ui/quantity_popup.dart';
import 'package:kadi/features/liste/ui/quantity_tag.dart';
import 'package:kadi/features/liste/ui/rayon_tag.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e_harness.dart';

const _keyboard = 300.0;

/// Id de l'article Piles fourni.
const _pilesFourni = '647841c6-7cff-40f4-a8dd-69d7e781eb8b';

final _quantityTag = find.byWidgetPredicate(
  (w) => w is QuantityTag && w.emptyLabel == StringsFr.quantite,
);
final _rayonTag = find.byType(RayonTag);
final _popup = find.byType(QuantityPopup);

/// Le tag quantité de la ligne [row] du panneau.
Finder _lineTag(Finder row) =>
    find.descendant(of: row, matching: find.byType(QuantityTag));

/// Haut du Panneau + ouvert.
double _panelTop(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ListeScreen)),
  listen: false,
).read(listePanelProvider).top!;

/// La Ligne d'article de [name] est posée au-dessus du panneau, sous la
/// Barre d'application.
void _expectAbovePanel(WidgetTester tester, String name, {String? reason}) {
  final rect = tester.getRect(itemRow(name));
  expect(rect.bottom, lessThanOrEqualTo(_panelTop(tester) + 1), reason: reason);
  expect(rect.top, greaterThanOrEqualTo(kToolbarHeight), reason: reason);
}

/// Le clavier se ferme (ou s'ouvre) : la vue perd (ou retrouve) sa marge.
void _keyboardShown(WidgetTester tester, bool shown) {
  tester.view.viewInsets = shown
      ? const FakeViewPadding(bottom: _keyboard)
      : FakeViewPadding.zero;
}

/// État de départ : une liste en cours de la semaine, assez longue pour
/// que Crèmerie et Entretien soient sous le panneau ; « piles » n'est pas
/// au catalogue.
Future<AppDatabase> _pumpFrigo(WidgetTester tester) async {
  phone(tester, size: const Size(412, 914), keyboard: _keyboard);
  final db = await pumpE2e(tester);
  await (db.update(db.articles)..where((a) => a.id.equals(_pilesFourni))).write(
    const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
  );
  final articles =
      await (db.select(db.articles)
            ..where(
              (a) =>
                  a.rayon.equals(Rayon.fruitsLegumes.code) &
                  a.deletedAt.isNull(),
            )
            ..limit(12))
          .get();
  final repo = ListeRepository(db, Clock());
  for (final article in articles) {
    await repo.addArticle(article.id);
  }
  await tester.pumpAndSettle();
  return db;
}

void flux3AjoutEclair() {
  group('Flux 3 — L’ajout éclair en semaine', () {
    testBothThemes('FAB +, Lait en un tap : ★ il arrive dans Crèmerie au-'
        'dessus du panneau ; « piles », Entretien, 4, Entrée ; Qté du Lait '
        '→ 2', (tester) async {
      final db = await _pumpFrigo(tester);

      // 1-2. FAB + : champ focalisé, clavier ouvert, tags et « Ajouts
      // fréquents » dessous, la Liste visible au-dessus.
      await openAddSheet(tester);
      expect(addFieldFocused(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(_quantityTag, findsOneWidget);
      expect(_rayonTag, findsOneWidget);
      final title = inAddSheet(find.byType(FrequentsTitle));
      expect(title, findsOneWidget);
      expect(
        tester.getTopLeft(title).dy,
        greaterThan(tester.getTopLeft(addField).dy),
      );
      expect(find.byType(ListeScreen), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ItemRow).first).dy,
        lessThan(_panelTop(tester)),
      );

      // Le titre des fréquents ferme le clavier.
      await tester.tap(find.text(StringsFr.ajoutsFrequents));
      await tester.pumpAndSettle();
      expect(addFieldFocused(tester), isFalse);
      _keyboardShown(tester, false);
      await tester.pumpAndSettle();

      // 3. Lait : le + devient une coche, un tag « Qté » apparaît ; rien
      // d'autre ne s'ouvre.
      await tapFrequent(tester, 'Lait');
      final lait = frequentRow('Lait');
      expect(
        find.descendant(of: lait, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lait, matching: find.byIcon(Icons.add)),
        findsNothing,
      );
      expect(
        find.descendant(of: _lineTag(lait), matching: find.text(StringsFr.qte)),
        findsOneWidget,
      );
      expect(_popup, findsNothing);
      expect(find.byType(ItemEditSheet), findsNothing);

      // 4. ★ Le lait arrive dans Crèmerie, juste au-dessus du panneau : un
      // tap a suffi.
      expect(itemRow('Lait'), findsOneWidget, reason: '★');
      _expectAbovePanel(tester, 'Lait', reason: '★');
      expect(
        tester.getTopLeft(itemRow('Lait')).dy,
        greaterThan(tester.getTopLeft(rayonHeader(StringsFr.rayonCremerie)).dy),
        reason: '★ sous Crèmerie',
      );

      // 5. « piles », Tag Rayon Entretien, Tag Quantité 4, Entrée.
      await tester.showKeyboard(addField);
      _keyboardShown(tester, true);
      await tester.pumpAndSettle();
      await tester.enterText(addField, 'piles');
      await tester.pumpAndSettle();
      expect(find.byType(AddTypedRow), findsOneWidget);
      await tapAndSettle(tester, _rayonTag);
      await tester.ensureVisible(find.byKey(const ValueKey(Rayon.entretien)));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byKey(const ValueKey(Rayon.entretien)));
      await tapAndSettle(tester, _quantityTag);
      expect(_popup, findsOneWidget);
      await tester.enterText(
        find.descendant(of: _popup, matching: find.byType(TextField)),
        '4',
      );
      await tester.pump();
      await pressEnter(tester);
      expect(_popup, findsNothing);
      expect(
        find.descendant(
          of: _quantityTag,
          matching: find.text(formatQuantity(4000, Unit.piece)),
        ),
        findsOneWidget,
      );
      await pressEnter(tester);

      // Champ vidé, clavier ouvert, tags à zéro.
      expect(tester.widget<TextField>(addField).controller!.text, isEmpty);
      expect(addFieldFocused(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        find.descendant(
          of: _quantityTag,
          matching: find.text(StringsFr.quantite),
        ),
        findsOneWidget,
      );
      expect(tester.widget<RayonTag>(_rayonTag).chosen, isFalse);
      // La Liste a défilé jusqu'à Entretien, où « Piles 4 » arrive.
      expect(
        itemRowWith('Piles', formatQuantity(4000, Unit.piece)),
        findsOneWidget,
      );
      _expectAbovePanel(tester, 'Piles');
      expect(
        tester.getTopLeft(itemRow('Piles')).dy,
        greaterThan(
          tester.getTopLeft(rayonHeader(StringsFr.rayonEntretien)).dy,
        ),
      );
      // Sans entrer au catalogue.
      final piles =
          await (db.select(db.articles)..where(
                (a) => a.normalizedName.equals('piles') & a.deletedAt.isNull(),
              ))
              .getSingle();
      expect(piles.inCatalogue, isFalse);

      // 6. Le tag « Qté » du Lait : Popup quantité, 2, Valider.
      await scrollToFrequent(tester, 'Lait');
      await tapAndSettle(tester, _lineTag(frequentRow('Lait')));
      expect(_popup, findsOneWidget);
      expect(
        tester.getRect(_popup).bottom,
        lessThanOrEqualTo(tester.getRect(addSheet).bottom),
      );
      await tester.enterText(
        find.descendant(of: _popup, matching: find.byType(TextField)),
        '2',
      );
      await tester.pump();
      await tapAndSettle(
        tester,
        find.descendant(
          of: _popup,
          matching: find.byTooltip(StringsFr.valider),
        ),
      );
      expect(_popup, findsNothing);
      final quantity = formatQuantity(2000, Unit.piece);
      expect(
        find.descendant(
          of: _lineTag(frequentRow('Lait')),
          matching: find.text(quantity),
        ),
        findsOneWidget,
      );
      await closeAddSheet(tester);
      expect(itemRowWith('Lait', quantity), findsOneWidget);
    });

    testBothThemes('Échec : Lait déjà dans la liste, touché : retiré avec '
        'Annuler, un second tap le remet ; Entrée sur « lait » : rien, puis '
        'avec Boissons : sa ligne change de rayon, montrée', (tester) async {
      final db = await _pumpFrigo(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      _keyboardShown(tester, false);
      await openAddSheet(tester);

      await tapFrequent(tester, 'Lait');
      expect(itemRow('Lait'), findsNothing);
      expect(
        find.descendant(of: addSheet, matching: undoAction),
        findsOneWidget,
      );
      await tapFrequent(tester, 'Lait');
      expect(itemRow('Lait'), findsOneWidget);
      expect(
        find.descendant(
          of: frequentRow('Lait'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      // Entrée sur un article présent, sans tag : rien ne change.
      await tester.showKeyboard(addField);
      _keyboardShown(tester, true);
      await tester.pumpAndSettle();
      await tester.enterText(addField, 'lait');
      await tester.pumpAndSettle();
      await pressEnter(tester);
      expect(itemRow('Lait'), findsOneWidget);
      final lines =
          await (db.select(db.listLines)..where(
                (l) => l.articleId.equals(SeedIds.lait) & l.deletedAt.isNull(),
              ))
              .get();
      expect(lines, hasLength(1));
      expect(lines.single.rayon, Rayon.cremerie.code);

      // Avec le Tag Rayon Boissons : sa ligne passe sous Boissons, montrée.
      await tester.enterText(addField, 'lait');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, _rayonTag);
      await tester.ensureVisible(find.byKey(const ValueKey(Rayon.boissons)));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byKey(const ValueKey(Rayon.boissons)));
      await pressEnter(tester);
      expect(itemRow('Lait'), findsOneWidget);
      _expectAbovePanel(tester, 'Lait');
      expect(
        tester.getTopLeft(itemRow('Lait')).dy,
        greaterThan(tester.getTopLeft(rayonHeader(StringsFr.rayonBoissons)).dy),
      );
    });
  });
}

void main() => flux3AjoutEclair();
