import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:kadi/features/liste/ui/item_edit_sheet.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

/// Monte Kadi sur une base en mémoire ; l'app s'ouvre sur la Liste.
Future<AppDatabase> _pumpApp(WidgetTester tester, {_SpyUndo? undo}) => pumpKadi(
  tester,
  overrides: [
    if (undo != null)
      undoProvider.overrideWith((ref) {
        undo.attach(ref.watch(databaseProvider), ref.watch(clockProvider));
        return undo;
      }),
  ],
);

/// La quantité [quantity] affichée dans une Ligne d'article de [name].
Finder _rowWith(String name, String quantity) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ItemRow)),
  matching: find.text(quantity),
);

/// La Ligne d'article de [name], hors ou dans la Section Cochés.
Finder _row(String name, {bool inSection = false}) {
  final rows = find.ancestor(
    of: find.text(name),
    matching: find.byType(ItemRow),
  );
  final section = find.descendant(
    of: find.byType(CheckedSection),
    matching: rows,
  );
  if (inSection) return section;
  return find.byElementPredicate(
    (e) => rows.evaluate().contains(e) && !section.evaluate().contains(e),
  );
}

/// La case de la Ligne d'article de [name].
Finder _box(String name, {bool inSection = false}) => find.descendant(
  of: _row(name, inSection: inSection),
  matching: find.byType(Checkbox),
);

