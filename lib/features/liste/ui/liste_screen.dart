import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';
import 'add_sheet.dart';
import 'checked_section.dart';
import 'item_row.dart';
import 'rayon_header.dart';

/// Liste : lignes groupées par rayon dans l'ordre du parcours, Section
/// Cochés en bas, FAB +.
class ListeScreen extends ConsumerWidget {
  const ListeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(listeGroupsProvider).value;
    final checked = ref.watch(listeCheckedProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.tabListe)),
      body: switch ((groups, checked)) {
        (final groups?, final checked?)
            when groups.isEmpty && checked.isEmpty =>
          const EmptyState(message: StringsFr.listeVide),
        (final groups?, final checked?) => ListView(
          padding: const EdgeInsets.only(bottom: KadiSpacing.listBottomInset),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddSheet(context),
        child: const Icon(Icons.add, semanticLabel: StringsFr.ajouterUnArticle),
      ),
    );
  }
}
