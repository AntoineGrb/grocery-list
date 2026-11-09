import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/ui/recipe_monogram.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/data/recipe_photos.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/recettes.dart';
import '../../helpers/test_db.dart';

/// Image PNG de 1 × 1 px, lisible par le décodeur.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Photos de recette dans un dossier temporaire, en E/S synchrones (la zone
/// de test des widgets n'attend pas les E/S asynchrones). Les noms sont
/// tirés dans l'ordre : `photo-1.jpg`, `photo-2.jpg`…
class _TempPhotos extends RecipePhotos {
  _TempPhotos(this.documents) : super(() async => documents);

  final Directory documents;
  var _count = 0;

  Directory get dir =>
      Directory('${documents.path}${Platform.pathSeparator}photos');

  /// Noms des fichiers présents dans `photos/`.
  Set<String> get files => dir.existsSync()
      ? {
          for (final f in dir.listSync().whereType<File>())
            f.uri.pathSegments.last,
        }
      : {};

  @override
  Future<String> importPhoto(String sourcePath) async {
    dir.createSync(recursive: true);
    final name = 'photo-${++_count}.jpg';
    File(sourcePath).copySync(RecipePhotos.fileIn(dir, name).path);
    return name;
  }

  @override
  Future<void> delete(String name) async {
    final file = RecipePhotos.fileIn(dir, name);
    if (file.existsSync()) file.deleteSync();
  }
}

/// Faux sélecteur : rend tour à tour les chemins de [results] (`null` =
/// annulé) et note les sources demandées.
class _FakePicker {
  final results = <String?>[];
  final sources = <PhotoSource>[];

  /// Choix en attente : le sélecteur rend son résultat quand il est
  /// complété.
  Completer<String?>? pending;

  Future<String?> call(PhotoSource source) async {
    sources.add(source);
    final wait = pending;
    if (wait != null) return wait.future;
    return results.removeAt(0);
  }
}

/// Dépôt dont « Enregistrer » attend [hold] avant d'écrire.
class _SlowSaveRepository extends RecettesRepository {
  _SlowSaveRepository(super.db, super.clock);

  Completer<void>? hold;

  @override
  Future<bool> saveDraft(RecipeDraft draft) async {
    await hold?.future;
    return super.saveDraft(draft);
  }
}

/// Faux navigateur : note les adresses, rend [result] ou lève.
class _FakeBrowser {
  final opened = <Uri>[];
  bool result = true;
  bool fails = false;

  Future<bool> call(Uri uri) async {
    opened.add(uri);
    if (fails) throw StateError('échec simulé');
    return result;
  }
}

class _Env {
  _Env(this.db, this.photos, this.picker, this.browser, this.source);
  final AppDatabase db;
  final _TempPhotos photos;
  final _FakePicker picker;
  final _FakeBrowser browser;

  /// Image « choisie » par le faux sélecteur.
  final File source;
}

