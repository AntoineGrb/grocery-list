import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';

import '../data/liste_repository.dart';

final listeRepositoryProvider = Provider<ListeRepository>(
  (ref) =>
      ListeRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Groupe de la Liste : un rayon et ses lignes non cochées.
class RayonGroup {
  const RayonGroup(this.rayon, this.items);

  final Rayon rayon;
  final List<ListeItem> items;

  /// Compteur de l'En-tête : lignes actives non cochées du rayon.
  int get count => items.length;
}

/// Groupes non vides de la Liste, dans l'ordre du parcours de `settings`.
final listeGroupsProvider = StreamProvider<List<RayonGroup>>((ref) async* {
  final settings = await ref.watch(settingsProvider.future);
  yield* ref
      .watch(listeRepositoryProvider)
      .watchUnchecked()
      .map((items) => groupByRoute(items, settings.routeOrder));
});

/// Regroupe [items] par rayon dans l'ordre [routeOrder] ; seuls les rayons
/// non vides restent. Dans un rayon, l'ordre d'ajout est conservé.
List<RayonGroup> groupByRoute(List<ListeItem> items, List<Rayon> routeOrder) {
  final byRayon = <Rayon, List<ListeItem>>{};
  for (final item in items) {
    byRayon.putIfAbsent(item.rayon, () => []).add(item);
  }
  return [
    for (final rayon in routeOrder)
      if (byRayon[rayon] case final lines?) RayonGroup(rayon, lines),
  ];
}

/// Lignes cochées de la Section Cochés, la dernière cochée en tête.
final listeCheckedProvider = StreamProvider<List<ListeItem>>(
  (ref) => ref.watch(listeRepositoryProvider).watchChecked(),
);

/// Ids des articles « dans la liste » : une ligne active non cochée (AD-4).
final inListProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(listeRepositoryProvider).watchInListArticleIds(),
);

/// Groupe de fréquents du Panneau + : un rayon et ses articles.
class FrequentGroup {
  const FrequentGroup(this.rayon, this.articles);

  final Rayon rayon;
  final List<CatalogueArticle> articles;
}

/// Fréquents groupés par le rayon par défaut de leur article, dans l'ordre
/// du parcours de `settings` ; rayons vides absents (R6).
final frequentGroupsProvider = FutureProvider<List<FrequentGroup>>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final frequents = await ref.watch(frequentsProvider.future);
  return groupFrequentsByRoute(frequents, settings.routeOrder);
});

/// Regroupe [articles] par rayon dans l'ordre [routeOrder] ; seuls les
/// rayons non vides restent. Dans un rayon, l'ordre reçu (`position`) est
/// conservé.
List<FrequentGroup> groupFrequentsByRoute(
  List<CatalogueArticle> articles,
  List<Rayon> routeOrder,
) {
  final byRayon = <Rayon, List<CatalogueArticle>>{};
  for (final article in articles) {
    byRayon.putIfAbsent(article.rayon, () => []).add(article);
  }
  return [
    for (final rayon in routeOrder)
      if (byRayon[rayon] case final group?) FrequentGroup(rayon, group),
  ];
}
