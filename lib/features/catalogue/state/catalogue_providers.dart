import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';

import '../data/catalogue_repository.dart';

final catalogueRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Fréquents actifs du Panneau +, par `position`.
final frequentsProvider = StreamProvider<List<CatalogueArticle>>(
  (ref) => ref.watch(catalogueRepositoryProvider).watchFrequents(),
);

/// Fréquents en liste plate : rayons (par défaut de l'article) dans l'ordre
/// du parcours de `settings`, puis `position` dans un rayon (R16). Les
/// Ajouts fréquents du Panneau + et Paramètres › Fréquents les montrent
/// dans cet ordre.
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

/// Tout le catalogue par ordre alphabétique (Paramètres › Articles, champ de
/// recherche vide).
final catalogueArticlesProvider =
    StreamProvider.autoDispose<List<CatalogueArticle>>(
      (ref) => ref.watch(catalogueRepositoryProvider).watchCatalogue(),
    );

/// Résultats de recherche pour une saisie du Panneau +, de la Fiche recette,
/// de Paramètres › Articles ou de Paramètres › Fréquents.
final articleSearchProvider = StreamProvider.autoDispose
    .family<List<CatalogueArticle>, String>(
      (ref, query) => ref.watch(catalogueRepositoryProvider).watchSearch(query),
    );
