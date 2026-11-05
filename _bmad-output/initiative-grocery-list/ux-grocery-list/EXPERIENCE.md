---
title: EXPERIENCE — grocery-list
name: grocery-list
status: draft
updated: 2026-11-05
sources:
  - ../../forge-grocery-list/forge-grocery-list.md
  - ../../forge-grocery-list/.memlog.md
  - .memlog.md
---

# grocery-list — Experience Spine

## Foundation

| Aspect | Décision |
|---|---|
| Plateforme | Téléphone Android, Flutter. Usage au magasin à une main, réseau disponible mais non requis. |
| Système d'UI | Material 3 (Flutter), composants standard pour le POC. Ce spine ne décrit que le delta comportemental. |
| Langue | Français uniquement. |
| Thème | Clair et sombre, suit le réglage système Android. |
| Données | V1 entièrement locale, sans compte ; export/import par fichier depuis les Paramètres. |
| Hors périmètre | V2 (partage du foyer, coche à deux en temps réel, code ou QR code) ; planning par jour. |
| Référence visuelle | `DESIGN.md` est la référence d'identité ; ce fichier décrit le comportement. Le spine prime sur toute maquette en cas de conflit. |

Principe directeur : épuré, peu de menus et d'options, impression de facilité. L'ajout manuel doit rester aussi simple qu'une todo.

## Information Architecture

| Surface | Atteinte depuis | Rôle |
|---|---|---|
| Recettes | Barre de navigation (onglet) | Catalogue en Cartes recette 2 colonnes ; sélection de la semaine ; Valider ; Action Nouvelle liste |
| Fiche recette | Icône « modifier » de la Carte recette ; FAB + de Recettes pour créer | Écran poussé plein écran (flèche retour, sans Barre de navigation). Nom, ingrédients, quantité facultative, lien facultatif, photo facultative. Rien d'autre. S'enregistre par « Enregistrer ». |
| Popup d'ajout d'ingrédient | Bouton « Ajouter un ingrédient » de la Fiche recette | Ajout d'ingrédients à la suite, fiche visible au-dessus : recherche dans le catalogue, Entrée, « Créer « … » » |
| Revue | Bouton d'action « Valider » dans Recettes | Écran poussé plein écran (flèche retour, sans Barre de navigation). Ingrédients des recettes nouvellement validées, groupés par rayon, tout coché par défaut |
| Liste | Barre de navigation (onglet) ; fin de la Revue | La liste en cours, groupée par rayon dans l'ordre du parcours ; seul endroit où l'on coche |
| Panneau + | FAB + de la Liste | Ajout éclair, Liste visible au-dessus : Entrée ou un tap ajoute et se voit aussitôt ; tags Quantité et Rayon ; recherche dans tout le catalogue en plus ; Ajouts fréquents |
| Paramètres | Icône ⚙ de la Barre d'application, sur Liste et sur Recettes | Écran poussé plein écran (flèche retour, sans Barre de navigation), dans cet ordre : Garder l'écran allumé, Grouper par rayon, Parcours, Articles, Fréquents, Exporter mes données, Importer une sauvegarde |
| Paramètres › Parcours | Ligne de paramètre « Parcours » | Sous-écran : ordonner les 13 rayons (Ligne de parcours) |
| Paramètres › Articles | Ligne de paramètre « Articles » | Sous-écran : catalogue d'articles, Champ de recherche + Fiche article |
| Paramètres › Fréquents | Ligne de paramètre « Fréquents » ; bouton « Gérer » du Panneau + | Sous-écran : ajouter ou retirer des fréquents, changer leur rayon |

