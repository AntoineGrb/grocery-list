import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import '../theme/kadi_colors.dart';
import '../theme/kadi_tokens.dart';
import 'phosphor_table.dart';

/// Résolveur unique des pictos (AD-18) : traduit une `picto_key` en icône du
/// pack Phosphor (style regular), selon la correspondance choisie
/// ([pictoArticleIcons], [pictoRayonFallbacks]).
///
/// Changer de pack ne change que ce résolveur et sa table.
abstract final class PictoResolver {
  /// Nom de l'icône Phosphor de [pictoKey] pour un article de [rayon] :
  ///
  /// - une clé de la correspondance donne son icône, ou le repli de [rayon]
  ///   si elle n'en a pas ;
  /// - sinon un nom d'icône connu ([phosphorIcons], choisi dans la Fiche
  ///   article) est rendu tel quel ;
  /// - sinon (clé inconnue, `article`, vide, article hors catalogue) : le
  ///   repli de [rayon].
  static String iconNameFor(String pictoKey, Rayon rayon) {
    if (pictoArticleIcons.containsKey(pictoKey)) {
      return pictoArticleIcons[pictoKey] ?? fallbackFor(rayon);
    }
    if (phosphorIcons.containsKey(pictoKey)) return pictoKey;
    return fallbackFor(rayon);
  }

  /// Nom de l'icône de repli de [rayon].
  static String fallbackFor(Rayon rayon) => pictoRayonFallbacks[rayon.code]!;

  /// Icône de [pictoKey] pour un article de [rayon] (voir [iconNameFor]).
  static IconData iconFor(String pictoKey, Rayon rayon) =>
      phosphorIcons[iconNameFor(pictoKey, rayon)]!;
}

/// Glyphes Phosphor de l'interface, hors pictos d'article.
abstract final class KadiGlyphs {
  /// Balance (`scales`, U+E750) du tag sans quantité.
  static const scales = IconData(0xe750, fontFamily: phosphorFontFamily);
}

/// Picto d'un article, 24 dp par défaut, teinté de l'accent de son rayon.
/// Non interactif, exclu de la sémantique.
class Picto extends StatelessWidget {
  const Picto({
    super.key,
    required this.pictoKey,
    required this.rayon,
    this.size = KadiSpacing.picto,
  });

  final String pictoKey;
  final Rayon rayon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = KadiColors.of(context).rayon(rayon).accent;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Icon(
            PictoResolver.iconFor(pictoKey, rayon),
            size: size,
            color: color,
          ),
        ),
      ),
    );
  }
}
