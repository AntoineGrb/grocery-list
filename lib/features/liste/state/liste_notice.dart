import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Avis de la Liste : un message que la Liste montre une fois en snackbar
/// sous son propre messager, puis vide. Une autre fonctionnalité le lève
/// (« Ta liste est prête. » après la Revue) sans que `liste` en dépende.
class ListeNotice extends Notifier<String?> {
  @override
  String? build() => null;

  /// Demande à la Liste de montrer [message].
  void show(String message) => state = message;

  /// Rend le message en attente et le vide ; `null` s'il n'y en a pas.
  String? take() {
    final message = state;
    if (message != null) state = null;
    return message;
  }
}

final listeNoticeProvider = NotifierProvider<ListeNotice, String?>(
  ListeNotice.new,
);
