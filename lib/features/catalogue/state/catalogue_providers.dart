import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';

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

/// Tout le catalogue par ordre alphabétique (Paramètres › Articles, champ de
/// recherche vide).
final catalogueArticlesProvider =
    StreamProvider.autoDispose<List<CatalogueArticle>>(
      (ref) => ref.watch(catalogueRepositoryProvider).watchCatalogue(),
    );

/// Résultats de recherche pour une saisie du Panneau +, de la Fiche recette
/// ou de Paramètres › Articles.
final articleSearchProvider = StreamProvider.autoDispose
    .family<List<CatalogueArticle>, String>(
      (ref, query) => ref.watch(catalogueRepositoryProvider).watchSearch(query),
    );
