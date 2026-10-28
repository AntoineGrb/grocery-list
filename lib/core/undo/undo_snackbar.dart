import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../strings/strings_fr.dart';
import 'undo.dart';

/// Montre le snackbar Annuler de [entry] avec [message] (AD-10).
///
/// Remplace le snackbar courant ; à sa fermeture, l'emplacement est vidé
/// s'il contient encore [entry]. « Annuler » réécrit l'état d'avant ; un
/// Annuler devenu sans effet (autre écriture entre-temps) ne fait rien, un
/// échec montre « Annulation impossible ».
void showUndoSnackBar(BuildContext context, String message, UndoEntry entry) {
  final undo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(undoProvider);
  final messenger = ScaffoldMessenger.of(context);

  Future<void> onUndo() async {
    try {
      await undo.undo(entry);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(StringsFr.annulationImpossible)),
      );
    }
  }

  messenger.hideCurrentSnackBar();
  messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: StringsFr.annuler, onPressed: onUndo),
          persist: false,
          // Flottant : le Scaffold le pose au-dessus du FAB + (DESIGN,
          // `undo-snackbar`).
          behavior: SnackBarBehavior.floating,
        ),
      )
      .closed
      .then((_) => undo.clear(entry));
}
