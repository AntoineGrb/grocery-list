import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Rapport largeur / hauteur le plus large couvert sans flou : une photo
/// plus panoramique est un peu agrandie pour couvrir la hauteur.
const _maxAspect = 2.0;

/// Photo de recette [file] recadrée (`BoxFit.cover`) sur [height] et toute
/// la largeur donnée, décodée à la taille d'affichage (et non aux 1600 px
/// stockés) ; [fallback] si le fichier est absent ou illisible, rien pendant
/// sa lecture.
class RecipePhotoImage extends StatelessWidget {
  const RecipePhotoImage({
    super.key,
    required this.file,
    required this.height,
    required this.fallback,
  });

  final File file;
  final double height;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Largeur décodée qui couvre la boîte pour toute photo jusqu'à
          // [_maxAspect] : la hauteur de la boîte en fixe le minimum.
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : height * _maxAspect;
          final cacheWidth = (math.max(width, height * _maxAspect) * ratio)
              .ceil();
          return Image.file(
            file,
            key: ValueKey(file.path),
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            frameBuilder: (_, child, frame, sync) =>
                sync || frame != null ? child : const SizedBox.shrink(),
            errorBuilder: (_, _, _) => fallback,
          );
        },
      ),
    );
  }
}