/// Kadi sur un téléphone haut, onglet Recettes ouvert ; photos, sélecteur
/// et navigateur remplacés.
Future<_Env> _openRecettes(
  WidgetTester tester, {
  Size size = const Size(400, 1400),
  List<Override> overrides = const [],
}) async {
  tallPhone(tester, size);
  final documents = Directory.systemTemp.createTempSync('kadi_fiche_');
  addTearDown(() {
    try {
      documents.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows : un fichier encore ouvert par le décodeur d'image.
    }
  });
  final source = File('${documents.path}${Platform.pathSeparator}pick.png')
    ..writeAsBytesSync(_png);
  final photos = _TempPhotos(documents);
  final picker = _FakePicker();
  final browser = _FakeBrowser();
  final db = await pumpKadi(
    tester,
    overrides: [
      recipePhotosProvider.overrideWithValue(photos),
      photoPickerProvider.overrideWithValue(picker.call),
      openLinkProvider.overrideWithValue(browser.call),
      ...overrides,
    ],
  );
  await openTab(tester, StringsFr.tabRecettes);
  return _Env(db, photos, picker, browser, source);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// La pastille appareil photo du monogramme de la fiche.
Finder get _badge => find.byKey(recipePhotoBadgeKey);

/// Pastille appareil photo, puis [source] dans la feuille. [action] ne sert
/// plus : la pastille ajoute ou remplace.
Future<void> _pick(
  WidgetTester tester, {
  String action = StringsFr.ajouterUnePhoto,
  String source = StringsFr.galerie,
}) async {
  await _tap(tester, _badge);
  expect(find.text(StringsFr.galerie), findsOneWidget);
  await tester.tap(find.text(source));
  await tester.pumpAndSettle();
}

/// Pastille appareil photo, puis « Retirer la photo ».
Future<void> _removePhoto(WidgetTester tester) async {
  await _tap(tester, _badge);
  await tester.tap(find.text(StringsFr.retirerLaPhoto));
  await tester.pumpAndSettle();
}

/// Lien de la fiche par son dialogue : [text] saisi, puis OK.
Future<void> _setLink(WidgetTester tester, String text) async {
  final add = find.text(StringsFr.ajouterUnLien);
  await _tap(
    tester,
    add.evaluate().isNotEmpty ? add : find.byIcon(Icons.link).first,
  );
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.tap(find.text(StringsFr.ok));
  await tester.pumpAndSettle();
}

Finder get _openLink => find.byTooltip(StringsFr.ouvrirLeLien);

/// Photo dans le monogramme de la fiche.
Finder get _preview => find.descendant(
  of: find.byType(FicheRecetteScreen),
  matching: find.byType(Image),
);

/// Photo de la carte de [name], nulle sur le visuel de repli.
Image? _cardImage(WidgetTester tester, String name) {
  final images = find.descendant(
    of: recipeCard(name),
    matching: find.byType(Image),
  );
  return images.evaluate().isEmpty ? null : tester.widget<Image>(images);
}

/// Le monogramme de repli de la ligne de [name] (sans photo).
Finder _cardPicto(String name) => find.descendant(
  of: recipeCard(name),
  matching: find.text(recipeInitials(name)),
);

/// Laisse les E/S réelles de lecture d'image finir, puis reconstruit.
Future<void> _loadImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Galerie : aperçu dans la fiche, photos/<nom> écrit, la carte '
      '« Chili con carne » montre la photo', (tester) async {
    final env = await _openRecettes(tester);
    expect(_cardImage(tester, 'Chili con carne'), isNull);
    expect(_cardPicto('Chili con carne'), findsOneWidget);

    await editRecipe(tester, 'Chili con carne');
    expect(_preview, findsNothing);
    env.picker.results.add(env.source.path);
    await _pick(tester);

    expect(env.picker.sources, [PhotoSource.galerie]);
    expect(_preview, findsOneWidget);
    expect(env.photos.files, {'photo-1.jpg'});
    // Rien d'écrit avant « Enregistrer ».
    expect((await recipeNamed(env.db, 'Chili con carne'))!.photo, isNull);

    await saveFiche(tester);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );
    final image = _cardImage(tester, 'Chili con carne')!;
    final resized = image.image as ResizeImage;
    expect(
      (resized.imageProvider as FileImage).file.path,
      RecipePhotos.fileIn(env.photos.dir, 'photo-1.jpg').path,
    );
    expect(image.fit, BoxFit.cover);
    // La photo remplace le monogramme, recadrée sur ses 56 dp, décodée à
    // la taille d'affichage et non aux 1600 px stockés.
    final shown = tester.getSize(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.byType(Image),
      ),
    );
    expect(shown, const Size.square(56));
    expect(resized.width, lessThan(1600));
    expect(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.text('Cc'),
      ),
      findsNothing,
    );
    // Le fichier reste après la fermeture : la base le porte.
    expect(env.photos.files, {'photo-1.jpg'});
  });

  testWidgets('choix annulé : rien ne change', (tester) async {
    final env = await _openRecettes(tester);
    final before = await env.db.select(env.db.recipes).get();
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add(null);
    await _pick(tester, source: StringsFr.appareilPhoto);

    expect(env.picker.sources, [PhotoSource.appareilPhoto]);
    expect(_preview, findsNothing);
    expect(env.photos.files, isEmpty);
    expect(await env.db.select(env.db.recipes).get(), before);

    // Feuille fermée sans choix : le sélecteur n'est pas ouvert.
    await _tap(tester, _badge);
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.galerie), findsNothing);
    expect(env.picker.sources, hasLength(1));
  });

  testWidgets('Remplacer : B choisie, A reste jusqu’à « Enregistrer » ; '
      'enregistrée, la base porte B et le fichier A est supprimé', (
    tester,
  ) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.addAll([env.source.path, env.source.path]);
    await _pick(tester);
    await saveFiche(tester);
    expect(env.photos.files, {'photo-1.jpg'});

    await editRecipe(tester, 'Chili con carne');
    await _pick(
      tester,
      action: StringsFr.remplacer,
      source: StringsFr.appareilPhoto,
    );
    expect(env.picker.sources, [
      PhotoSource.galerie,
      PhotoSource.appareilPhoto,
    ]);
    // A est encore celle de la base.
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );
    expect(env.photos.files, {'photo-1.jpg', 'photo-2.jpg'});

    await saveFiche(tester);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-2.jpg',
    );
    expect(env.photos.files, {'photo-2.jpg'});
  });

  testWidgets('Retirer : la photo reste jusqu’à « Enregistrer » ; '
      'enregistrée, photo nulle, fichier supprimé, la carte revient au '
      'picto de repli', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add(env.source.path);
    await _pick(tester);
    await saveFiche(tester);
    expect(_cardImage(tester, 'Chili con carne'), isNotNull);

    await editRecipe(tester, 'Chili con carne');
    // Photo lue de la base : son aperçu est là.
    expect(_preview, findsOneWidget);
    await _removePhoto(tester);
    expect(_preview, findsNothing);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );
    expect(env.photos.files, {'photo-1.jpg'});

    await saveFiche(tester);
    expect((await recipeNamed(env.db, 'Chili con carne'))!.photo, isNull);
    expect(env.photos.files, isEmpty);
    expect(_cardImage(tester, 'Chili con carne'), isNull);
    expect(_cardPicto('Chili con carne'), findsOneWidget);
  });

  testWidgets('photo abandonnée : remplacée avant « Enregistrer », ou fiche '
      'quittée, son fichier est supprimé et l’ancienne reste ; nouvelle '
      'fiche enregistrée avec sa photo', (tester) async {
    final env = await _openRecettes(tester);
    final count = (await env.db.select(env.db.recipes).get()).length;

    // Nouvelle fiche : A puis B, quittée : pas de recette, aucun fichier.
    await tester.tap(find.byTooltip(StringsFr.nouvelleRecette));
    await tester.pumpAndSettle();
    await tester.enterText(ficheNameField, 'Soupe');
    await tester.pumpAndSettle();
    env.picker.results.addAll([env.source.path, env.source.path]);
    await _pick(tester);
    await _pick(tester, action: StringsFr.remplacer);
    // A, jamais écrite, est supprimée dès le remplacement.
    expect(env.photos.files, {'photo-2.jpg'});
    await quitFiche(tester);
    expect(await env.db.select(env.db.recipes).get(), hasLength(count));
    expect(env.photos.files, isEmpty);

    // Photo d'abord, puis nom et ingrédient, « Enregistrer » : créée avec
    // sa photo.
    await tester.tap(find.byTooltip(StringsFr.nouvelleRecette));
    await tester.pumpAndSettle();
    env.picker.results.add(env.source.path);
    await _pick(tester);
    await tester.enterText(ficheNameField, 'Soupe');
    await tester.pumpAndSettle();
    await addIngredientBySheet(tester, 'riz', 'Riz');
    expect(await recipeNamed(env.db, 'Soupe'), isNull);
    await saveFiche(tester);
    expect((await recipeNamed(env.db, 'Soupe'))!.photo, 'photo-3.jpg');
    expect(env.photos.files, {'photo-3.jpg'});
    expect(_cardImage(tester, 'Soupe'), isNotNull);

    // Recette avec photo : une autre choisie, puis Quitter : la nouvelle
    // est supprimée, l'ancienne reste en base et sur le disque.
    await editRecipe(tester, 'Soupe');
    env.picker.results.add(env.source.path);
    await _pick(tester, action: StringsFr.remplacer);
    expect(env.photos.files, {'photo-3.jpg', 'photo-4.jpg'});
    await quitFiche(tester);
    expect((await recipeNamed(env.db, 'Soupe'))!.photo, 'photo-3.jpg');
    expect(env.photos.files, {'photo-3.jpg'});

    // Photo retirée, puis Quitter : la photo reste.
    await editRecipe(tester, 'Soupe');
    await _removePhoto(tester);
    await quitFiche(tester);
    expect((await recipeNamed(env.db, 'Soupe'))!.photo, 'photo-3.jpg');
    expect(env.photos.files, {'photo-3.jpg'});
  });

  testWidgets('échec de la copie : snackbar d’erreur, rien d’écrit', (
    tester,
  ) async {
    final env = await _openRecettes(tester);
    final before = await env.db.select(env.db.recipes).get();
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add('${env.photos.documents.path}/absente.png');
    await _pick(tester);

    expect(find.text(StringsFr.photoImpossible), findsOneWidget);
    expect(_preview, findsNothing);
    expect(await env.db.select(env.db.recipes).get(), before);
    expect(env.photos.files, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('fichier perdu : la carte montre le picto de repli, sans '
      'erreur', (tester) async {
    final env = await _openRecettes(tester);
    await (env.db.update(env.db.recipes)
          ..where((r) => r.id.equals(SeedRecipeIds.chili)))
        .write(const RecipesCompanion(photo: Value('perdue.jpg')));
    await tester.pumpAndSettle();
    expect(_cardImage(tester, 'Chili con carne'), isNotNull);
    await _loadImages(tester);
    expect(tester.takeException(), isNull);
    expect(_cardPicto('Chili con carne'), findsOneWidget);

    // La fiche aussi s'ouvre sans erreur.
    await editRecipe(tester, 'Chili con carne');
    await _loadImages(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lien : « Ajouter un lien » par le dialogue, domaine montré, '
      'l’icône ouvre https://… ; enregistré nettoyé ; vidé, lien nul', (
    tester,
  ) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    expect(_openLink, findsNothing);
    expect(find.text(StringsFr.ajouterUnLien), findsOneWidget);

    await _setLink(tester, ' marmiton.org/chili ');
    expect((await recipeNamed(env.db, 'Chili con carne'))!.link, isNull);
    expect(find.text('marmiton.org'), findsOneWidget);
    expect(_openLink, findsOneWidget);
    await _tap(tester, _openLink);
    expect(env.browser.opened, [Uri.parse('https://marmiton.org/chili')]);
    expect(find.text(StringsFr.lienImpossible), findsNothing);

    await saveFiche(tester);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.link,
      'marmiton.org/chili',
    );
    await editRecipe(tester, 'Chili con carne');
    await _setLink(tester, '');
    expect(_openLink, findsNothing);
    expect(find.text(StringsFr.ajouterUnLien), findsOneWidget);
    await saveFiche(tester);
    expect((await recipeNamed(env.db, 'Chili con carne'))!.link, isNull);
  });

  testWidgets('Lien qui ne s’ouvre pas : snackbar « Impossible d’ouvrir le '
      'lien. »', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    await _setLink(tester, 'https://exemple.fr');

    env.browser.result = false;
    await _tap(tester, _openLink);
    expect(find.text(StringsFr.lienImpossible), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    env.browser.fails = true;
    await _tap(tester, _openLink);
    expect(find.text(StringsFr.lienImpossible), findsOneWidget);
    expect(env.browser.opened, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('TalkBack : pastille « Ajouter une photo », puis « Remplacer la '
      'photo » ; « Galerie », « Appareil photo », « Retirer la photo » ; '
      '« Ouvrir le lien »', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    expect(
      tester.getSemantics(find.bySemanticsLabel(StringsFr.ajouterUnePhoto)),
      isSemantics(
        label: StringsFr.ajouterUnePhoto,
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel(StringsFr.ajouterUnePhoto));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(StringsFr.galerie), findsOneWidget);
    expect(find.bySemanticsLabel(StringsFr.appareilPhoto), findsOneWidget);
    env.picker.results.add(env.source.path);
    await tester.tap(find.text(StringsFr.galerie));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(StringsFr.remplacerLaPhoto), findsOneWidget);
    await _tap(tester, _badge);
    expect(find.bySemanticsLabel(StringsFr.retirerLaPhoto), findsOneWidget);
    await tester.tap(find.text(StringsFr.retirerLaPhoto));
    await tester.pumpAndSettle();
    expect(_preview, findsNothing);

    await _setLink(tester, 'marmiton.org');
    expect(
      tester.getSemantics(_openLink),
      isSemantics(
        tooltip: StringsFr.ouvrirLeLien,
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('police ×$scale sur 360 dp : en-tête, photo et lien sans '
        'débordement', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = await _openRecettes(tester, size: const Size(360, 800));
      await editRecipe(tester, 'Chili con carne');
      expect(tester.takeException(), isNull);
      env.picker.results.add(env.source.path);
      await _pick(tester);
      expect(tester.takeException(), isNull);
      await _setLink(
        tester,
        'https://www.marmiton.org/recettes/recette_chili-con-carne.aspx',
      );
      expect(tester.takeException(), isNull);
      expect(_openLink.hitTestable(), findsOneWidget);
    });
  }
  testWidgets('photo choisie puis « Supprimer la recette » : la photo, non '
      'enregistrée, est abandonnée ; Annuler rend la carte telle qu’en '
      'base', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add(env.source.path);
    await _pick(tester);

    await _tap(tester, find.byTooltip(StringsFr.plusDOptions));
    await _tap(tester, find.text(StringsFr.supprimerLaRecette));

    expect(find.byType(FicheRecetteScreen), findsNothing);
    expect(recipeCard('Chili con carne'), findsNothing);
    final recipe = await (env.db.select(
      env.db.recipes,
    )..where((r) => r.name.equals('Chili con carne'))).getSingle();
    expect((recipe.photo, recipe.deletedAt != null), (null, true));
    expect(env.photos.files, isEmpty);

    await tester.tap(find.widgetWithText(SnackBarAction, StringsFr.annuler));
    await tester.pumpAndSettle();
    expect(recipeCard('Chili con carne'), findsOneWidget);
    expect(_cardImage(tester, 'Chili con carne'), isNull);
  });

  testWidgets('choix de photo en cours : « Enregistrer » grisé, le retour '
      'demande confirmation ; la photo arrivée, il revient', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    expect(saveEnabled(tester), isTrue);

    final pending = env.picker.pending = Completer<String?>();
    await _pick(tester);
    expect(saveEnabled(tester), isFalse);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(quitDialog, findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, StringsFr.garder));
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsOneWidget);

    pending.complete(env.source.path);
    await tester.pumpAndSettle();
    expect(_preview, findsOneWidget);
    expect(saveEnabled(tester), isTrue);
    await saveFiche(tester);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );
    expect(env.photos.files, {'photo-1.jpg'});
  });

  testWidgets('pendant « Enregistrer » : la fiche est inerte, « Retirer la '
      'photo » (toucher ou TalkBack) ne fait rien ; la photo est écrite', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    late _SlowSaveRepository repository;
    final env = await _openRecettes(
      tester,
      overrides: [
        recettesRepositoryProvider.overrideWith(
          (ref) => repository = _SlowSaveRepository(
            ref.watch(databaseProvider),
            ref.watch(clockProvider),
          ),
        ),
      ],
    );
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add(env.source.path);
    await _pick(tester);

    final hold = repository.hold = Completer<void>();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.tap(_badge, warnIfMissed: false);
    await tester.pumpAndSettle();
    // TalkBack : l'action est bloquée pendant l'écriture.
    expect(
      () => tester.semantics.tap(
        find.semantics.byLabel(StringsFr.remplacerLaPhoto),
      ),
      throwsStateError,
    );
    await tester.pumpAndSettle();
    expect(find.text(StringsFr.retirerLaPhoto), findsNothing);
    expect(_preview, findsOneWidget);
    expect(env.photos.files, {'photo-1.jpg'});

    hold.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FicheRecetteScreen), findsNothing);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );
    expect(env.photos.files, {'photo-1.jpg'});
    handle.dispose();
  });
}