Deux onglets, pas de tiroir. Une seule liste en cours. L'app s'ouvre sur Recettes au premier lancement, puis sur la Liste. Les feuilles (Panneau +, Popup d'ajout d'ingrédient, Feuille d'édition d'article, Fiche article, Choix de rayon d'un fréquent) s'ouvrent sur une surface, jamais l'une sur l'autre. La Popup quantité n'est pas une feuille : elle flotte au-dessus du Panneau +, qui reste ouvert dessous. Le geste retour Android ferme la feuille ou le dialogue ouvert, sinon remonte d'un niveau.

Les Paramètres et leurs sous-écrans (epic 3) suivent les hypothèses de l'epic, construites telles quelles : Antoine les valide au test de fin d'epic 3 [ASSUMPTION].

→ Référence de composition : `.working/color-themes-2.html`, variation B (écran Liste, clair et sombre, section Cochés dépliée/repliée). Maquettes clés : `.working/key-liste.html`, `.working/key-revue.html`, `.working/key-recettes.html`, `.working/key-panneau-plus.html` ; leurs choix provisoires de mise en page sont retenus (2026-10-25), l'app construite prime sur elles. `imports/` est vide.

## Voice and Tone

Tutoiement, ton complice. Phrases courtes. Les touches chaleureuses sont réservées aux moments clés (liste prête, fin des courses, premier lancement) ; ailleurs, le texte est sobre et fonctionnel. Pas d'emoji, pas de jargon technique.

Microcopie de l'app (`lib/core/strings/strings_fr.dart`). Celle des epics 1 et 2 est validée par Antoine ; celle des Paramètres (epic 3) l'est au test de fin d'epic 3.

| Moment | Texte |
|---|---|
| Bouton Valider (Recettes) | « Valider (3) » ; masqué sans recette à valider |
| Titre et consigne de la Revue | « Revue » · « Décoche ce que tu as déjà. » |
| Bouton de fin de Revue | « Ajouter à la liste » |
| Arrivée sur la Liste après la Revue | « Ta liste est prête. » |
| Section Cochés | « Cochés (5) » |
| Tout est coché | Bouton « Terminer les courses » |
| Après Terminer les courses | « Courses terminées. Bon appétit ! » · « Annuler » |
| Dialogue Nouvelle liste | Titre « Nouvelle liste ? » · « La liste en cours et la sélection de la semaine seront effacées. » · « Garder » / « Effacer et recommencer » |
| Liste vide | « Ta liste est vide. Choisis tes recettes de la semaine ou ajoute un article avec +. » |
| Recettes vide | « Pas encore de recette. Ajoute ta première avec +. » |
| Champ d'ajout (Panneau +) | Texte indicatif « Ajouter un article » |
| Section des fréquents (Panneau +) | Titre « Ajouts fréquents » · bouton « Gérer » |
| Tags du Panneau + | « Quantité » · « Qté » sur une ligne · le rayon, « Divers » par défaut |
| Panneau +, aucun résultat | « Ajouter « piles » » |
| Panneau +, aucun fréquent | « Pas encore de fréquents. Ajoute-les dans les paramètres. » |
| Premier lancement (Recettes) | « Voici quelques recettes pour essayer. Supprime-les quand tu veux. » |
| Suppression d'un article | « Retiré de la liste : Tomates » · « Annuler » |
| Désélection d'une recette validée | « Ingrédients de « Chili » retirés de la liste » · « Annuler » |
| Fiche recette | Titre « Nouvelle recette » ou « Recette » · « Nom de la recette » · bouton « Ajouter un ingrédient » · « Lien » · « Ajouter une photo » (« Galerie » / « Appareil photo » ; « Remplacer » / « Retirer ») · « Enregistrer » · « Supprimer la recette » |
| Popup d'ajout d'ingrédient | Texte indicatif « Ajouter un ingrédient » · « Créer « Piment » » |
| Quitter une Fiche recette modifiée | Titre « Quitter sans enregistrer ? » · « Tes modifications seront perdues. » · « Garder » / « Quitter » |
| Suppression d'une recette | « Recette supprimée : Chili » · « Annuler » |
| Écran allumé (Paramètres) | « Garder l'écran allumé » · « Pendant que la liste est affichée » |
| Groupement (Paramètres) | « Grouper par rayon » · « Sinon, la liste suit l'ordre d'ajout » |
| Lignes de navigation (Paramètres) | « Parcours » · « L'ordre des rayons dans ton magasin » ; « Articles » · « Ton catalogue d'articles » ; « Fréquents » · « Tes ajouts fréquents du bouton + » |
| Export (Paramètres) | « Exporter mes données » · « Recettes, liste et réglages dans un fichier » ; après le partage « Sauvegarde prête. » |
| Import (Paramètres) | « Importer une sauvegarde » · « Fusionnée avec tes données » ; après l'import « Sauvegarde importée. » ; fichier invalide « Ce fichier n'est pas une sauvegarde Kadi. » |
| Paramètres › Articles | Texte indicatif « Chercher un article » · « Créer « Piment » » · Fiche article : « Nouvel article », « Nom », « Rayon par défaut », « Unité par défaut » (pièce · g · ml · sans), « Enregistrer » ; nom pris « Un article porte déjà ce nom. » |
| Paramètres › Fréquents | Texte indicatif « Ajouter un fréquent » · vide « Pas encore de fréquents. Cherche un article pour l'ajouter. » · retrait « Retiré des fréquents : Lait » · « Annuler » · Choix de rayon « Rayon par défaut » |
| Échecs d'écriture | Snackbar sobre, sans action : « Ajout impossible. Réessaie. », « Enregistrement impossible. Réessaie. », « Réglage impossible à enregistrer. », « Parcours impossible à enregistrer. », « Article impossible à enregistrer. », « Fréquent impossible à enregistrer. », « Export impossible. », « Import impossible. » |

| Do | Don't |
|---|---|
| « Décoche ce que tu as déjà. » | « Veuillez sélectionner les éléments à exclure. » |
| « Ta liste est prête. » | « Opération réussie ! » |
| Une touche chaleureuse au bon moment | Des encouragements sur chaque écran |
| Nommer l'article concerné dans le snackbar | « Élément supprimé » |

## Component Patterns

Comportemental. Les spécifications visuelles sont dans `DESIGN.md` (section Components), sous les mêmes noms.

| Composant | Usage | Règles de comportement |
|---|---|---|
| Barre d'application | Toutes les surfaces | Titre de la surface. Icône ⚙ vers Paramètres sur Liste et Recettes ; sur Recettes, l'Action Nouvelle liste à gauche de ⚙. Ne porte aucune action fréquente (hors zone du pouce). |
| Barre de navigation | Recettes, Liste | Deux onglets. Tap = changer d'onglet ; l'état de défilement de chaque onglet est conservé. |
| FAB + | Liste ; Recettes | Liste : ouvre le Panneau +. Recettes : ouvre une Fiche recette vide. Toujours visible ; empilé au-dessus du Bouton d'action quand celui-ci est affiché. |
| Bouton d'action | Recettes (Valider), Revue (Ajouter à la liste), Liste (Terminer les courses), Fiche recette et Fiche article (Enregistrer) | Valider : visible dès qu'une recette non encore validée est sélectionnée, affiche le nombre ; ouvre la Revue. Ajouter à la liste : fusionne et ouvre la Liste. Terminer les courses : n'apparaît que quand tout est coché ; vide la liste et remet la sélection de la semaine à zéro (Snackbar Annuler). Enregistrer : grisé tant que la fiche n'est pas enregistrable ; écrit puis ferme la fiche. Pleine largeur en bas, au-dessus de la Barre de navigation (au-dessus du clavier dans la Fiche recette). |
| Carte recette | Recettes | Chaque carte porte en haut à gauche une petite coche ronde, comme la Liste : vide, ou pleine si la recette est sélectionnée pour la semaine, un seul état (validée ou non) ; pas de bordure. Tap sur la carte, coche comprise = sélectionner / désélectionner. Tap sur le crayon discret « modifier » = ouvrir la Fiche recette, sans toucher à la sélection. Appui long : aucun effet. Désélectionner une recette déjà validée retire ses ingrédients non cochés de la liste (quantités fusionnées réduites d'autant) + Snackbar Annuler. |
| Action Nouvelle liste | Recettes | Action texte de la Barre d'application, à gauche de ⚙. Ouvre le Dialogue de confirmation. Confirmé : efface tous les articles de la liste, cochés ou non, et remet la sélection à zéro. |
| En-tête de rayon | Liste, Revue | Non interactif. Ordre des groupes = ordre du parcours. Sans compteur. Absent du Panneau +. |
| Ligne d'article | Liste | Coche ronde + nom + quantité, sans Picto. Tap sur la coche = cocher (l'article rejoint la Section Cochés) ; tap sur le nom : aucun effet. Glisser vers la gauche = supprimer + Snackbar Annuler. Appui long = Feuille d'édition d'article. Panneau + ouvert : une ligne nouvelle arrive animée et brièvement surlignée ; si elle serait masquée, la Liste défile jusqu'à la poser juste au-dessus du panneau, son En-tête de rayon visible si la place le permet ; sinon rien ne défile. |
| Section Cochés | Liste | Repliée par défaut, en bas de la liste. Tap sur l'en-tête = déplier / replier. Décocher une ligne la renvoie dans son rayon. |
| Panneau + | Liste | Carte flottante sur un voile léger : la Liste reste visible et vivante au-dessus, mais inerte. S'ouvre avec le Champ d'ajout focalisé, clavier ouvert ; dessous les deux tags et le bouton Valider, qui fait comme Entrée. Hauteur au contenu : clavier ouvert, seul le titre « Ajouts fréquents » dépasse, qui invite à fermer le clavier ; clavier fermé, quelques fréquents ; pendant la saisie, jusqu'à trois résultats. Un tap sur le titre « Ajouts fréquents », le glissement de ses lignes ou le retour ferment le clavier. Reste ouvert après un ajout pour enchaîner ; se ferme par glissement vers le bas, tap hors du panneau ou retour. Rien ne se déplie après un ajout. |
| Champ d'ajout | Panneau + | Majuscule en début de saisie. Icône × pour effacer dès qu'il y a du texte. Chaque frappe filtre aussi tout le catalogue (Lignes de résultat). Entrée ajoute le texte tapé, qu'un résultat s'affiche ou non, avec les tags : l'article du catalogue de ce nom exact (casse et accents ignorés), sinon une ligne libre qui n'entre pas au catalogue et dont le rayon n'est jamais mémorisé. Un article déjà dans la liste n'est ni ajouté une seconde fois ni retiré : sans tag, rien ne change ; avec des tags, leur quantité et leur rayon remplacent ceux de sa plus ancienne ligne non cochée, qui est montrée et surlignée. Après Entrée, le champ se vide, le clavier reste ouvert et les tags reviennent à zéro. |
| Tag Quantité | Panneau +, sous le Champ d'ajout | Ouvre la Popup quantité pour l'ajout suivant. Contour « Quantité » sans valeur ; plein avec la valeur. Revient à zéro après l'ajout. Effacer le texte ne le remet pas à zéro. Sans effet sur un tap sur un fréquent. |
| Tag Rayon | Panneau +, sous le Champ d'ajout | Liste déroulante des 13 rayons dans l'ordre du parcours, posée juste au-dessus du panneau, clavier conservé. Contour : rayon de l'article au nom exact tapé, sinon Divers ; plein dès qu'un rayon est choisi, qui prime alors sur celui de l'article. Le choix ne vaut que pour la ligne ajoutée suivante, jamais pour l'article. Revient à zéro après l'ajout. |
| Tag quantité de ligne | Ligne de fréquent, Ligne de résultat, dans la liste | Ouvre la Popup quantité de la plus ancienne ligne non cochée de l'article. « Qté » en contour sans quantité ; la quantité en plein sinon. Absent hors liste. |
| Popup quantité | Tag Quantité, Tag quantité de ligne | Carte compacte juste au-dessus du panneau, sur sa marge gauche : Champ quantité focalisé et bouton Valider, puis le Choix d'unité. Sans titre visible ; TalkBack lit le nom de l'article, sinon « Quantité ». Jamais le rayon. Valider, Entrée, tap hors de la carte et retour la ferment en enregistrant ; vide = sans quantité. La saisie du nom reprend le clavier après sa fermeture. |
| Popup d'ajout d'ingrédient | Fiche recette (bouton « Ajouter un ingrédient ») | Sur le principe du Panneau +, sans tags ni fréquents : carte flottante sur un voile léger, la fiche visible au-dessus. Champ « Ajouter un ingrédient » focalisé, clavier ouvert, × pour effacer ; dès la saisie, jusqu'à trois Lignes de résultat du catalogue. Tap sur un résultat = l'ajouter en dernier ingrédient ; déjà ingrédient, sa coche s'affiche et le tap ne fait rien. Entrée ajoute le texte tapé : l'article de ce nom exact (casse et accents ignorés), sinon un article créé au catalogue (Divers, sans unité) ; sans nom exact, une ligne « Créer « … » » sous les résultats fait comme Entrée. Après chaque ajout, le champ se vide, clavier et popup restent ouverts ; la ligne ajoutée apparaît dans la fiche, qui défile pour la montrer juste au-dessus de la popup. Se ferme par glissement vers le bas, tap hors de la popup ou retour. |
| Champ de recherche | Paramètres › Articles, Paramètres › Fréquents | Loupe, texte indicatif, icône × pour effacer dès qu'il y a du texte. Filtre les articles du catalogue à chaque frappe (jamais les articles hors catalogue). Sans article de ce nom exact, « Créer « … » » en tête des résultats. Glisser la liste ferme le clavier. |
| Ligne de fréquent | Panneau + | Section titrée « Ajouts fréquents », bouton « Gérer » à droite du titre : il ferme le Panneau + et ouvre Paramètres › Fréquents ; au retour, la Liste est affichée, panneau fermé. Liste plate dans l'ordre du parcours, sans En-tête ni libellé de rayon. Tap = ajouter (le + devient une coche, le Tag quantité de ligne apparaît), ou retirer s'il y est déjà, avec Annuler. Pas de choix de rayon : il se gère dans Paramètres › Fréquents. État synchronisé dans les deux sens avec la Liste (cocher dans la Liste repasse le fréquent à « hors liste »). Pas d'appui long. Sans fréquent, ni titre ni « Gérer » : le message d'état vide seul. |
| Ligne de résultat | Panneau +, Popup d'ajout d'ingrédient | Panneau + : tap = ajouter avec les tags (le + devient une coche) ou retirer s'il est déjà dans la liste, même règle et même Tag quantité de ligne que les fréquents, et même dessin, sans libellé de rayon. Un ajout vide le champ, comme Entrée ; un retrait le garde. Sans résultat, une seule ligne « Ajouter « … » » fait comme Entrée. Popup d'ajout d'ingrédient : Picto, nom et rayon ; tap = ajouter comme ingrédient (voir Popup d'ajout d'ingrédient). |
| Champ quantité | Revue, Feuille d'édition d'article, Popup quantité, Ligne d'ingrédient | Tap = clavier numérique. Vide = sans quantité. Aucune conversion entre pièces, poids et volumes. Dans la Feuille d'édition et la Popup quantité, l'unité vient du Choix d'unité ; dans la Ligne d'ingrédient, l'unité de l'article (sinon pièce) est préchoisie et un tap sur l'unité ouvre le Choix d'unité ; en Revue, la quantité se corrige dans l'unité de la ligne, sans Choix d'unité. Jamais focalisé d'office après l'ajout d'un ingrédient. |
| Choix d'unité | Feuille d'édition d'article, Popup quantité, Ligne d'ingrédient | Puces de choix sur une ligne : pièce, g, kg, ml, L, au choix libre. Préchoisie : l'unité de la ligne, sinon celle de l'article, sinon pièce. kg et L se saisissent en kg et L mais s'enregistrent en g et ml. Changer l'unité d'une ligne de la liste la fusionne avec la ligne non cochée du même article dans cette unité. |
| Choix de rayon | Feuille d'édition d'article, Fiche article, Choix de rayon d'un fréquent | Les 13 rayons (pastille), le rayon actuel entouré. Feuille d'édition : tap = placer la ligne dans ce rayon ; l'article du catalogue garde son rayon par défaut ; une ligne libre va dans Divers tant qu'aucun rayon n'est choisi. Fiche article et Choix de rayon d'un fréquent : rayon par défaut de l'article. |
| Ligne de Revue | Revue | Coche ronde, nom, sans Picto. Cochée par défaut. Tap sur la coche = décocher ce qu'on a déjà. Pour un ingrédient chiffré seulement, un petit Champ quantité éditable à droite (« 6 » au lieu de « 8 »), valeur exacte dans l'unité de la ligne : l'arrondi de lecture (1 kg, 40 cl) ne vaut que dans la Liste. Ingrédient sans quantité : ni champ ni quantité. |
| Feuille d'édition d'article | Liste (appui long) | Feuille courte qui monte du bas, hauteur au contenu. Titre = nom de l'article ; Champ quantité, Choix d'unité, Choix de rayon, Supprimer. Tout est facultatif. Changer le rayon déplace l'article dans la liste en cours. Supprimer ferme la feuille + Snackbar Annuler. Jamais ouverte depuis le Panneau +. |
| Snackbar Annuler | Liste, Recettes, Paramètres › Fréquents | Après suppression d'article, désélection d'une recette validée, Terminer les courses, suppression d'une recette et retrait d'un fréquent. Durée M3 par défaut ; un nouveau snackbar remplace le précédent (l'action précédente est alors définitive). L'import d'une sauvegarde vide l'Annuler en cours. |
| Dialogue de confirmation | Recettes (Nouvelle liste), Fiche recette (quitter une fiche modifiée) | Seules actions confirmées par dialogue. Repli par défaut = « Garder » ; tap hors du dialogue et retour valent « Garder ». |
| Ligne d'ingrédient | Fiche recette | Picto, nom, Champ quantité facultatif, icône de retrait. Ajoutée par la Popup d'ajout d'ingrédient, en dernière position. Le premier ingrédient fournit le visuel de repli de la carte. |
| Ligne de paramètre | Paramètres | Switch (Garder l'écran allumé, Grouper par rayon), navigation avec chevron (Parcours, Articles, Fréquents) ou action (Exporter mes données, Importer une sauvegarde, désactivées le temps de l'opération). Chaque ligne a son texte d'aide. |
| Ligne de parcours | Paramètres › Parcours | Pastille du rayon et poignée. Glisser-déposer par la seule poignée, sans appui long, pour ordonner les 13 rayons selon le magasin ; actions TalkBack « Monter » et « Descendre », un cran à la fois. Seul glisser-déposer de l'app. |
| Ligne du catalogue | Paramètres › Articles, Paramètres › Fréquents | Picto, nom et, dessous, nom du rayon. Articles : tap = Fiche article. Fréquents, champ vide : tap = Choix de rayon d'un fréquent, icône de retrait à droite (Snackbar Annuler). Fréquents, résultat : + à droite et tap = ajouter aux fréquents (en dernier de son rayon, champ vidé) ; déjà fréquent : coche, tap sans effet. |
| Fiche article | Paramètres › Articles | Feuille modale à poignée, hauteur au contenu. Titre (nom de l'article ou « Nouvel article ») à côté du Picto, affiché sans être modifiable (repli neutre pour une création ; le choix du Picto vient avec le pack). Champ Nom, rayon par défaut (Choix de rayon), unité par défaut en puces pièce · g · ml · sans (jamais kg ni L), « Enregistrer ». Enregistrer est actif dès que le nom n'est pas vide et qu'un champ a changé (en création, le nom suffit) ; il écrit et ferme la fiche. Un nom porté par un autre article est refusé sous le champ. Fermer sans enregistrer n'écrit rien, sans question. Les modifications valent pour les ajouts suivants ; un rayon changé passe le fréquent de l'article en dernier de son nouveau rayon. |
| Choix de rayon d'un fréquent | Paramètres › Fréquents | Feuille modale : Picto et nom de l'article en titre, « Rayon par défaut », Choix de rayon. Toucher un rayon ferme la feuille, change le rayon par défaut de l'article et passe le fréquent en dernier de ce rayon. |
| Picto | Ligne de fréquent, Ligne de résultat, Ligne d'ingrédient, Ligne du catalogue, Fiche article, Carte recette (repli) | Non interactif. Teinté du rayon de l'article ; une ligne libre prend le repli neutre. Absent de la Ligne d'article de la Liste et de la Ligne de Revue. Tant que le pack n'est pas choisi (story 3.5), tous les Pictos sont le repli neutre. |
| Message d'état vide | Recettes, Liste, Panneau +, Paramètres › Fréquents | Une phrase et au plus une action. Disparaît dès qu'un contenu existe. |

## State Patterns

| Surface | État | Traitement |
|---|---|---|
| Recettes | Premier lancement | 4 recettes exemples simples, préremplies et supprimables, plus une ligne d'accueil (voir Voix). Catalogue d'environ 200 articles et environ 30 fréquents déjà en place. L'app s'ouvre sur Recettes. |
| App | Lancements suivants | L'app s'ouvre sur la Liste. |
| Recettes | Vide (toutes les recettes supprimées) | Message d'état vide « Pas encore de recette… » + FAB +. |
| Recettes | Aucune sélection | Bouton Valider masqué. |
| Recettes | Sélection en cours | Cartes sélectionnées : coche ronde pleine ; « Valider (n) » compte les recettes pas encore validées. |
| Recettes | Liste déjà validée, nouvelle recette sélectionnée | Valider n'envoie en Revue que les ingrédients des recettes nouvellement sélectionnées. |
| Recettes | Recette validée modifiée ou supprimée | La liste en cours ne change pas ; une modification vaut pour les validations suivantes. |
| Fiche recette | Création | Champs vides, nom focalisé, clavier ouvert. Rien n'est écrit avant « Enregistrer », grisé tant que la fiche n'a pas de nom ou pas d'ingrédient ; il écrit nom, ingrédients, photo et lien d'un coup, puis ferme la fiche sur Recettes. Échec : snackbar, fiche ouverte, rien d'écrit. |
| Fiche recette | Modification | Même bouton « Enregistrer ». « Supprimer la recette » en bas, sans confirmation : retour à Recettes avec « Recette supprimée : Chili » · « Annuler ». |
| Fiche recette | Quittée modifiée | Le retour (flèche ou Android) demande « Quitter sans enregistrer ? » : « Garder » reste sur la fiche, « Quitter » la ferme sans rien écrire. Non modifiée, elle se ferme sans question. |
| Fiche recette | Ajout d'ingrédient | Popup d'ajout ouverte au-dessus de la fiche ; chaque ajout arrive en dernier ingrédient, sans quantité, et la fiche le montre. Aucun Champ quantité ne prend le focus. |
| Fiche recette | Photo | « Ajouter une photo » : choix entre la galerie et l'appareil photo ; puis « Remplacer » ou « Retirer ». |
| Fiche recette | Sans photo | La Carte recette affiche le visuel de repli : Picto de l'ingrédient principal (le premier), teinté de son rayon. |
| Fiche recette | Ingrédient inconnu | Entrée ou « Créer « … » » dans la popup : l'article rejoint aussitôt le catalogue (Divers, sans unité), même si la fiche n'est pas enregistrée ensuite. |
| Revue | Par défaut | Ingrédients groupés par rayon (comme la future Liste), tous cochés, quantités des recettes. Même article et même unité : quantités additionnées ; unités différentes : deux lignes. |
| Revue | Ingrédient sans quantité | Ni champ ni quantité (cuillères, pincées, gousses) ; la ligne se décoche comme les autres. |
| Revue | Tout décoché | « Ajouter à la liste » reste possible et n'ajoute rien. |
| Revue | Retour sans valider | Rien n'est ajouté ; la sélection est conservée. |
| Liste | Vide | Message d'état vide « Ta liste est vide… » ; FAB + actif. |
| Liste | En cours | Groupes de rayon dans l'ordre du parcours ; seuls les rayons non vides s'affichent. |
| Liste | Rayon entièrement coché | Le groupe disparaît, ses articles sont dans la Section Cochés. |
| Liste | Aucun article coché | Section Cochés absente. |
| Liste | Tout coché | Pas de vidage automatique. Le Bouton d'action « Terminer les courses » apparaît ; la Section Cochés reste repliée. |
| Liste | Panneau + ouvert | Liste visible sous un voile léger, non interactive (un tap hors du panneau le ferme). La zone cachée par le panneau reste atteignable : le bas de la Liste réserve sa hauteur. Le message de liste vide se centre dans la zone libre. |
| Liste | Après Terminer les courses | Liste vide, sélection de la semaine remise à zéro + Snackbar Annuler, qui restaure les deux. |
| Liste | Groupement par rayon désactivé | Ordre d'ajout, sans En-tête de rayon ; la case garde la couleur du rayon. |
| Liste | Écran allumé actif | L'écran ne se met pas en veille tant que l'onglet Liste est affiché. Réglage désactivé par défaut. |
| Panneau + | Ouverture | Champ d'ajout vide et focalisé, clavier ouvert ; « Ajouts fréquents » en liste plate dans l'ordre du parcours, avec leur état. |
| Panneau + | Après un ajout | L'article apparaît dans la Liste au-dessus. Le + de la ligne devient une coche, le Tag quantité de ligne apparaît à côté ; rien ne se déplie. Après Entrée : champ vidé, clavier ouvert, tags à zéro. |
| Panneau + | Saisie | Résultats sur tout le catalogue ; les fréquents laissent la place aux résultats ; Entrée reste possible à tout moment. |
| Panneau + | Aucun résultat | Une seule ligne « Ajouter « … » », qui fait comme Entrée. |
| Panneau + | Aucun fréquent | Message d'état vide renvoyant aux Paramètres, sans titre ni « Gérer ». |
| Paramètres | Par défaut | Écran allumé désactivé ; groupement par rayon activé ; parcours dans l'ordre de la liste des 13 rayons. Une écriture de réglage qui échoue laisse le switch à sa valeur et montre un snackbar. |
| Paramètres | Export | Archive de sauvegarde (données et photos) partagée via la feuille de partage Android ; « Sauvegarde prête. » au retour du partage, rien si la feuille est fermée sans choix. Ligne désactivée pendant l'export. |
| Paramètres | Import | Sélecteur de fichier, sans confirmation. Fusion avec les données existantes, par UUID ; la modification la plus récente l'emporte, suppressions comprises [ASSUMPTION] ; les doublons de nom (articles, lignes) sont réunis ; le parcours, le groupement et Écran allumé viennent du fichier. L'Annuler en cours est vidé ; « Sauvegarde importée. ». Ligne désactivée pendant l'import. |
| Paramètres | Import, fichier invalide | Snackbar « Ce fichier n'est pas une sauvegarde Kadi. » ; aucune donnée modifiée. |
| Paramètres › Parcours | Par défaut | Les 13 rayons dans l'ordre du parcours. Un déplacement s'écrit aussitôt ; s'il échoue, l'ordre de la base revient avec un snackbar. |
| Paramètres › Articles | Champ vide | Tout le catalogue par ordre alphabétique ; les articles hors catalogue n'y sont jamais. |
| Paramètres › Articles | Recherche sans nom exact | « Créer « … » » en tête des résultats ouvre une Fiche article préremplie avec le nom nettoyé. |
| Paramètres › Fréquents | Champ vide | Les fréquents dans l'ordre du parcours, comme dans le Panneau +. |
| Paramètres › Fréquents | Aucun fréquent | Message d'état vide « Pas encore de fréquents. Cherche un article pour l'ajouter. » ; la recherche reste possible. |
| Paramètres › Fréquents | Recherche | Articles du catalogue, + ou coche ; sans nom exact, « Créer « … » » en tête crée l'article au catalogue (Divers, sans unité) et son fréquent. Un fréquent est toujours un article du catalogue. |

Hors ligne : sans objet en V1 (tout est local). Seules permissions système : galerie et appareil photo, pour la photo de recette.

## Interaction Primitives

| Geste | Où | Effet |
|---|---|---|
| Tap sur la case | Ligne d'article | Cocher / décocher |
| Tap sur le nom | Ligne d'article | Aucun effet |
| Tap (coche comprise) | Carte recette | Sélectionner / désélectionner |
| Tap sur l'icône « modifier » | Carte recette | Ouvrir la Fiche recette |
| Tap | Ligne de fréquent, Ligne de résultat (Panneau +) | Ajouter / retirer de la liste |
| Entrée | Champ d'ajout | Ajouter le texte tapé |
| Tap sur un tag quantité | Ligne de fréquent, Ligne de résultat (dans la liste), Tag Quantité | Popup quantité au-dessus du Panneau + |
| Tap sur le Tag Rayon | Panneau + | Liste déroulante des 13 rayons |
| Tap sur « Gérer » | Panneau + | Paramètres › Fréquents, panneau fermé |
| Tap sur « Ajouter un ingrédient » | Fiche recette | Popup d'ajout d'ingrédient |
| Tap, Entrée | Ligne de résultat, champ de la Popup d'ajout d'ingrédient | Ajouter comme ingrédient |
| Tap | Champ quantité | Clavier numérique |
| Glisser vers la gauche | Ligne d'article | Supprimer + Snackbar Annuler |
| Appui long | Ligne d'article | Feuille d'édition d'article |
| Glisser-déposer sur la poignée | Ligne de parcours (Paramètres › Parcours) | Ordonner les rayons |
| Tap | Ligne du catalogue (Paramètres › Articles) | Fiche article |
| Tap ; tap sur l'icône de retrait | Ligne du catalogue (Paramètres › Fréquents) | Choix de rayon d'un fréquent ; retirer le fréquent + Snackbar Annuler |

- **Annuler plutôt que confirmer** : suppression d'article, désélection d'une recette validée, Terminer les courses, suppression d'une recette et retrait d'un fréquent passent par le Snackbar Annuler. Seules Nouvelle liste et le retour sur une Fiche recette modifiée demandent une confirmation.
- **Coche** : animation minimale mais satisfaisante (remplissage du cercle et tracé de la coche, durée courte M3), puis la ligne rejoint la Section Cochés. Pas de vibration, pas de son.
- **Écran allumé** : réglage facultatif, limité à l'onglet Liste.
- **Interdits** : appui long sur un fréquent ; appui long sur une Carte recette ; glisser-déposer hors parcours (pas de planning par jour en V1) ; réordonnancement manuel des fréquents ; vidage automatique de la liste ; entrée automatique dans les fréquents ; tri par fréquence ; suggestions dans la Liste ; tuiles.

## Accessibility Floor

Comportemental. Les contrastes sont dans `DESIGN.md` (section Colors).

| Exigence | Règle |
|---|---|
| Une main | Actions fréquentes dans la zone du pouce : FAB +, Barre de navigation, Bouton d'action en bas. La Barre d'application ne porte que ⚙, rarement utilisée. |
| Cibles tactiles | ≥ `{spacing.touch-target}` (48 dp) pour toute zone interactive : coche ronde, coche et icône « modifier » de la Carte recette (même visuellement petites), tags du Panneau + (visuellement petits), bouton « Gérer », puces du Choix d'unité, Champ quantité, en-tête de la Section Cochés, poignée de la Ligne de parcours, icônes de retrait (ingrédient, fréquent). |
| Repères non colorés | Le rayon est identifié par son nom écrit dans l'En-tête de rayon, jamais par la couleur seule. Coché = coche + barré + déplacement dans Cochés. État d'un fréquent = icône, pas teinte. Carte sélectionnée = coche pleine, pas teinte. |
| TalkBack | Ligne d'article : « Tomates, 500 g, Fruits et légumes, non coché ». En-tête de rayon annoncé comme titre, par son seul nom : « Fruits et légumes ». Ligne du Panneau + dans la liste : « Lait, dans la liste » ; son tag : « Quantité de Lait, 500 g » ou « Quantité de Lait, aucune ». Tags du champ : « Quantité, aucune », « Rayon, Divers ». Bouton : « Gérer les ajouts fréquents ». La Liste étant inaccessible sous le panneau, un ajout s'annonce : « Lait ajouté, Crèmerie ». FAB + : « Ajouter un article » (Liste), « Nouvelle recette » (Recettes). Carte recette : « Chili, sélectionnée » ; icône : « Modifier Chili ». Popup d'ajout d'ingrédient : un ajout s'annonce « Haricots rouges ajouté » ; résultat déjà ingrédient : « Riz, Épicerie salée, dans la recette ». Ligne de Revue : « Pâtes, 500 g, Épicerie salée », son champ « Quantité de Pâtes, 500 g ». Ligne de parcours : « Fruits et légumes, position 1 sur 13 », et après « Monter » : « Boulangerie, position 1 sur 13 ». Paramètres › Fréquents : « Retirer Lait des fréquents », « Lait, déjà dans les fréquents ». Section Cochés : « Cochés, 5 articles, replié ». Changement de quantité ou de coche annoncé. |
| Gestes alternatifs | Glisser pour supprimer et appui long ont des actions TalkBack équivalentes (« Supprimer », « Modifier »). Le glisser-déposer du parcours a des actions « Monter » / « Descendre ». |
| Taille du texte | Taille de police système respectée ; les lignes grandissent en hauteur, le nom d'article passe à la ligne plutôt que d'être tronqué. |
| Animations | Si les animations sont désactivées dans Android, la coche est instantanée ; une ligne nouvelle apparaît sans animation ni surlignage et la Liste saute à sa place sans glisser ; la Popup quantité apparaît d'un coup ; la Ligne de parcours glissée se soulève d'un coup. |
| Ordre de lecture | Haut en bas : rayons dans l'ordre du parcours, puis Section Cochés, puis Bouton d'action. |

## Key Flows

### Flux 1 — Le dimanche soir (Antoine et sa femme, dimanche soir, à la maison)

1. Antoine ouvre l'onglet Recettes. La liste précédente a été terminée ; sinon il passe par Action Nouvelle liste et confirme.
2. Avec sa femme, en regardant ce qu'il y a à la maison, il touche les Cartes recette de la semaine (4 recettes). « Valider (4) » apparaît.
3. Il touche Valider. La Revue s'ouvre : ingrédients groupés par rayon, tous cochés.
4. Sa femme signale qu'il reste des pâtes : il décoche « Pâtes ». Il touche le Champ quantité des œufs et tape 6 au lieu de 8.
5. Il touche « Ajouter à la liste ».
6. **★ La Liste apparaît, fusionnée et triée par rayon dans l'ordre du parcours, sans aucun classement manuel** : les tomates des deux recettes tiennent sur une seule ligne. « Ta liste est prête. »
7. Il touche FAB +, ajoute « Papier toilette » et « Lait » depuis les fréquents, ferme le Panneau +.

Échec : Antoine a sélectionné une recette par erreur et l'a validée → il la désélectionne dans Recettes ; ses ingrédients non cochés quittent la liste, les quantités fusionnées sont réduites, Snackbar Annuler.

### Flux 2 — Au magasin à une main (Antoine, samedi matin, chariot dans l'autre main)

1. Antoine ouvre l'onglet Liste. Si Écran allumé est actif, l'écran ne se met pas en veille.
2. Il suit les rayons dans l'ordre du parcours ; il coche chaque article du pouce. La case se remplit, la ligne rejoint la Section Cochés (repliée).
3. Un rayon entièrement coché disparaît de la liste.
4. Il a coché « Riz » par erreur : il déplie Cochés, décoche « Riz », qui retourne dans Épicerie salée.
5. Il coche le dernier article.
6. **★ « Terminer les courses » apparaît** : la liste ne s'est pas vidée toute seule, Antoine garde la main.
7. Il touche « Terminer les courses ». La liste et la sélection de la semaine se vident. « Courses terminées. Bon appétit ! »

Échec : un article est introuvable → il le laisse non coché ; « Terminer les courses » n'apparaît pas et l'article reste dans la liste jusqu'à ce qu'il le supprime par glissement vers la gauche (Snackbar Annuler) ou que Nouvelle liste efface tout.

### Flux 3 — L'ajout éclair en semaine (Antoine, mardi soir, devant le frigo)

1. Antoine voit qu'il n'y a plus de lait. Il ouvre l'onglet Liste et touche FAB +.
2. Le Panneau + s'ouvre, bas : Champ d'ajout focalisé, clavier ouvert, tags et « Ajouts fréquents » dessous ; sa liste reste visible au-dessus.
3. Il touche « Lait » dans les fréquents : le + devient une coche, un tag « Qté » apparaît à côté ; rien d'autre ne s'ouvre.
4. **★ Il voit le lait arriver dans Crèmerie, juste au-dessus du panneau : un tap a suffi.**
5. Il tape « piles », touche le Tag Rayon et choisit Entretien, puis le Tag Quantité : 4, Entrée. Il appuie sur Entrée dans le champ. Le champ se vide, le clavier reste ouvert, les tags reviennent à zéro ; la Liste défile jusqu'à Entretien, où « Piles 4 » arrive, sans entrer au catalogue.
6. Il touche le tag « Qté » du Lait : la Popup quantité apparaît au-dessus du panneau ; il tape 2 et valide, le tag affiche « 2 ». Il ferme le Panneau +.

Échec : il touche un fréquent déjà dans la liste → l'article est retiré, avec Annuler ; un second tap le remet. Il appuie sur Entrée pour un article déjà dans la liste → rien n'est ajouté ni retiré ; s'il a choisi une quantité ou un rayon, ils remplacent ceux de sa ligne, qui est montrée.

### Flux 4 — Saisir une recette en moins d'une minute (Antoine, un soir de mise en route, une vingtaine de recettes à saisir)

1. Dans Recettes, Antoine touche FAB +. Une Fiche recette vide s'ouvre, le nom focalisé.
2. Il tape le nom : « Chili ».
3. Il touche « Ajouter un ingrédient » : la Popup d'ajout s'ouvre au-dessus de la fiche, champ focalisé. Il tape « hari », touche « Haricots rouges » : l'ingrédient apparaît dans la fiche derrière, le champ se vide, la popup reste ouverte.
4. Il ajoute de même oignon, bœuf haché, tomates, épices, puis ferme la popup.
5. Il touche le Champ quantité des haricots rouges (unité de l'article préchoisie) et saisit 500 ; les épices restent sans quantité. Il ne met ni lien ni photo et touche « Enregistrer », actif depuis le nom et le premier ingrédient : la fiche se ferme sur Recettes.
6. **★ La Carte recette « Chili » apparaît dans le catalogue avec le Picto des haricots rouges en repli, en moins d'une minute.**

Échec : un ingrédient n'existe pas → Entrée ou « Créer « … » » l'ajoute au catalogue (Divers, sans unité) sans quitter la popup. Il revient en arrière sans enregistrer → « Quitter sans enregistrer ? » : « Garder » le ramène à la fiche, « Quitter » ne crée pas la recette. Sans nom ou sans ingrédient → « Enregistrer » reste grisé.

### Flux 5 — La recette du mercredi (Antoine, mercredi, la liste de la semaine est déjà validée)

1. Sa femme propose d'ajouter une quiche. Antoine ouvre Recettes et touche la Carte recette « Quiche ».
2. « Valider (1) » apparaît ; il le touche.
3. La Revue ne montre que les ingrédients de la quiche. Il décoche « Œufs » (déjà dans la liste) et laisse le reste.
4. Il touche « Ajouter à la liste ».
5. **★ La liste en cours est complétée sans repartir de zéro : les nouveaux ingrédients rejoignent leurs rayons, les quantités d'un même article s'additionnent.**

Échec : finalement, pas de quiche → il désélectionne la carte ; ses ingrédients non cochés quittent la liste, Snackbar Annuler.

### Flux 6 — Le premier lancement (Antoine, juste après l'installation)

1. Antoine ouvre l'app. Recettes affiche les 4 recettes exemples et la ligne d'accueil.
2. Il touche deux Cartes recette, puis Valider.
3. La Revue s'ouvre ; il touche « Ajouter à la liste » sans rien changer.
4. **★ En moins d'une minute, il voit tout le flux fonctionner : sa première liste triée par rayon, sans avoir rien saisi.**
5. Il revient à Recettes, ouvre une recette exemple par l'icône « modifier » et la supprime par « Supprimer la recette » (Snackbar Annuler).

Échec : il supprime toutes les recettes exemples → Recettes affiche le Message d'état vide et le FAB +.

## Inspiration & Anti-patterns

| Source | Repris | Rejeté |
|---|---|---|
| Bring! | Référence visuelle : joli design, ajout d'articles agréable, pictos par article | Tuiles (Antoine préfère une liste simple) ; inscription obligatoire ; contenu commercial ; todo générique sans recettes |
| Paprika | L'idée d'un catalogue de recettes personnel | Trop de menus, de champs et de clics ; pas de transfert automatique menus → liste ; todo peu pratique ; étapes, portions, temps, tags |
| Jow | Le passage direct recettes → liste | Compte Carrefour ; app trop grosse ; suggestions de recettes |
| App todo actuelle d'Antoine | La liste à cocher simple ; le sombre comme option bien conçue | — |

Aussi écartés : onglets Boissons/Divers séparés, onglet « Habituels », inventaire de stock (remplacé par la Revue), import d'URL de recettes, plusieurs magasins, conversion d'unités.

## Questions ouvertes

- Source exacte du pack de pictos et sa licence ; faisabilité du complément en SVG générés dans le même style. Antoine choisit le pack (story 3.5) ; d'ici là, tous les Pictos sont le repli neutre.
- Tranchée le 2026-11-04 : un ingrédient inconnu de la Fiche recette est créé au catalogue (Divers, sans unité) par « Créer « … » » ou Entrée, jamais en texte libre.
