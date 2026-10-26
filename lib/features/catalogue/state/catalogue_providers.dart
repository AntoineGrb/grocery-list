import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';

import '../data/catalogue_repository.dart';

final catalogueRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(ref.watch(databaseProvider)),
);

/// Résultats de recherche pour une saisie du Panneau +.
final articleSearchProvider = StreamProvider.autoDispose
    .family<List<CatalogueArticle>, String>(
      (ref, query) => ref.watch(catalogueRepositoryProvider).watchSearch(query),
    );
