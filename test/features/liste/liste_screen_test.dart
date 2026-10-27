import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_db.dart';

/// Monte Kadi sur une base en mémoire ; l'app s'ouvre sur la Liste.
Future<AppDatabase> _pumpApp(WidgetTester tester) async {
  final seed = (await tester.runAsync(
    () => diskAssetLoader('assets/seed/articles.json'),
  ))!;
  final db = memoryDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedAssetLoaderProvider.overrideWithValue((_) async => seed),
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
}
