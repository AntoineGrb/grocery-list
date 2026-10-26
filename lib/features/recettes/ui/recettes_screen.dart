import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:material_ui/material_ui.dart';

/// Recettes : seul son message d'état vide existe pour l'instant.
class RecettesScreen extends StatelessWidget {
  const RecettesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.tabRecettes)),
      body: const EmptyState(message: StringsFr.recettesVide),
    );
  }
}
