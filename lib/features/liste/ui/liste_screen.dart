import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';
import 'add_sheet.dart';
import 'checked_section.dart';
import 'item_edit_sheet.dart';
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
      showErrorSnackBar(messenger, StringsFr.terminerImpossible);
      return;
    }
    if (entry == null || !context.mounted) return;
    showUndoSnackBar(context, StringsFr.coursesTerminees, entry);
  }

  /// Supprime la ligne de [item] (glisser, Feuille d'édition, TalkBack) et
  /// montre le snackbar Annuler sous le messager de la Liste (AD-10).
  ///
  /// [context] est celui du `Builder` de la Liste. Rend `false` si
  /// l'écriture a échoué (snackbar d'erreur, la ligne reste) ; une ligne
  /// déjà absente rend `true` sans snackbar.
  Future<bool> _remove(
    BuildContext context,
    WidgetRef ref,
    ListeItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(listeRepositoryProvider);
    final undo = ref.read(undoProvider);
    final List<UndoRow> rows;
    try {
      rows = await repository.removeLine(item.lineId);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
      return false;
    }
    if (rows.isEmpty) return true;
    final entry = undo.record(rows);
    if (context.mounted) {
      showUndoSnackBar(context, StringsFr.retireDeLaListe(item.name), entry);
    }
    return true;
  }

  /// Ouvre la Feuille d'édition de [item] ; « Supprimer » y revient ici.
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ListeItem item,
  ) async {
    final result = await showItemEditSheet(context, item);
    if (result == ItemEditResult.delete && context.mounted) {
      await _remove(context, ref, item);
    }
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
                    ItemRow(
                      key: ValueKey(item.lineId),
                      item: item,
                      onRemove: () => _remove(context, ref, item),
                      onEdit: () => _edit(context, ref, item),
                    ),
                ],
                // Clé : la section garde son état quand des groupes apparaissent
                // ou disparaissent au-dessus d'elle.
                if (checked.isNotEmpty)
                  CheckedSection(
                    key: const ValueKey('checked-section'),
                    items: checked,
                    onRemove: (item) => _remove(context, ref, item),
                    onEdit: (item) => _edit(context, ref, item),
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
