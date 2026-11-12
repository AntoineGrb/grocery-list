import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/backup/backup_providers.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/screen/screen_awake.dart';
import 'package:kadi/core/strings/strings_fr.dart';

import '../helpers/navigation.dart';

import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';
import 'package:kadi/features/liste/ui/checked_section.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/recettes/ui/revue_row.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/panneau.dart';
import '../helpers/pump_app.dart';
import '../helpers/recettes.dart';

export '../helpers/panneau.dart';
export '../helpers/pump_app.dart';
export '../helpers/recettes.dart';
export '../helpers/test_db.dart';

/// Suite de bout en bout : les six Key Flows d'EXPERIENCE.md rejoués sur
/// l'app montée entière ([pumpKadi]), par les gestes de l'utilisateur.
///
/// Chaque scénario se joue deux fois, thème clair puis sombre, par la
/// luminosité de la plateforme du test. Le même code sert `flutter test
/// test/e2e` et `integration_test/parcours_test.dart` (sur le téléphone).

/// Les deux thèmes de la plateforme, et leur nom dans le titre du test.
const e2eThemes = [(Brightness.light, 'clair'), (Brightness.dark, 'sombre')];

/// Déclare [description] une fois par thème : clair puis sombre.
///
/// [skip] marque un défaut d'app reporté (raison dans le texte).
void testBothThemes(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  String? skip,
}) {
  for (final (brightness, name) in e2eThemes) {
    testWidgets('$description ($name)', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await body(tester);
    }, skip: skip != null);
  }
}

