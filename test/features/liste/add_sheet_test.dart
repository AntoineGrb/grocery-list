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
import 'package:kadi/features/reglages/ui/frequents_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/panneau.dart';
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
Finder _frequent(String name) => find.widgetWithText(FrequentChip, name);

/// La Ligne de résultat de [name].
Finder _result(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SearchResultRow));

/// L'indicateur [icon] (coche ou +) de la ligne [row].
Finder _indicator(Finder row, IconData icon) =>
    find.descendant(of: row, matching: find.byIcon(icon));

/// Ouvre le Panneau +, fréquents affichés (⚡).
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await showFrequents(tester);
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

/// La Feuille d'édition : jamais ouverte depuis le panneau.
final _editSheet = find.byType(ItemEditSheet);

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
  // Écran très haut : tous les fréquents tiennent dans le panneau.
  setUp(() => addPanelFrequentRows = 40);
  tearDown(() => addPanelFrequentRows = 4.5);

  testWidgets('Panneau + au repos : champ focalisé, tags Quantité, Rayon et '
      '⚡ Fréquents, rien d’autre ; ⚡ ferme le clavier et montre « Ajouts '
      'fréquents », Gérer et les 31 pastilles dans l’ordre du parcours ; '
      'retaper dans le champ rouvre le clavier', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(_inSheet(find.text(StringsFr.quantite)), findsOneWidget);
    expect(_inSheet(find.text(Rayon.divers.label)), findsOneWidget);
    expect(_inSheet(find.text(StringsFr.frequents)), findsOneWidget);
    expect(_title, findsNothing);
    expect(find.byType(FrequentChip), findsNothing);

    await showFrequents(tester);
    expect(editable.focusNode.hasFocus, isFalse);
    expect(_title, findsOneWidget);
    final manage = find.descendant(
      of: _title,
      matching: find.widgetWithText(TextButton, StringsFr.gerer),
    );
    expect(manage, findsOneWidget);
    expect(tester.getSize(manage).height, greaterThanOrEqualTo(48));
    // ⚡ actif à l'encre, jamais d'argile (C6).
    final scheme = Theme.of(tester.element(_sheet)).colorScheme;
    expect(
      tester
          .widgetList<Material>(
            find.ancestor(
              of: _inSheet(find.text(StringsFr.frequents)),
              matching: find.byType(Material),
            ),
          )
          .first
          .color,
      scheme.onSurface,
    );

    // Rayons dans l'ordre du parcours (par défaut), puis `position`.
    final rows = tester.widgetList<FrequentChip>(find.byType(FrequentChip));
    final routeIndexes = [
      for (final row in rows) Rayon.values.indexOf(row.article.rayon),
    ];
    expect(routeIndexes, [...routeIndexes]..sort());
    expect(find.byType(FrequentChip), findsNWidgets(31));
    final lait = _frequent('Lait');
    expect(_indicator(lait, Icons.add), findsOneWidget);
    expect(tester.getSize(lait).height, greaterThanOrEqualTo(48));

    await tester.tap(_search);
    await tester.pumpAndSettle();
    expect(_title, findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('pastilles de fréquent : picto Phosphor teinté de son rayon, '
      'jamais un rond neutre', (tester) async {
    await _pumpApp(tester);
    await _openSheet(tester);

    final colors = KadiColors.of(tester.element(_sheet));
    final rows = find.byType(FrequentChip);
    expect(rows, findsNWidgets(31));
    for (final row in tester.widgetList<FrequentChip>(rows)) {
      final article = row.article;
      final icon = tester.widget<Icon>(
        find
            .descendant(of: find.byWidget(row), matching: find.byType(Icon))
            .first,
      );
      expect(
        icon.icon,
        PictoResolver.iconFor(article.pictoKey, article.rayon),
        reason: article.name,
      );
      expect(icon.color, colors.rayon(article.rayon).accent);
    }
    // Lait : jar, correction d'Antoine.
    final lait = tester.widget<Icon>(
      find.descendant(of: _frequent('Lait'), matching: find.byType(Icon)).first,
    );
    expect(lait.icon, PictoResolver.iconFor('jar', Rayon.cremerie));
  });

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

  testWidgets('bouton Gérer : le panneau se ferme et Paramètres › Fréquents '
      's’ouvre ; au retour, la Liste, panneau fermé', (tester) async {
    await _pumpApp(tester);
    await _openSheet(tester);

    await tester.tap(find.widgetWithText(TextButton, StringsFr.gerer));
    await tester.pumpAndSettle();

    expect(_sheet, findsNothing);
    expect(_editSheet, findsNothing);
    expect(find.byType(FrequentsScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(FrequentsScreen), findsNothing);
    expect(_sheet, findsNothing);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
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
    expect(find.byType(FrequentChip), findsNothing);
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
    // Pastille passée à l'encre (C6).
    expect(
      tester
          .widget<Material>(
            find.descendant(
              of: _frequent('Lait'),
              matching: find.byType(Material),
            ),
          )
          .color,
      Theme.of(tester.element(check)).colorScheme.onSurface,
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
    // En-tête avec le nombre d'articles restants (V2).
    expect(
      find.descendant(
        of: find.widgetWithText(RayonHeader, 'Crèmerie'),
        matching: find.text('1'),
      ),
      findsOneWidget,
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
      'résultats, sans rayon écrit ; le résultat Lait ajoute et vide le '
      'champ, puis retire', (tester) async {
    final db = await _pumpApp(tester);
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'lai');
    await tester.pumpAndSettle();

    expect(find.byType(FrequentChip), findsNothing);
    expect(_title, findsNothing);
    expect(_inSheet(find.byType(RayonHeader)), findsNothing);
    expect(find.byType(SearchResultRow), findsWidgets);
    expect(_indicator(_result('Lait'), Icons.add), findsOneWidget);
    // V2 : le rayon sous le nom, comme dans l'ajout d'ingrédient.
    expect(
      find.descendant(
        of: _result('Lait'),
        matching: find.text(Rayon.cremerie.label),
      ),
      findsOneWidget,
    );

    // Ajouté : le champ se vide ; taper a ramené le clavier, les fréquents
    // reviennent par ⚡ (V2 2g).
    await _tap(tester, _result('Lait'));
    expect(_sheet, findsOneWidget);
    expect(await _activeLines(db, SeedIds.lait), hasLength(1));
    expect(tester.widget<TextField>(_search).controller!.text, isEmpty);
    expect(find.byType(SearchResultRow), findsNothing);
    expect(find.byType(FrequentChip), findsNothing);
    await showFrequents(tester);
    expect(_indicator(_frequent('Lait'), Icons.check), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'lai');
    await tester.pumpAndSettle();
    expect(_indicator(_result('Lait'), Icons.check), findsOneWidget);
    await _tap(tester, _result('Lait'));
    expect(await _activeLines(db, SeedIds.lait), isEmpty);
    expect(_indicator(_result('Lait'), Icons.add), findsOneWidget);
    expect(
      _inSheet(find.text(StringsFr.retireDeLaListe('Lait'))),
      findsOneWidget,
    );
    expect(_inSheet(_undoAction), findsOneWidget);

    // Effacer la recherche : plus de résultats ; les fréquents reviennent
    // par ⚡ (V2 2g).
    await tester.tap(find.byTooltip(StringsFr.effacerLeTexte));
    await tester.pumpAndSettle();
    expect(find.byType(SearchResultRow), findsNothing);
    // Le snackbar fermé ne couvre plus le tag ⚡.
    await _letSnackBarClose(tester);
    await showFrequents(tester);
    expect(find.byType(FrequentChip), findsNWidgets(31));
    expect(_title, findsOneWidget);
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
    // Titre des fréquents lu comme titre ; « Gérer », comme un bouton.
    expect(
      tester.getSemantics(find.bySemanticsLabel(StringsFr.ajoutsFrequents)),
      isSemantics(label: StringsFr.ajoutsFrequents, isHeader: true),
    );
    expect(
      tester.getSemantics(
        find.descendant(of: _title, matching: find.byType(TextButton)),
      ),
      isSemantics(
        label: StringsFr.gererLesAjoutsFrequents,
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
        // Sans icône : le texte posé sur la carte.
        expect(
          find.descendant(of: _search, matching: find.byIcon(Icons.add)),
          findsNothing,
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
        // Rien ne se déplie après Entrée ; le clavier reste (V2 2f).
        expect(_inSheet(find.byType(QuantityField)), findsNothing);
        expect(_inSheet(find.byType(RayonPicker)), findsNothing);
        expect(_frequent('Lait'), findsNothing);

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
      // Retaper dans le champ : clavier rouvert.
      await tester.tap(_search);
      await tester.pumpAndSettle();

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
}
