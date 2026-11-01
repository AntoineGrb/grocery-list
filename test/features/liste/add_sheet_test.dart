import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/item_edit_sheet.dart';
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

/// Le titre « Ajouts fréquents » du panneau.
final _title = _inSheet(find.byType(FrequentsTitle));

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

/// Le Champ d'ajout du panneau (le premier champ : un Champ quantité peut
/// le suivre).
Finder get _search => _inSheet(find.byType(TextField)).first;

/// La Feuille d'édition, empilée sur le panneau.
final _editSheet = find.byType(ItemEditSheet);
Finder _inEditSheet(Finder finder) =>
    find.descendant(of: _editSheet, matching: finder);

/// Le crayon de la ligne [row].
Finder _pencil(Finder row) =>
    find.descendant(of: row, matching: find.byIcon(Icons.edit_outlined));

/// Ouvre la Feuille d'édition par le crayon de [row].
Future<void> _tapPencil(WidgetTester tester, Finder row) async {
  await tester.tap(_pencil(row));
  await tester.pumpAndSettle();
}

/// Ferme la Feuille d'édition par un tap sur sa barrière : le panneau
/// reste ouvert dessous.
Future<void> _closeEditSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(20, 20));
  await tester.pumpAndSettle();
}

/// La ligne « Ajouter « … » ».
final _addTyped = find.byType(AddTypedRow);

/// La Ligne d'article de [name] dans la Liste.
Finder _listRow(String name) => find.widgetWithText(ItemRow, name);

/// Entrée dans le Champ d'ajout.
Future<void> _enter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Texte du Champ d'ajout.
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_search).controller!.text;

