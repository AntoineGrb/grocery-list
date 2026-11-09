import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';
import '../strings/strings_fr.dart';
import '../theme/kadi_colors.dart';
import '../theme/kadi_theme.dart';
import '../theme/kadi_tokens.dart';

/// Mots ignorés pour la 2e initiale : « Chili con carne » → `Cc`.
const _stopWords = {
  'de',
  'du',
  'des',
  'la',
  'le',
  'les',
  'au',
  'aux',
  'à',
  'a',
  'et',
  'en',
  'con',
};

/// Élisions retirées en tête de mot : « Gratin d'aubergines » → `Ga`.
final _elision = RegExp(r"^(d|l|qu)['’]", caseSensitive: false);
final _letter = RegExp(r'\p{L}', unicode: true);

/// Initiales du monogramme d'une recette (README redesign §4.1) : 1re lettre
/// du 1er mot en majuscule, puis 1re lettre du 2e mot significatif en
/// minuscule ; un seul mot donne ses 2 premières lettres (« Ratatouille » →
/// `Ra`). Vide sans lettre.
String recipeInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceFirst(_elision, ''))
      .where((w) => _letter.hasMatch(w))
      .toList();
  if (words.isEmpty) return '';
  final first = _letters(words.first);
  final second = words
      .skip(1)
      .where((w) => !_stopWords.contains(w.toLowerCase()))
      .map(_letters)
      .firstOrNull;
  if (second != null && second.isNotEmpty) {
    return first.first.toUpperCase() + second.first.toLowerCase();
  }
  return first.first.toUpperCase() +
      (first.length > 1 ? first[1].toLowerCase() : '');
}

List<String> _letters(String word) => [
  for (final m in _letter.allMatches(word)) m.group(0)!,
];

/// Tailles du monogramme : 56 dp (ligne de Recettes) et 72 dp (Fiche).
enum MonogramSize {
  small(56, KadiRadius.monogramSmall, KadiText.monogramSmall),
  large(72, KadiRadius.card, KadiText.monogramLarge);

  const MonogramSize(this.dimension, this.radius, this.style);
  final double dimension;
  final double radius;
  final TextStyle style;
}

/// Clé de la pastille appareil photo (tests).
const recipePhotoBadgeKey = Key('recipe-photo-badge');

/// Taille de la pastille appareil photo de la Fiche.
const _badgeSize = 26.0;

/// Marge de cible autour de la pastille : 48 dp en tout.
const _badgeMargin = (KadiSpacing.touchTarget - _badgeSize) / 2;

/// Monogramme d'une recette (README redesign §4.1) : carré arrondi au fond de
/// l'accent du rayon de l'ingrédient principal, initiales à la pastille de ce
/// rayon. [photo] le remplace, recadrée au même rayon. Sans [rayon] (nom ou
/// ingrédient manquant) : monogramme neutre.
///
/// [onPhotoTap] ajoute la pastille appareil photo, en bas à droite.
class RecipeMonogram extends StatelessWidget {
  const RecipeMonogram({
    super.key,
    required this.name,
    required this.rayon,
    this.size = MonogramSize.small,
    this.photo,
    this.onPhotoTap,
    this.photoSemanticLabel,
  });

  final String name;
  final Rayon? rayon;
  final MonogramSize size;
  final Widget? photo;
  final VoidCallback? onPhotoTap;
  final String? photoSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = rayon == null ? null : KadiColors.of(context).rayon(rayon!);
    final initials = recipeInitials(name);
    final radius = BorderRadius.circular(size.radius);
    final Widget square = ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: size.dimension,
        child:
            photo ??
            ColoredBox(
              color: colors?.accent ?? scheme.surfaceContainerHigh,
              child: Center(
                child: Text(
                  initials,
                  maxLines: 1,
                  // Les initiales gardent leur taille : le carré est fixe.
                  textScaler: TextScaler.noScaling,
                  style: size.style.copyWith(
                    color: colors?.pastille ?? scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
      ),
    );
    final visual = ExcludeSemantics(child: square);
    if (onPhotoTap == null) return visual;
    return SizedBox.square(
      dimension: size.dimension,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          visual,
          Positioned(
            // Pastille débordant de 4 dp, plus sa marge de cible.
            right: -4 - _badgeMargin,
            bottom: -4 - _badgeMargin,
            child: Semantics(
              button: true,
              label: photoSemanticLabel ?? StringsFr.ajouterUnePhoto,
              excludeSemantics: true,
              onTap: onPhotoTap,
              child: GestureDetector(
                key: recipePhotoBadgeKey,
                behavior: HitTestBehavior.opaque,
                onTap: onPhotoTap,
                // Cible élargie autour de la pastille de 26 dp.
                child: Padding(
                  padding: const EdgeInsets.all(_badgeMargin),
                  child: Container(
                    width: _badgeSize,
                    height: _badgeSize,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: KadiShadows.badge,
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
