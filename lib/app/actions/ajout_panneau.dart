import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

/// Résultat d'Entrée dans le Panneau + : l'article du texte tapé, s'il vient
/// d'être ajouté (faux : il était déjà dans la liste) et sa ligne (la plus
/// ancienne non cochée s'il était déjà dans la liste).
typedef TexteAjoute = ({CatalogueArticle article, bool ajoute, String lineId});

/// Entrée dans le Champ d'ajout du Panneau + (R25, AD-3, AD-17), en une
/// transaction : l'article du texte par l'unique `resolveTypedArticle`
/// (l'article actif de ce nom, sinon un article hors catalogue), puis son
/// ajout sans quantité, sauf s'il est déjà dans la liste : Entrée ne retire
/// jamais et n'ajoute jamais deux fois.
class AjouterTexte {
  AjouterTexte(this._db, this._catalogue, this._liste);

  final AppDatabase _db;
  final CatalogueRepository _catalogue;
  final ListeRepository _liste;

  /// Ajoute l'article du texte [name]. Lève une [ArgumentError] pour un
  /// texte vide ; un échec lève et n'écrit rien.
  Future<TexteAjoute> call(String name) {
    return _db.transaction(() async {
      final article = await _catalogue.resolveTypedArticle(name);
      final present = await _liste.firstUnchecked(article.id);
      if (present != null) {
        return (article: article, ajoute: false, lineId: present.lineId);
      }
      final added = await _liste.addArticle(article.id);
      return (article: article, ajoute: true, lineId: added.lineId);
    });
  }
}

final ajouterTexteProvider = Provider<AjouterTexte>(
  (ref) => AjouterTexte(
    ref.watch(databaseProvider),
    ref.watch(catalogueRepositoryProvider),
    ref.watch(listeRepositoryProvider),
  ),
);