/// Touche la case de [name] et laisse passer l'animation et l'écriture.
Future<void> _tapBox(
  WidgetTester tester,
  String name, {
  bool inSection = false,
}) async {
  await tester.tap(_box(name, inSection: inSection));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

/// Service Annuler qui garde la dernière entrée enregistrée.
class _SpyUndo implements Undo {
  late Undo _undo;
  UndoEntry? last;

  void attach(AppDatabase db, Clock clock) => _undo = Undo(db, clock);

  @override
  UndoEntry record(List<UndoRow> rows) => last = _undo.record(rows);

  @override
  bool canUndo(UndoEntry entry) => _undo.canUndo(entry);

  @override
  Future<bool> undo(UndoEntry entry) => _undo.undo(entry);

  @override
  void clear([UndoEntry? entry]) => _undo.clear(entry);
}

/// Monte Kadi avec Tomates 500 g et Courgettes dans la liste.
Future<AppDatabase> _pumpWithTomatesCourgettes(
  WidgetTester tester, {
  _SpyUndo? undo,
}) async {
  final db = await _pumpApp(tester, undo: undo);
  final repo = ListeRepository(db, Clock());
  await repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g);
  await repo.addArticle(SeedIds.courgettes);
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets('quantités : 500 g fusionnés, 2 pièces sur une seconde ligne, '
      '1,5 kg de riz', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await _pumpApp(tester);
    final repo = ListeRepository(db, Clock());

    await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
    await repo.addArticle(SeedIds.tomates, quantity: 200, unit: Unit.g);
    await tester.pumpAndSettle();

    expect(find.text('Tomates'), findsOneWidget);
    expect(_rowWith('Tomates', '500 g'), findsOneWidget);
    expect(
      find.widgetWithText(RayonHeader, 'Fruits & légumes'),
      findsOneWidget,
    );
    // En-tête de rayon sans compteur, lu comme titre par son seul nom.
    expect(
      find.descendant(of: find.byType(RayonHeader), matching: find.text('1')),
      findsNothing,
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^Fruits et légumes$')),
      ),
      isSemantics(label: 'Fruits et légumes', isHeader: true),
    );
    expect(
      find.bySemanticsLabel('Tomates, 500 g, Fruits et légumes'),
      findsOneWidget,
    );

    await repo.addArticle(SeedIds.tomates, quantity: 2000, unit: Unit.piece);
    await tester.pumpAndSettle();

    expect(find.text('Tomates'), findsNWidgets(2));
    expect(find.text('500 g'), findsOneWidget);
    expect(find.text('2 pièces'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(RayonHeader), matching: find.text('2')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Fruits et légumes$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Tomates, 2 pièces, Fruits et légumes'),
      findsOneWidget,
    );

    await repo.addArticle(SeedIds.riz, quantity: 1500, unit: Unit.g);
    await tester.pumpAndSettle();

    expect(_rowWith('Riz', '1,5 kg'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Riz, 1,5 kg, Épicerie salée'),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('cocher au magasin', () {
    testWidgets('cocher Tomates et Courgettes : le rayon disparaît, '
        '« Cochés (2) » repliée, sans message de liste vide', (tester) async {
      await _pumpWithTomatesCourgettes(tester);
      expect(find.text('Fruits & légumes'), findsOneWidget);
      expect(find.byType(CheckedSection), findsNothing);
      expect(
        tester.widget<Checkbox>(_box('Tomates')).shape,
        isA<CircleBorder>(),
      );

      await _tapBox(tester, 'Tomates');
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      await _tapBox(tester, 'Courgettes');

      expect(find.byType(RayonHeader), findsNothing);
      expect(find.text('Fruits & légumes'), findsNothing);
      expect(find.text(StringsFr.cochesTitre(2)), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('Afficher'), findsNothing);
      expect(find.byType(ItemRow), findsNothing);
      expect(find.text(StringsFr.listeVide), findsNothing);
    });

    testWidgets('déplier : lignes barrées, case pleine, chevron ouvert ; '
        'décocher Tomates la renvoie dans son rayon', (tester) async {
      await _pumpWithTomatesCourgettes(tester);
      await _tapBox(tester, 'Tomates');
      await _tapBox(tester, 'Courgettes');

      await tester.tap(find.text(StringsFr.cochesTitre(2)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('Replier'), findsNothing);
      for (final name in ['Tomates', 'Courgettes']) {
        expect(_row(name, inSection: true), findsOneWidget);
        expect(
          tester.widget<Checkbox>(_box(name, inSection: true)).value,
          isTrue,
        );
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byType(CheckedSection),
            matching: find.text(name),
          ),
        );
        expect(text.style?.decoration, TextDecoration.lineThrough);
      }
      final quantity = tester.widget<Text>(
        find.descendant(
          of: find.byType(CheckedSection),
          matching: find.text('500 g'),
        ),
      );
      expect(quantity.style?.decoration, TextDecoration.lineThrough);

      final handle = tester.ensureSemantics();
      await _tapBox(tester, 'Tomates', inSection: true);

      expect(_row('Tomates'), findsOneWidget);
      expect(_row('Tomates', inSection: true), findsNothing);
      expect(tester.widget<Checkbox>(_box('Tomates')).value, isFalse);
      expect(find.text('Fruits & légumes'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Fruits et légumes$')),
        findsOneWidget,
      );
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      // La section reste dépliée.
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(_row('Courgettes', inSection: true), findsOneWidget);
      handle.dispose();
    });

    testWidgets('TalkBack : ligne non cochée, activation qui coche, '
        'annonce, en-tête « Cochés, 2 articles, replié »', (tester) async {
      final handle = tester.ensureSemantics();
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<dynamic, dynamic>;
            if (map['type'] == 'announce') {
              announcements.add((map['data'] as Map)['message'] as String);
            }
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await _pumpWithTomatesCourgettes(tester);

      const label = 'Tomates, 500 g, Fruits et légumes';
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(
          label: label,
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(_row('Tomates'), findsNothing);
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      expect(announcements, contains(StringsFr.cocheAnnonce('Tomates')));

      await _tapBox(tester, 'Courgettes');
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(StringsFr.cochesLu(2, expanded: false)),
        ),
        isSemantics(
          label: 'Cochés, 2 articles, replié',
          isButton: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text(StringsFr.cochesTitre(2)));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Cochés, 2 articles, déplié'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, hasCheckedState: true, isChecked: true),
      );
      handle.dispose();
    });

    testWidgets('animations coupées : la ligne rejoint Cochés sans délai', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpWithTomatesCourgettes(tester);

      await tester.tap(_box('Tomates'));
      await tester.pump();
      await tester.pump();

      expect(_row('Tomates'), findsNothing);
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('tap sur le nom : rien ne change', (tester) async {
      final db = await _pumpWithTomatesCourgettes(tester);

      await tester.tap(find.text('Tomates'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(_row('Tomates'), findsOneWidget);
      expect(tester.widget<Checkbox>(_box('Tomates')).value, isFalse);
      expect(find.byType(CheckedSection), findsNothing);
      final lines = await db.select(db.listLines).get();
      expect(lines.every((l) => l.checkedAt == null), isTrue);
    });
  });

  group('terminer les courses', () {
    final terminer = find.widgetWithText(
      FilledButton,
      StringsFr.terminerLesCourses,
    );

    Future<void> checkAll(WidgetTester tester) async {
      await _tapBox(tester, 'Tomates');
      await _tapBox(tester, 'Courgettes');
    }

    Future<void> tapTerminer(WidgetTester tester) async {
      await tester.tap(terminer);
      await tester.pump();
      await tester.pumpAndSettle();
    }

    /// Laisse passer la durée du snackbar et sa sortie.
    Future<void> letSnackBarClose(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('le bouton n’apparaît que quand tout est coché, en bas de la '
        'Liste, au-dessus de la Barre de navigation', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpWithTomatesCourgettes(tester);
      expect(terminer, findsNothing);

      await _tapBox(tester, 'Tomates');
      expect(terminer, findsNothing);

      await _tapBox(tester, 'Courgettes');
      expect(terminer, findsOneWidget);
      expect(
        tester.getBottomLeft(terminer).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );
      expect(
        tester.getBottomLeft(terminer).dy,
        greaterThan(tester.getBottomLeft(find.byType(CheckedSection)).dy),
      );
      // Le FAB + remonte au-dessus du bouton.
      expect(
        tester.getBottomLeft(find.byType(FloatingActionButton)).dy,
        lessThanOrEqualTo(tester.getTopLeft(terminer).dy),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(StringsFr.terminerLesCourses),
        ),
        isSemantics(
          label: StringsFr.terminerLesCourses,
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Terminer vide la liste et montre le snackbar Annuler ; '
        'Annuler la restaure telle quelle', (tester) async {
      await _pumpWithTomatesCourgettes(tester);
      await checkAll(tester);

      await tapTerminer(tester);

      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(terminer, findsNothing);
      expect(find.byType(CheckedSection), findsNothing);
      expect(find.text(StringsFr.coursesTerminees), findsOneWidget);
      expect(
        find.widgetWithText(SnackBarAction, StringsFr.annuler),
        findsOneWidget,
      );
      // Snackbar de la Liste : au-dessus du FAB + et de la Barre de
      // navigation.
      final snackBar = find.byType(SnackBar);
      expect(
        tester.getBottomLeft(snackBar).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(FloatingActionButton)).dy,
        ),
      );
      expect(
        tester.getBottomLeft(snackBar).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );

      await tester.tap(find.widgetWithText(SnackBarAction, StringsFr.annuler));
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.listeVide), findsNothing);
      expect(find.text(StringsFr.coursesTerminees), findsNothing);
      expect(find.text(StringsFr.cochesTitre(2)), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(terminer, findsOneWidget);

      await tester.tap(find.text(StringsFr.cochesTitre(2)));
      await tester.pumpAndSettle();
      expect(_row('Tomates', inSection: true), findsOneWidget);
      expect(_row('Courgettes', inSection: true), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CheckedSection),
          matching: find.text('500 g'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('snackbar fermé à la fin de sa durée : plus rien ne restaure '
        'la liste', (tester) async {
      final undo = _SpyUndo();
      await _pumpWithTomatesCourgettes(tester, undo: undo);
      await checkAll(tester);
      await tapTerminer(tester);
      final entry = undo.last!;

      await letSnackBarClose(tester);

      expect(find.text(StringsFr.coursesTerminees), findsNothing);
      expect(await undo.undo(entry), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.listeVide), findsOneWidget);
    });

    testWidgets('échec de Terminer : snackbar d’erreur, liste inchangée', (
      tester,
    ) async {
      final db = await _pumpWithTomatesCourgettes(tester);
      await checkAll(tester);
      await db.customStatement(
        'CREATE TRIGGER no_clear BEFORE UPDATE OF deleted_at ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await tapTerminer(tester);

      expect(find.text(StringsFr.terminerImpossible), findsOneWidget);
      expect(find.text(StringsFr.cochesTitre(2)), findsOneWidget);
      expect(terminer, findsOneWidget);
      // Le snackbar ne cache pas le bouton à retoucher.
      expect(
        tester.getBottomLeft(find.byType(SnackBar)).dy,
        lessThanOrEqualTo(tester.getTopLeft(terminer).dy),
      );
      await letSnackBarClose(tester);
    });

    testWidgets('échec d’Annuler : snackbar d’erreur, liste toujours vide', (
      tester,
    ) async {
      final db = await _pumpWithTomatesCourgettes(tester);
      await checkAll(tester);
      await tapTerminer(tester);
      await db.customStatement(
        'CREATE TRIGGER no_restore BEFORE UPDATE OF deleted_at ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await tester.tap(find.widgetWithText(SnackBarAction, StringsFr.annuler));
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.annulationImpossible), findsOneWidget);
      expect(find.text(StringsFr.coursesTerminees), findsNothing);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(terminer, findsNothing);
      final active = await (db.select(
        db.listLines,
      )..where((l) => l.deletedAt.isNull())).get();
      expect(active, isEmpty);
      await letSnackBarClose(tester);
    });
  });

  group('supprimer et corriger', () {
    final undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);
    final sheet = find.byType(ItemEditSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);

    /// Monte Kadi avec les articles ajoutés par [add].
    Future<AppDatabase> pumpWith(
      WidgetTester tester,
      Future<void> Function(ListeRepository repo) add,
    ) async {
      final db = await _pumpApp(tester);
      await add(ListeRepository(db, Clock()));
      await tester.pumpAndSettle();
      return db;
    }

    Future<void> swipeLeft(WidgetTester tester, Finder row) async {
      await tester.drag(row, const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    Future<void> longPress(WidgetTester tester, Finder row) async {
      await tester.longPress(row);
      await tester.pumpAndSettle();
    }

    /// Ferme la feuille par un tap sur la barrière.
    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }

    Future<void> letSnackBarClose(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    /// Couleur de bordure de la pastille de [rayon] dans la feuille.
    Color? pastilleBorder(WidgetTester tester, Rayon rayon) {
      final pastille = tester.widget<RayonPastille>(
        inSheet(
          find.byWidgetPredicate((w) => w is RayonPastille && w.rayon == rayon),
        ),
      );
      return (pastille.border as Border?)?.top.color;
    }

    Future<ListLine> lineOf(AppDatabase db, String articleId) =>
        (db.select(db.listLines)..where(
              (l) => l.articleId.equals(articleId) & l.deletedAt.isNull(),
            ))
            .getSingle();

    testWidgets('glisser Riz vers la gauche : retiré, snackbar Annuler ; '
        'Annuler le remet sous Épicerie salée avec 1,5 kg', (tester) async {
      await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.riz, quantity: 1500, unit: Unit.g),
      );
      expect(_rowWith('Riz', '1,5 kg'), findsOneWidget);

      await swipeLeft(tester, _row('Riz'));

      expect(_row('Riz'), findsNothing);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.text(StringsFr.retireDeLaListe('Riz')), findsOneWidget);
      expect(find.text('Retiré de la liste : Riz'), findsOneWidget);
      expect(undoAction, findsOneWidget);

      await tester.tap(undoAction);
      await tester.pumpAndSettle();

      expect(_rowWith('Riz', '1,5 kg'), findsOneWidget);
      expect(
        find.widgetWithText(RayonHeader, 'Épicerie salée'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_row('Riz')).dy,
        greaterThan(
          tester
              .getTopLeft(find.widgetWithText(RayonHeader, 'Épicerie salée'))
              .dy,
        ),
      );
    });

    testWidgets('appui long sur Lardons : feuille avec Champ quantité (g), '
        'Choix de rayon (Viande/Poisson entouré) et « Supprimer »', (
      tester,
    ) async {
      await pumpWith(tester, (repo) => repo.addArticle(SeedIds.lardons));

      await longPress(tester, _row('Lardons'));

      expect(sheet, findsOneWidget);
      expect(inSheet(find.text('Lardons')), findsOneWidget);
      expect(inSheet(find.byType(QuantityField)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuantityField),
          matching: find.text(StringsFr.uniteG),
        ),
        findsOneWidget,
      );
      // Sans quantité : champ vide.
      expect(
        tester
            .widget<TextField>(inSheet(find.byType(TextField)))
            .controller!
            .text,
        isEmpty,
      );
      expect(inSheet(find.byType(RayonPicker)), findsOneWidget);
      final onSurface = Theme.of(tester.element(find.byType(RayonPicker)))
          .colorScheme
          .onSurface;
      expect(pastilleBorder(tester, Rayon.viandePoisson), onSurface);
      expect(pastilleBorder(tester, Rayon.platsPrepares), isNot(onSurface));
      final supprimer = inSheet(find.text(StringsFr.supprimer));
      expect(supprimer, findsOneWidget);
      final error = Theme.of(tester.element(supprimer)).colorScheme.error;
      expect(
        tester
            .widget<TextButton>(inSheet(find.byType(TextButton)))
            .style
            ?.foregroundColor
            ?.resolve({}),
        error,
      );
      expect(
        tester.getSize(inSheet(find.byType(TextButton))).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );
    });

    testWidgets('saisir 300, choisir Plats préparés, fermer : Lardons 300 g '
        'sous Plats préparés, plus sous Viande/Poisson', (tester) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.lardons),
      );
      await longPress(tester, _row('Lardons'));

      await tester.enterText(inSheet(find.byType(TextField)), '300');
      await tester.tap(inSheet(find.text('Plats préparés')));
      await tester.pumpAndSettle();
      // La feuille reste ouverte, la sélection suit.
      expect(sheet, findsOneWidget);
      final onSurface = Theme.of(tester.element(find.byType(RayonPicker)))
          .colorScheme
          .onSurface;
      expect(pastilleBorder(tester, Rayon.platsPrepares), onSurface);
      expect(pastilleBorder(tester, Rayon.viandePoisson), isNot(onSurface));

      await closeSheet(tester);

      expect(sheet, findsNothing);
      expect(_rowWith('Lardons', '300 g'), findsOneWidget);
      final header = find.widgetWithText(RayonHeader, 'Plats préparés');
      expect(header, findsOneWidget);
      expect(find.widgetWithText(RayonHeader, 'Viande/Poisson'), findsNothing);
      expect(
        tester.getTopLeft(_row('Lardons')).dy,
        greaterThan(tester.getTopLeft(header).dy),
      );

      final line = await lineOf(db, SeedIds.lardons);
      expect(line.rayon, 'plats-prepares');
      expect(line.unit, 'g');
      expect(line.manualAt, isNotNull);
      final article = await (db.select(
        db.articles,
      )..where((a) => a.id.equals(SeedIds.lardons))).getSingle();
      expect(article.rayon, 'viande-poisson');
      final active = await (db.select(
        db.listContributions,
      )..where((c) => c.lineId.equals(line.id) & c.deletedAt.isNull())).get();
      expect(active.single.source, ContributionSource.edition);
      expect(active.single.quantity, 300);
    });

    testWidgets('ouvrir et fermer sans rien changer : rien n’est écrit', (
      tester,
    ) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.tomates, quantity: 500, unit: Unit.g),
      );
      final before = await lineOf(db, SeedIds.tomates);

      await longPress(tester, _row('Tomates'));
      expect(
        tester
            .widget<TextField>(inSheet(find.byType(TextField)))
            .controller!
            .text,
        '500',
      );
      await closeSheet(tester);

      expect(await lineOf(db, SeedIds.tomates), before);
      expect(_rowWith('Tomates', '500 g'), findsOneWidget);
    });

    testWidgets('pièces fractionnaires (1 ½, préremplie 2) : fermer sans '
        'saisir n’écrit rien ; saisir 2 écrit 2 pièces', (tester) async {
      final db = await pumpWith(
        tester,
        (repo) =>
            repo.addArticle(SeedIds.lait, quantity: 1500, unit: Unit.piece),
      );
      final before = await lineOf(db, SeedIds.lait);
      final field = inSheet(find.byType(TextField));

      await longPress(tester, _row('Lait'));
      expect(tester.widget<TextField>(field).controller!.text, '2');
      await closeSheet(tester);
      expect(await lineOf(db, SeedIds.lait), before);

      await longPress(tester, _row('Lait'));
      await tester.enterText(field, '');
      await tester.enterText(field, '2');
      await closeSheet(tester);

      final line = await lineOf(db, SeedIds.lait);
      expect(line.manualAt, isNotNull);
      expect(line.unit, 'piece');
      final active =
          await (db.select(db.listContributions)
                ..where((c) => c.lineId.equals(line.id) & c.deletedAt.isNull()))
              .getSingle();
      expect(active.source, ContributionSource.edition);
      expect(active.quantity, 2000);
      expect(
        _rowWith('Lait', formatQuantity(2000, Unit.piece)),
        findsOneWidget,
      );
    });

    testWidgets('« Supprimer » dans la feuille : feuille fermée, ligne '
        'retirée, snackbar Annuler ; la quantité saisie n’est pas écrite', (
      tester,
    ) async {
      final db = await pumpWith(tester, (repo) async {
        await repo.addArticle(SeedIds.lardons);
        await repo.addArticle(SeedIds.tomates);
      });
      await longPress(tester, _row('Lardons'));
      await tester.enterText(inSheet(find.byType(TextField)), '300');

      await tester.ensureVisible(inSheet(find.text(StringsFr.supprimer)));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text(StringsFr.supprimer)));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(_row('Lardons'), findsNothing);
      expect(_row('Tomates'), findsOneWidget);
      expect(find.text(StringsFr.retireDeLaListe('Lardons')), findsOneWidget);
      expect(undoAction, findsOneWidget);
      final editions = await (db.select(
        db.listContributions,
      )..where((c) => c.source.equals(ContributionSource.edition))).get();
      expect(editions, isEmpty);

      await tester.tap(undoAction);
      await tester.pumpAndSettle();
      expect(_row('Lardons'), findsOneWidget);
      expect(
        find.widgetWithText(RayonHeader, 'Viande/Poisson'),
        findsOneWidget,
      );
    });

    testWidgets('TalkBack : « Supprimer » retire la ligne avec Annuler, '
        '« Modifier » ouvre la feuille', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.riz, quantity: 1500, unit: Unit.g),
      );
      const label = 'Riz, 1,5 kg, Épicerie salée';
      const supprimer = CustomSemanticsAction(label: StringsFr.supprimer);
      const modifier = CustomSemanticsAction(label: StringsFr.modifier);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(
          label: label,
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
          customActions: [supprimer, modifier],
        ),
      );

      tester.semantics.customAction(find.semantics.byLabel(label), modifier);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(inSheet(find.text('Riz')), findsOneWidget);
      await closeSheet(tester);
      expect(sheet, findsNothing);

      tester.semantics.customAction(find.semantics.byLabel(label), supprimer);
      await tester.pumpAndSettle();
      expect(_row('Riz'), findsNothing);
      expect(find.text(StringsFr.retireDeLaListe('Riz')), findsOneWidget);
      expect(undoAction, findsOneWidget);
      await letSnackBarClose(tester);
      handle.dispose();
    });

    testWidgets('ligne cochée dans la Section Cochés dépliée : appui long et '
        'glisser y marchent aussi', (tester) async {
      await _pumpWithTomatesCourgettes(tester);
      await _tapBox(tester, 'Tomates');
      await tester.tap(find.text(StringsFr.cochesTitre(1)));
      await tester.pumpAndSettle();
      expect(_row('Tomates', inSection: true), findsOneWidget);

      await longPress(tester, _row('Tomates', inSection: true));
      expect(sheet, findsOneWidget);
      expect(
        tester
            .widget<TextField>(inSheet(find.byType(TextField)))
            .controller!
            .text,
        '500',
      );
      await tester.enterText(inSheet(find.byType(TextField)), '300');
      await closeSheet(tester);
      expect(
        find.descendant(
          of: find.byType(CheckedSection),
          matching: find.text('300 g'),
        ),
        findsOneWidget,
      );

      await swipeLeft(tester, _row('Tomates', inSection: true));
      expect(_row('Tomates', inSection: true), findsNothing);
      expect(find.byType(CheckedSection), findsNothing);
      expect(find.text(StringsFr.retireDeLaListe('Tomates')), findsOneWidget);

      await tester.tap(undoAction);
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
    });

    testWidgets('échec d’une modification : snackbar d’erreur, la sélection '
        'revient au rayon d’avant', (tester) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.lardons),
      );
      await db.customStatement(
        'CREATE TRIGGER no_rayon BEFORE UPDATE OF rayon ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );
      await longPress(tester, _row('Lardons'));

      await tester.tap(inSheet(find.text('Plats préparés')));
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.modificationImpossible), findsOneWidget);
      final onSurface = Theme.of(tester.element(find.byType(RayonPicker)))
          .colorScheme
          .onSurface;
      expect(pastilleBorder(tester, Rayon.viandePoisson), onSurface);
      await closeSheet(tester);
      expect((await lineOf(db, SeedIds.lardons)).rayon, 'viande-poisson');
      await letSnackBarClose(tester);
    });

    /// La puce [unit] du Choix d'unité.
    Finder chip(InputUnit unit) => inSheet(find.byKey(ValueKey(unit)));

    /// L'unité choisie dans le Choix d'unité.
    InputUnit selectedUnit(WidgetTester tester) => InputUnit.values.singleWhere(
      (u) => tester.widget<ChoiceChip>(chip(u)).selected,
    );

    Future<void> tapChip(WidgetTester tester, InputUnit unit) async {
      await tester.ensureVisible(chip(unit));
      await tester.pumpAndSettle();
      await tester.tap(chip(unit));
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester) => tester
        .widget<TextField>(inSheet(find.byType(TextField)))
        .controller!
        .text;

    testWidgets('feuille : titre en titleMedium, Choix d’unité pièce · g · '
        'kg · ml · L, la puce de la ligne choisie en contour on-surface et '
        'coche, jamais en argile', (tester) async {
      await pumpWith(
        tester,
        (repo) =>
            repo.addArticle(SeedIds.tomates, quantity: 1500, unit: Unit.g),
      );
      await longPress(tester, _row('Tomates'));

      final theme = Theme.of(tester.element(sheet));
      expect(
        tester.widget<Text>(inSheet(find.text('Tomates'))).style?.fontSize,
        theme.textTheme.titleMedium?.fontSize,
      );
      expect(inSheet(find.text(StringsFr.unite)), findsOneWidget);
      expect(
        [
          for (final u in InputUnit.values)
            ((tester.widget<ChoiceChip>(chip(u)).label) as Text).data,
        ],
        ['pièce', 'g', 'kg', 'ml', 'L'],
      );
      // Ligne en g au-delà de 1000 : ouverte en g.
      expect(selectedUnit(tester), InputUnit.g);
      expect(fieldText(tester), '1500');
      final scheme = theme.colorScheme;
      final selected = tester.widget<ChoiceChip>(chip(InputUnit.g));
      expect(selected.side?.color, scheme.onSurface);
      expect(selected.showCheckmark, isTrue);
      expect(selected.checkmarkColor, scheme.onSurface);
      expect(
        selected.color?.resolve({WidgetState.selected}),
        isNot(scheme.primary),
      );
      expect(
        selected.color?.resolve({WidgetState.selected}),
        isNot(scheme.primaryContainer),
      );
      expect(
        tester.widget<ChoiceChip>(chip(InputUnit.kg)).side?.color,
        scheme.outline,
      );
      for (final u in InputUnit.values) {
        expect(
          tester.getSize(chip(u)).height,
          greaterThanOrEqualTo(KadiSpacing.touchTarget),
        );
      }
    });

    testWidgets('unité préchoisie : ligne sans quantité → unité de l’article '
        '(ml) ; article sans unité → pièce', (tester) async {
      final db = await pumpWith(tester, (repo) async {
        await repo.addArticle(SeedIds.lait);
        await repo.addArticle(SeedIds.riz);
      });
      await (db.update(db.articles)..where((a) => a.id.equals(SeedIds.lait)))
          .write(const ArticlesCompanion(unit: Value('ml')));
      await (db.update(db.articles)..where((a) => a.id.equals(SeedIds.riz)))
          .write(const ArticlesCompanion(unit: Value(null)));
      await tester.pumpAndSettle();

      await longPress(tester, _row('Lait'));
      expect(selectedUnit(tester), InputUnit.ml);
      expect(
        find.descendant(
          of: inSheet(find.byType(QuantityField)),
          matching: find.text(StringsFr.uniteMl),
        ),
        findsOneWidget,
      );
      await closeSheet(tester);

      await longPress(tester, _row('Riz'));
      expect(selectedUnit(tester), InputUnit.piece);
      await closeSheet(tester);
    });

    testWidgets('changer d’unité avec jumeau : Tomates 300 g et 2 pièces, la '
        'ligne pièces → g, 200 : une seule ligne « Tomates 500 g »', (
      tester,
    ) async {
      final db = await pumpWith(tester, (repo) async {
        await repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g);
        await repo.addArticle(
          SeedIds.tomates,
          quantity: 2000,
          unit: Unit.piece,
        );
      });
      final pieces = find.ancestor(
        of: find.text(formatQuantity(2000, Unit.piece)),
        matching: find.byType(ItemRow),
      );
      await longPress(tester, pieces);
      expect(selectedUnit(tester), InputUnit.piece);

      await tapChip(tester, InputUnit.g);
      // Le nombre tapé est gardé : la puce dit l'unité où il est lu.
      expect(fieldText(tester), '2');
      expect(
        find.descendant(
          of: inSheet(find.byType(QuantityField)),
          matching: find.text(StringsFr.uniteG),
        ),
        findsOneWidget,
      );
      await tester.enterText(inSheet(find.byType(TextField)), '200');
      await closeSheet(tester);

      expect(find.widgetWithText(ItemRow, 'Tomates'), findsOneWidget);
      expect(_rowWith('Tomates', formatQuantity(500, Unit.g)), findsOneWidget);
      final lines = await (db.select(
        db.listLines,
      )..where((l) => l.deletedAt.isNull())).get();
      expect(lines.single.unit, 'g');
      expect(lines.single.manualAt, isNotNull);
    });

    testWidgets('saisie en kg : Riz sans quantité, kg, « 1,5 » → « 1,5 kg », '
        'stocké 1500 g', (tester) async {
      final db = await pumpWith(tester, (repo) => repo.addArticle(SeedIds.riz));
      await longPress(tester, _row('Riz'));

      await tapChip(tester, InputUnit.kg);
      expect(
        tester.widget<TextField>(inSheet(find.byType(TextField))).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      await tester.enterText(inSheet(find.byType(TextField)), '1,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(_rowWith('Riz', formatQuantity(1500, Unit.g)), findsOneWidget);
      final line = await lineOf(db, SeedIds.riz);
      expect(line.unit, 'g');
      final active = await (db.select(
        db.listContributions,
      )..where((c) => c.lineId.equals(line.id) & c.deletedAt.isNull())).get();
      expect(active.single.quantity, 1500);
      expect(active.single.unit, 'g');

      // Rouverte : en g, 1500.
      await longPress(tester, _row('Riz'));
      expect(selectedUnit(tester), InputUnit.g);
      expect(fieldText(tester), '1500');
      await closeSheet(tester);
    });

    testWidgets('saisie en L : Lait, L, « 2 » → « 2 l », stocké 2000 ml', (
      tester,
    ) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.lait),
      );
      await longPress(tester, _row('Lait'));

      await tapChip(tester, InputUnit.l);
      await tester.enterText(inSheet(find.byType(TextField)), '2');
      await closeSheet(tester);

      expect(_rowWith('Lait', formatQuantity(2000, Unit.ml)), findsOneWidget);
      expect((await lineOf(db, SeedIds.lait)).unit, 'ml');
    });

    testWidgets('kg puis g : les décimales que g n’admet pas tombent', (
      tester,
    ) async {
      await pumpWith(tester, (repo) => repo.addArticle(SeedIds.riz));
      await longPress(tester, _row('Riz'));
      await tapChip(tester, InputUnit.kg);
      await tester.enterText(inSheet(find.byType(TextField)), '1,5');

      await tapChip(tester, InputUnit.g);

      expect(fieldText(tester), '1');
      await closeSheet(tester);
      expect(_rowWith('Riz', formatQuantity(1, Unit.g)), findsOneWidget);
    });

    testWidgets('vider la quantité : ligne sans quantité, quelle que soit la '
        'puce', (tester) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g),
      );
      await longPress(tester, _row('Tomates'));
      await tester.enterText(inSheet(find.byType(TextField)), '');
      await tapChip(tester, InputUnit.kg);
      await closeSheet(tester);

      expect(_rowWith('Tomates', formatQuantity(300, Unit.g)), findsNothing);
      final line = await lineOf(db, SeedIds.tomates);
      expect(line.unit, isNull);
      expect(line.manualAt, isNotNull);
    });

    testWidgets('changer de puce puis revenir, sans saisir : rien n’est '
        'écrit', (tester) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.tomates, quantity: 300, unit: Unit.g),
      );
      final before = await lineOf(db, SeedIds.tomates);
      await longPress(tester, _row('Tomates'));
      await tapChip(tester, InputUnit.kg);
      await tapChip(tester, InputUnit.g);
      await closeSheet(tester);

      expect(await lineOf(db, SeedIds.tomates), before);
    });

    testWidgets('TalkBack : titre, « Quantité », chaque puce avec son état '
        'choisi, rayons, « Supprimer »', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWith(
        tester,
        (repo) =>
            repo.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece),
      );
      await longPress(tester, _row('Lait'));

      expect(
        tester.getSemantics(inSheet(find.text('Lait'))),
        isSemantics(label: 'Lait', isHeader: true),
      );
      expect(
        tester.getSemantics(inSheet(find.byType(EditableText))),
        isSemantics(label: StringsFr.quantite, isTextField: true),
      );
      for (final (unit, label) in [
        (InputUnit.piece, 'pièce'),
        (InputUnit.g, 'g'),
        (InputUnit.kg, 'kg'),
        (InputUnit.ml, 'ml'),
        (InputUnit.l, 'L'),
      ]) {
        expect(
          tester.getSemantics(chip(unit)),
          isSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: unit == InputUnit.piece,
            hasTapAction: true,
          ),
        );
      }
      expect(
        tester.getSemantics(
          find.descendant(
            of: inSheet(find.byType(RayonPicker)),
            matching: find.bySemanticsLabel('Crèmerie'),
          ),
        ),
        isSemantics(label: 'Crèmerie', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(inSheet(find.byType(TextButton))),
        isSemantics(label: StringsFr.supprimer, isButton: true),
      );
      await closeSheet(tester);
      handle.dispose();
    });

    testWidgets('échec de la suppression : snackbar d’erreur, la ligne '
        'reste', (tester) async {
      final db = await pumpWith(
        tester,
        (repo) => repo.addArticle(SeedIds.riz, quantity: 1500, unit: Unit.g),
      );
      await db.customStatement(
        'CREATE TRIGGER no_delete BEFORE UPDATE OF deleted_at ON list_lines '
        "BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await swipeLeft(tester, _row('Riz'));

      expect(find.text(StringsFr.suppressionImpossible), findsOneWidget);
      expect(_rowWith('Riz', '1,5 kg'), findsOneWidget);
      expect(undoAction, findsNothing);
      await letSnackBarClose(tester);
    });
  });
}
