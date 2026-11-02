import 'package:material_ui/material_ui.dart';

import '../rayons/rayon.dart';

/// Tokens de couleur de DESIGN.md (palette « Argile sur fusain »).
///
/// Seul dossier de l'app où s'écrivent des couleurs (AD-12).
class KadiPalette {
  const KadiPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.scrim,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.checked,
    required this.error,
    required this.rayonAccents,
    required this.rayonPastilles,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color surface;
  final Color surfaceContainer;

  /// Fond des tags et des pop-ups du Panneau +, posés sur sa carte.
  final Color surfaceContainerHigh;

  /// Voile qui assombrit un peu la Liste sous le Panneau +.
  final Color scrim;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color checked;
  final Color error;
  final Map<Rayon, Color> rayonAccents;
  final Map<Rayon, Color> rayonPastilles;

  static const light = KadiPalette(
    primary: Color(0xFF9C4A2A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF2D6C8),
    onPrimaryContainer: Color(0xFF3B1305),
    surface: Color(0xFFFBF6F2),
    surfaceContainer: Color(0xFFF3ECE6),
    surfaceContainerHigh: Color(0xFFE8DFD8),
    scrim: Color(0x33000000),
    onSurface: Color(0xFF2A211C),
    onSurfaceVariant: Color(0xFF5C4E46),
    outline: Color(0xFF8F7E74),
    checked: Color(0xFF6F625A),
    error: Color(0xFFB3261E),
    rayonAccents: {
      Rayon.fruitsLegumes: Color(0xFF4B9245),
      Rayon.boulangerie: Color(0xFF927245),
      Rayon.viandePoisson: Color(0xFF924546),
      Rayon.cremerie: Color(0xFF485A99),
      Rayon.epicerieSalee: Color(0xFF925F45),
      Rayon.epicerieSucree: Color(0xFF924563),
      Rayon.surgeles: Color(0xFF45928E),
      Rayon.platsPrepares: Color(0xFF84783E),
      Rayon.boissons: Color(0xFF83499C),
      Rayon.hygiene: Color(0xFF459272),
      Rayon.entretien: Color(0xFF544BA0),
      Rayon.bebeAnimaux: Color(0xFF99488F),
      Rayon.divers: Color(0xFF706B66),
    },
    rayonPastilles: {
      Rayon.fruitsLegumes: Color(0xFFDFE6D6),
      Rayon.boulangerie: Color(0xFFEAE1D6),
      Rayon.viandePoisson: Color(0xFFEADAD6),
      Rayon.cremerie: Color(0xFFDEDDE4),
      Rayon.epicerieSalee: Color(0xFFEADED6),
      Rayon.epicerieSucree: Color(0xFFEADADB),
      Rayon.surgeles: Color(0xFFDEE6E2),
      Rayon.platsPrepares: Color(0xFFE8E2D5),
      Rayon.boissons: Color(0xFFE8DAE4),
      Rayon.hygiene: Color(0xFFDEE6DE),
      Rayon.entretien: Color(0xFFE0DBE5),
      Rayon.bebeAnimaux: Color(0xFFEBDAE2),
      Rayon.divers: Color(0xFFE5E0DC),
    },
  );

  static const dark = KadiPalette(
    primary: Color(0xFFF0A585),
    onPrimary: Color(0xFF4D1C08),
    primaryContainer: Color(0xFF6E3219),
    onPrimaryContainer: Color(0xFFFFDBCC),
    surface: Color(0xFF1B1715),
    surfaceContainer: Color(0xFF26201D),
    surfaceContainerHigh: Color(0xFF342C28),
    scrim: Color(0x52000000),
    onSurface: Color(0xFFF0E5DD),
    onSurfaceVariant: Color(0xFFD0C2B8),
    outline: Color(0xFF9A8B81),
    checked: Color(0xFFA6988E),
    error: Color(0xFFFFB4AB),
    rayonAccents: {
      Rayon.fruitsLegumes: Color(0xFF93CE8D),
      Rayon.boulangerie: Color(0xFFCEB38D),
      Rayon.viandePoisson: Color(0xFFCE8D8E),
      Rayon.cremerie: Color(0xFF909FD0),
      Rayon.epicerieSalee: Color(0xFFCEA38D),
      Rayon.epicerieSucree: Color(0xFFCE8DA6),
      Rayon.surgeles: Color(0xFF8DCECB),
      Rayon.platsPrepares: Color(0xFFCBC086),
      Rayon.boissons: Color(0xFFBD92D0),
      Rayon.hygiene: Color(0xFF8DCEB3),
      Rayon.entretien: Color(0xFF9B94D1),
      Rayon.bebeAnimaux: Color(0xFFD090C8),
      Rayon.divers: Color(0xFFB2ADA9),
    },
    rayonPastilles: {
      Rayon.fruitsLegumes: Color(0xFF384332),
      Rayon.boulangerie: Color(0xFF463C32),
      Rayon.viandePoisson: Color(0xFF463332),
      Rayon.cremerie: Color(0xFF373842),
      Rayon.epicerieSalee: Color(0xFF463932),
      Rayon.epicerieSucree: Color(0xFF463338),
      Rayon.surgeles: Color(0xFF364341),
      Rayon.platsPrepares: Color(0xFF454030),
      Rayon.boissons: Color(0xFF423542),
      Rayon.hygiene: Color(0xFF36433B),
      Rayon.entretien: Color(0xFF3A3542),
      Rayon.bebeAnimaux: Color(0xFF463440),
      Rayon.divers: Color(0xFF3F3B39),
    },
  );
}

/// Échelle de formes M3 (DESIGN.md, `rounded`).
abstract final class KadiRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
  static const full = 9999.0;
}

/// Grille de 4 dp (DESIGN.md, `spacing`).
abstract final class KadiSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const margin = 16.0;
  static const gutter = 12.0;
  static const touchTarget = 48.0;
  static const rowMinHeight = 48.0;
  static const listBottomInset = 96.0;
  static const rayonDot = 10.0;
  static const picto = 24.0;
  static const panelHandleHeight = 20.0;
  static const panelHandleWidth = 32.0;
  static const panelHandleThickness = 4.0;
  static const tagHeight = 32.0;
  static const tagMaxWidth = 144.0;
  static const addFieldHeight = 56.0;
  static const addPopupMaxWidth = 340.0;

  /// Carte recette (`recipe-card`) : hauteur du visuel, Picto de repli,
  /// pastille de sélection, hauteur minimale du nom.
  static const recipeVisualHeight = 118.0;
  static const recipePicto = 44.0;
  static const recipeMark = 26.0;
  static const recipeCaptionMinHeight = 64.0;
}
