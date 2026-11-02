import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../strings/strings_fr.dart';

/// Chemins des onglets et des routes poussées (AD-13).
abstract final class AppRoutes {
  static const recettes = '/recettes';
  static const liste = '/liste';

  /// Revue : poussée hors de la coque, sans Barre de navigation.
  static const revue = '/revue';
}

/// Navigation de l'app (AD-13) : un `StatefulShellRoute` à deux branches,
/// Recettes et Liste, qui gardent leur état ; ouverture sur Liste.
///
/// Les écrans sont fournis par l'appelant : `core` ne dépend d'aucune
/// fonctionnalité. [pushed] sont les routes poussées (Revue…), sur le
/// navigateur racine, au-dessus de la coque : plein écran, flèche retour.
GoRouter createAppRouter({
  required WidgetBuilder recettes,
  required WidgetBuilder liste,
  List<RouteBase> pushed = const [],
  String initialLocation = AppRoutes.liste,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.recettes,
                builder: (context, state) => recettes(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.liste,
                builder: (context, state) => liste(context),
              ),
            ],
          ),
        ],
      ),
      ...pushed,
    ],
  );
}

/// Coque à deux onglets : Barre de navigation Recettes / Liste.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_outlined),
            label: StringsFr.tabRecettes,
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_outlined),
            label: StringsFr.tabListe,
          ),
        ],
      ),
    );
  }
}
