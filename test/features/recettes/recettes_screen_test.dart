import 'dart:ui' show SemanticsFlag;

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
import '../../helpers/recettes.dart';
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
Future<void> _openRecettes(WidgetTester tester) =>
    openTab(tester, StringsFr.tabRecettes);

/// Ouvre l'onglet Liste.
Future<void> _openListe(WidgetTester tester) =>
    openTab(tester, StringsFr.tabListe);

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

/// La coche ronde de la carte de [name].
Finder _cardCheck(String name) =>
    find.descendant(of: recipeCard(name), matching: find.byType(Checkbox));

/// La coche de la carte de [name] est-elle pleine ?
bool _cardChecked(WidgetTester tester, String name) =>
    tester.widget<Checkbox>(_cardCheck(name)).value!;

/// Touche la coche ronde de la carte de [name].
Future<void> _tapCardCheck(WidgetTester tester, String name) async {
  await tester.ensureVisible(_cardCheck(name));
  await tester.tap(_cardCheck(name));
  await tester.pumpAndSettle();
}

/// L'icône « modifier » de la carte de [name].
Finder _editButton(String name) =>
    find.byTooltip(StringsFr.modifierRecette(name));

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
  tallPhone(tester);
  final db = await pumpKadi(tester);
  await _openRecettes(tester);
  await tapRecipeCard(tester, 'Pâtes carbonara');
  await tapRecipeCard(tester, 'Quiche lorraine');
  await openRevue(tester, 2);
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
    final chili = tester.getRect(recipeCard('Chili con carne'));
    final carbonara = tester.getRect(recipeCard('Pâtes carbonara'));
    final quiche = tester.getRect(recipeCard('Quiche lorraine'));
    final ratatouille = tester.getRect(recipeCard('Ratatouille'));
    // Rangées de deux cartes de même hauteur, triées par nom.
    expect(chili.top, carbonara.top);
    expect(chili.height, carbonara.height);
    expect(chili.left, lessThan(carbonara.left));
    expect(quiche.top, greaterThan(chili.bottom));
    expect(quiche.top, ratatouille.top);
    expect(chili.width, carbonara.width);
    // Le picto de repli de l'ingrédient principal, 44 dp.
    final chiliPicto = find.descendant(
      of: recipeCard('Chili con carne'),
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

  testWidgets('sélectionner, désélectionner : coche ronde vide puis pleine, '
      'sans bordure, et Valider (n)', (tester) async {
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    // Chaque carte : coche ronde vide en haut à gauche du visuel, en
    // on-surface (jamais d'argile), cible de 48 dp ; la carte sans bordure.
    final scheme = Theme.of(tester.element(recipeCard('Chili con carne')))
        .colorScheme;
    for (final name in [
      'Chili con carne',
      'Pâtes carbonara',
      'Quiche lorraine',
      'Ratatouille',
    ]) {
      final check = tester.widget<Checkbox>(_cardCheck(name));
      expect(check.value, isFalse);
      expect(check.activeColor, scheme.onSurface);
      expect(check.side?.color, scheme.onSurface);
      expect(check.checkColor, scheme.surface);
      final card = tester.getRect(recipeCard(name));
      final target = tester.getRect(
        find
            .ancestor(of: _cardCheck(name), matching: find.byType(SizedBox))
            .first,
      );
      expect(target.size, const Size.square(KadiSpacing.touchTarget));
      expect(target.topLeft, card.topLeft);
      // Le nom, sous le visuel, n'est jamais masqué par la coche.
      expect(
        tester.getRect(find.text(name)).top,
        greaterThanOrEqualTo(target.bottom),
      );
    }
    Material cardMaterial(String name) => tester.widget<Material>(
      find.descendant(
        of: recipeCard(name),
        matching: find.byWidgetPredicate(
          (w) => w is Material && w.color == scheme.surfaceContainer,
        ),
      ),
    );
    expect(
      (cardMaterial('Chili con carne').shape! as RoundedRectangleBorder).side,
      BorderSide.none,
    );

    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    await tapRecipeCard(tester, 'Chili con carne');
    expect(
      find.bySemanticsLabel('Chili con carne, sélectionnée'),
      findsOneWidget,
    );
    expect(_cardChecked(tester, 'Chili con carne'), isTrue);
    expect(_cardChecked(tester, 'Ratatouille'), isFalse);
    // Sélectionnée : toujours sans bordure.
    expect(
      (cardMaterial('Chili con carne').shape! as RoundedRectangleBorder).side,
      BorderSide.none,
    );
    expect(validerButton(1), findsOneWidget);
    expect(await db.select(db.weekSelections).get(), hasLength(1));

    await tapRecipeCard(tester, 'Ratatouille');
    expect(validerButton(2), findsOneWidget);

    // Désélection d'une recette non validée, par TalkBack.
    tester.semantics.tap(
      find.semantics.byLabel('Chili con carne, sélectionnée'),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    expect(validerButton(1), findsOneWidget);
    await tapRecipeCard(tester, 'Ratatouille');
    expect(find.byType(FilledButton), findsNothing);
    // Une carte non validée se désélectionne sans snackbar.
    expect(find.byType(SnackBar), findsNothing);
    handle.dispose();
  });

  testWidgets('tap sur la coche : comme un tap sur la carte, une seule fois', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    await _tapCardCheck(tester, 'Chili con carne');
    expect(_cardChecked(tester, 'Chili con carne'), isTrue);
    expect(
      find.bySemanticsLabel('Chili con carne, sélectionnée'),
      findsOneWidget,
    );
    expect(validerButton(1), findsOneWidget);
    expect(await db.select(db.weekSelections).get(), hasLength(1));

    await _tapCardCheck(tester, 'Chili con carne');
    expect(_cardChecked(tester, 'Chili con carne'), isFalse);
    expect(
      find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      (await db.select(db.weekSelections).get()).where(
        (s) => s.deletedAt == null,
      ),
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('TalkBack : la coche n’ajoute aucun nœud lu, la carte garde '
      'sa lecture et son tap', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpKadi(tester);
    await _openRecettes(tester);

    expect(find.semantics.byFlag(SemanticsFlag.hasCheckedState), findsNothing);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Chili con carne, non sélectionnée'),
      ),
      isSemantics(
        label: 'Chili con carne, non sélectionnée',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tapRecipeCard(tester, 'Chili con carne');
    expect(find.semantics.byFlag(SemanticsFlag.hasCheckedState), findsNothing);
    expect(
      find.bySemanticsLabel('Chili con carne, sélectionnée'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('icône « modifier » : 18 dp, on-surface-variant, sans fond, '
      'cible de 48 dp ; ouvre la fiche sans changer la sélection', (
    tester,
  ) async {
    final db = await pumpKadi(tester);
    await _openRecettes(tester);

    final edit = _editButton('Chili con carne');
    expect(tester.getSize(edit), const Size.square(KadiSpacing.touchTarget));
    final icon = find.descendant(
      of: edit,
      matching: find.byIcon(Icons.edit_outlined),
    );
    final size = tester.getSize(icon);
    expect(size.width, lessThanOrEqualTo(18));
    expect(size.height, lessThanOrEqualTo(18));
    final scheme = Theme.of(tester.element(edit)).colorScheme;
    expect(tester.widget<Icon>(icon).color, scheme.onSurfaceVariant);
    // Sans photo : ni fond de bouton, ni disque.
    final button = tester.widget<IconButton>(
      find.ancestor(of: edit, matching: find.byType(IconButton)),
    );
    expect(button.style?.backgroundColor, isNull);
    expect(recipeCardDiscs('Chili con carne'), findsNothing);

    await editRecipe(tester, 'Chili con carne');
    await backFromFiche(tester);
    expect(_cardChecked(tester, 'Chili con carne'), isFalse);
    expect(await db.select(db.weekSelections).get(), isEmpty);
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
    await tapRecipeCard(tester, 'Pâtes carbonara');
    await tapRecipeCard(tester, 'Quiche lorraine');
    await openRevue(tester, 2);

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

    // Ratatouille seule en Revue.
    await tapRecipeCard(tester, 'Ratatouille');
    await openRevue(tester, 1);
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
    expect(validerButton(2), findsOneWidget);
    expect(await db.select(db.listLines).get(), isEmpty);
    expect(
      (await db.select(db.weekSelections).get()).every(
        (s) => s.validatedAt == null,
      ),
      isTrue,
    );

    // Le brouillon est mort avec l'écran.
    await openRevue(tester, 2);
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
    await tapRecipeCard(tester, 'Chili con carne');
    await openRevue(tester, 1);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RevueScreen), findsNothing);
    expect(validerButton(1), findsOneWidget);
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
    await tapRecipeCard(tester, 'Chili con carne');
    await openRevue(tester, 1);

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

  group('désélectionner une recette validée (R6)', () {
    final undoAction = find.widgetWithText(SnackBarAction, StringsFr.annuler);
    final carbonaraRetiree = StringsFr.ingredientsRetires('Pâtes carbonara');
    const lardons400 = 'Lardons, 400${_nbsp}g, Viande et poisson';
    const lardons200 = 'Lardons, 200${_nbsp}g, Viande et poisson';

    /// Carbonara et Quiche validées (Lardons 400 g dans la Liste), puis
    /// retour sur Recettes.
    Future<AppDatabase> validatedCarbonaraQuiche(WidgetTester tester) async {
      final db = await _openCarbonaraQuiche(tester);
      await tester.tap(_ajouterButton);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(lardons400), findsOneWidget);
      await _openRecettes(tester);
      return db;
    }

    Future<void> letSnackBarClose(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('toucher Carbonara validée : plus de coche, « Lardons 200 g » '
        'dans la Liste, snackbar annoncé ; Annuler : resélectionnée sans '
        'Valider, « Lardons 400 g »', (tester) async {
      final handle = tester.ensureSemantics();
      await validatedCarbonaraQuiche(tester);

      // Par TalkBack : la carte est activable et relue après le tap.
      tester.semantics.tap(
        find.semantics.byLabel('Pâtes carbonara, sélectionnée'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Pâtes carbonara, non sélectionnée'),
        findsOneWidget,
      );
      expect(_cardChecked(tester, 'Pâtes carbonara'), isFalse);
      expect(
        find.bySemanticsLabel('Quiche lorraine, sélectionnée'),
        findsOneWidget,
      );
      expect(
        carbonaraRetiree,
        'Ingrédients de «${_nbsp}Pâtes carbonara$_nbsp» retirés de la liste',
      );
      expect(find.text(carbonaraRetiree), findsOneWidget);
      expect(undoAction, findsOneWidget);
      // Snackbar annoncé par TalkBack (région dynamique).
      expect(
        tester.getSemantics(find.text(carbonaraRetiree)),
        isSemantics(isLiveRegion: true),
      );
      // Aucune recette à valider : pas de Bouton d'action.
      expect(find.byType(FilledButton), findsNothing);

      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons200), findsOneWidget);
      expect(find.text('Pâtes'), findsNothing);
      expect(find.text('Poivre'), findsNothing);

      await _openRecettes(tester);
      expect(undoAction, findsOneWidget);
      await tester.tap(undoAction);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Pâtes carbonara, sélectionnée'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons400), findsOneWidget);
      expect(find.text('Pâtes'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('snackbar au-dessus de « Valider (1) » ; ensuite, Ratatouille '
        'validée : la Revue n’en montre que les ingrédients (Flux 5)', (
      tester,
    ) async {
      await validatedCarbonaraQuiche(tester);
      await tapRecipeCard(tester, 'Ratatouille');
      await tapRecipeCard(tester, 'Pâtes carbonara');

      expect(find.text(carbonaraRetiree), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(SnackBar)).dy,
        lessThanOrEqualTo(tester.getTopLeft(validerButton(1)).dy),
      );

      await openRevue(tester, 1);
      expect(find.byType(RevueScreen), findsOneWidget);
      expect(find.byType(RevueRow), findsNWidgets(7));
      expect(find.text('Courgettes'), findsOneWidget);
      expect(find.text('Lardons'), findsNothing);
      expect(find.text('Pâtes'), findsNothing);
    });

    testWidgets('tap sur la coche de Carbonara validée : même désélection, '
        'un seul snackbar ; Annuler la resélectionne', (tester) async {
      await validatedCarbonaraQuiche(tester);
      await _tapCardCheck(tester, 'Pâtes carbonara');

      expect(_cardChecked(tester, 'Pâtes carbonara'), isFalse);
      expect(find.text(carbonaraRetiree), findsOneWidget);
      expect(undoAction, findsOneWidget);
      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons200), findsOneWidget);

      await _openRecettes(tester);
      await tester.tap(undoAction);
      await tester.pumpAndSettle();
      expect(_cardChecked(tester, 'Pâtes carbonara'), isTrue);
      expect(find.byType(FilledButton), findsNothing);
      await _openListe(tester);
      expect(find.bySemanticsLabel(lardons400), findsOneWidget);
    });

    testWidgets('fin du snackbar : plus d’Annuler, la carte reste '
        'désélectionnée', (tester) async {
      final db = await validatedCarbonaraQuiche(tester);
      await tapRecipeCard(tester, 'Pâtes carbonara');
      await letSnackBarClose(tester);

      expect(find.text(carbonaraRetiree), findsNothing);
      expect(
        (await db.select(db.weekSelections).get()).where(
          (s) => s.deletedAt == null,
        ),
        hasLength(1),
      );
    });

    testWidgets('échec : snackbar d’erreur, rien d’écrit, carte toujours '
        'sélectionnée', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await validatedCarbonaraQuiche(tester);
      final lines = await db.select(db.listLines).get();
      final selections = await db.select(db.weekSelections).get();
      await db.customStatement(
        'CREATE TRIGGER no_deselect BEFORE UPDATE OF deleted_at ON '
        "week_selections BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await tapRecipeCard(tester, 'Pâtes carbonara');

      expect(find.text(StringsFr.modificationImpossible), findsOneWidget);
      expect(find.text(carbonaraRetiree), findsNothing);
      expect(
        find.bySemanticsLabel('Pâtes carbonara, sélectionnée'),
        findsOneWidget,
      );
      expect(await db.select(db.listLines).get(), lines);
      expect(await db.select(db.weekSelections).get(), selections);
      await letSnackBarClose(tester);
      handle.dispose();
    });
  });

  group('Nouvelle liste (R8) et Terminer les courses (R10)', () {
    final action = find.widgetWithText(TextButton, StringsFr.nouvelleListe);
    final garder = find.widgetWithText(TextButton, StringsFr.garder);
    final effacer = find.widgetWithText(
      TextButton,
      StringsFr.effacerEtRecommencer,
    );

    /// Coche la ligne de la Liste de [name].
    Future<void> checkOnListe(WidgetTester tester, String name) async {
      final box = find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(ItemRow)),
        matching: find.byType(Checkbox),
      );
      await tester.ensureVisible(box.first);
      await tester.tap(box.first);
      await tester.pumpAndSettle();
    }

    /// Carbonara et Quiche validées, Lardons cochés dans la Liste, Chili
    /// sélectionnée non validée ; Recettes ouverte.
    Future<AppDatabase> semaineEnCours(WidgetTester tester) async {
      final db = await _openCarbonaraQuiche(tester);
      await tester.tap(_ajouterButton);
      await tester.pumpAndSettle();
      await checkOnListe(tester, 'Lardons');
      await _openRecettes(tester);
      await tapRecipeCard(tester, 'Chili con carne');
      expect(validerButton(1), findsOneWidget);
      return db;
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    /// Les trois tables touchées par Nouvelle liste.
    Future<List<Object>> snapshot(AppDatabase db) async => [
      ...await db.select(db.listLines).get(),
      ...await db.select(db.listContributions).get(),
      ...await db.select(db.weekSelections).get(),
    ];

    testWidgets('action texte de la Barre d’application, on-surface, 48 dp, '
        'lue « Nouvelle liste » ; dialogue avec ses textes et couleurs', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpKadi(tester);
      await _openRecettes(tester);

      expect(
        find.descendant(of: find.byType(AppBar), matching: action),
        findsOneWidget,
      );
      final size = tester.getSize(action);
      expect(size.height, greaterThanOrEqualTo(KadiSpacing.touchTarget));
      expect(size.width, greaterThanOrEqualTo(KadiSpacing.touchTarget));
      final scheme = Theme.of(tester.element(action)).colorScheme;
      final label = tester.widget<RichText>(
        find.descendant(of: action, matching: find.byType(RichText)),
      );
      expect(label.text.style?.color, scheme.onSurface);
      expect(label.text.style?.color, isNot(scheme.primary));
      expect(
        tester.getSemantics(find.bySemanticsLabel(StringsFr.nouvelleListe)),
        isSemantics(
          label: StringsFr.nouvelleListe,
          isButton: true,
          hasTapAction: true,
        ),
      );

      // Toujours visible, même sans sélection ni liste.
      await openDialog(tester);
      expect(find.text(StringsFr.nouvelleListeTitre), findsOneWidget);
      expect(find.text(StringsFr.nouvelleListeTexte), findsOneWidget);
      expect(garder, findsOneWidget);
      expect(effacer, findsOneWidget);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, scheme.surfaceContainer);
      Color? colorOf(Finder button) => tester
          .widget<RichText>(
            find.descendant(of: button, matching: find.byType(RichText)),
          )
          .text
          .style
          ?.color;
      expect(colorOf(garder), scheme.onSurface);
      expect(colorOf(effacer), scheme.error);
      expect(
        tester.getSize(garder).height,
        greaterThanOrEqualTo(KadiSpacing.touchTarget),
      );

      // Déjà vide : rien à effacer, pas d'erreur.
      await tester.tap(effacer);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      handle.dispose();
    });

    testWidgets('Effacer et recommencer : aucune carte sélectionnée, pas de '
        '« Valider », pas d’Annuler, la Liste vide', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await semaineEnCours(tester);

      await openDialog(tester);
      await tester.tap(effacer);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      for (final name in [
        'Chili con carne',
        'Pâtes carbonara',
        'Quiche lorraine',
        'Ratatouille',
      ]) {
        expect(
          find.bySemanticsLabel('$name, non sélectionnée'),
          findsOneWidget,
        );
      }
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(RecipeCard), findsNWidgets(4));
      final selections = await db.select(db.weekSelections).get();
      expect(selections.every((s) => s.deletedAt != null), isTrue);

      await _openListe(tester);
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.byType(ItemRow), findsNothing);
      expect(find.textContaining('Cochés'), findsNothing);
      handle.dispose();
    });

    testWidgets('Garder, retour Android, tap hors du dialogue : rien ne '
        'change', (tester) async {
      final db = await semaineEnCours(tester);
      final before = await snapshot(db);

      await openDialog(tester);
      await tester.tap(garder);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await openDialog(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await openDialog(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      expect(await snapshot(db), before);
      expect(_cardChecked(tester, 'Pâtes carbonara'), isTrue);
      expect(validerButton(1), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // Toujours sur Recettes.
      expect(find.byType(RecipeCard), findsNWidgets(4));
    });

    testWidgets('échec : snackbar d’erreur sur Recettes, rien d’écrit', (
      tester,
    ) async {
      final db = await semaineEnCours(tester);
      final before = await snapshot(db);
      await db.customStatement(
        'CREATE TRIGGER no_clear BEFORE UPDATE OF deleted_at ON '
        "week_selections BEGIN SELECT RAISE(ABORT, 'échec simulé'); END",
      );

      await openDialog(tester);
      await tester.tap(effacer);
      await tester.pumpAndSettle();

      expect(find.text(StringsFr.nouvelleListeImpossible), findsOneWidget);
      expect(await snapshot(db), before);
      expect(validerButton(1), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('police ×2 sur 360 dp : action et dialogue entiers, sans '
        'débordement', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await pumpKadi(tester);
      await _openRecettes(tester);
      expect(tester.takeException(), isNull);
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getRect(action).right, lessThanOrEqualTo(360));

      await openDialog(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(StringsFr.nouvelleListeTexte), findsOneWidget);
      expect(garder.hitTestable(), findsOneWidget);
      expect(effacer.hitTestable(), findsOneWidget);
      await tester.tap(garder);
      await tester.pumpAndSettle();
    });

    testWidgets('Liste → Terminer les courses : cartes désélectionnées ; '
        'Annuler : lignes cochées et cartes de nouveau sélectionnées, sans '
        '« Valider »', (tester) async {
      final handle = tester.ensureSemantics();
      await _openCarbonaraQuiche(tester);
      await tester.tap(_ajouterButton);
      await tester.pumpAndSettle();
      final names = [
        for (final row in tester.widgetList<ItemRow>(find.byType(ItemRow)))
          row.item.name,
      ];
      expect(names, hasLength(8));
      for (final name in names) {
        await checkOnListe(tester, name);
      }
      final terminer = find.widgetWithText(
        FilledButton,
        StringsFr.terminerLesCourses,
      );
      await tester.tap(terminer);
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.listeVide), findsOneWidget);
      expect(find.text(StringsFr.coursesTerminees), findsOneWidget);

      await _openRecettes(tester);
      expect(
        find.bySemanticsLabel('Pâtes carbonara, non sélectionnée'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Quiche lorraine, non sélectionnée'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);

      await _openListe(tester);
      await tester.tap(find.widgetWithText(SnackBarAction, StringsFr.annuler));
      await tester.pumpAndSettle();
      expect(find.text(StringsFr.listeVide), findsNothing);
      expect(find.text(StringsFr.cochesTitre(8)), findsOneWidget);
      expect(terminer, findsOneWidget);

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
      handle.dispose();
    });
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

      final chili = tester.getRect(recipeCard('Chili con carne'));
      final carbonara = tester.getRect(recipeCard('Pâtes carbonara'));
      expect(chili.height, carbonara.height);
      final name = tester.widget<Text>(find.text('Pâtes carbonara'));
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);
      // Coche au-dessus du nom, jamais sur lui ; icône « modifier » toujours
      // de 18 dp dans sa cible de 48 dp.
      final checkTarget = tester.getRect(
        find
            .ancestor(
              of: _cardCheck('Pâtes carbonara'),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        tester.getRect(find.text('Pâtes carbonara')).top,
        greaterThanOrEqualTo(checkTarget.bottom),
      );
      expect(
        tester.getSize(_editButton('Pâtes carbonara')),
        const Size.square(KadiSpacing.touchTarget),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: _editButton('Pâtes carbonara'),
                matching: find.byIcon(Icons.edit_outlined),
              ),
            )
            .width,
        lessThanOrEqualTo(18),
      );

      await _tapCardCheck(tester, 'Pâtes carbonara');
      expect(_cardChecked(tester, 'Pâtes carbonara'), isTrue);
      await _tapCardCheck(tester, 'Pâtes carbonara');
      await tapRecipeCard(tester, 'Pâtes carbonara');
      await openRevue(tester, 1);
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
