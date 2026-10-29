import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

/// Dernier ajout du Panneau + : l'article, sa ligne, la contribution `ajout`
/// écrite et si l'article vient d'être créé dans le panneau.
class ArticleAjoute {
  const ArticleAjoute({
    required this.article,
    required this.lineId,
    required this.contributionId,
    this.articleCree = false,
  });

  final CatalogueArticle article;
  final String lineId;
  final String contributionId;

  /// L'article a été créé par « Créer « … » » : le Choix de rayon change
  /// aussi son rayon.
  final bool articleCree;
}

/// « Créer « … » » du Panneau + (R8, AD-3, AD-17) : crée l'article par
/// l'unique `createArticle` (Divers, sans unité) puis l'ajoute à la liste,
/// en une transaction.
class CreerEtAjouter {
  CreerEtAjouter(this._db, this._catalogue, this._liste);

  final AppDatabase _db;
  final CatalogueRepository _catalogue;
  final ListeRepository _liste;

  /// Crée l'article de nom [name] et l'ajoute sans quantité. Si un article
  /// actif porte déjà ce nom normalisé, il est ajouté sans création
  /// (`articleCree` faux). Un échec lève et n'écrit rien.
  Future<ArticleAjoute> call(String name) {
    return _db.transaction(() async {
      final existing = await _catalogue.findByName(name);
      final article = existing ?? await _catalogue.createArticle(name);
      final added = await _liste.addArticle(article.id);
      return ArticleAjoute(
        article: article,
        lineId: added.lineId,
        contributionId: added.contributionId,
        articleCree: existing == null,
      );
    });
  }
}

/// Choix de rayon d'une ligne ajoutée depuis le Panneau + (R9, AD-3,
/// AD-15) : la ligne change de rayon ; l'article aussi s'il vient d'être
/// créé dans le panneau, dans la même transaction.
class PlacerLigneAjoutee {
  PlacerLigneAjoutee(this._db, this._catalogue, this._liste);

  final AppDatabase _db;
  final CatalogueRepository _catalogue;
  final ListeRepository _liste;

  /// Place la ligne [lineId] dans [rayon], et l'article [articleId] avec
  /// elle si [articleCree]. Un échec lève et n'écrit rien.
  Future<void> call(
    String lineId,
    String articleId,
    Rayon rayon, {
    bool articleCree = false,
  }) {
    return _db.transaction(() async {
      await _liste.setRayon(lineId, rayon);
      if (articleCree) await _catalogue.setArticleRayon(articleId, rayon);
    });
  }
}

final creerEtAjouterProvider = Provider<CreerEtAjouter>(
  (ref) => CreerEtAjouter(
    ref.watch(databaseProvider),
    ref.watch(catalogueRepositoryProvider),
    ref.watch(listeRepositoryProvider),
  ),
);

final placerLigneAjouteeProvider = Provider<PlacerLigneAjoutee>(
  (ref) => PlacerLigneAjoutee(
    ref.watch(databaseProvider),
    ref.watch(catalogueRepositoryProvider),
    ref.watch(listeRepositoryProvider),
  ),
);
