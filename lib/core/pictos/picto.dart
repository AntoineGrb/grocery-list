import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import '../theme/kadi_colors.dart';
import '../theme/kadi_tokens.dart';

/// Résolveur unique des pictos (AD-18) : traduit une `picto_key` en asset.
///
/// Le pack de pictos n'est pas encore choisi : toute clé résout vers le repli
/// neutre. Changer de pack ne change que ce résolveur et les assets.
abstract final class PictoResolver {
  /// Chemin de l'asset de [pictoKey], ou `null` pour le repli neutre.
  static String? assetFor(String pictoKey) => null;
}

/// Picto d'un article, 24 dp, teinté de l'accent de son rayon. Non interactif.
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
    final asset = PictoResolver.assetFor(pictoKey);
    final Widget child = asset == null
        ? Icon(Icons.circle_outlined, size: size * 0.75, color: color)
        : Image.asset(asset, width: size, height: size, color: color);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    );
  }
}
