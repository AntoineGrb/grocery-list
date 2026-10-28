import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/kadi_app.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_db.dart';

Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  Brightness platformBrightness = Brightness.light,
  Map<String, String> assetOverrides = const {},
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final assets = (await tester.runAsync(readSeedAssets))!;
  final db = memoryDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        seedAssetLoaderProvider.overrideWithValue(
          assetLoaderWith({...assets, ...assetOverrides}),
        ),
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

void main() {
  testWidgets('installation neuve : Liste vide, puis Recettes vide', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text(StringsFr.listeVide), findsOneWidget);
    expect(find.text(StringsFr.tabListe), findsWidgets);

    await tester.tap(find.text(StringsFr.tabRecettes));
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.recettesVide), findsOneWidget);
  });

  testWidgets(
    'FAB +, « lait », tap sur Lait : Lait sous Crèmerie, compteur 1',
    (tester) async {
      final handle = tester.ensureSemantics();
      final db = await _pumpApp(tester);

      expect(find.bySemanticsLabel(StringsFr.ajouterUnArticle), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).autofocus, isTrue);
      expect(find.text(StringsFr.rechercherUnArticle), findsOneWidget);
      // Recherche vide : aucune ligne de résultat.
      expect(find.byType(SearchResultRow), findsNothing);

      await tester.enterText(field, 'lait');
      await tester.pumpAndSettle();
      // Lait en premier, parmi d'autres résultats (Lait de coco…).
      final laitRow = find.byType(SearchResultRow).first;
      expect(
        find.descendant(of: laitRow, matching: find.text('Lait')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Lait, Crèmerie'), findsOneWidget);

      await tester.tap(laitRow);
      await tester.pumpAndSettle();

      // Le Panneau + reste ouvert.
      expect(find.byType(AddSheet), findsOneWidget);
      expect(await db.select(db.listLines).get(), hasLength(1));

      // Fermer le panneau et lire la Liste.
      Navigator.of(tester.element(find.byType(AddSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.listeVide), findsNothing);
      expect(find.text('Crèmerie'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Lait'), findsOneWidget);
      expect(find.bySemanticsLabel('Crèmerie, 1 article'), findsOneWidget);
      expect(find.bySemanticsLabel('Lait, Crèmerie'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('« kumquat » : aucune ligne de résultat', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kumquat');
    await tester.pumpAndSettle();
    expect(find.byType(SearchResultRow), findsNothing);
  });

  for (final (brightness, palette) in [
    (Brightness.light, KadiPalette.light),
    (Brightness.dark, KadiPalette.dark),
  ]) {
    testWidgets(
      'thème ${brightness.name} : argile sur le FAB et l’onglet actif',
      (tester) async {
        await _pumpApp(tester, platformBrightness: brightness);
        final context = tester.element(find.byType(FloatingActionButton));
        final theme = Theme.of(context);

        expect(theme.brightness, brightness);
        expect(theme.colorScheme.surface, palette.surface);
        expect(theme.colorScheme.surfaceTint.a, 0);
        expect(theme.scaffoldBackgroundColor, palette.surface);
        expect(
          theme.floatingActionButtonTheme.backgroundColor,
          palette.primary,
        );
        expect(
          theme.floatingActionButtonTheme.foregroundColor,
          palette.onPrimary,
        );
        expect(
          theme.navigationBarTheme.indicatorColor,
          palette.primaryContainer,
        );
        expect(
          theme.navigationBarTheme.backgroundColor,
          palette.surfaceContainer,
        );
        expect(theme.appBarTheme.backgroundColor, palette.surface);
        expect(theme.textSelectionTheme.cursorColor, palette.onSurface);
      },
    );
  }

  testWidgets('contenu fourni illisible : écran d’erreur bloquant', (
    tester,
  ) async {
    final db = await _pumpApp(
      tester,
      assetOverrides: {SeedLoader.articlesPath: '{pas du json'},
    );

    expect(find.byType(BlockingErrorScreen), findsOneWidget);
    expect(find.text(StringsFr.erreurOuvertureTitre), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(await db.select(db.articles).get(), isEmpty);
  });
}
