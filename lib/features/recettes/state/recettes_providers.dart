import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';

import '../data/recettes_repository.dart';
import 'revue.dart';

final recettesRepositoryProvider = Provider<RecettesRepository>(
  (ref) =>
      RecettesRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Cartes de l'écran Recettes, triées par nom.
final recipeCardsProvider = StreamProvider<List<RecipeCardItem>>(
  (ref) => ref.watch(recettesRepositoryProvider).watchCards(),
);

/// Nombre de recettes sélectionnées pas encore validées : le n de
/// « Valider (n) » (R3).
final toValidateCountProvider = Provider<int>((ref) {
  final cards = ref.watch(recipeCardsProvider).value ?? const [];
  return cards.where((c) => c.selected && !c.validated).length;
});

/// « Créer « … » » de la Fiche recette : l'article au catalogue par l'unique
/// `createArticle` (Divers, sans unité ; un nom porté par un article hors
/// catalogue y entre, même id, AD-17), en une transaction. Lève sur un échec,
/// sans rien écrire.
final creerArticleProvider =
    Provider<Future<CatalogueArticle> Function(String name)>((ref) {
      final db = ref.watch(databaseProvider);
      final catalogue = ref.watch(catalogueRepositoryProvider);
      return (name) => db.transaction(() => catalogue.createArticle(name));
    });

/// Lit, à l'ouverture de la Revue, les sélections à valider et construit
/// son instantané dans l'ordre du parcours (AD-1, AD-16).
final revueLoaderProvider = Provider<Future<Revue> Function()>(
  (ref) => () async {
    final settings = await ref.read(settingsProvider.future);
    final pending = await ref
        .read(recettesRepositoryProvider)
        .pendingSelections();
    return buildRevue(
      selectionIds: pending.selectionIds,
      ingredients: pending.ingredients,
      routeOrder: settings.routeOrder,
    );
  },
);
