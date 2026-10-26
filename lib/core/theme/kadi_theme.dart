import 'package:material_ui/material_ui.dart';

import 'kadi_colors.dart';
import 'kadi_tokens.dart';

/// Construit seul les thèmes clair et sombre depuis les tokens (AD-12).
///
/// L'argile (`primary`) ne colore que le FAB + et, par sa teinte claire,
/// l'indicateur de l'onglet actif ; `surfaceTint` est neutralisé.
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceContainer,
        modalBackgroundColor: p.surfaceContainer,
        surfaceTintColor: Colors.transparent,
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
