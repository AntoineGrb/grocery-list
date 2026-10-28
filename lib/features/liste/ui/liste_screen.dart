import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';
import 'add_sheet.dart';
import 'checked_section.dart';
import 'item_row.dart';
import 'rayon_header.dart';

/// Liste : lignes groupées par rayon dans l'ordre du parcours, Section
/// Cochés en bas, FAB + ; Bouton d'action « Terminer les courses » quand
/// tout est coché (R4).
class ListeScreen extends ConsumerWidget {
  const ListeScreen({super.key});

  Future<void> _terminer(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final UndoEntry? entry;
    try {
      entry = await ref.read(terminerLesCoursesProvider).call();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(StringsFr.terminerImpossible)),
      );
      return;
    }
    if (entry == null || !context.mounted) return;
    showUndoSnackBar(context, StringsFr.coursesTerminees, entry);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(listeGroupsProvider).value;
    final checked = ref.watch(listeCheckedProvider).value;
    final allChecked =
        groups != null &&
        checked != null &&
        groups.isEmpty &&
        checked.isNotEmpty;

    // Messager propre à la Liste : ses snackbars s'affichent dans son
    // Scaffold, au-dessus du FAB + et du Bouton d'action, pas dans la coque.
    // Le Builder donne un contexte sous ce messager, qui reste monté quand le
    // Bouton d'action disparaît.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text(StringsFr.tabListe)),
          body: switch ((groups, checked)) {
            (final groups?, final checked?)
                when groups.isEmpty && checked.isEmpty =>
              const EmptyState(message: StringsFr.listeVide),
            (final groups?, final checked?) => ListView(
              padding: const EdgeInsets.only(
                bottom: KadiSpacing.listBottomInset,
              ),
              children: [
                for (final group in groups) ...[
                  RayonHeader(rayon: group.rayon, count: group.count),
                  for (final item in group.items)
                    ItemRow(key: ValueKey(item.lineId), item: item),
                ],
                // Clé : la section garde son état quand des groupes apparaissent
                // ou disparaissent au-dessus d'elle.
                if (checked.isNotEmpty)
                  CheckedSection(
                    key: const ValueKey('checked-section'),
                    items: checked,
                  ),
              ],
            ),
            _ => const SizedBox.shrink(),
          },
          // Dans le Scaffold de la Liste, le FAB + remonte au-dessus du bouton.
          bottomNavigationBar: allChecked
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                  ),
                  child: FilledButton(
                    onPressed: () => _terminer(context, ref),
                    child: const Text(StringsFr.terminerLesCourses),
                  ),
                )
              : null,
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddSheet(context),
            child: const Icon(
              Icons.add,
              semanticLabel: StringsFr.ajouterUnArticle,
            ),
          ),
        ),
      ),
    );
  }
}
