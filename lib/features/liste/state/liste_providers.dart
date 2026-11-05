import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';

import '../data/liste_repository.dart';
import 'liste_panel.dart';

final listeRepositoryProvider = Provider<ListeRepository>(
  (ref) =>
      ListeRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Objet partagé entre le Panneau + et la Liste (AD-19).
final listePanelProvider = Provider<ListePanel>((ref) {
  final panel = ListePanel();
  ref.onDispose(panel.dispose);
  return panel;
});

/// Groupe de la Liste : un rayon et ses lignes non cochées ; sans rayon
/// (pas d'En-tête de rayon) quand la Liste n'est pas groupée.
class RayonGroup {
  const RayonGroup(this.rayon, this.items);

  /// Nul : groupement par rayon désactivé, toutes les lignes en un groupe.
  final Rayon? rayon;
  final List<ListeItem> items;
}

/// Groupes non vides de la Liste : par rayon dans l'ordre du parcours de
/// `settings`, ou, groupement désactivé, un seul groupe sans rayon dans
/// l'ordre d'ajout (AD-4). Suit chaque changement de réglage.
final listeGroupsProvider = StreamProvider<List<RayonGroup>>((ref) async* {
  final (grouped, routeOrder) = await ref.watch(
    settingsProvider.selectAsync((s) => (s.groupByRayon, s.routeOrder)),
  );
  yield* ref
      .watch(listeRepositoryProvider)
      .watchUnchecked()
      .map(
        (items) => grouped ? groupByRoute(items, routeOrder) : ungrouped(items),
      );
});

/// Toutes les lignes [items] en un seul groupe sans rayon, dans l'ordre
/// reçu (ordre d'ajout) ; aucun groupe si [items] est vide.
List<RayonGroup> ungrouped(List<ListeItem> items) =>
    items.isEmpty ? const [] : [RayonGroup(null, items)];

/// Regroupe [items] par rayon dans l'ordre [routeOrder] ; seuls les rayons
/// non vides restent. Dans un rayon, l'ordre d'ajout est conservé.
List<RayonGroup> groupByRoute(List<ListeItem> items, List<Rayon> routeOrder) =>
    [
      for (final (rayon, lines) in groupByRayon(
        items,
        (item) => item.rayon,
        routeOrder,
      ))
        RayonGroup(rayon, lines),
    ];

/// Lignes cochées de la Section Cochés, la dernière cochée en tête.
final listeCheckedProvider = StreamProvider<List<ListeItem>>(
  (ref) => ref.watch(listeRepositoryProvider).watchChecked(),
);

/// Ids des articles « dans la liste » : une ligne active non cochée (AD-4).
final inListProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(listeRepositoryProvider).watchInListArticleIds(),
);

/// Plus ancienne ligne non cochée de chaque article « dans la liste » : celle
/// que décrit et édite le tag quantité du Panneau +.
final oldestLineByArticleProvider = StreamProvider<Map<String, ListeItem>>(
  (ref) => ref
      .watch(listeRepositoryProvider)
      .watchUnchecked()
      .map(oldestLineByArticle),
);

/// Première ligne de chaque article dans [items], reçues dans l'ordre d'ajout
/// (`added_at` puis `id`).
Map<String, ListeItem> oldestLineByArticle(List<ListeItem> items) {
  final lines = <String, ListeItem>{};
  for (final item in items) {
    lines.putIfAbsent(item.articleId, () => item);
  }
  return lines;
}
