import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';
import 'add_sheet.dart';
import 'item_row.dart';
import 'rayon_header.dart';

/// Liste : lignes groupées par rayon dans l'ordre du parcours, FAB +.
class ListeScreen extends ConsumerWidget {
  const ListeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(listeGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.tabListe)),
      body: switch (groups) {
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          message: StringsFr.listeVide,
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: KadiSpacing.listBottomInset),
          children: [
            for (final group in value) ...[
              RayonHeader(rayon: group.rayon, count: group.count),
              for (final item in group.items)
                ItemRow(key: ValueKey(item.lineId), item: item),
            ],
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
