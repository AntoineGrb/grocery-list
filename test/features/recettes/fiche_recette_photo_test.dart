import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/recettes/data/recipe_photos.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_photo.dart';
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

  Future<String?> call(PhotoSource source) async {
    sources.add(source);
    return results.removeAt(0);
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

/// « Ajouter une photo » (ou « Remplacer »), puis [source] dans la feuille.
Future<void> _pick(
  WidgetTester tester, {
  String action = StringsFr.ajouterUnePhoto,
  String source = StringsFr.galerie,
}) async {
  await _tap(tester, find.text(action));
  expect(find.byType(PhotoSourceSheet), findsOneWidget);
  await tester.tap(find.text(source));
  await tester.pumpAndSettle();
}

Finder get _linkField => find.ancestor(
  of: find.text(StringsFr.lien),
  matching: find.byType(TextField),
);

Finder get _openLink => find.byTooltip(StringsFr.ouvrirLeLien);

/// Aperçu de la photo dans la fiche.
Finder get _preview => find.descendant(
  of: find.byType(RecipePhotoZone),
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

Finder _cardPicto(String name) =>
    find.descendant(of: recipeCard(name), matching: find.byType(Picto));

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
    expect(find.text(StringsFr.remplacer), findsOneWidget);
    expect(find.text(StringsFr.retirer), findsOneWidget);
    expect(find.text(StringsFr.ajouterUnePhoto), findsNothing);
    expect(env.photos.files, {'photo-1.jpg'});
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );

    await backFromFiche(tester);
    final image = _cardImage(tester, 'Chili con carne')!;
    final resized = image.image as ResizeImage;
    expect(
      (resized.imageProvider as FileImage).file.path,
      RecipePhotos.fileIn(env.photos.dir, 'photo-1.jpg').path,
    );
    expect(image.fit, BoxFit.cover);
    // Décodée à la taille d'affichage, pas aux 1600 px stockés : la
    // largeur couvre la carte, et la hauteur pour une photo jusqu'à 2:1.
    final shown = tester.getSize(
      find.descendant(
        of: recipeCard('Chili con carne'),
        matching: find.byType(Image),
      ),
    );
    expect(
      resized.width,
      (shown.width > KadiSpacing.recipeVisualHeight * 2
              ? shown.width
              : KadiSpacing.recipeVisualHeight * 2)
          .ceil(),
    );
    expect(resized.width, lessThan(1600));
    expect(
      tester
          .getSize(
            find.descendant(
              of: recipeCard('Chili con carne'),
              matching: find.byType(Image),
            ),
          )
          .height,
      KadiSpacing.recipeVisualHeight,
    );
    // Le visuel de repli n'est pas montré sous une photo.
    expect(_cardPicto('Chili con carne'), findsNothing);
    // Sur la photo, un disque `surface` translucide derrière la coche et
    // derrière l'icône « modifier », qui garde sa cible de 48 dp.
    expect(recipeCardDiscs('Chili con carne'), findsNWidgets(2));
    expect(recipeCardDiscs('Ratatouille'), findsNothing);
    final scheme = Theme.of(tester.element(recipeCard('Chili con carne')))
        .colorScheme;
    for (final disc in tester.widgetList<DecoratedBox>(
      recipeCardDiscs('Chili con carne'),
    )) {
      expect(
        (disc.decoration as BoxDecoration).color,
        scheme.surface.withValues(alpha: 0.8),
      );
    }
    final checkTarget = find
        .ancestor(
          of: find.descendant(
            of: recipeCard('Chili con carne'),
            matching: find.byType(Checkbox),
          ),
          matching: find.byType(SizedBox),
        )
        .first;
    expect([
      for (final e in recipeCardDiscs('Chili con carne').evaluate())
        tester.getCenter(find.byWidget(e.widget)),
    ], contains(tester.getCenter(checkTarget)));
    expect(
      tester.getSize(
        find.byTooltip(StringsFr.modifierRecette('Chili con carne')),
      ),
      const Size.square(KadiSpacing.touchTarget),
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
    expect(find.text(StringsFr.ajouterUnePhoto), findsOneWidget);
    expect(env.photos.files, isEmpty);
    expect(await env.db.select(env.db.recipes).get(), before);

    // Feuille fermée sans choix : le sélecteur n'est pas ouvert.
    await _tap(tester, find.text(StringsFr.ajouterUnePhoto));
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSourceSheet), findsNothing);
    expect(env.picker.sources, hasLength(1));
  });

  testWidgets('Remplacer : la base porte B, le fichier A est supprimé', (
    tester,
  ) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.addAll([env.source.path, env.source.path]);
    await _pick(tester);
    expect(env.photos.files, {'photo-1.jpg'});

    await _pick(
      tester,
      action: StringsFr.remplacer,
      source: StringsFr.appareilPhoto,
    );
    expect(env.picker.sources, [
      PhotoSource.galerie,
      PhotoSource.appareilPhoto,
    ]);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-2.jpg',
    );
    expect(env.photos.files, {'photo-2.jpg'});
    await backFromFiche(tester);
    expect(env.photos.files, {'photo-2.jpg'});
  });

  testWidgets('Retirer : photo nulle, fichier supprimé, la carte revient au '
      'picto de repli', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add(env.source.path);
    await _pick(tester);
    await backFromFiche(tester);
    expect(_cardImage(tester, 'Chili con carne'), isNotNull);

    await editRecipe(tester, 'Chili con carne');
    // Photo lue de la base : son aperçu est là.
    expect(_preview, findsOneWidget);
    await _tap(tester, find.text(StringsFr.retirer));
    expect(_preview, findsNothing);
    expect(find.text(StringsFr.ajouterUnePhoto), findsOneWidget);
    expect((await recipeNamed(env.db, 'Chili con carne'))!.photo, isNull);
    expect(env.photos.files, isEmpty);

    await backFromFiche(tester);
    expect(_cardImage(tester, 'Chili con carne'), isNull);
    expect(_cardPicto('Chili con carne'), findsOneWidget);
  });

  testWidgets('fiche pas encore valide : la photo part avec le premier '
      'enregistrement ; quittée sans être créée, son fichier est supprimé', (
    tester,
  ) async {
    final env = await _openRecettes(tester);
    final count = (await env.db.select(env.db.recipes).get()).length;

    // Photo puis retour sans ingrédient : pas de recette, fichier supprimé.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(ficheNameField, 'Soupe');
    await tester.pumpAndSettle();
    env.picker.results.addAll([env.source.path, env.source.path]);
    await _pick(tester);
    await _pick(tester, action: StringsFr.remplacer);
    // A, jamais écrite, est supprimée dès le remplacement.
    expect(env.photos.files, {'photo-2.jpg'});
    await backFromFiche(tester);
    expect(await env.db.select(env.db.recipes).get(), hasLength(count));
    expect(env.photos.files, isEmpty);

    // Photo d'abord, puis nom et ingrédient : créée avec sa photo.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    env.picker.results.add(env.source.path);
    await _pick(tester);
    await tester.enterText(ficheNameField, 'Soupe');
    await tester.pumpAndSettle();
    await addIngredientBySheet(tester, 'riz', 'Riz');
    expect((await recipeNamed(env.db, 'Soupe'))!.photo, 'photo-3.jpg');
    await backFromFiche(tester);
    expect(env.photos.files, {'photo-3.jpg'});
    expect(_cardImage(tester, 'Soupe'), isNotNull);
  });

  testWidgets('recette existante rendue invalide : la photo choisie n’est '
      'pas écrite, son fichier est supprimé, l’ancienne reste', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.addAll([env.source.path, env.source.path]);
    await _pick(tester);
    await tester.enterText(ficheNameField, '');
    await tester.pumpAndSettle();
    await _pick(tester, action: StringsFr.remplacer);
    await backFromFiche(tester);
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.photo,
      'photo-1.jpg',
    );
    expect(env.photos.files, {'photo-1.jpg'});
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

    // La fiche aussi s'ouvre sans erreur, avec « Remplacer » et « Retirer ».
    await editRecipe(tester, 'Chili con carne');
    await _loadImages(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(StringsFr.retirer), findsOneWidget);
  });

  testWidgets('Lien : enregistré nettoyé, l’icône ouvre https://… ; vidé, '
      'lien nul et icône masquée', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    expect(_openLink, findsNothing);
    final field = tester.widget<TextField>(_linkField);
    expect(field.keyboardType, TextInputType.url);

    await tester.ensureVisible(_linkField);
    await tester.enterText(_linkField, ' marmiton.org/chili ');
    await tester.pumpAndSettle();
    expect(
      (await recipeNamed(env.db, 'Chili con carne'))!.link,
      'marmiton.org/chili',
    );
    expect(_openLink, findsOneWidget);
    expect(
      tester.getSize(_openLink),
      const Size.square(KadiSpacing.touchTarget),
    );
    await _tap(tester, _openLink);
    expect(env.browser.opened, [Uri.parse('https://marmiton.org/chili')]);
    expect(find.text(StringsFr.lienImpossible), findsNothing);

    await backFromFiche(tester);
    await editRecipe(tester, 'Chili con carne');
    expect(
      tester.widget<TextField>(_linkField).controller!.text,
      'marmiton.org/chili',
    );
    await tester.ensureVisible(_linkField);
    await tester.enterText(_linkField, '');
    await tester.pumpAndSettle();
    expect(_openLink, findsNothing);
    expect((await recipeNamed(env.db, 'Chili con carne'))!.link, isNull);
  });

  testWidgets('Lien qui ne s’ouvre pas : snackbar « Impossible d’ouvrir le '
      'lien. »', (tester) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    await tester.ensureVisible(_linkField);
    await tester.enterText(_linkField, 'https://exemple.fr');
    await tester.pumpAndSettle();

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

  testWidgets('TalkBack : « Ajouter une photo », « Galerie », « Appareil '
      'photo », « Photo de Chili con carne », « Remplacer la photo », '
      '« Retirer la photo », « Lien », « Ouvrir le lien »', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    expect(
      tester.getSemantics(find.bySemanticsLabel(StringsFr.ajouterUnePhoto)),
      isSemantics(
        label: StringsFr.ajouterUnePhoto,
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
      ),
    );
    await _tap(tester, find.text(StringsFr.ajouterUnePhoto));
    expect(find.bySemanticsLabel(StringsFr.galerie), findsOneWidget);
    expect(find.bySemanticsLabel(StringsFr.appareilPhoto), findsOneWidget);
    env.picker.results.add(env.source.path);
    await tester.tap(find.text(StringsFr.galerie));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Photo de Chili con carne'), findsOneWidget);
    for (final label in [
      StringsFr.remplacerLaPhoto,
      StringsFr.retirerLaPhoto,
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    expect(find.bySemanticsLabel(RegExp('^${StringsFr.lien}')), findsWidgets);
    await tester.ensureVisible(_linkField);
    await tester.enterText(_linkField, 'marmiton.org');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_linkField),
      isSemantics(label: StringsFr.lien, isTextField: true),
    );
    expect(
      tester.getSemantics(_openLink),
      isSemantics(
        tooltip: StringsFr.ouvrirLeLien,
        isButton: true,
        hasTapAction: true,
      ),
    );

    // TalkBack « Retirer la photo » agit.
    tester.semantics.tap(find.semantics.byLabel(StringsFr.retirerLaPhoto));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Photo de Chili con carne'), findsNothing);
    handle.dispose();
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('police ×$scale sur 360 dp : zone photo et lien sans '
        'débordement ni troncature', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = await _openRecettes(tester, size: const Size(360, 800));
      await editRecipe(tester, 'Chili con carne');
      await tester.ensureVisible(find.text(StringsFr.ajouterUnePhoto));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      env.picker.results.add(env.source.path);
      await _pick(tester);
      expect(tester.takeException(), isNull);
      for (final text in [StringsFr.remplacer, StringsFr.retirer]) {
        final widget = tester.widget<Text>(find.text(text));
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
      }
      await tester.ensureVisible(_linkField);
      await tester.enterText(
        _linkField,
        'https://www.marmiton.org/recettes/recette_chili-con-carne.aspx',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_openLink.hitTestable(), findsOneWidget);
    });
  }
  testWidgets('photo choisie puis « Supprimer la recette » : la photo est '
      'enregistrée puis gardée ; Annuler rend la carte avec sa photo', (
    tester,
  ) async {
    final env = await _openRecettes(tester);
    await editRecipe(tester, 'Chili con carne');
    env.picker.results.add(env.source.path);
    await _pick(tester);

    await _tap(
      tester,
      find.widgetWithText(TextButton, StringsFr.supprimerLaRecette),
    );

    expect(find.byType(FicheRecetteScreen), findsNothing);
    expect(recipeCard('Chili con carne'), findsNothing);
    final recipe = await (env.db.select(
      env.db.recipes,
    )..where((r) => r.name.equals('Chili con carne'))).getSingle();
    expect((recipe.photo, recipe.deletedAt != null), ('photo-1.jpg', true));
    expect(env.photos.files, {'photo-1.jpg'});

    await tester.tap(find.widgetWithText(SnackBarAction, StringsFr.annuler));
    await tester.pumpAndSettle();
    await _loadImages(tester);
    expect(_cardImage(tester, 'Chili con carne'), isNotNull);
    expect(env.photos.files, {'photo-1.jpg'});
  });
}
