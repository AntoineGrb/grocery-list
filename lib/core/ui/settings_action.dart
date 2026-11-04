import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../router/app_router.dart';
import '../strings/strings_fr.dart';

/// Icône ⚙ de la Barre d'application de Liste et de Recettes : pousse
/// Paramètres. Couleur `on-surface`, jamais d'argile ; cible de 48 dp ; lue
/// « Paramètres » par TalkBack.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.push(AppRoutes.parametres),
      tooltip: StringsFr.parametres,
      color: Theme.of(context).colorScheme.onSurface,
      icon: const Icon(Icons.settings_outlined),
    );
  }
}
