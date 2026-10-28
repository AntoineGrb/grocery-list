import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_db.dart';

/// Monte Kadi sur une base en mémoire ; l'app s'ouvre sur la Liste.
Future<AppDatabase> _pumpApp(WidgetTester tester, {_SpyUndo? undo}) async {
  final assets = (await tester.runAsync(readSeedAssets))!;
  final db = memoryDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedAssetLoaderProvider.overrideWithValue(assetLoaderWith(assets)),
        if (undo != null)
          undoProvider.overrideWith((ref) {
            undo.attach(ref.watch(databaseProvider), ref.watch(clockProvider));
            return undo;
          }),
      ],
      child: const KadiApp(),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  return db;
}

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
    expect(
      find.bySemanticsLabel('Fruits et légumes, 1 article'),
      findsOneWidget,
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
      find.bySemanticsLabel('Fruits et légumes, 2 articles'),
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

      await _tapBox(tester, 'Tomates');
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      await _tapBox(tester, 'Courgettes');

      expect(find.byType(RayonHeader), findsNothing);
      expect(find.text('Fruits & légumes'), findsNothing);
      expect(find.text(StringsFr.cochesTitre(2)), findsOneWidget);
      expect(find.text(StringsFr.afficher), findsOneWidget);
      expect(find.byType(ItemRow), findsNothing);
      expect(find.text(StringsFr.listeVide), findsNothing);
    });

    testWidgets('déplier : lignes barrées, case pleine, « Replier » ; '
        'décocher Tomates la renvoie dans son rayon', (tester) async {
      await _pumpWithTomatesCourgettes(tester);
      await _tapBox(tester, 'Tomates');
      await _tapBox(tester, 'Courgettes');

      await tester.tap(find.text(StringsFr.cochesTitre(2)));
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.replier), findsOneWidget);
      expect(find.text(StringsFr.afficher), findsNothing);
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
        find.bySemanticsLabel('Fruits et légumes, 1 article'),
        findsOneWidget,
      );
      expect(find.text(StringsFr.cochesTitre(1)), findsOneWidget);
      // La section reste dépliée.
      expect(find.text(StringsFr.replier), findsOneWidget);
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
      expect(find.text(StringsFr.afficher), findsOneWidget);
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
}
