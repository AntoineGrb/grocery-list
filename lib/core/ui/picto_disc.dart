import 'package:material_ui/material_ui.dart';

import '../pictos/picto.dart';
import '../rayons/rayon.dart';
import '../theme/kadi_colors.dart';

/// Disque picto de la V2 (README redesign §4.5) : rond de [size] sur la
/// pastille du rayon, picto Phosphor à l'accent. 34 dp dans la Fiche recette
/// et les résultats, 28 dp dans les suggestions. Non interactif seul.
class PictoDisc extends StatelessWidget {
  const PictoDisc({
    super.key,
    required this.pictoKey,
    required this.rayon,
    this.size = large,
  });

  static const large = 34.0;
  static const small = 28.0;

  final String pictoKey;
  final Rayon rayon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = KadiColors.of(context).rayon(rayon);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.pastille, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Picto(
        pictoKey: pictoKey,
        rayon: rayon,
        size: size == large ? 20 : 17,
      ),
    );
  }
}
