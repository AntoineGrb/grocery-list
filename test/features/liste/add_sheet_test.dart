import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

/// Monte Kadi sur une base en mémoire, dans une vue assez haute pour que
/// les 31 fréquents tiennent dans le Panneau +. L'app s'ouvre sur la Liste.
Future<AppDatabase> _pumpApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 3000);
  addTearDown(tester.view.reset);
  return pumpKadi(tester);
}

final _sheet = find.byType(AddSheet);
Finder _inSheet(Finder finder) => find.descendant(of: _sheet, matching: finder);
final _undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);

/// La Ligne de fréquent de [name].
Finder _frequent(String name) => find.widgetWithText(FrequentRow, name);

/// La Ligne de résultat de [name].
Finder _result(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SearchResultRow));

/// L'indicateur [icon] (coche ou +) de la ligne [row].
Finder _indicator(Finder row, IconData icon) =>
    find.descendant(of: row, matching: find.byIcon(icon));

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(_sheet)).pop();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder row) async {
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _letSnackBarClose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Le Champ de recherche du panneau (le premier champ : un Champ quantité
/// peut le suivre).
Finder get _search => _inSheet(find.byType(TextField)).first;

/// Le Champ quantité de la ligne dépliée.
final _quantity = _inSheet(find.byType(QuantityField));

/// La ligne « Créer « … » ».
final _create = find.byType(CreateArticleRow);

/// La pastille [rayon] du Choix de rayon de la ligne dépliée.
Finder _pastille(Rayon rayon) => find.descendant(
  of: _inSheet(find.byType(RayonPicker)),
  matching: find.byKey(ValueKey(rayon)),
);

/// Id de l'article Piles fourni.
const _pilesFourni = '647841c6-7cff-40f4-a8dd-69d7e781eb8b';

/// « piles » absent du catalogue : l'article fourni est supprimé.
Future<void> _withoutPiles(WidgetTester tester, AppDatabase db) async {
  await (db.update(db.articles)..where((a) => a.id.equals(_pilesFourni))).write(
    const ArticlesCompanion(deletedAt: Value(1), updatedAt: Value(1)),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
}

/// Articles actifs de nom normalisé [normalized].
Future<List<Article>> _activeArticles(AppDatabase db, String normalized) =>
    (db.select(db.articles)..where(
          (a) => a.normalizedName.equals(normalized) & a.deletedAt.isNull(),
        ))
        .get();

/// Lignes actives (cochées ou non) de [articleId].
Future<List<ListLine>> _activeLines(AppDatabase db, String articleId) =>
    (db.select(db.listLines)
          ..where((l) => l.articleId.equals(articleId) & l.deletedAt.isNull()))
        .get();

void main() {
  testWidgets(
    'Panneau + ouvert : champ focalisé, fréquents groupés sous des '
    'en-têtes sans compteur, dans l’ordre du parcours, avec Picto, nom et +',
    (tester) async {
      await _pumpApp(tester);
      await _openSheet(tester);

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);

      final headers = tester
          .widgetList<RayonHeader>(_inSheet(find.byType(RayonHeader)))
          .toList();
      expect(headers.every((h) => h.count == null), isTrue);
      expect(
        [for (final h in headers) h.rayon],
        [
          Rayon.fruitsLegumes,
          Rayon.boulangerie,
          Rayon.viandePoisson,
          Rayon.cremerie,
          Rayon.epicerieSalee,
          Rayon.epicerieSucree,
          Rayon.surgeles,
          Rayon.boissons,
          Rayon.hygiene,
          Rayon.entretien,
        ],
      );
      final fruits = find.widgetWithText(RayonHeader, 'Fruits & légumes');
      final cremerie = _inSheet(find.widgetWithText(RayonHeader, 'Crèmerie'));
      expect(
        tester.getTopLeft(fruits).dy,
        lessThan(tester.getTopLeft(cremerie).dy),
      );
      // Lait sous Crèmerie, avant Œufs (position).
      expect(
        tester.getTopLeft(_frequent('Lait')).dy,
        greaterThan(tester.getTopLeft(cremerie).dy),
      );
      expect(
        tester.getTopLeft(_frequent('Lait')).dy,
        lessThan(tester.getTopLeft(_frequent('Œufs')).dy),
      );

      expect(find.byType(FrequentRow), findsNWidgets(31));
      expect(find.byType(SearchResultRow), findsNothing);
      final lait = _frequent('Lait');
      expect(find.descendant(of: lait, matching: find.byType(Picto)), findsOne);
      expect(_indicator(lait, Icons.add), findsOneWidget);
      expect(_indicator(lait, Icons.check), findsNothing);
      expect(
        tester.widget<Icon>(_indicator(lait, Icons.add)).color,
        Theme.of(tester.element(lait)).colorScheme.onSurfaceVariant,
      );
      expect(tester.getSize(lait).height, greaterThanOrEqualTo(48));
    },
  );

  testWidgets('aucun fréquent : message d’état vide, sans action', (
    tester,
  ) async {
    final db = await _pumpApp(tester);
    await db
        .update(db.frequents)
        .write(
          const FrequentsCompanion(deletedAt: Value(1), updatedAt: Value(1)),
        );
    await _openSheet(tester);

    expect(find.text(StringsFr.pasDeFrequents), findsOneWidget);
    expect(find.byType(FrequentRow), findsNothing);
    expect(_inSheet(find.byType(RayonHeader)), findsNothing);
    expect(
      find.ancestor(
        of: find.text(StringsFr.pasDeFrequents),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('tap sur Lait hors liste : panneau ouvert, coche à l’accent de '
      'Crèmerie, Lait sous Crèmerie dans la Liste', (tester) async {
    final db = await _pumpApp(tester);
    await _openSheet(tester);

    await _tap(tester, _frequent('Lait'));

    expect(_sheet, findsOneWidget);
    final check = _indicator(_frequent('Lait'), Icons.check);
    expect(check, findsOneWidget);
    expect(_indicator(_frequent('Lait'), Icons.add), findsNothing);
    expect(
      tester.widget<Icon>(check).color,
      KadiColors.of(tester.element(check)).rayon(Rayon.cremerie).accent,
    );
    final line = (await _activeLines(db, SeedIds.lait)).single;
    expect(line.unit, isNull);
    expect(line.rayon, Rayon.cremerie.code);

    await _closeSheet(tester);
    final row = find.widgetWithText(ItemRow, 'Lait');
    expect(row, findsOneWidget);
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(
        tester.getTopLeft(find.widgetWithText(RayonHeader, 'Crèmerie')).dy,
      ),
    );
    expect(tester.widget<RayonHeader>(find.byType(RayonHeader)).count, 1);
  });

  testWidgets('Lait dans la liste, tap : retiré, + revient, snackbar dans le '
      'panneau ; Annuler le remet et la coche réapparaît', (tester) async {
    final db = await _pumpApp(tester);
    final repo = ListeRepository(db, Clock());
    await repo.addArticle(SeedIds.lait, quantity: 500, unit: Unit.g);
    await repo.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
    await tester.pumpAndSettle();
    await _openSheet(tester);
    expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);

    await _tap(tester, _frequent('Lait'));

    expect(_sheet, findsOneWidget);
    expect(await _activeLines(db, SeedIds.lait), isEmpty);
    expect(_indicator(_frequent('Lait'), Icons.add), findsOneWidget);
    expect(_indicator(_frequent('Lait'), Icons.check), findsNothing);
    // Snackbar du panneau, au-dessus de la barrière.
    expect(
      _inSheet(find.text(StringsFr.retireDeLaListe('Lait'))),
      findsOneWidget,
    );
    expect(find.text('Retiré de la liste : Lait'), findsOneWidget);
    expect(_inSheet(_undoAction), findsOneWidget);

    await _tap(tester, _undoAction);

    expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);
    final lines = await _activeLines(db, SeedIds.lait);
    expect(lines.map((l) => l.unit), unorderedEquals(['g', 'piece']));

    await _closeSheet(tester);
    expect(find.text(formatQuantity(500, Unit.g)), findsOneWidget);
    expect(find.text(formatQuantity(2000, Unit.piece)), findsOneWidget);
  });

  testWidgets('retirer Lait puis fermer le panneau : le snackbar Annuler '
      'passe sur la Liste, Annuler y remet Lait', (tester) async {
    final db = await _pumpApp(tester);
    await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await _tap(tester, _frequent('Lait'));
    expect(await _activeLines(db, SeedIds.lait), isEmpty);
    await _closeSheet(tester);

    expect(_sheet, findsNothing);
    expect(find.text(StringsFr.retireDeLaListe('Lait')), findsOneWidget);
    expect(find.text(StringsFr.listeVide), findsOneWidget);

    await _tap(tester, _undoAction);

    expect(await _activeLines(db, SeedIds.lait), hasLength(1));
    expect(find.widgetWithText(ItemRow, 'Lait'), findsOneWidget);
  });

  testWidgets('snackbar du panneau fermé à sa fin, puis panneau fermé : rien '
      'n’est remontré sur la Liste', (tester) async {
    final db = await _pumpApp(tester);
    await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await _tap(tester, _frequent('Lait'));
    await _letSnackBarClose(tester);
    expect(find.text(StringsFr.retireDeLaListe('Lait')), findsNothing);
    await _closeSheet(tester);

    expect(find.text(StringsFr.retireDeLaListe('Lait')), findsNothing);
    expect(find.text(StringsFr.listeVide), findsOneWidget);
  });

  testWidgets('Lait coché dans la Liste puis panneau rouvert : le fréquent '
      'Lait montre +', (tester) async {
    await _pumpApp(tester);
    await _openSheet(tester);
    await _tap(tester, _frequent('Lait'));
    await _closeSheet(tester);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ItemRow, 'Lait'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);

    await _openSheet(tester);
    expect(_indicator(_frequent('Lait'), Icons.add), findsOneWidget);
    expect(_indicator(_frequent('Lait'), Icons.check), findsNothing);
  });

  testWidgets('recherche « lai » : les fréquents laissent la place aux '
      'résultats ; le résultat Lait ajoute puis retire', (tester) async {
    final db = await _pumpApp(tester);
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'lai');
    await tester.pumpAndSettle();

    expect(find.byType(FrequentRow), findsNothing);
    expect(_inSheet(find.byType(RayonHeader)), findsNothing);
    expect(find.byType(SearchResultRow), findsWidgets);
    expect(_indicator(_result('Lait'), Icons.add), findsOneWidget);

    await _tap(tester, _result('Lait'));
    expect(_sheet, findsOneWidget);
    expect(await _activeLines(db, SeedIds.lait), hasLength(1));
    expect(_indicator(_result('Lait'), Icons.check), findsOneWidget);

    await _tap(tester, _result('Lait'));
    expect(await _activeLines(db, SeedIds.lait), isEmpty);
    expect(_indicator(_result('Lait'), Icons.add), findsOneWidget);
    expect(
      _inSheet(find.text(StringsFr.retireDeLaListe('Lait'))),
      findsOneWidget,
    );
    expect(_inSheet(_undoAction), findsOneWidget);

    // Effacer la recherche : les fréquents reviennent.
    await tester.tap(find.byTooltip(StringsFr.effacerLaRecherche));
    await tester.pumpAndSettle();
    expect(find.byType(FrequentRow), findsNWidgets(31));
    expect(find.byType(SearchResultRow), findsNothing);
    await _letSnackBarClose(tester);
  });

  testWidgets('TalkBack : fréquents et résultats lus comme boutons, avec '
      '« dans la liste »', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _pumpApp(tester);
    await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
    await tester.pumpAndSettle();
    await _openSheet(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Lait, dans la liste')),
      isSemantics(
        label: 'Lait, dans la liste',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Beurre$'))),
      isSemantics(label: 'Beurre', isButton: true, hasTapAction: true),
    );
    // En-tête du panneau : nom du rayon seul.
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Crèmerie$'))),
      isSemantics(label: 'Crèmerie', isHeader: true),
    );

    await tester.enterText(find.byType(TextField), 'lai');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Lait, Crèmerie, dans la liste'),
      ),
      isSemantics(
        label: 'Lait, Crèmerie, dans la liste',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('échec de l’ajout : snackbar d’erreur dans le panneau, + reste', (
    tester,
  ) async {
    final db = await _pumpApp(tester);
    await db.customStatement(
      'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
      "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
    );
    await _openSheet(tester);

    await _tap(tester, _frequent('Lait'));

    expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
    expect(_indicator(_frequent('Lait'), Icons.add), findsOneWidget);
    expect(await _activeLines(db, SeedIds.lait), isEmpty);
    await _letSnackBarClose(tester);
  });

  testWidgets('échec du retrait : snackbar d’erreur dans le panneau, Lait '
      'reste dans la liste', (tester) async {
    final db = await _pumpApp(tester);
    await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
    await db.customStatement(
      'CREATE TRIGGER no_remove BEFORE UPDATE OF deleted_at ON list_lines '
      "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
    );
    await tester.pumpAndSettle();
    await _openSheet(tester);

    await _tap(tester, _frequent('Lait'));

    expect(
      _inSheet(find.text(StringsFr.suppressionImpossible)),
      findsOneWidget,
    );
    expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);
    expect(await _activeLines(db, SeedIds.lait), hasLength(1));
    // Rien n'a été écrit : contributions toujours actives.
    final contributions = await db.select(db.listContributions).get();
    expect(contributions.every((c) => c.deletedAt == null), isTrue);
    await _letSnackBarClose(tester);
  });

  group('créer, quantité et rayon à l’ajout', () {
    testWidgets('« piles » absent : une seule ligne « Créer « piles » » ; '
        'la toucher crée Piles, dépliée sans Champ quantité, Divers entouré ; '
        'Entretien place la ligne et l’article', (tester) async {
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await _openSheet(tester);

      await _type(tester, 'piles');

      expect(_create, findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);
      expect(find.text('Créer «\u00A0piles\u00A0»'), findsOneWidget);
      expect(
        find.descendant(of: _create, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
      expect(tester.getSize(_create).height, greaterThanOrEqualTo(48));

      await _tap(tester, _create);

      final piles = (await _activeArticles(db, 'piles')).single;
      expect(piles.name, 'Piles');
      expect(piles.rayon, 'divers');
      expect(piles.unit, isNull);
      expect((await _activeLines(db, piles.id)).single.rayon, 'divers');
      // La saisie reste ; Piles apparaît comme résultat, déplié.
      expect(tester.widget<TextField>(_search).controller!.text, 'piles');
      expect(_create, findsNothing);
      expect(_indicator(_result('Piles'), Icons.check), findsOneWidget);
      expect(find.byType(AddedLineEditor), findsOneWidget);
      expect(_quantity, findsNothing);
      expect(
        tester.widget<RayonPicker>(find.byType(RayonPicker)).selected,
        Rayon.divers,
      );

      await _tap(tester, _pastille(Rayon.entretien));

      expect(
        tester.widget<RayonPicker>(find.byType(RayonPicker)).selected,
        Rayon.entretien,
      );
      expect((await _activeArticles(db, 'piles')).single.rayon, 'entretien');
      expect((await _activeLines(db, piles.id)).single.rayon, 'entretien');
      expect(
        find.descendant(
          of: _result('Piles'),
          matching: find.text(Rayon.entretien.label),
        ),
        findsOneWidget,
      );

      await _closeSheet(tester);
      final row = find.widgetWithText(ItemRow, 'Piles');
      expect(row, findsOneWidget);
      expect(
        tester.getTopLeft(row).dy,
        greaterThan(
          tester.getTopLeft(find.widgetWithText(RayonHeader, 'Entretien')).dy,
        ),
      );
    });

    testWidgets('« lait » puis « LAIT » : pas de « Créer » ; le résultat '
        'ajoute Lait sans créer d’article', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      final articlesBefore = await db.select(db.articles).get();

      await _type(tester, 'lait');
      expect(_create, findsNothing);
      await _type(tester, 'LAIT');
      expect(_create, findsNothing);

      await _tap(tester, _result('Lait'));

      expect(await _activeLines(db, SeedIds.lait), hasLength(1));
      expect(await db.select(db.articles).get(), articlesBefore);
      expect(_create, findsNothing);
    });

    testWidgets('« lai » : les résultats puis, en dernier, « Créer « lai » »', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openSheet(tester);

      await _type(tester, 'lai');

      expect(_create, findsOneWidget);
      expect(find.text('Créer «\u00A0lai\u00A0»'), findsOneWidget);
      final results = find.byType(SearchResultRow);
      expect(results, findsWidgets);
      final createTop = tester.getTopLeft(_create).dy;
      for (final element in results.evaluate()) {
        final box = element.renderObject! as RenderBox;
        expect(box.localToGlobal(Offset.zero).dy, lessThan(createTop));
      }
    });

    testWidgets('« zzz » : une seule ligne « Créer « zzz » »', (tester) async {
      await _pumpApp(tester);
      await _openSheet(tester);

      await _type(tester, 'zzz');

      expect(_create, findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);
      expect(find.text(StringsFr.creer('zzz')), findsOneWidget);
    });

    testWidgets('Œufs dans les fréquents : dépliée avec le Champ quantité '
        '(pièces, vide) et Crèmerie entouré ; 6 validé : « 6 pièces » dans la '
        'Liste, ligne non manuelle', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      expect(find.byType(AddedLineEditor), findsNothing);

      await _tap(tester, _frequent('Œufs'));

      final editor = find.byType(AddedLineEditor);
      expect(editor, findsOneWidget);
      // Sous la ligne d'Œufs.
      expect(
        tester.getTopLeft(editor).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(_frequent('Œufs')).dy),
      );
      final field = tester.widget<QuantityField>(_quantity);
      expect(field.unit, Unit.piece);
      expect(field.controller.text, isEmpty);
      expect(
        find.descendant(of: _quantity, matching: find.text('pièces')),
        findsOneWidget,
      );
      expect(
        tester.widget<RayonPicker>(find.byType(RayonPicker)).selected,
        Rayon.cremerie,
      );
      expect(tester.getSize(_quantity).height, greaterThanOrEqualTo(48));

      await tester.enterText(_quantity, '6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final line = (await _activeLines(db, SeedIds.oeufs)).single;
      expect(line.unit, 'piece');
      expect(line.manualAt, isNull);
      final contribution = (await db.select(db.listContributions).get()).single;
      expect(contribution.source, ContributionSource.ajout);
      expect(contribution.quantity, 6000);
      expect(contribution.unit, 'piece');

      await _closeSheet(tester);
      final row = find.widgetWithText(ItemRow, 'Œufs');
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text(formatQuantity(6000, Unit.piece)),
        ),
        findsOneWidget,
      );
      // Une seule écriture : la fermeture n'a rien réécrit.
      expect(
        (await db.select(db.listContributions).get()).single.updatedAt,
        contribution.updatedAt,
      );
    });

    testWidgets('ligne dépliée, autre ajout : la première se replie et sa '
        'quantité est écrite ; à la fermeture, la quantité en cours est '
        'écrite', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);

      await _tap(tester, _frequent('Œufs'));
      await tester.enterText(_quantity, '6');
      await tester.pump();

      await _tap(tester, _frequent('Lait'));

      final editor = find.byType(AddedLineEditor);
      expect(editor, findsOneWidget);
      expect(
        tester.getTopLeft(editor).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(_frequent('Lait')).dy),
      );
      expect(tester.widget<QuantityField>(_quantity).controller.text, isEmpty);
      final oeufs = (await _activeLines(db, SeedIds.oeufs)).single;
      expect(oeufs.unit, 'piece');

      await tester.enterText(_quantity, '2');
      await tester.pump();
      await _closeSheet(tester);

      final lait = (await _activeLines(db, SeedIds.lait)).single;
      expect(lait.unit, 'piece');
      expect(lait.manualAt, isNull);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(ItemRow, 'Lait'),
          matching: find.text(formatQuantity(2000, Unit.piece)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ItemRow, 'Œufs'),
          matching: find.text(formatQuantity(6000, Unit.piece)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quantité vidée : la ligne redevient sans quantité ; retirer '
        'l’article déplié replie sa ligne', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);

      await _tap(tester, _frequent('Œufs'));
      await tester.enterText(_quantity, '6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect((await _activeLines(db, SeedIds.oeufs)).single.unit, 'piece');

      await tester.enterText(_quantity, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final contribution = (await db.select(db.listContributions).get()).single;
      expect(contribution.quantity, isNull);
      expect(contribution.unit, isNull);
      expect((await _activeLines(db, SeedIds.oeufs)).single.unit, isNull);

      await _tap(tester, _frequent('Œufs'));
      expect(find.byType(AddedLineEditor), findsNothing);
      expect(await _activeLines(db, SeedIds.oeufs), isEmpty);
      await _letSnackBarClose(tester);
    });

    testWidgets('quantité saisie sans valider, retrait d’un autre article puis '
        'fermeture : Annuler sur la Liste remet Lait, Œufs lit « 6 pièces »', (
      tester,
    ) async {
      final db = await _pumpApp(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await _tap(tester, _frequent('Œufs'));
      await tester.enterText(_quantity, '6');
      await tester.pump();
      await _tap(tester, _frequent('Lait'));

      expect(await _activeLines(db, SeedIds.lait), isEmpty);
      expect(find.byType(AddedLineEditor), findsNothing);
      expect((await _activeLines(db, SeedIds.oeufs)).single.unit, 'piece');

      await _closeSheet(tester);
      expect(find.text(StringsFr.retireDeLaListe('Lait')), findsOneWidget);
      await _tap(tester, _undoAction);

      expect(await _activeLines(db, SeedIds.lait), hasLength(1));
      expect(find.widgetWithText(ItemRow, 'Lait'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ItemRow, 'Œufs'),
          matching: find.text(formatQuantity(6000, Unit.piece)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('article créé, retiré puis rajouté dans le panneau : le Choix '
        'de rayon change encore le rayon de l’article', (tester) async {
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await _openSheet(tester);

      await _type(tester, 'piles');
      await _tap(tester, _create);
      await _tap(tester, _result('Piles'));
      final piles = (await _activeArticles(db, 'piles')).single;
      expect(await _activeLines(db, piles.id), isEmpty);
      await _tap(tester, _result('Piles'));
      expect(find.byType(AddedLineEditor), findsOneWidget);

      await _tap(tester, _pastille(Rayon.entretien));

      expect((await _activeArticles(db, 'piles')).single.rayon, 'entretien');
      expect((await _activeLines(db, piles.id)).single.rayon, 'entretien');
      await _letSnackBarClose(tester);
    });

    testWidgets('rayon d’un article existant : seule la ligne change', (
      tester,
    ) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);

      await _tap(tester, _frequent('Lait'));
      await _tap(tester, _pastille(Rayon.epicerieSalee));

      expect(
        (await _activeLines(db, SeedIds.lait)).single.rayon,
        Rayon.epicerieSalee.code,
      );
      final lait = await (db.select(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lait))).getSingle();
      expect(lait.rayon, 'cremerie');
    });

    testWidgets('TalkBack : « Créer « piles » » bouton, Champ quantité lu '
        '« Quantité », pastilles lues par leur nom', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await _openSheet(tester);

      await _type(tester, 'piles');
      expect(
        tester.getSemantics(find.bySemanticsLabel(StringsFr.creer('piles'))),
        isSemantics(
          label: StringsFr.creer('piles'),
          isButton: true,
          hasTapAction: true,
        ),
      );

      await _tap(tester, find.byTooltip(StringsFr.effacerLaRecherche));
      await _tap(tester, _frequent('Œufs'));
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Quantité'))),
        matchesSemantics(
          label: StringsFr.quantite,
          isTextField: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(RayonPicker),
            matching: find.bySemanticsLabel('Fruits et légumes'),
          ),
        ),
        isSemantics(
          label: 'Fruits et légumes',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(RayonPicker),
            matching: find.bySemanticsLabel('Crèmerie'),
          ),
        ),
        isSemantics(label: 'Crèmerie', isButton: true, isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('échec de la création : snackbar d’erreur, rien n’est créé', (
      tester,
    ) async {
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await db.customStatement(
        'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      await _openSheet(tester);

      await _type(tester, 'piles');
      await _tap(tester, _create);

      expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
      expect(await _activeArticles(db, 'piles'), isEmpty);
      expect(_create, findsOneWidget);
      expect(find.byType(AddedLineEditor), findsNothing);
      await _letSnackBarClose(tester);
    });
  });
}