/// Téléphone de [size] dp (par défaut 412 × 1600 : toute la Liste d'une
/// semaine est bâtie), clavier de [keyboard] dp.
void phone(
  WidgetTester tester, {
  Size size = const Size(412, 1600),
  double keyboard = 0,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  if (keyboard > 0) tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

/// Monte Kadi ([pumpKadi]) et vérifie que l'app suit le thème de la
/// plateforme.
Future<AppDatabase> pumpE2e(
  WidgetTester tester, {
  bool firstLaunch = false,
  AppDatabase? database,
  List<Override> overrides = const [],
  ShareFile? shareFile,
  PickBackupFile? pickBackupFile,
  ScreenAwake? screenAwake,
}) async {
  final db = await pumpKadi(
    tester,
    firstLaunch: firstLaunch,
    database: database,
    overrides: overrides,
    shareFile: shareFile,
    pickBackupFile: pickBackupFile,
    screenAwake: screenAwake,
  );
  expectPlatformTheme(tester);
  return db;
}

/// Le thème affiché est celui de la plateforme (clair ou sombre).
void expectPlatformTheme(WidgetTester tester) {
  final brightness = tester.platformDispatcher.platformBrightness;
  final scaffold = find.byType(Scaffold).first;
  expect(
    Theme.of(tester.element(scaffold)).brightness,
    brightness,
    reason: 'thème de la plateforme',
  );
}

// Gestes communs.

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Entrée au clavier dans le champ focalisé.
Future<void> pressEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Laisse se fermer le snackbar ouvert (durée M3 par défaut).
Future<void> letSnackBarClose(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

final undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);

// Liste.

/// La Ligne d'article de [name], hors ou dans la Section Cochés.
Finder itemRow(String name, {bool inSection = false}) {
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

/// La quantité [quantity] dans la Ligne d'article de [name].
Finder itemRowWith(String name, String quantity) =>
    find.descendant(of: itemRow(name), matching: find.text(quantity));

/// Touche la case de [name] du pouce et laisse passer l'animation.
Future<void> checkItem(
  WidgetTester tester,
  String name, {
  bool inSection = false,
}) async {
  final box = find.descendant(
    of: itemRow(name, inSection: inSection),
    matching: find.byType(Checkbox),
  );
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

/// En-tête de rayon [label] (nom affiché).
Finder rayonHeader(String label) => find.widgetWithText(RayonHeader, label);

/// Noms affichés des En-têtes de rayon, de haut en bas.
List<String> shownHeaders(WidgetTester tester) {
  if (find.byType(RevueRayonCard).evaluate().isNotEmpty) {
    return [for (final r in revueRayons(tester)) r.label];
  }
  final headers = [
    for (final e in find.byType(RayonHeader).evaluate())
      (e.widget as RayonHeader, tester.getTopLeft(find.byWidget(e.widget)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (h, _) in headers) h.rayon.label];
}

/// Noms des Lignes d'article hors Cochés, de haut en bas.
List<String> shownItems(WidgetTester tester) {
  final section = find
      .descendant(
        of: find.byType(CheckedSection),
        matching: find.byType(ItemRow),
      )
      .evaluate()
      .toSet();
  final rows = [
    for (final e in find.byType(ItemRow).evaluate())
      if (!section.contains(e))
        (
          (e.widget as ItemRow).item.name,
          tester.getTopLeft(find.byWidget(e.widget)).dy,
        ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (n, _) in rows) n];
}

// Revue.

Finder revueRow(String name) =>
    find.byWidgetPredicate((w) => w is RevueRow && w.line.name == name);

Finder revueField(String name) =>
    find.descendant(of: revueRow(name), matching: find.byType(TextField));

Future<void> uncheckInRevue(WidgetTester tester, String name) =>
    toggleRevueRow(tester, name);

Finder get ajouterALaListe => revueAddButton;

// Panneau +.

final addSheet = find.byType(AddSheet);
Finder inAddSheet(Finder finder) =>
    find.descendant(of: addSheet, matching: finder);

/// Le Champ d'ajout du Panneau +.
Finder get addField => inAddSheet(find.byType(TextField)).first;

Finder frequentRow(String name) => find.widgetWithText(FrequentChip, name);

/// Ouvre le Panneau + (clavier ouvert, fréquents cachés derrière ⚡).
Future<void> openAddSheet(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  expect(addSheet, findsOneWidget);
}

/// Ferme le Panneau + par le retour.
Future<void> closeAddSheet(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(addSheet, findsNothing);
}

/// Fait défiler les fréquents du panneau jusqu'à [name].
Future<void> scrollToFrequent(WidgetTester tester, String name) async {
  await showFrequents(tester);
  final scrollable = find
      .descendant(
        of: inAddSheet(find.byType(ListView)),
        matching: find.byType(Scrollable),
      )
      .first;
  // Le fréquent peut être au-dessus : on remonte d'abord, par petits
  // glissements, sans aller jusqu'au glissement qui fermerait le panneau.
  final position = tester.state<ScrollableState>(scrollable).position;
  for (
    var i = 0;
    i < 50 && frequentRow(name).evaluate().isEmpty && position.pixels > 0;
    i++
  ) {
    await tester.drag(scrollable, Offset(0, math.min(100, position.pixels)));
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    frequentRow(name),
    100,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
}

/// Touche le fréquent [name] du panneau, amené à l'écran d'abord.
Future<void> tapFrequent(WidgetTester tester, String name) async {
  await scrollToFrequent(tester, name);
  await tester.tap(frequentRow(name));
  await tester.pumpAndSettle();
}

/// Le Champ d'ajout a le focus (clavier ouvert).
bool addFieldFocused(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(of: addField, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

// Paramètres.

Finder get parametresScrollable => find
    .descendant(
      of: find.byType(ParametresScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Ouvre les Paramètres par leur onglet.
Future<void> openParametres(WidgetTester tester) async {
  await tester.tap(parametresTab);
  await tester.pumpAndSettle();
  expect(find.byType(ParametresScreen), findsOneWidget);
}

/// Touche la ligne de paramètre [title], amenée à l'écran (liste
/// paresseuse).
Future<void> tapParametre(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    100,
    scrollable: parametresScrollable,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// Annonces TalkBack envoyées pendant le test.
List<String> recordAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      final map = message as Map<dynamic, dynamic>;
      if (map['type'] == 'announce') {
        announcements.add((map['data'] as Map)['message'] as String);
      }
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}
