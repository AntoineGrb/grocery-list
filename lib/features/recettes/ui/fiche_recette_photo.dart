import 'dart:io';

import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recipe_photos.dart';
import 'recipe_photo_image.dart';

/// Hauteur de l'aperçu de la photo dans la Fiche recette.
const _previewHeight = 200.0;

/// Choix de la source d'une photo : « Galerie » ou « Appareil photo », en
/// feuille modale. Rend `null` si la feuille est fermée sans choix.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) =>
    showModalBottomSheet<PhotoSource>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const PhotoSourceSheet(),
    );

/// Feuille du choix de la source d'une photo.
class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(PhotoSource source, IconData icon, String label) => ListTile(
      minTileHeight: KadiSpacing.rowMinHeight,
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(source),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            PhotoSource.galerie,
            Icons.photo_library_outlined,
            StringsFr.galerie,
          ),
          option(
            PhotoSource.appareilPhoto,
            Icons.photo_camera_outlined,
            StringsFr.appareilPhoto,
          ),
        ],
      ),
    );
  }
}

/// Zone photo de la Fiche recette : sans photo, « Ajouter une photo » ;
/// avec une photo, son aperçu (lu « Photo de Chili ») et les actions
/// « Remplacer » et « Retirer ». [onPick] reçoit la source choisie.
class RecipePhotoZone extends StatelessWidget {
  const RecipePhotoZone({
    super.key,
    required this.recipeName,
    required this.file,
    required this.hasPhoto,
    required this.onPick,
    required this.onRemove,
  });

  /// Nom de la recette, nettoyé, pour la lecture de l'aperçu.
  final String recipeName;

  /// Fichier de la photo, nul tant que le dossier des photos n'est pas lu.
  final File? file;
  final bool hasPhoto;
  final ValueChanged<PhotoSource> onPick;
  final VoidCallback onRemove;

  Future<void> _choose(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source != null) onPick(source);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: scheme.onSurface,
      minimumSize: const Size(KadiSpacing.touchTarget, KadiSpacing.touchTarget),
    );

    if (!hasPhoto) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          style: buttonStyle,
          onPressed: () => _choose(context),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text(StringsFr.ajouterUnePhoto),
        ),
      );
    }

    final placeholder = ColoredBox(
      color: scheme.surfaceContainer,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final file = this.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: StringsFr.photoDe(recipeName),
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(KadiRadius.md),
            ),
            child: SizedBox(
              height: _previewHeight,
              child: file == null
                  ? placeholder
                  : RecipePhotoImage(
                      file: file,
                      height: _previewHeight,
                      fallback: placeholder,
                    ),
            ),
          ),
        ),
        const SizedBox(height: KadiSpacing.s1),
        Wrap(
          spacing: KadiSpacing.s2,
          children: [
            Semantics(
              label: StringsFr.remplacerLaPhoto,
              button: true,
              excludeSemantics: true,
              onTap: () => _choose(context),
              child: TextButton.icon(
                style: buttonStyle,
                onPressed: () => _choose(context),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text(StringsFr.remplacer),
              ),
            ),
            Semantics(
              label: StringsFr.retirerLaPhoto,
              button: true,
              excludeSemantics: true,
              onTap: onRemove,
              child: TextButton.icon(
                style: buttonStyle,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text(StringsFr.retirer),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