/// Le Champ d'ajout a le focus (clavier ouvert).
bool _fieldFocused(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(of: _search, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

/// La pastille [rayon] du Choix de rayon de la Feuille d'édition.
Finder _pastille(Rayon rayon) => find.descendant(
  of: _inEditSheet(find.byType(RayonPicker)),
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
    'Panneau + ouvert : champ focalisé, « Ajouts fréquents » et son crayon, '
    'puis les fréquents en liste plate dans l’ordre du parcours, sans '
    'en-tête ni libellé de rayon, avec Picto, nom et +',
    (tester) async {
      await _pumpApp(tester);
      await _openSheet(tester);

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);

      // Titre « Ajouts fréquents » en title-small on-surface-variant, crayon
      // à droite, cible de 48 dp.
      expect(_title, findsOneWidget);
      final titleText = find.descendant(
        of: _title,
        matching: find.text(StringsFr.ajoutsFrequents),
      );
      expect(titleText, findsOneWidget);
      final theme = Theme.of(tester.element(_title));
      final style = tester.widget<Text>(titleText).style!;
      expect(style.fontSize, theme.textTheme.titleSmall!.fontSize);
      expect(style.fontWeight, theme.textTheme.titleSmall!.fontWeight);
      expect(style.color, theme.colorScheme.onSurfaceVariant);
      final pencil = _pencil(_title);
      expect(pencil, findsOneWidget);
      expect(
        tester.widget<Icon>(pencil).color,
        theme.colorScheme.onSurfaceVariant,
      );
      final pencilButton = find.descendant(
        of: _title,
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(pencilButton).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(pencilButton).height, greaterThanOrEqualTo(48));
      expect(
        tester.getCenter(pencilButton).dx,
        greaterThan(tester.getCenter(titleText).dx),
      );

      // Aucun En-tête ni libellé de rayon.
      expect(_inSheet(find.byType(RayonHeader)), findsNothing);
      for (final rayon in Rayon.values) {
        expect(_inSheet(find.text(rayon.label)), findsNothing);
      }

      // Liste plate : rayons dans l'ordre du parcours (par défaut, celui des
      // 13 rayons), puis `position` dans un rayon.
      final rows = tester.widgetList<FrequentRow>(find.byType(FrequentRow));
      final routeIndexes = [
        for (final row in rows) Rayon.values.indexOf(row.article.rayon),
      ];
      expect(routeIndexes, [...routeIndexes]..sort());
      expect(
        tester.getTopLeft(_title).dy,
        lessThan(tester.getTopLeft(_frequent('Tomates')).dy),
      );
      expect(
        tester.getTopLeft(_frequent('Tomates')).dy,
        lessThan(tester.getTopLeft(_frequent('Lait')).dy),
      );
      // Lait avant Œufs (position).
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

  testWidgets('parcours avec Crèmerie avant Fruits & légumes : Lait avant '
      'Tomates', (tester) async {
    final db = await _pumpApp(tester);
    await db
        .update(db.settings)
        .write(
          SettingsCompanion(
            routeOrder: Value(
              SettingsRepository.encodeRouteOrder([
                Rayon.cremerie,
                ...Rayon.values.where((r) => r != Rayon.cremerie),
              ]),
            ),
          ),
        );
    await tester.pumpAndSettle();
    await _openSheet(tester);

    expect(
      tester.getTopLeft(_frequent('Lait')).dy,
      lessThan(tester.getTopLeft(_frequent('Tomates')).dy),
    );
    expect(_inSheet(find.byType(RayonHeader)), findsNothing);
  });

  testWidgets('crayon du titre : rien ne se passe, le panneau reste ouvert', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSheet(tester);

    await _tapPencil(tester, _title);

    expect(_sheet, findsOneWidget);
    expect(_editSheet, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(_title, findsOneWidget);
    expect(find.byType(FrequentRow), findsNWidgets(31));
  });

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
    expect(_title, findsNothing);
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
    // En-tête sans compteur.
    expect(
      find.descendant(of: find.byType(RayonHeader), matching: find.text('1')),
      findsNothing,
    );
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
    expect(_title, findsNothing);
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
    await tester.tap(find.byTooltip(StringsFr.effacerLeTexte));
    await tester.pumpAndSettle();
    expect(find.byType(FrequentRow), findsNWidgets(31));
    expect(_title, findsOneWidget);
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
    // Titre des fréquents lu comme titre ; son crayon, comme un bouton.
    expect(
      tester.getSemantics(find.bySemanticsLabel(StringsFr.ajoutsFrequents)),
      isSemantics(label: StringsFr.ajoutsFrequents, isHeader: true),
    );
    expect(
      tester.getSemantics(
        find.descendant(of: _title, matching: find.byType(IconButton)),
      ),
      isSemantics(
        tooltip: StringsFr.modifierLesAjoutsFrequents,
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    // Aucun rayon lu dans le panneau (la Liste dessous a son En-tête).
    expect(
      _inSheet(find.bySemanticsLabel(RegExp(r'^Crèmerie$'))),
      findsNothing,
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

  group('Entrée', () {
    testWidgets(
      '« piles » + Entrée : Piles hors catalogue sous Divers ; champ '
      'vidé, clavier ouvert, aucune Ligne saisie ; « pil » ne le montre pas',
      (tester) async {
        final db = await _pumpApp(tester);
        await _withoutPiles(tester, db);
        await _openSheet(tester);

        final field = tester.widget<TextField>(_search);
        expect(field.decoration!.hintText, StringsFr.ajouterUnArticle);
        expect(field.textInputAction, TextInputAction.done);
        expect(
          find.descendant(of: _search, matching: find.byIcon(Icons.add)),
          findsOneWidget,
        );

        await _type(tester, 'piles');
        await _enter(tester);

        final piles = (await _activeArticles(db, 'piles')).single;
        expect(piles.name, 'Piles');
        expect(piles.rayon, 'divers');
        expect(piles.unit, isNull);
        expect(piles.inCatalogue, isFalse);
        expect((await _activeLines(db, piles.id)).single.rayon, 'divers');

        expect(_fieldText(tester), isEmpty);
        expect(_fieldFocused(tester), isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        // Piles n'apparaît que dans la Liste, rien sous le champ.
        expect(_inSheet(find.text('Piles')), findsNothing);
        expect(_listRow('Piles'), findsOneWidget);
        // Rien ne se déplie après Entrée ; les fréquents reviennent.
        expect(_inSheet(find.byType(QuantityField)), findsNothing);
        expect(_inSheet(find.byType(RayonPicker)), findsNothing);
        expect(_frequent('Lait'), findsOneWidget);

        await _type(tester, 'pil');
        expect(find.byType(SearchResultRow), findsNothing);
        expect(_addTyped, findsOneWidget);

        await _closeSheet(tester);
        final row = find.widgetWithText(ItemRow, 'Piles');
        expect(row, findsOneWidget);
        expect(
          tester.getTopLeft(row).dy,
          greaterThan(
            tester.getTopLeft(find.widgetWithText(RayonHeader, 'Divers')).dy,
          ),
        );
      },
    );

    testWidgets('« LAIT » + Entrée : le Lait du catalogue sous Crèmerie, aucun '
        'article créé', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      final articlesBefore = await db.select(db.articles).get();

      await _type(tester, 'LAIT');
      expect(_addTyped, findsNothing);
      await _enter(tester);

      expect(await db.select(db.articles).get(), articlesBefore);
      expect(
        (await _activeLines(db, SeedIds.lait)).single.rayon,
        Rayon.cremerie.code,
      );
      expect(_listRow('Lait'), findsOneWidget);
    });

    testWidgets('déjà dans la liste : Entrée ne change rien, champ vidé', (
      tester,
    ) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      await _tap(tester, _frequent('Lait'));
      final lines = await db.select(db.listLines).get();
      final contributions = await db.select(db.listContributions).get();

      await _type(tester, 'lait');
      await _enter(tester);

      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.listContributions).get(), contributions);
      expect(_fieldText(tester), isEmpty);
      expect(_listRow('Lait'), findsOneWidget);
      expect(_inSheet(_undoAction), findsNothing);
    });

    testWidgets('texte vide ou espaces + Entrée : rien', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);

      await _enter(tester);
      await _type(tester, '   ');
      await _enter(tester);

      expect(await db.select(db.listLines).get(), isEmpty);
      expect(_fieldFocused(tester), isTrue);
    });

    testWidgets('« lai » : des résultats, pas de « Ajouter « … » »', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openSheet(tester);

      await _type(tester, 'lai');

      expect(find.byType(SearchResultRow), findsWidgets);
      expect(_addTyped, findsNothing);
    });

    testWidgets('« zzz » sans résultat : une seule ligne « Ajouter « zzz » » ; '
        'la toucher fait comme Entrée', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);

      await _type(tester, 'zzz');

      expect(_addTyped, findsOneWidget);
      expect(find.byType(SearchResultRow), findsNothing);
      expect(find.text(StringsFr.ajouterNom('zzz')), findsOneWidget);
      expect(find.text('Ajouter « zzz »'), findsOneWidget);
      expect(
        find.descendant(of: _addTyped, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
      expect(tester.getSize(_addTyped).height, greaterThanOrEqualTo(48));

      await _tap(tester, _addTyped);

      final zzz = (await _activeArticles(db, 'zzz')).single;
      expect(zzz.inCatalogue, isFalse);
      expect(await _activeLines(db, zzz.id), hasLength(1));
      expect(_fieldText(tester), isEmpty);
      expect(_listRow('Zzz'), findsOneWidget);
    });

    testWidgets('texte libre réutilisé : Piles retiré puis retapé, même '
        'article', (tester) async {
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await _openSheet(tester);

      await _type(tester, 'piles');
      await _enter(tester);
      final piles = (await _activeArticles(db, 'piles')).single;
      await ListeRepository(db, Clock()).removeArticle(piles.id);
      await tester.pumpAndSettle();

      await _type(tester, 'Piles');
      await _enter(tester);

      expect((await _activeArticles(db, 'piles')).single.id, piles.id);
      expect(await _activeLines(db, piles.id), hasLength(1));
    });

    testWidgets('TalkBack : le champ lu « Ajouter un article », « Ajouter '
        '« piles » » bouton', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await _openSheet(tester);

      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: StringsFr.ajouterUnArticle,
          isTextField: true,
          isFocused: true,
        ),
      );

      await _type(tester, 'piles');
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(StringsFr.ajouterNom('piles')),
        ),
        isSemantics(
          label: StringsFr.ajouterNom('piles'),
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('échec d’Entrée : snackbar d’erreur, rien n’est écrit, la '
        'saisie reste', (tester) async {
      final db = await _pumpApp(tester);
      await _withoutPiles(tester, db);
      await db.customStatement(
        'CREATE TRIGGER no_add BEFORE INSERT ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      await _openSheet(tester);

      await _type(tester, 'piles');
      await _enter(tester);

      expect(_inSheet(find.text(StringsFr.ajoutImpossible)), findsOneWidget);
      expect(await _activeArticles(db, 'piles'), isEmpty);
      expect(_fieldText(tester), 'piles');
      expect(_listRow('Piles'), findsNothing);
      await _letSnackBarClose(tester);
    });
  });

  group('crayon et Feuille d’édition (R14, AD-13)', () {
    testWidgets('tap sur Lait : le + devient une coche et un crayon apparaît '
        'à sa gauche, rien ne se déplie ; hors liste, pas de crayon', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openSheet(tester);
      expect(_pencil(_frequent('Lait')), findsNothing);

      await _tap(tester, _frequent('Lait'));

      final pencil = _pencil(_frequent('Lait'));
      expect(pencil, findsOneWidget);
      expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);
      expect(_pencil(_frequent('Beurre')), findsNothing);
      expect(
        tester.getCenter(pencil).dx,
        lessThan(
          tester.getCenter(_indicator(_frequent('Lait'), Icons.check)).dx,
        ),
      );
      final button = find.ancestor(
        of: pencil,
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(
        tester.widget<Icon>(pencil).color,
        Theme.of(tester.element(pencil)).colorScheme.onSurfaceVariant,
      );
      expect(find.byTooltip(StringsFr.modifierNom('Lait')), findsOneWidget);
      // La ligne garde la hauteur d'une ligne sans crayon.
      expect(
        tester.getSize(_frequent('Lait')).height,
        tester.getSize(_frequent('Beurre')).height,
      );
      // Rien ne se déplie, aucune feuille ne s'ouvre.
      expect(_inSheet(find.byType(QuantityField)), findsNothing);
      expect(_inSheet(find.byType(RayonPicker)), findsNothing);
      expect(_editSheet, findsNothing);
    });

    testWidgets('crayon de Lait : feuille empilée sur le panneau ; quantité '
        'changée puis feuille fermée : le panneau est toujours ouvert, la '
        'Liste montre la nouvelle quantité', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      await _tap(tester, _frequent('Lait'));

      await _tapPencil(tester, _frequent('Lait'));

      expect(_editSheet, findsOneWidget);
      expect(_sheet, findsOneWidget);
      expect(_inEditSheet(find.text('Lait')), findsOneWidget);
      // Lait est en pièces : la puce pièce est préchoisie.
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey(InputUnit.piece)))
            .selected,
        isTrue,
      );
      await tester.enterText(_inEditSheet(find.byType(TextField)), '2');
      await _closeEditSheet(tester);

      expect(_editSheet, findsNothing);
      expect(_sheet, findsOneWidget);
      expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);
      final line = (await _activeLines(db, SeedIds.lait)).single;
      expect(line.unit, 'piece');
      expect(line.manualAt, isNotNull);

      await _closeSheet(tester);
      expect(
        find.descendant(
          of: find.widgetWithText(ItemRow, 'Lait'),
          matching: find.text(formatQuantity(2000, Unit.piece)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rayon depuis le panneau : crayon de Lait, Épicerie salée → '
        'la ligne change de groupe, l’article garde son rayon', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      await _tap(tester, _frequent('Lait'));
      await _tapPencil(tester, _frequent('Lait'));

      await _tap(tester, _pastille(Rayon.epicerieSalee));
      // La feuille reste ouverte.
      expect(_editSheet, findsOneWidget);
      await _closeEditSheet(tester);

      expect(
        (await _activeLines(db, SeedIds.lait)).single.rayon,
        Rayon.epicerieSalee.code,
      );
      final lait = await (db.select(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lait))).getSingle();
      expect(lait.rayon, 'cremerie');
      await _closeSheet(tester);
      expect(
        tester.getTopLeft(find.widgetWithText(ItemRow, 'Lait')).dy,
        greaterThan(
          tester
              .getTopLeft(find.widgetWithText(RayonHeader, 'Épicerie salée'))
              .dy,
        ),
      );
      expect(find.widgetWithText(RayonHeader, 'Crèmerie'), findsNothing);
    });

    testWidgets('« Supprimer » depuis le panneau : ligne retirée, snackbar '
        'Annuler dans le panneau ; Annuler la remet', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      await _tap(tester, _frequent('Lait'));
      await _tapPencil(tester, _frequent('Lait'));

      await _tap(tester, _inEditSheet(find.text(StringsFr.supprimer)));

      expect(_editSheet, findsNothing);
      expect(_sheet, findsOneWidget);
      expect(await _activeLines(db, SeedIds.lait), isEmpty);
      expect(_indicator(_frequent('Lait'), Icons.add), findsOneWidget);
      expect(_pencil(_frequent('Lait')), findsNothing);
      expect(
        _inSheet(find.text(StringsFr.retireDeLaListe('Lait'))),
        findsOneWidget,
      );

      await _tap(tester, _inSheet(_undoAction));

      expect(await _activeLines(db, SeedIds.lait), hasLength(1));
      expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);
    });

    testWidgets('« Supprimer » depuis le panneau puis panneau fermé : '
        'l’Annuler passe sur la Liste', (tester) async {
      final db = await _pumpApp(tester);
      await _openSheet(tester);
      await _tap(tester, _frequent('Lait'));
      await _tapPencil(tester, _frequent('Lait'));
      await _tap(tester, _inEditSheet(find.text(StringsFr.supprimer)));
      await _closeSheet(tester);

      expect(find.text(StringsFr.retireDeLaListe('Lait')), findsOneWidget);
      await _tap(tester, _undoAction);
      expect(await _activeLines(db, SeedIds.lait), hasLength(1));
      expect(find.widgetWithText(ItemRow, 'Lait'), findsOneWidget);
    });

    testWidgets('échec de « Supprimer » : snackbar d’erreur dans le panneau, '
        'Lait reste', (tester) async {
      final db = await _pumpApp(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await db.customStatement(
        'CREATE TRIGGER no_remove BEFORE UPDATE OF deleted_at ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);
      await _tapPencil(tester, _frequent('Lait'));

      await _tap(tester, _inEditSheet(find.text(StringsFr.supprimer)));

      expect(
        _inSheet(find.text(StringsFr.suppressionImpossible)),
        findsOneWidget,
      );
      expect(await _activeLines(db, SeedIds.lait), hasLength(1));
      expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);
      await _letSnackBarClose(tester);
    });

    testWidgets('échec d’une modification : snackbar d’erreur dans le '
        'messager du panneau', (tester) async {
      final db = await _pumpApp(tester);
      await ListeRepository(db, Clock()).addArticle(SeedIds.lait);
      await db.customStatement(
        'CREATE TRIGGER no_rayon BEFORE UPDATE OF rayon ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      await tester.pumpAndSettle();
      await _openSheet(tester);
      await _tapPencil(tester, _frequent('Lait'));

      await _tap(tester, _pastille(Rayon.epicerieSalee));

      expect(
        _inSheet(find.text(StringsFr.modificationImpossible)),
        findsOneWidget,
      );
      await _closeEditSheet(tester);
      expect(
        (await _activeLines(db, SeedIds.lait)).single.rayon,
        Rayon.cremerie.code,
      );
      await _letSnackBarClose(tester);
    });

    testWidgets('article sur deux lignes : la feuille ouvre la plus ancienne '
        'ligne non cochée', (tester) async {
      final db = await _pumpApp(tester);
      final repo = ListeRepository(db, Clock());
      await repo.addArticle(SeedIds.lait, quantity: 500, unit: Unit.ml);
      await repo.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
      await tester.pumpAndSettle();
      await _openSheet(tester);

      await _tapPencil(tester, _frequent('Lait'));

      expect(
        tester
            .widget<TextField>(_inEditSheet(find.byType(TextField)))
            .controller!
            .text,
        '500',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey(InputUnit.ml)))
            .selected,
        isTrue,
      );
    });

    testWidgets('résultat dans la liste : crayon qui ouvre la feuille ; hors '
        'liste, pas de crayon', (tester) async {
      await _pumpApp(tester);
      await _openSheet(tester);

      await _type(tester, 'lai');
      expect(_pencil(_result('Lait')), findsNothing);
      await _tap(tester, _result('Lait'));
      expect(_pencil(_result('Lait')), findsOneWidget);

      await _tapPencil(tester, _result('Lait'));

      expect(_inEditSheet(find.text('Lait')), findsOneWidget);
      await _closeEditSheet(tester);
      expect(_sheet, findsOneWidget);
    });

    testWidgets('TalkBack : la ligne reste lue « Lait, dans la liste », le '
        'crayon est un bouton à part lu « Modifier Lait »', (tester) async {
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
      final pencil = find.descendant(
        of: _frequent('Lait'),
        matching: find.byType(IconButton),
      );
      expect(
        tester.getSemantics(pencil),
        isSemantics(
          tooltip: StringsFr.modifierNom('Lait'),
          isButton: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(
        find.semantics.byPredicate(
          (node) => node.tooltip == StringsFr.modifierNom('Lait'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_editSheet, findsOneWidget);
      handle.dispose();
    });
  });
}
