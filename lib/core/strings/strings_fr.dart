/// Toute la microcopie française de Kadi (Voice and Tone d'EXPERIENCE.md).
///
/// Aucun texte d'interface ne s'écrit en dur dans un widget.
abstract final class StringsFr {
  static const appName = 'Kadi';

  // Barre de navigation et titres.
  static const tabRecettes = 'Recettes';
  static const tabListe = 'Liste';

  // États vides.
  static const listeVide =
      'Ta liste est vide. Choisis tes recettes de la semaine ou ajoute un article avec +.';
  static const recettesVide =
      'Pas encore de recette. Ajoute ta première avec +.';

  // FAB + de la Liste.
  static const ajouterUnArticle = 'Ajouter un article';

  // Panneau +.
  static const rechercherUnArticle = 'Rechercher un article';
  static const effacerLaRecherche = 'Effacer la recherche';
  static const ajoutImpossible = 'Ajout impossible. Réessaie.';

  // Écran d'erreur bloquant (base ou contenu fourni illisible).
  static const erreurOuvertureTitre = 'Impossible d’ouvrir tes données.';
  static const erreurOuvertureCorps =
      'Ferme Kadi et relance-la. Ta liste n’a pas été modifiée.';

  /// Compteur d'un En-tête de rayon : « 1 article », « 3 articles ».
  static String articles(int n) => n == 1 ? '1 article' : '$n articles';

  // Suffixes d'unité d'une quantité lue (AD-6).
  static const uniteG = 'g';
  static const uniteKg = 'kg';
  static const uniteMl = 'ml';
  static const uniteCl = 'cl';
  static const uniteL = 'l';
  static const unitePiece = 'pièce';
  static const unitePieces = 'pièces';

  // Noms affichés des 13 rayons (AD-11).
  static const rayonFruitsLegumes = 'Fruits & légumes';
  static const rayonBoulangerie = 'Boulangerie';
  static const rayonViandePoisson = 'Viande/Poisson';
  static const rayonCremerie = 'Crèmerie';
  static const rayonEpicerieSalee = 'Épicerie salée';
  static const rayonEpicerieSucree = 'Épicerie sucrée';
  static const rayonSurgeles = 'Surgelés';
  static const rayonPlatsPrepares = 'Plats préparés';
  static const rayonBoissons = 'Boissons';
  static const rayonHygiene = 'Hygiène';
  static const rayonEntretien = 'Entretien';
  static const rayonBebeAnimaux = 'Bébé/Animaux';
  static const rayonDivers = 'Divers';

  // Noms lus par TalkBack, quand le nom affiché porte un symbole.
  static const rayonFruitsLegumesLu = 'Fruits et légumes';
  static const rayonViandePoissonLu = 'Viande et poisson';
  static const rayonBebeAnimauxLu = 'Bébé et animaux';
}
