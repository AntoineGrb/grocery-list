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

  /// Ligne d'accueil de Recettes au premier lancement.
  static const recettesAccueil =
      'Voici quelques recettes pour essayer. Supprime-les quand tu veux.';

  // Recettes : sélection et Bouton d'action.
  /// Bouton d'action de Recettes : « Valider (2) ».
  static String validerN(int n) => 'Valider ($n)';

  /// Carte recette lue par TalkBack : « Chili, sélectionnée ».
  static String recetteSelectionnee(String name, {required bool selected}) =>
      '$name, ${selected ? 'sélectionnée' : 'non sélectionnée'}';

  /// Snackbar Annuler de la désélection d'une recette validée :
  /// « Ingrédients de « Chili » retirés de la liste » (guillemets français,
  /// espaces insécables).
  static String ingredientsRetires(String name) =>
      'Ingrédients de « $name » retirés de la liste';

  // Fiche recette.
  /// FAB + de Recettes, lu par TalkBack, et titre d'une fiche vide.
  static const nouvelleRecette = 'Nouvelle recette';

  /// Titre de la fiche d'une recette existante.
  static const recette = 'Recette';
  static const nomDeLaRecette = 'Nom de la recette';
  static const ajouterUnIngredient = 'Ajouter un ingrédient';

  /// Icône « modifier » d'une Carte recette : « Modifier Chili con carne ».
  static String modifierRecette(String name) => 'Modifier $name';

  /// Ligne des résultats sans article de ce nom : « Créer « Piment » »
  /// (guillemets français, espaces insécables).
  static String creerNom(String saisie) => 'Créer « $saisie »';

  /// État lu d'un résultat déjà ingrédient : « Riz, Épicerie salée, dans la
  /// recette ».
  static const dansLaRecette = 'dans la recette';

  /// Annonce d'un ajout depuis la popup d'ingrédient de la Fiche recette :
  /// « Haricots rouges ajouté ».
  static String ingredientAjoute(String name) => '$name ajouté';

  /// Icône de retrait d'une Ligne d'ingrédient : « Retirer Haricots rouges ».
  static String retirerIngredient(String name) => 'Retirer $name';

  /// Unité du Champ quantité d'une Ligne d'ingrédient, lue par TalkBack :
  /// « Unité, g ».
  static String uniteDe(String value) => '$unite, $value';
  static const enregistrementImpossible =
      'Enregistrement impossible. Réessaie.';

  /// Bouton d'action du bas de la fiche : écrit la recette et la ferme.
  static const enregistrer = 'Enregistrer';

  /// Dialogue du retour sur une fiche modifiée, non enregistrée ; « Garder »
  /// ([garder]) y reste sur la fiche.
  static const quitterSansEnregistrerTitre = 'Quitter sans enregistrer ?';
  static const quitterSansEnregistrerTexte =
      'Tes modifications seront perdues.';
  static const quitter = 'Quitter';

  /// Bouton du bas de la fiche d'une recette enregistrée.
  static const supprimerLaRecette = 'Supprimer la recette';

  /// Snackbar Annuler de Recettes après une suppression :
  /// « Recette supprimée : Chili ».
  static String recetteSupprimee(String name) => 'Recette supprimée : $name';

  // Photo et lien de la Fiche recette.
  static const ajouterUnePhoto = 'Ajouter une photo';
  static const galerie = 'Galerie';
  static const appareilPhoto = 'Appareil photo';

  /// Actions sous l'aperçu de la photo, et leur lecture par TalkBack.
  static const remplacer = 'Remplacer';
  static const retirer = 'Retirer';
  static const remplacerLaPhoto = 'Remplacer la photo';
  static const retirerLaPhoto = 'Retirer la photo';

  /// Aperçu de la photo lu par TalkBack : « Photo de Chili » ; « Photo de la
  /// recette » tant que la fiche n'a pas de nom.
  static String photoDe(String name) =>
      name.isEmpty ? 'Photo de la recette' : 'Photo de $name';
  static const photoImpossible = 'Photo impossible à ajouter. Réessaie.';
  static const lien = 'Lien';
  static const ouvrirLeLien = 'Ouvrir le lien';
  static const lienImpossible = 'Impossible d’ouvrir le lien.';

  // Nouvelle liste : action de la Barre d'application de Recettes et son
  // Dialogue de confirmation.
  static const nouvelleListe = 'Nouvelle liste';
  static const nouvelleListeTitre = 'Nouvelle liste ?';
  static const nouvelleListeTexte =
      'La liste en cours et la sélection de la semaine seront effacées.';
  static const garder = 'Garder';
  static const effacerEtRecommencer = 'Effacer et recommencer';
  static const nouvelleListeImpossible =
      'Impossible d’effacer la liste. Réessaie.';

  // Revue.
  static const revue = 'Revue';
  static const revueConsigne = 'Décoche ce que tu as déjà.';
  static const ajouterALaListe = 'Ajouter à la liste';

  /// Avis de la Liste à l'arrivée depuis la Revue.
  static const listePrete = 'Ta liste est prête.';

  // FAB + de la Liste.
  static const ajouterUnArticle = 'Ajouter un article';

  // Panneau + : le Champ d'ajout porte le texte indicatif
  // [ajouterUnArticle].
  static const effacerLeTexte = 'Effacer le texte';
  static const valider = 'Valider';
  static const ajoutImpossible = 'Ajout impossible. Réessaie.';

  /// Seule ligne des résultats quand la saisie ne trouve rien, qui fait
  /// comme Entrée : « Ajouter « piles » » (guillemets français, espaces
  /// insécables).
  static String ajouterNom(String saisie) => 'Ajouter « $saisie »';

  /// Titre de la section des fréquents du Panneau +.
  static const ajoutsFrequents = 'Ajouts fréquents';

  /// Bouton du titre « Ajouts fréquents » et sa lecture par TalkBack.
  static const gerer = 'Gérer';
  static const gererLesAjoutsFrequents = 'Gérer les ajouts fréquents';

  /// État vide des fréquents du Panneau +.
  static const pasDeFrequents =
      'Pas encore de fréquents. Ajoute-les dans les paramètres.';

  /// État lu d'un fréquent ou d'un résultat : « Lait, dans la liste ».
  static const dansLaListe = 'dans la liste';

  /// Annonce d'un ajout depuis le Panneau + : « Lait ajouté, Crèmerie ».
  static String ajouteAnnonce(String name, String rayon) =>
      '$name ajouté, $rayon';

  /// Annonce d'Entrée sur un article présent : « Lait, dans la liste ».
  static String dansLaListeAnnonce(String name) => '$name, $dansLaListe';

  /// Annonce d'Entrée qui applique un tag à un article présent :
  /// « Lait modifié ».
  static String modifieAnnonce(String name) => '$name modifié';

  // Terminer les courses et Annuler.
  static const terminerLesCourses = 'Terminer les courses';
  static const coursesTerminees = 'Courses terminées. Bon appétit !';
  static const annuler = 'Annuler';
  static const terminerImpossible =
      'Impossible de terminer les courses. Réessaie.';
  static const annulationImpossible = 'Annulation impossible.';

  // Supprimer et corriger une ligne (glisser, appui long, TalkBack).
  /// Snackbar Annuler d'une suppression : « Retiré de la liste : Riz ».
  static String retireDeLaListe(String name) => 'Retiré de la liste : $name';
  static const supprimer = 'Supprimer';
  static const modifier = 'Modifier';
  static const quantite = 'Quantité';

  /// Tag quantité d'une ligne du Panneau + sans quantité.
  static const qte = 'Qté';

  /// Tag quantité lu par TalkBack, [value] étant la quantité lue, vide sans
  /// quantité : « Quantité de Lait, 500 g », « Quantité de Lait, aucune ».
  static String quantiteDe(String name, String value) =>
      'Quantité de $name, ${value.isEmpty ? 'aucune' : value}';

  /// Tag Quantité du Champ d'ajout lu par TalkBack, [value] étant la quantité
  /// lue, vide sans quantité : « Quantité, 500 g », « Quantité, aucune ».
  static String quantiteTag(String value) =>
      '$quantite, ${value.isEmpty ? 'aucune' : value}';

  /// Tag Rayon du Champ d'ajout lu par TalkBack : « Rayon, Divers ».
  static String rayonTag(String spokenLabel) => '$rayon, $spokenLabel';
  static const unite = 'Unité';
  static const rayon = 'Rayon';
  static const suppressionImpossible = 'Suppression impossible. Réessaie.';
  static const modificationImpossible = 'Modification impossible. Réessaie.';

  // Écran d'erreur bloquant (base ou contenu fourni illisible).
  static const erreurOuvertureTitre = 'Impossible d’ouvrir tes données.';
  static const erreurOuvertureCorps =
      'Ferme Kadi et relance-la. Ta liste n’a pas été modifiée.';

  /// Nombre d'articles lu : « 1 article », « 3 articles ».
  static String articles(int n) => n == 1 ? '1 article' : '$n articles';

  // Section Cochés.
  static String cochesTitre(int n) => 'Cochés ($n)';

  /// En-tête de la Section Cochés lu par TalkBack :
  /// « Cochés, 2 articles, replié ».
  static String cochesLu(int n, {required bool expanded}) =>
      'Cochés, ${articles(n)}, ${expanded ? 'déplié' : 'replié'}';

  /// Annonce d'un changement de coche : « Tomates, coché ».
  static String cocheAnnonce(String name) => '$name, coché';

  /// Annonce d'un changement de coche : « Tomates, non coché ».
  static String nonCocheAnnonce(String name) => '$name, non coché';

  // Suffixes d'unité d'une quantité lue (AD-6).
  static const uniteG = 'g';
  static const uniteKg = 'kg';
  static const uniteMl = 'ml';
  static const uniteCl = 'cl';
  static const uniteL = 'l';
  static const unitePiece = 'pièce';
  static const unitePieces = 'pièces';

  // Suffixes d'unité du Champ quantité (unité de saisie : pièces
  // entières, g, kg, ml, l).
  static const champUniteG = uniteG;
  static const champUniteKg = uniteKg;
  static const champUniteMl = uniteMl;
  static const champUniteL = uniteL;
  static const champUnitePieces = unitePieces;

  // Puces du Choix d'unité (Feuille d'édition, Popup quantité).
  static const puceUnitePiece = unitePiece;
  static const puceUniteG = uniteG;
  static const puceUniteKg = uniteKg;
  static const puceUniteMl = uniteMl;
  static const puceUniteL = 'L';

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
