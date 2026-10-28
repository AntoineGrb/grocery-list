import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_db.dart';

/// Monte Kadi sur une base en mémoire ; l'app s'ouvre sur la Liste.
Future<AppDatabase> _pumpApp(WidgetTester tester) async {
  final assets = (await tester.runAsync(readSeedAssets))!;
  final db = memoryDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedAssetLoaderProvider.overrideWithValue(assetLoaderWith(assets)),
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

/// Monte Kadi avec Tomates 500 g et Courgettes dans la liste.
Future<AppDatabase> _pumpWithTomatesCourgettes(WidgetTester tester) async {
  final db = await _pumpApp(tester);
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
}
