import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform;
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/recettes_repository.dart';
import '../data/recipe_photos.dart';
import 'revue.dart';

/// Photos de recette dans le dossier documents de l'app (AD-18). Remplacé
/// en test par un dossier temporaire.
final recipePhotosProvider = Provider<RecipePhotos>(
  (ref) => RecipePhotos(getApplicationDocumentsDirectory),
);

/// Dossier `photos/` des photos de recette, pour les afficher.
final photosDirectoryProvider = FutureProvider<Directory>(
  (ref) => ref.watch(recipePhotosProvider).directory(),
);

/// Choix d'une photo (`image_picker`) : la galerie par le sélecteur de
/// photos Android, l'appareil photo par l'application photo du téléphone ;
/// aucune permission (C2). Remplacé en test par un faux sélecteur.
final photoPickerProvider = Provider<PickPhoto>((ref) {
  final platform = ImagePickerPlatform.instance;
  if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
  final picker = ImagePicker();
  return (source) async {
    final file = await picker.pickImage(
      source: switch (source) {
        PhotoSource.galerie => ImageSource.gallery,
        PhotoSource.appareilPhoto => ImageSource.camera,
      },
      maxWidth: photoMaxSide,
      maxHeight: photoMaxSide,
      imageQuality: photoQuality,
      requestFullMetadata: false,
    );
    return file?.path;
  };
});

/// Ouverture d'un lien de recette dans le navigateur (`url_launcher`,
/// application externe). Remplacé en test.
final openLinkProvider = Provider<OpenLink>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final recettesRepositoryProvider = Provider<RecettesRepository>(
  (ref) =>
      RecettesRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Cartes de l'écran Recettes, triées par nom.
final recipeCardsProvider = StreamProvider<List<RecipeCardItem>>(
  (ref) => ref.watch(recettesRepositoryProvider).watchCards(),
);

/// Nombre de recettes sélectionnées pas encore validées : le n de
/// « Valider (n) » (R3).
final toValidateCountProvider = Provider<int>((ref) {
  final cards = ref.watch(recipeCardsProvider).value ?? const [];
  return cards.where((c) => c.selected && !c.validated).length;
});

/// « Créer « … » » de la Fiche recette : l'article au catalogue par l'unique
/// `createArticle` (Divers, sans unité ; un nom porté par un article hors
/// catalogue y entre, même id, AD-17), en une transaction. Lève sur un échec,
/// sans rien écrire.
final creerArticleProvider =
    Provider<Future<CatalogueArticle> Function(String name)>((ref) {
      final db = ref.watch(databaseProvider);
      final catalogue = ref.watch(catalogueRepositoryProvider);
      return (name) => db.transaction(() => catalogue.createArticle(name));
    });

/// Lit, à l'ouverture de la Revue, les sélections à valider et construit
/// son instantané dans l'ordre du parcours (AD-1, AD-16).
final revueLoaderProvider = Provider<Future<Revue> Function()>(
  (ref) => () async {
    final settings = await ref.read(settingsProvider.future);
    final pending = await ref
        .read(recettesRepositoryProvider)
        .pendingSelections();
    return buildRevue(
      selectionIds: pending.selectionIds,
      ingredients: pending.ingredients,
      routeOrder: settings.routeOrder,
    );
  },
);
