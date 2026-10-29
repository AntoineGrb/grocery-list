import 'package:material_ui/material_ui.dart';

/// Montre le snackbar d'erreur [message], sans action, sous [messenger] ;
/// ne fait rien si le messager n'est plus monté (écran ou panneau fermé
/// pendant l'écriture).
void showErrorSnackBar(ScaffoldMessengerState messenger, String message) {
  if (!messenger.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
