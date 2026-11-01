import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/liste/state/liste_providers.dart';

/// Résultat d'Entrée dans le Panneau + : l'article du texte tapé, s'il vient
/// d'être ajouté (faux : il était déjà dans la liste) et sa ligne (la plus
/// ancienne non cochée s'il était déjà dans la liste).
typedef TexteAjoute = ({CatalogueArticle article, bool ajoute, String lineId});

/// Ajoute [articleId] en contribution `ajout`, jamais manuelle (AD-5) ; [rayon]
/// va sur la seule ligne, jamais sur l'article (AD-15). Dans une transaction.
Future<AddedContribution> _addLine(
  ListeRepository liste,
  String articleId, {
  int? quantity,
  Unit? unit,
  Rayon? rayon,
}) async {
  final added = await liste.addArticle(
    articleId,
    quantity: quantity,
    unit: unit,
  );
  if (rayon != null) await liste.setRayon(added.lineId, rayon);
  return added;
}

/// Entrée dans le Champ d'ajout du Panneau + (R25, R28, AD-3, AD-17), en une
/// transaction : l'article du texte par l'unique `resolveTypedArticle`
/// (l'article actif de ce nom, sinon un article hors catalogue), puis son
/// ajout avec la quantité et le rayon des tags. Déjà dans la liste, Entrée ne
/// retire jamais et n'ajoute jamais deux fois : les tags réglés remplacent la
/// quantité et le rayon de sa plus ancienne ligne non cochée, et sans tag rien
/// ne change.
class AjouterTexte {
  AjouterTexte(this._db, this._catalogue, this._liste);

  final AppDatabase _db;
  final CatalogueRepository _catalogue;
  final ListeRepository _liste;

  /// Ajoute l'article du texte [name]. Lève une [ArgumentError] pour un
  /// texte vide ; un échec lève et n'écrit rien.
  Future<TexteAjoute> call(
    String name, {
    int? quantity,
    Unit? unit,
    Rayon? rayon,
  }) {
    return _db.transaction(() async {
      final article = await _catalogue.resolveTypedArticle(name);
      final present = await _liste.firstUnchecked(article.id);
      if (present != null) {
        // Par le chemin de l'édition, fusion comprise (AD-5) ; un rayon seul
        // ne touche pas la quantité.
        if (quantity != null) {
          await _liste.setQuantity(present.lineId, quantity, unit: unit);
        }
        if (rayon != null) await _liste.setRayon(present.lineId, rayon);
        return (article: article, ajoute: false, lineId: present.lineId);
      }
      final added = await _addLine(
        _liste,
        article.id,
        quantity: quantity,
        unit: unit,
        rayon: rayon,
      );
      return (article: article, ajoute: true, lineId: added.lineId);
    });
  }
}

/// Tap sur une ligne du Panneau + hors liste : l'ajout de l'article avec la
/// quantité et le rayon des tags, en une transaction (R28, AD-3).
class AjouterArticle {
  AjouterArticle(this._db, this._liste);

  final AppDatabase _db;
  final ListeRepository _liste;

  /// Ajoute [articleId] ; un échec lève et n'écrit rien.
  Future<AddedContribution> call(
    String articleId, {
    int? quantity,
    Unit? unit,
    Rayon? rayon,
  }) {
    return _db.transaction(
      () => _addLine(
        _liste,
        articleId,
        quantity: quantity,
        unit: unit,
        rayon: rayon,
      ),
    );
  }
}

final ajouterTexteProvider = Provider<AjouterTexte>(
  (ref) => AjouterTexte(
    ref.watch(databaseProvider),
    ref.watch(catalogueRepositoryProvider),
    ref.watch(listeRepositoryProvider),
  ),
);

final ajouterArticleProvider = Provider<AjouterArticle>(
  (ref) => AjouterArticle(
    ref.watch(databaseProvider),
    ref.watch(listeRepositoryProvider),
  ),
);
