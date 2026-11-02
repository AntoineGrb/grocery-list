import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/features/liste/state/liste_notice.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../state/recettes_providers.dart';
import '../state/revue.dart';
import 'revue_row.dart';

/// Revue : écran poussé plein écran, flèche retour, sans Barre de
/// navigation. Les ingrédients des recettes à valider, groupés par rayon
/// dans l'ordre du parcours, tous cochés (R4) ; Bouton d'action « Ajouter à
/// la liste » (R5).
///
/// La Revue lit les sélections à valider à son ouverture et garde cet
/// instantané (AD-1) : « Ajouter à la liste » valide exactement celles-là.
/// Quitter la Revue ne valide rien (AD-16).
class RevueScreen extends ConsumerStatefulWidget {
  const RevueScreen({super.key});

  @override
  ConsumerState<RevueScreen> createState() => _RevueScreenState();
}

class _RevueScreenState extends ConsumerState<RevueScreen> {
  late final Future<Revue> _revue = ref.read(revueLoaderProvider)();

  /// Écriture en cours : le bouton ne réagit plus.
  bool _adding = false;

  Future<void> _ajouter(BuildContext context, Revue revue) async {
    if (_adding) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final notice = ref.read(listeNoticeProvider.notifier);
    try {
      await ref.read(ajouterALaListeProvider).call(revue);
    } catch (_) {
      if (mounted) setState(() => _adding = false);
      showErrorSnackBar(messenger, StringsFr.ajoutImpossible);
      return;
    }
    // La Liste remplace la Revue et montre son avis sous son messager.
    router.go(AppRoutes.liste);
    notice.show(StringsFr.listePrete);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Revue>(
      future: _revue,
      builder: (context, snapshot) {
        final revue = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text(StringsFr.revue)),
          body: revue == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KadiSpacing.margin,
                        KadiSpacing.s2,
                        KadiSpacing.margin,
                        0,
                      ),
                      child: Text(
                        StringsFr.revueConsigne,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final group in revue.groups) ...[
                      RayonHeader(rayon: group.rayon),
                      for (final line in group.lines) RevueRow(line: line),
                    ],
                  ],
                ),
          bottomNavigationBar: revue == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KadiSpacing.margin,
                      KadiSpacing.s2,
                      KadiSpacing.margin,
                      KadiSpacing.s2,
                    ),
                    child: FilledButton(
                      onPressed: _adding
                          ? null
                          : () => _ajouter(context, revue),
                      child: const Text(StringsFr.ajouterALaListe),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
