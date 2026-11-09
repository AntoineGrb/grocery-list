import 'package:material_ui/material_ui.dart';

import 'kadi_colors.dart';
import 'kadi_tokens.dart';

/// Styles display de la V2 en Bricolage Grotesque (README redesign §3.2).
/// Sans couleur : le texte prend celle de son contexte (`on-surface`).
abstract final class KadiText {
  static const displayFamily = 'BricolageGrotesque';

  /// Titre d'onglet : « Recettes », « Liste ».
  static const screenTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w600,
  );

  /// Titre de la Revue : « Qu'as-tu déjà ? ».
  static const revueTitle = TextStyle(
    fontFamily: displayFamily,
    fontSize: 26,
    height: 30 / 26,
    fontWeight: FontWeight.w600,
  );

  /// Nom de recette dans la Fiche recette.
  static const recipeName = TextStyle(
    fontFamily: displayFamily,
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w600,
  );

  /// Initiales du monogramme de 56 dp.
  static const monogramSmall = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    height: 26 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Initiales du monogramme de 72 dp.
  static const monogramLarge = TextStyle(
    fontFamily: displayFamily,
    fontSize: 26,
    height: 30 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Grand nombre du Module quantité.
  static const bigNumber = TextStyle(
    fontFamily: displayFamily,
    fontSize: 44,
    height: 1,
    fontWeight: FontWeight.w600,
  );
}

/// Construit seul les thèmes clair et sombre depuis les tokens (AD-12).
///
/// L'argile (`primary`) ne colore que le FAB +, le Bouton d'action et, par
/// sa teinte claire, l'indicateur de l'onglet actif ; `surfaceTint` est
/// neutralisé.
abstract final class KadiTheme {
  static ThemeData get light =>
      _build(KadiPalette.light, KadiPalette.dark, Brightness.light);
  static ThemeData get dark =>
      _build(KadiPalette.dark, KadiPalette.light, Brightness.dark);

  static ThemeData _build(
    KadiPalette p,
    KadiPalette opposite,
    Brightness brightness,
  ) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: KadiPalette.light.primary,
          brightness: brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.primaryContainer,
          onPrimaryContainer: p.onPrimaryContainer,
          surface: p.surface,
          surfaceContainer: p.surfaceContainer,
          surfaceContainerHigh: p.surfaceContainerHigh,
          scrim: p.scrim,
          onSurface: p.onSurface,
          onSurfaceVariant: p.onSurfaceVariant,
          outline: p.outline,
          error: p.error,
          surfaceTint: Colors.transparent,
          inverseSurface: p.onSurface,
          onInverseSurface: p.surface,
          inversePrimary: opposite.primary,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = base.textTheme;
    const fullRadius = BorderRadius.all(Radius.circular(KadiRadius.full));
    const noBorder = OutlineInputBorder(
      borderRadius: fullRadius,
      borderSide: BorderSide.none,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.surface,
      extensions: [KadiColors.fromPalette(p)],
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(color: p.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primaryContainer,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.onPrimaryContainer
                : p.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? p.onSurface
                : p.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KadiRadius.lg)),
        ),
      ),
      // Bouton d'action (Terminer les courses, Valider, Ajouter à la liste).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, KadiSpacing.touchTarget),
          shape: const RoundedRectangleBorder(borderRadius: fullRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceContainer,
        modalBackgroundColor: p.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        // Par défaut transparente en M3 : l'élévation ne se verrait pas.
        shadowColor: scheme.shadow,
        dragHandleColor: p.onSurfaceVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KadiRadius.xl),
          ),
        ),
      ),
      // Champ de recherche : jamais d'argile, ni curseur ni bordure de focus.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.onSurface,
        selectionColor: p.onSurface.withValues(alpha: 0.24),
        selectionHandleColor: p.onSurface,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.surface,
        hintStyle: text.bodyLarge?.copyWith(color: p.onSurfaceVariant),
        prefixIconColor: p.onSurfaceVariant,
        suffixIconColor: p.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: KadiSpacing.s4),
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: noBorder,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.onSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
        actionTextColor: opposite.primary,
      ),
    );
  }
}
