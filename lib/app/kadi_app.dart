import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/screen/screen_awake.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_screen.dart';
import 'package:kadi/features/recettes/ui/recettes_screen.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:kadi/features/reglages/ui/articles_screen.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:kadi/features/reglages/ui/parcours_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'keep_screen_on.dart';
import 'startup.dart';

const _locale = Locale('fr');

/// Racine de Kadi : attend l'ouverture de la base et le contenu fourni, puis
/// la navigation ; un échec affiche un écran d'erreur bloquant (AD-8).
///
/// Elle tient aussi l'Écran allumé (R14) : maintenu tant que le réglage est
/// actif, que l'emplacement du routeur est la Liste et que l'app est au
/// premier plan ([shouldKeepScreenOn]).
class KadiApp extends ConsumerStatefulWidget {
  const KadiApp({super.key});

  @override
  ConsumerState<KadiApp> createState() => _KadiAppState();
}

class _KadiAppState extends ConsumerState<KadiApp> with WidgetsBindingObserver {
  /// Créé une fois, après le démarrage : il ouvre sur Recettes au premier
  /// lancement, sur la Liste sinon (AD-13).
  GoRouter? _router;

  late final KeepScreenOnController _keepScreenOn;

  /// Réglage Écran allumé, faux tant que les réglages ne sont pas lus.
  bool _keepScreenOnSetting = false;

  @override
  void initState() {
    super.initState();
    _keepScreenOn = KeepScreenOnController(ref.read(screenAwakeProvider));
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(settingsProvider, (_, next) {
      final value = next.value?.keepScreenOn;
      if (value == null) return;
      _keepScreenOnSetting = value;
      _updateKeepScreenOn();
    }, fireImmediately: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _updateKeepScreenOn();

  /// Applique l'état voulu de l'Écran allumé ; aucun maintien avant que le
  /// routeur existe.
  void _updateKeepScreenOn() {
    final router = _router;
    _keepScreenOn.update(
      setting: _keepScreenOnSetting,
      // Emplacement de la page du dessus : `uri` ignorerait une route
      // poussée (Paramètres, Revue, Fiche recette).
      path:
          router
              ?.routerDelegate
              .currentConfiguration
              .lastOrNull
              ?.matchedLocation ??
          '',
      lifecycle: WidgetsBinding.instance.lifecycleState,
    );
  }

  GoRouter _routerFor({required bool firstLaunch}) =>
      _router ??= _createRouter(firstLaunch: firstLaunch)
        ..routerDelegate.addListener(_updateKeepScreenOn);

  GoRouter _createRouter({required bool firstLaunch}) => createAppRouter(
    initialLocation: firstLaunch ? AppRoutes.recettes : AppRoutes.liste,
    recettes: (_) => const RecettesScreen(),
    liste: (_) => const ListeScreen(),
    pushed: [
      GoRoute(
        path: AppRoutes.revue,
        builder: (context, state) => const RevueScreen(),
      ),
      GoRoute(
        path: AppRoutes.nouvelleRecette,
        builder: (context, state) => const FicheRecetteScreen(),
      ),
      GoRoute(
        path: AppRoutes.recettePattern,
        builder: (context, state) =>
            FicheRecetteScreen(recipeId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.parametres,
        builder: (context, state) => const ParametresScreen(),
      ),
      GoRoute(
        path: AppRoutes.parcours,
        builder: (context, state) => const ParcoursScreen(),
      ),
      GoRoute(
        path: AppRoutes.articles,
        builder: (context, state) => const ArticlesScreen(),
      ),
    ],
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_updateKeepScreenOn);
    _keepScreenOn.release();
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(appStartupProvider);
    return switch (startup) {
      AsyncData(value: final firstLaunch) => MaterialApp.router(
        title: StringsFr.appName,
        debugShowCheckedModeBanner: false,
        theme: KadiTheme.light,
        darkTheme: KadiTheme.dark,
        locale: _locale,
        supportedLocales: const [_locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _routerFor(firstLaunch: firstLaunch),
      ),
      AsyncError() => const _StaticApp(child: BlockingErrorScreen()),
      _ => const _StaticApp(child: Scaffold()),
    };
  }
}

/// App sans navigation, pour le démarrage et l'erreur bloquante.
class _StaticApp extends StatelessWidget {
  const _StaticApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: StringsFr.appName,
      debugShowCheckedModeBanner: false,
      theme: KadiTheme.light,
      darkTheme: KadiTheme.dark,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );
  }
}

/// Base ou contenu fourni illisible : rien de partiel ne s'affiche.
class BlockingErrorScreen extends StatelessWidget {
  const BlockingErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KadiSpacing.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: KadiSpacing.s4),
                Text(
                  StringsFr.erreurOuvertureTitre,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: KadiSpacing.s2),
                Text(
                  StringsFr.erreurOuvertureCorps,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
