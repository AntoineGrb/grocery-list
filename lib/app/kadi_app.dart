import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/liste/ui/liste_screen.dart';
import 'package:kadi/features/recettes/ui/recettes_screen.dart';
import 'package:kadi/features/recettes/ui/revue_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'startup.dart';

const _locale = Locale('fr');

/// Racine de Kadi : attend l'ouverture de la base et le contenu fourni, puis
/// la navigation ; un échec affiche un écran d'erreur bloquant (AD-8).
class KadiApp extends ConsumerStatefulWidget {
  const KadiApp({super.key});

  @override
  ConsumerState<KadiApp> createState() => _KadiAppState();
}

class _KadiAppState extends ConsumerState<KadiApp> {
  late final GoRouter _router = createAppRouter(
    recettes: (_) => const RecettesScreen(),
    liste: (_) => const ListeScreen(),
    pushed: [
      GoRoute(
        path: AppRoutes.revue,
        builder: (context, state) => const RevueScreen(),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(appStartupProvider);
    return switch (startup) {
      AsyncData() => MaterialApp.router(
        title: StringsFr.appName,
        debugShowCheckedModeBanner: false,
        theme: KadiTheme.light,
        darkTheme: KadiTheme.dark,
        locale: _locale,
        supportedLocales: const [_locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
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
