import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/seed/seed_loader.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/item_row.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:kadi/features/recettes/state/revue.dart';
import 'package:kadi/features/recettes/ui/recipe_card.dart';
import 'package:kadi/features/recettes/ui/revue_row.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

const _nbsp = ' ';

/// Échoue toujours, sans rien écrire.
class _FailingAjouter implements AjouterALaListe {
  @override
  Future<void> call(
    Revue revue, {
    RevueDraft draft = const RevueDraft(),
  }) async => throw StateError('échec simulé');
}

/// Ouvre l'onglet Recettes.
Future<void> _openRecettes(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(StringsFr.tabRecettes),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _card(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(RecipeCard));

Future<void> _tapCard(WidgetTester tester, String name) async {
  await tester.ensureVisible(_card(name));
  await tester.tap(_card(name));
  await tester.pumpAndSettle();
}

Finder _valider(int n) =>
    find.widgetWithText(FilledButton, StringsFr.validerN(n));

Future<void> _validate(WidgetTester tester, int n) async {
  await tester.tap(_valider(n));
  await tester.pumpAndSettle();
}

/// La Ligne de Revue de [name].
Finder _revueRow(String name) =>
    find.byWidgetPredicate((w) => w is RevueRow && w.line.name == name);

/// Le Champ quantité de la Ligne de Revue de [name].
Finder _field(String name) =>
    find.descendant(of: _revueRow(name), matching: find.byType(TextField));

String _fieldText(WidgetTester tester, String name) =>
    tester.widget<TextField>(_field(name)).controller!.text;

/// Touche la coche de la Ligne de Revue de [name].
Future<void> _tapCheck(WidgetTester tester, String name) async {
  final check = find.descendant(
    of: _revueRow(name),
    matching: find.byType(Checkbox),
  );
  await tester.ensureVisible(check);
  await tester.tap(check);
  await tester.pumpAndSettle();
}

Finder get _ajouterButton =>
    find.widgetWithText(FilledButton, StringsFr.ajouterALaListe);

/// Annonces TalkBack envoyées pendant le test.
List<String> _recordAnnouncements(WidgetTester tester) {
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

/// Ouvre la Revue de Pâtes carbonara et Quiche lorraine, sur un téléphone
/// haut où toute la Revue et toute la Liste sont bâties.
Future<AppDatabase> _openCarbonaraQuiche(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);
  final db = await pumpKadi(tester);
  await _openRecettes(tester);
  await _tapCard(tester, 'Pâtes carbonara');
  await _tapCard(tester, 'Quiche lorraine');
  await _validate(tester, 2);
  return db;
}

/// Rayons des En-têtes de rayon visibles, de haut en bas.
List<Rayon> _headers(WidgetTester tester) {
  final headers = find.byType(RayonHeader);
  final list = [for (final e in headers.evaluate()) e.widget as RayonHeader];
  list.sort(
    (a, b) => tester
        .getTopLeft(find.byWidget(a))
        .dy
        .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
  );
  return [for (final h in list) h.rayon];
}

void main() {
  testWidgets('installation neuve : les 4 recettes exemples en cartes sur 2 '
      'colonnes, chacune avec son picto', (tester) async {
    await pumpKadi(tester);
    await _openRecettes(tester);

    expect(find.byType(RecipeCard), findsNWidgets(4));
    expect(find.text(StringsFr.recettesVide), findsNothing);
    final chili = tester.getRect(_card('Chili con carne'));
    final carbonara = tester.getRect(_card('Pâtes carbonara'));
    final quiche = tester.getRect(_card('Quiche lorraine'));
    final ratatouille = tester.getRect(_card('Ratatouille'));
    // Rangées de deux cartes de même hauteur, triées par nom.
    expect(chili.top, carbonara.top);
    expect(chili.height, carbonara.height);
    expect(chili.left, lessThan(carbonara.left));
    expect(quiche.top, greaterThan(chili.bottom));
    expect(quiche.top, ratatouille.top);
    expect(chili.width, carbonara.width);
    // Le picto de repli de l'ingrédient principal, 44 dp.
    final chiliPicto = find.descendant(
      of: _card('Chili con carne'),
      matching: find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == KadiSpacing.recipePicto &&
            w.height == KadiSpacing.recipePicto,
      ),
    );
    expect(chiliPicto, findsOneWidget);
    // Aucun Bouton d'action sans sélection.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('sans recette : message d’état vide', (tester) async {
    await pumpKadi(
      tester,
      assetOverrides: {SeedLoader.recettesPath: emptyRecettesFile()},
    );
    await _openRecettes(tester);
    expect(find.text(StringsFr.recettesVide), findsOneWidget);
    expect(find.byType(RecipeCard), findsNothing);
  });

  testWidgets('sélectionner, désélectionner : coche, bordure et Valider (n)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    await _tapCard(tester, 'Chili con carne');
    expect(
      find.bySemanticsLabel('Chili con carne, sélectionnée'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _card('Chili con carne'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(_valider(1), findsOneWidget);
    expect(await db.select(db.weekSelections).get(), hasLength(1));

    await _tapCard(tester, 'Ratatouille');
    expect(_valider(2), findsOneWidget);

    // Désélection d'une recette non validée, par TalkBack.
    tester.semantics.tap(
      find.semantics.byLabel('Chili con carne, sélectionnée'),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    expect(_valider(1), findsOneWidget);
    await _tapCard(tester, 'Ratatouille');
    expect(find.byType(FilledButton), findsNothing);
    handle.dispose();
  });

  testWidgets('Carbonara + Quiche : Valider (2), Revue, Ajouter à la liste, '
      'Liste prête ; puis Ratatouille seule en Revue', (tester) async {
    // Téléphone haut : toute la Revue et toute la Liste sont bâties.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);
    await _tapCard(tester, 'Pâtes carbonara');
    await _tapCard(tester, 'Quiche lorraine');
    await _validate(tester, 2);

    // Revue : plein écran, sans Barre de navigation, flèche retour.
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(find.text(StringsFr.revue), findsOneWidget);
    expect(find.text(StringsFr.revueConsigne), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    // Groupée par rayon dans l'ordre du parcours (par défaut), tout coché.
    expect(_headers(tester), [
      Rayon.viandePoisson,
      Rayon.cremerie,
      Rayon.epicerieSalee,
    ]);
    expect(find.byType(RevueRow), findsNWidgets(8));
    expect(find.text('Lardons'), findsOneWidget);
    expect(_fieldText(tester, 'Lardons'), '400');
    expect(find.text('Œufs'), findsOneWidget);
    expect(_fieldText(tester, 'Œufs'), '6');
    expect(find.text('Poivre'), findsOneWidget);
    // Poivre sans quantité : champ vide dans la pièce (article sans unité).
    expect(_fieldText(tester, 'Poivre'), '');
    expect(
      find.descendant(
        of: _revueRow('Poivre'),
        matching: find.text(StringsFr.champUnitePieces),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Lardons, 400${_nbsp}g, Viande et poisson'),
      ),
      isSemantics(
        label: 'Lardons, 400${_nbsp}g, Viande et poisson',
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    expect(find.bySemanticsLabel('Poivre, Épicerie salée'), findsOneWidget);
    expect(
      tester
          .widgetList<Checkbox>(
            find.descendant(
              of: find.byType(RevueRow),
              matching: find.byType(Checkbox),
            ),
          )
          .every((c) => c.value == true),
      isTrue,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
    );
    await tester.pumpAndSettle();

    // La Liste, triée par rayon, avec son avis.
    expect(find.byType(RevueScreen), findsNothing);
    expect(find.text(StringsFr.listePrete), findsOneWidget);
    expect(find.byType(ItemRow), findsNWidgets(8));
    expect(_headers(tester), [
      Rayon.viandePoisson,
      Rayon.cremerie,
      Rayon.epicerieSalee,
    ]);
    expect(
      find.bySemanticsLabel('Lardons, 400${_nbsp}g, Viande et poisson'),
      findsOneWidget,
    );
    final selections = await db.select(db.weekSelections).get();
    expect(selections.every((s) => s.validatedAt != null), isTrue);

    // De retour sur Recettes : toujours sélectionnées, sans Valider.
    await _openRecettes(tester);
    expect(
      find.bySemanticsLabel('Pâtes carbonara, sélectionnée'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Quiche lorraine, sélectionnée'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);

    // Une carte validée ne change pas (story 3).
    await _tapCard(tester, 'Pâtes carbonara');
    expect(
      find.bySemanticsLabel('Pâtes carbonara, sélectionnée'),
      findsOneWidget,
    );
    expect(await db.select(db.weekSelections).get(), selections);

    // Ratatouille seule en Revue.
    await _tapCard(tester, 'Ratatouille');
    await _validate(tester, 1);
    expect(find.byType(RevueRow), findsNWidgets(7));
    expect(find.text('Courgettes'), findsOneWidget);
    expect(find.text('Lardons'), findsNothing);
    expect(find.text('Œufs'), findsNothing);
    handle.dispose();
  });

  testWidgets('décocher Pâtes, Œufs 6 → 4, Ajouter : la Liste sans Pâtes, '
      'avec « Œufs 4 pièces »', (tester) async {
    final announcements = _recordAnnouncements(tester);
    final db = await _openCarbonaraQuiche(tester);

    final before = tester.getTopLeft(_revueRow('Pâtes'));
    await _tapCheck(tester, 'Pâtes');

    // Décochée : couleur cochée sans barré, la ligne reste à sa place.
    final checkbox = tester.widget<Checkbox>(
      find.descendant(of: _revueRow('Pâtes'), matching: find.byType(Checkbox)),
    );
    expect(checkbox.value, isFalse);
    final name = tester.widget<Text>(
      find.descendant(of: _revueRow('Pâtes'), matching: find.text('Pâtes')),
    );
    final colors = KadiColors.of(tester.element(_revueRow('Pâtes')));
    expect(name.style?.color, colors.checked);
    expect(name.style?.decoration, isNot(TextDecoration.lineThrough));
    expect(tester.getTopLeft(_revueRow('Pâtes')), before);
    expect(find.byType(RevueRow), findsNWidgets(8));
    expect(announcements, ['Pâtes, non coché']);

    // Recocher puis redécocher : l'état suit chaque tap.
    await _tapCheck(tester, 'Pâtes');
    expect(announcements.last, 'Pâtes, coché');
    await _tapCheck(tester, 'Pâtes');

    await tester.enterText(_field('Œufs'), '4');
    await tester.pumpAndSettle();
    await tester.tap(_ajouterButton);
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(find.text(StringsFr.listePrete), findsOneWidget);
    expect(find.byType(ItemRow), findsNWidgets(7));
    expect(find.text('Pâtes'), findsNothing);
    expect(find.text('Œufs'), findsOneWidget);
    expect(find.text('4${_nbsp}pièces'), findsOneWidget);
    final lines = await db.select(db.listLines).get();
    expect(lines.every((l) => l.manualAt == null), isTrue);
  });

  testWidgets('tout décoché : la Liste ne change pas, Valider disparaît', (
    tester,
  ) async {
    final db = await _openCarbonaraQuiche(tester);
    for (final row in tester.widgetList<RevueRow>(find.byType(RevueRow))) {
      await _tapCheck(tester, row.line.name);
    }
    expect(
      tester
          .widgetList<Checkbox>(
            find.descendant(
              of: find.byType(RevueRow),
              matching: find.byType(Checkbox),
            ),
          )
          .every((c) => c.value == false),
      isTrue,
    );
    // Toujours actif.
    expect(tester.widget<FilledButton>(_ajouterButton).onPressed, isNotNull);
    await tester.tap(_ajouterButton);
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(find.byType(ItemRow), findsNothing);
    expect(await db.select(db.listLines).get(), isEmpty);
    final selections = await db.select(db.weekSelections).get();
    expect(selections.every((s) => s.validatedAt != null), isTrue);
    await _openRecettes(tester);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('retour après décoche et correction : rien n’est écrit, '
      '« Valider (2) » toujours là, Revue rouverte toute cochée', (
    tester,
  ) async {
    final db = await _openCarbonaraQuiche(tester);
    await _tapCheck(tester, 'Pâtes');
    await tester.enterText(_field('Œufs'), '4');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(_valider(2), findsOneWidget);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(
      (await db.select(db.weekSelections).get()).every(
        (s) => s.validatedAt == null,
      ),
      isTrue,
    );

    // Le brouillon est mort avec l'écran.
    await _validate(tester, 2);
    expect(_fieldText(tester, 'Œufs'), '6');
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: _revueRow('Pâtes'),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('TalkBack : ligne lue avec son état et activable, champ « '
      'Quantité de … » à part, suivant la saisie', (tester) async {
    final handle = tester.ensureSemantics();
    final announcements = _recordAnnouncements(tester);
    await _openCarbonaraQuiche(tester);

    const pates = 'Pâtes, 500${_nbsp}g, Épicerie salée';
    expect(
      tester.getSemantics(find.bySemanticsLabel(pates)),
      isSemantics(
        label: pates,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.bySemanticsLabel('Quantité de Pâtes, 500${_nbsp}g'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Quantité de Poivre, aucune'), findsOneWidget);

    tester.semantics.tap(find.semantics.byLabel(pates));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel(pates)),
      isSemantics(
        label: pates,
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
      ),
    );
    expect(announcements, ['Pâtes, non coché']);

    await tester.enterText(_field('Pâtes'), '400');
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Pâtes, 400${_nbsp}g, Épicerie salée'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Quantité de Pâtes, 400${_nbsp}g'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('clavier ouvert : « Ajouter à la liste » reste visible juste '
      'au-dessus et se touche sans fermer le clavier', (tester) async {
    await _openCarbonaraQuiche(tester);
    final closed = tester.getRect(_ajouterButton);
    expect(closed.bottom, lessThanOrEqualTo(1400));

    await tester.tap(_field('Œufs'));
    await tester.enterText(_field('Œufs'), '4');
    const keyboard = 600.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    final open = tester.getRect(_ajouterButton);
    expect(open.bottom, lessThanOrEqualTo(1400 - keyboard));
    expect(open.bottom, greaterThan(1400 - keyboard - KadiSpacing.s4 * 2));
    expect(open.size, closed.size);
    expect(_ajouterButton.hitTestable(), findsOneWidget);

    // Touché clavier ouvert : la saisie en cours est prise en compte.
    await tester.tap(_ajouterButton);
    await tester.pumpAndSettle();
    expect(find.byType(RevueScreen), findsNothing);
    expect(find.text('4${_nbsp}pièces'), findsOneWidget);
  });

  testWidgets('clavier fermé : le bouton revient à sa place', (tester) async {
    await _openCarbonaraQuiche(tester);
    final closed = tester.getRect(_ajouterButton);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    expect(tester.getRect(_ajouterButton), isNot(closed));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(_ajouterButton), closed);
  });

  testWidgets('retour depuis la Revue : rien n’est validé ni ajouté', (
    tester,
  ) async {
    final db = await pumpKadi(tester);
    await _openRecettes(tester);
    await _tapCard(tester, 'Chili con carne');
    await _validate(tester, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(_valider(1), findsOneWidget);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(
      (await db.select(db.weekSelections).getSingle()).validatedAt,
      isNull,
    );
  });

  testWidgets('échec de l’ajout : snackbar, la Revue reste', (tester) async {
    final db = await pumpKadi(
      tester,
      overrides: [ajouterALaListeProvider.overrideWithValue(_FailingAjouter())],
    );
    await _openRecettes(tester);
    await _tapCard(tester, 'Chili con carne');
    await _validate(tester, 1);

    await tester.tap(
      find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
    );
    await tester.pumpAndSettle();

    expect(find.text(StringsFr.ajoutImpossible), findsOneWidget);
    expect(find.byType(RevueScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
          )
          .onPressed,
      isNotNull,
    );
    expect(await db.select(db.listLines).get(), isEmpty);
  });

  for (final scale in [1.3, 2.0, 3.0]) {
    testWidgets('police ×$scale sur 360 dp : cartes et Revue sans '
        'débordement ni troncature', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await pumpKadi(tester);
      await _openRecettes(tester);
      expect(tester.takeException(), isNull);

      final chili = tester.getRect(_card('Chili con carne'));
      final carbonara = tester.getRect(_card('Pâtes carbonara'));
      expect(chili.height, carbonara.height);
      final name = tester.widget<Text>(find.text('Pâtes carbonara'));
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);

      await _tapCard(tester, 'Pâtes carbonara');
      await _validate(tester, 1);
      expect(tester.takeException(), isNull);
      expect(find.byType(RevueScreen), findsOneWidget);
      final button = tester.getSize(
        find.widgetWithText(FilledButton, StringsFr.ajouterALaListe),
      );
      expect(button.height, greaterThanOrEqualTo(KadiSpacing.touchTarget));

      // Ligne de Revue : coche et champ de 48 dp, nom entier, saisie sans
      // débordement.
      final check = find.descendant(
        of: _revueRow('Pâtes'),
        matching: find.byType(Checkbox),
      );
      await tester.scrollUntilVisible(
        _field('Œufs'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(RevueScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_field('Œufs')).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );
      final eggName = tester.widget<Text>(
        find.descendant(of: _revueRow('Œufs'), matching: find.text('Œufs')),
      );
      expect(eggName.maxLines, isNull);
      expect(eggName.overflow, isNull);
      await tester.enterText(_field('Œufs'), '999999');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        check,
        -100,
        scrollable: find
            .descendant(
              of: find.byType(RevueScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      // La cible de la coche : le carré de 48 dp qui la porte.
      expect(
        tester.getSize(
          find.ancestor(of: check, matching: find.byType(SizedBox)).first,
        ),
        const Size.square(KadiSpacing.touchTarget),
      );
    });
  }
}
