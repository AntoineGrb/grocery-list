import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';

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

/// Groupe de la Liste : un rayon et ses lignes non cochées.
class RayonGroup {
  const RayonGroup(this.rayon, this.items);

  final Rayon rayon;
  final List<ListeItem> items;
}

/// Groupes non vides de la Liste, dans l'ordre du parcours de `settings`.
final listeGroupsProvider = StreamProvider<List<RayonGroup>>((ref) async* {
  final settings = await ref.watch(settingsProvider.future);
  yield* ref
      .watch(listeRepositoryProvider)
      .watchUnchecked()
      .map((items) => groupByRoute(items, settings.routeOrder));
});

/// Regroupe [items] par rayon ([rayonOf]) dans l'ordre [routeOrder] : un
/// couple (rayon, éléments) par rayon non vide. Dans un rayon, l'ordre reçu
/// est conservé.
List<(Rayon, List<T>)> groupByRayon<T>(
  List<T> items,
  Rayon Function(T item) rayonOf,
  List<Rayon> routeOrder,
) {
  final byRayon = <Rayon, List<T>>{};
  for (final item in items) {
    byRayon.putIfAbsent(rayonOf(item), () => []).add(item);
  }
  return [
    for (final rayon in routeOrder)
      if (byRayon[rayon] case final group?) (rayon, group),
  ];
}

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

/// Fréquents du Panneau + en liste plate : rayons (par défaut de l'article)
/// dans l'ordre du parcours de `settings`, puis `position` dans un rayon
/// (R6).
final frequentsInRouteProvider = FutureProvider<List<CatalogueArticle>>((
  ref,
) async {
  final settings = await ref.watch(settingsProvider.future);
  final frequents = await ref.watch(frequentsProvider.future);
  return frequentsInRoute(frequents, settings.routeOrder);
});

/// Range [articles] par rayon dans l'ordre [routeOrder], en une seule liste
/// sans groupe. Dans un rayon, l'ordre reçu (`position`) est conservé.
List<CatalogueArticle> frequentsInRoute(
  List<CatalogueArticle> articles,
  List<Rayon> routeOrder,
) => [
  for (final (_, group) in groupByRayon(
    articles,
    (article) => article.rayon,
    routeOrder,
  ))
    ...group,
];
