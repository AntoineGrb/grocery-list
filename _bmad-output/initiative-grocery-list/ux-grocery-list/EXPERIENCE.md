---
title: EXPERIENCE — grocery-list
name: grocery-list
status: draft
updated: 2026-11-02
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
| Fiche recette | Icône « modifier » de la Carte recette ; FAB + de Recettes pour créer | Nom, ingrédients, quantité facultative, lien facultatif, photo facultative. Rien d'autre. |
| Revue | Bouton d'action « Valider » dans Recettes | Écran poussé plein écran (flèche retour, sans Barre de navigation). Ingrédients des recettes nouvellement validées, groupés par rayon, tout coché par défaut |
| Liste | Barre de navigation (onglet) ; fin de la Revue | La liste en cours, groupée par rayon dans l'ordre du parcours ; seul endroit où l'on coche |
| Panneau + | FAB + de la Liste | Ajout éclair, Liste visible au-dessus : Entrée ou un tap ajoute et se voit aussitôt ; tags Quantité et Rayon ; recherche dans tout le catalogue en plus ; Ajouts fréquents |
| Paramètres | Icône ⚙ de la Barre d'application, sur Liste et sur Recettes | Écran allumé, groupement par rayon, export/import ; lignes de navigation vers Articles, Fréquents, Parcours |
| Paramètres › Articles | Ligne de paramètre « Articles » | Catalogue d'articles : Champ de recherche + Fiche article |
| Paramètres › Fréquents | Ligne de paramètre « Fréquents » [ASSUMPTION : sous-écran] | Ajouter ou retirer des fréquents |
| Paramètres › Parcours | Ligne de paramètre « Parcours » [ASSUMPTION : sous-écran] | Ordonner les 13 rayons (Ligne de parcours) |

Deux onglets, pas de tiroir. Une seule liste en cours. L'app s'ouvre sur Recettes au premier lancement, puis sur la Liste. Les feuilles (Panneau +, Feuille d'édition d'article, Fiche article) s'ouvrent sur une surface, jamais l'une sur l'autre. La Popup quantité n'est pas une feuille : elle flotte au-dessus du Panneau +, qui reste ouvert dessous. Le geste retour Android ferme la feuille ou le dialogue ouvert, sinon remonte d'un niveau.

→ Référence de composition : `.working/color-themes-2.html`, variation B (écran Liste, clair et sombre, section Cochés dépliée/repliée). Maquettes clés : `.working/key-liste.html`, `.working/key-revue.html`, `.working/key-recettes.html`, `.working/key-panneau-plus.html` ; leurs choix provisoires de mise en page sont retenus (2026-10-25). `imports/` est vide.

## Voice and Tone

Tutoiement, ton complice. Phrases courtes. Les touches chaleureuses sont réservées aux moments clés (liste prête, fin des courses, premier lancement) ; ailleurs, le texte est sobre et fonctionnel. Pas d'emoji, pas de jargon technique.

Microcopie proposée, à valider sur maquette :

| Moment | Texte |
|---|---|
| Bouton Valider (Recettes) | « Valider (3) » ; désactivé sans sélection |
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
| Écran allumé (Paramètres) | « Garder l'écran allumé » · « Pendant que la liste est affichée » |

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
| Bouton d'action | Recettes (Valider), Revue (Ajouter à la liste), Liste (Terminer les courses) | Valider : visible dès qu'une recette non encore validée est sélectionnée, affiche le nombre ; ouvre la Revue. Ajouter à la liste : fusionne et ouvre la Liste. Terminer les courses : n'apparaît que quand tout est coché ; vide la liste et remet la sélection de la semaine à zéro (Snackbar Annuler). Pleine largeur en bas, au-dessus de la Barre de navigation. |
| Carte recette | Recettes | Tap sur la carte = sélectionner / désélectionner pour la semaine. Sélectionnée = coche dans le coin + bordure, un seul état (validée ou non). Tap sur l'icône « modifier » = ouvrir la Fiche recette. Appui long : aucun effet. Désélectionner une recette déjà validée retire ses ingrédients non cochés de la liste (quantités fusionnées réduites d'autant) + Snackbar Annuler. |
| Action Nouvelle liste | Recettes | Action texte de la Barre d'application, à gauche de ⚙. Ouvre le Dialogue de confirmation. Confirmé : efface tous les articles de la liste, cochés ou non, et remet la sélection à zéro. |
| En-tête de rayon | Liste, Revue | Non interactif. Ordre des groupes = ordre du parcours. Sans compteur. Absent du Panneau +. |
| Ligne d'article | Liste | Coche ronde + nom + quantité, sans Picto. Tap sur la coche = cocher (l'article rejoint la Section Cochés) ; tap sur le nom : aucun effet. Glisser vers la gauche = supprimer + Snackbar Annuler. Appui long = Feuille d'édition d'article. Panneau + ouvert : une ligne nouvelle arrive animée et brièvement surlignée ; si elle serait masquée, la Liste défile jusqu'à la poser juste au-dessus du panneau, son En-tête de rayon visible si la place le permet ; sinon rien ne défile. |
| Section Cochés | Liste | Repliée par défaut, en bas de la liste. Tap sur l'en-tête = déplier / replier. Décocher une ligne la renvoie dans son rayon. |
| Panneau + | Liste | Carte flottante sur un voile léger : la Liste reste visible et vivante au-dessus. S'ouvre avec le Champ d'ajout focalisé, clavier ouvert ; dessous les deux tags et le bouton Valider, qui fait comme Entrée. Hauteur au contenu : clavier ouvert, seul le titre « Ajouts fréquents » dépasse, qui invite à fermer le clavier ; clavier fermé, quelques fréquents ; pendant la saisie, jusqu'à trois résultats. Un tap sur le titre « Ajouts fréquents », le glissement de ses lignes ou le retour ferment le clavier. Reste ouvert après un ajout pour enchaîner ; se ferme par glissement vers le bas, tap hors du panneau ou retour. Rien ne se déplie après un ajout. |
| Champ d'ajout | Panneau + | Icône × pour effacer dès qu'il y a du texte. Chaque frappe filtre aussi tout le catalogue (Lignes de résultat). Entrée ajoute le texte tapé, qu'un résultat s'affiche ou non, avec les tags : l'article du catalogue de ce nom exact (casse et accents ignorés), sinon une ligne libre qui n'entre pas au catalogue et dont le rayon n'est jamais mémorisé. Un article déjà dans la liste n'est ni ajouté une seconde fois ni retiré : sans tag, rien ne change ; avec des tags, leur quantité et leur rayon remplacent ceux de sa plus ancienne ligne non cochée, qui est montrée et surlignée. Après Entrée, le champ se vide, le clavier reste ouvert et les tags reviennent à zéro. |
| Tag Quantité | Panneau +, sous le Champ d'ajout | Ouvre la Popup quantité pour l'ajout suivant. Contour « Quantité » sans valeur ; plein avec la valeur. Revient à zéro après l'ajout. Effacer le texte ne le remet pas à zéro. Sans effet sur un tap sur un fréquent. |
| Tag Rayon | Panneau +, sous le Champ d'ajout | Liste déroulante des 13 rayons dans l'ordre du parcours, posée juste au-dessus du panneau, clavier conservé. Contour : rayon de l'article au nom exact tapé, sinon Divers ; plein dès qu'un rayon est choisi, qui prime alors sur celui de l'article. Le choix ne vaut que pour la ligne ajoutée suivante, jamais pour l'article. Revient à zéro après l'ajout. |
| Tag quantité de ligne | Ligne de fréquent, Ligne de résultat, dans la liste | Ouvre la Popup quantité de la plus ancienne ligne non cochée de l'article. « Qté » en contour sans quantité ; la quantité en plein sinon. Absent hors liste. |
| Popup quantité | Tag Quantité, Tag quantité de ligne | Carte compacte juste au-dessus du panneau, sur sa marge gauche : Champ quantité focalisé et bouton Valider, puis le Choix d'unité. Sans titre visible ; TalkBack lit le nom de l'article, sinon « Quantité ». Jamais le rayon. Valider, Entrée, tap hors de la carte et retour la ferment en enregistrant ; vide = sans quantité. La saisie du nom reprend le clavier après sa fermeture. |
| Champ de recherche | Fiche recette, Paramètres › Articles | Icône × pour effacer dès qu'il y a du texte. Filtre tout le catalogue à chaque frappe. Sans correspondance exacte, propose « Créer « … » » : l'article inconnu rejoint le catalogue. |
| Ligne de fréquent | Panneau + | Section titrée « Ajouts fréquents », bouton « Gérer » à droite du titre (mènera à Paramètres › Fréquents ; sans action avant l'epic 3). Liste plate dans l'ordre du parcours, sans En-tête ni libellé de rayon. Tap = ajouter (le + devient une coche, le Tag quantité de ligne apparaît), ou retirer s'il y est déjà, avec Annuler. Pas de choix de rayon : il se gère dans Paramètres › Fréquents. État synchronisé dans les deux sens avec la Liste (cocher dans la Liste repasse le fréquent à « hors liste »). Pas d'appui long. |
| Ligne de résultat | Panneau +, Fiche recette | Panneau + : tap = ajouter avec les tags (le + devient une coche) ou retirer s'il est déjà dans la liste, même règle et même Tag quantité de ligne que les fréquents ; garde le libellé du rayon. Le champ garde son texte. Sans résultat, une seule ligne « Ajouter « … » » fait comme Entrée. Fiche recette : tap = ajouter comme ingrédient. |
| Champ quantité | Revue, Feuille d'édition d'article, Popup quantité, Ligne d'ingrédient | Tap = clavier numérique. Vide = sans quantité. Aucune conversion entre pièces, poids et volumes. Dans la Feuille d'édition et la Popup quantité, l'unité vient du Choix d'unité ; ailleurs, l'unité par défaut de l'article est préremplie. |
| Choix d'unité | Feuille d'édition d'article, Popup quantité | Pièce, g, kg, ml, L, au choix libre [ASSUMPTION : puces de choix sur une ligne]. Préchoisie : l'unité de la ligne, sinon celle de l'article, sinon pièce. kg et L se saisissent en kg et L mais s'enregistrent en g et ml. Changer l'unité d'une ligne la fusionne avec la ligne non cochée du même article dans cette unité. |
| Choix de rayon | Feuille d'édition d'article | Les 13 rayons (point + nom). Tap = placer la ligne dans ce rayon ; l'article du catalogue garde son rayon par défaut. Une ligne libre va dans Divers tant qu'aucun rayon n'est choisi. |
| Ligne de Revue | Revue | Cochée par défaut. Tap sur la case = décocher ce qu'on a déjà. Champ quantité éditable à droite (« 6 » au lieu de « 8 »), valeur exacte dans l'unité de l'article : l'arrondi de lecture (1 kg, 40 cl) ne vaut que dans la Liste. |
| Feuille d'édition d'article | Liste (appui long) | Feuille courte qui monte du bas, hauteur au contenu. Titre = nom de l'article ; Champ quantité, Choix d'unité, Choix de rayon, Supprimer. Tout est facultatif. Changer le rayon déplace l'article dans la liste en cours. Supprimer ferme la feuille + Snackbar Annuler. Jamais ouverte depuis le Panneau +. |
| Snackbar Annuler | Liste, Recettes | Après suppression d'article, désélection d'une recette validée et Terminer les courses. Durée M3 par défaut ; un nouveau snackbar remplace le précédent (l'action précédente est alors définitive). |
| Dialogue de confirmation | Recettes (Nouvelle liste) | Seule action confirmée par dialogue. Repli par défaut = « Garder ». |
| Ligne d'ingrédient | Fiche recette | Ajout par Champ de recherche + tap. Quantité facultative. Icône de retrait. Le premier ingrédient fournit le visuel de repli de la carte [ASSUMPTION]. |
| Ligne de paramètre | Paramètres | Switch (Écran allumé, groupement par rayon) ou navigation (Articles, Fréquents, Parcours, export, import). |
| Ligne de parcours | Paramètres | Glisser-déposer pour ordonner les 13 rayons selon le magasin. Seul glisser-déposer de l'app. |
| Fiche article | Paramètres › Articles | Feuille modale [ASSUMPTION]. Nom, Picto choisi dans une grille du pack avec recherche [ASSUMPTION], rayon par défaut, unité par défaut. Les modifications valent pour les ajouts suivants. |
| Picto | Ligne de fréquent, Ligne de résultat, Ligne de Revue, Ligne d'ingrédient, Fiche article, Carte recette (repli) | Non interactif. Teinté du rayon de l'article ; une ligne libre prend le repli neutre. Absent de la Ligne d'article de la Liste. |
| Message d'état vide | Recettes, Liste, Panneau + | Une phrase et au plus une action. Disparaît dès qu'un contenu existe. |

## State Patterns

| Surface | État | Traitement |
|---|---|---|
| Recettes | Premier lancement | 3 à 5 recettes exemples simples, préremplies et supprimables, plus une ligne d'accueil (voir Voix). Catalogue d'environ 200 articles et environ 30 fréquents déjà en place. L'app s'ouvre sur Recettes. |
| App | Lancements suivants | L'app s'ouvre sur la Liste. |
| Recettes | Vide (toutes les recettes supprimées) | Message d'état vide « Pas encore de recette… » + FAB +. |
| Recettes | Aucune sélection | Bouton Valider masqué ou désactivé. |
| Recettes | Sélection en cours | Cartes sélectionnées : coche dans le coin + bordure ; « Valider (n) » compte les recettes pas encore validées. |
| Recettes | Liste déjà validée, nouvelle recette sélectionnée | Valider n'envoie en Revue que les ingrédients des recettes nouvellement sélectionnées. |
| Recettes | Recette validée modifiée ou supprimée | La liste en cours ne change pas ; une modification vaut pour les validations suivantes. |
| Fiche recette | Création | Champs vides. Enregistrement automatique dès que la fiche a un nom et au moins un ingrédient. Quittée sans nom ou sans ingrédient, une nouvelle fiche ne crée pas de recette [ASSUMPTION]. |
| Fiche recette | Modification | Enregistrement automatique ; une recette privée de nom ou de tout ingrédient garde sa dernière version valide [ASSUMPTION]. |
| Fiche recette | Photo | Choix entre la galerie et l'appareil photo. |
| Fiche recette | Sans photo | La Carte recette affiche le visuel de repli : Picto de l'ingrédient principal, teinté de son rayon. |
| Fiche recette | Ingrédient inconnu | « Créer « … » » : l'article rejoint le catalogue avec l'unité « sans » et le rayon Divers. |
| Revue | Par défaut | Ingrédients groupés par rayon (comme la future Liste), tous cochés, quantités des recettes. Même article et même unité : quantités additionnées ; unités différentes : une ligne avec deux quantités, ou deux lignes. |
| Revue | Ingrédient sans quantité | Champ quantité vide (cuillères, pincées, gousses). |
| Revue | Tout décoché | « Ajouter à la liste » reste possible et n'ajoute rien. |
| Revue | Retour sans valider | Rien n'est ajouté ; la sélection est conservée. |
| Liste | Vide | Message d'état vide « Ta liste est vide… » ; FAB + actif. |
| Liste | En cours | Groupes de rayon dans l'ordre du parcours ; seuls les rayons non vides s'affichent. |
| Liste | Rayon entièrement coché | Le groupe disparaît, ses articles sont dans la Section Cochés. |
| Liste | Aucun article coché | Section Cochés absente. |
| Liste | Tout coché | Pas de vidage automatique. Le Bouton d'action « Terminer les courses » apparaît ; la Section Cochés reste repliée. |
| Liste | Panneau + ouvert | Liste visible, sans voile, non interactive (un tap hors du panneau le ferme). La zone cachée par le panneau reste atteignable : le bas de la Liste réserve sa hauteur. Le message de liste vide se centre dans la zone libre. |
| Liste | Après Terminer les courses | Liste vide, sélection de la semaine remise à zéro + Snackbar Annuler, qui restaure les deux. |
| Liste | Groupement par rayon désactivé | Ordre d'ajout, sans En-tête de rayon ; la case garde la couleur du rayon. |
| Liste | Écran allumé actif | L'écran ne se met pas en veille tant que l'onglet Liste est affiché. Réglage désactivé par défaut. |
| Panneau + | Ouverture | Champ d'ajout vide et focalisé, clavier ouvert ; « Ajouts fréquents » en liste plate dans l'ordre du parcours, avec leur état. |
| Panneau + | Après un ajout | L'article apparaît dans la Liste au-dessus. Le + de la ligne devient une coche, le Tag quantité de ligne apparaît à côté ; rien ne se déplie. Après Entrée : champ vidé, clavier ouvert, tags à zéro. |
| Panneau + | Saisie | Résultats sur tout le catalogue ; les fréquents laissent la place aux résultats ; Entrée reste possible à tout moment. |
| Panneau + | Aucun résultat | Une seule ligne « Ajouter « … » », qui fait comme Entrée. |
| Panneau + | Aucun fréquent | Message d'état vide renvoyant aux Paramètres. |
| Paramètres | Par défaut | Écran allumé désactivé ; groupement par rayon activé ; parcours dans l'ordre de la liste des 13 rayons. |
| Paramètres | Export | Fichier de sauvegarde partagé via la feuille de partage Android ; confirmation par snackbar. |
| Paramètres | Import | Fusion avec les données existantes, par UUID ; la modification la plus récente l'emporte [ASSUMPTION] ; confirmation par snackbar. |
| Paramètres | Import, fichier invalide | Message d'erreur en `{colors.error}` ; aucune donnée modifiée. |
| Paramètres › Articles | Recherche sans résultat | « Créer « … » » ouvre une Fiche article préremplie avec le nom. |

Hors ligne : sans objet en V1 (tout est local). Seules permissions système : galerie et appareil photo, pour la photo de recette.

## Interaction Primitives

| Geste | Où | Effet |
|---|---|---|
| Tap sur la case | Ligne d'article | Cocher / décocher |
| Tap sur le nom | Ligne d'article | Aucun effet |
| Tap | Carte recette | Sélectionner / désélectionner |
| Tap sur l'icône « modifier » | Carte recette | Ouvrir la Fiche recette |
| Tap | Ligne de fréquent, Ligne de résultat | Ajouter / retirer de la liste |
| Entrée | Champ d'ajout | Ajouter le texte tapé |
| Tap sur un tag quantité | Ligne de fréquent, Ligne de résultat (dans la liste), Tag Quantité | Popup quantité au-dessus du Panneau + |
| Tap sur le Tag Rayon | Panneau + | Liste déroulante des 13 rayons |
| Tap | Champ quantité | Clavier numérique |
| Glisser vers la gauche | Ligne d'article | Supprimer + Snackbar Annuler |
| Appui long | Ligne d'article | Feuille d'édition d'article |
| Glisser-déposer | Ligne de parcours (Paramètres) | Ordonner les rayons |

- **Annuler plutôt que confirmer** : suppression d'article, désélection d'une recette validée et Terminer les courses passent par le Snackbar Annuler. Seule Nouvelle liste demande une confirmation.
- **Coche** : animation minimale mais satisfaisante (remplissage du cercle et tracé de la coche, durée courte M3), puis la ligne rejoint la Section Cochés. Pas de vibration, pas de son.
- **Écran allumé** : réglage facultatif, limité à l'onglet Liste.
- **Interdits** : appui long sur un fréquent ; appui long sur une Carte recette ; glisser-déposer hors parcours (pas de planning par jour en V1) ; vidage automatique de la liste ; entrée automatique dans les fréquents ; tri par fréquence ; suggestions dans la Liste ; tuiles.

## Accessibility Floor

Comportemental. Les contrastes sont dans `DESIGN.md` (section Colors).

| Exigence | Règle |
|---|---|
| Une main | Actions fréquentes dans la zone du pouce : FAB +, Barre de navigation, Bouton d'action en bas. La Barre d'application ne porte que ⚙, rarement utilisée. |
| Cibles tactiles | ≥ `{spacing.touch-target}` (48 dp) pour toute zone interactive : coche ronde, icône « modifier » de la Carte recette (même visuellement petite), tags du Panneau + (visuellement petits), bouton « Gérer », puces du Choix d'unité, Champ quantité, en-tête de la Section Cochés, poignée de la Ligne de parcours. |
| Repères non colorés | Le rayon est identifié par son nom écrit dans l'En-tête de rayon, jamais par la couleur seule. Coché = coche + barré + déplacement dans Cochés. État d'un fréquent = icône, pas teinte. Carte sélectionnée = repère graphique, pas teinte. |
| TalkBack | Ligne d'article : « Tomates, 500 g, Fruits et légumes, non coché ». En-tête de rayon annoncé comme titre, par son seul nom : « Fruits et légumes ». Ligne du Panneau + dans la liste : « Lait, dans la liste » ; son tag : « Quantité de Lait, 500 g » ou « Quantité de Lait, aucune ». Tags du champ : « Quantité, aucune », « Rayon, Divers ». Bouton : « Gérer les ajouts fréquents ». La Liste étant inaccessible sous le panneau, un ajout s'annonce : « Lait ajouté, Crèmerie ». FAB + : « Ajouter un article » (Liste), « Nouvelle recette » (Recettes). Carte recette : « Chili, sélectionnée » ; icône : « Modifier Chili ». Section Cochés : « Cochés, 5 articles, replié ». Changement de quantité ou de coche annoncé. |
| Gestes alternatifs | Glisser pour supprimer et appui long ont des actions TalkBack équivalentes (« Supprimer », « Modifier ») [ASSUMPTION]. Le glisser-déposer du parcours a des actions « Monter » / « Descendre » [ASSUMPTION]. |
| Taille du texte | Taille de police système respectée ; les lignes grandissent en hauteur, le nom d'article passe à la ligne plutôt que d'être tronqué. |
| Animations | Si les animations sont désactivées dans Android, la coche est instantanée ; une ligne nouvelle apparaît sans animation ni surlignage et la Liste saute à sa place sans glisser ; la Popup quantité apparaît d'un coup. |
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

1. Dans Recettes, Antoine touche FAB +. Une Fiche recette vide s'ouvre.
2. Il tape le nom : « Chili ».
3. Dans le Champ de recherche des ingrédients, il tape « hari », touche « Haricots rouges ». Unité par défaut préremplie ; il saisit 500.
4. Il ajoute de même oignon, bœuf haché, tomates, épices (sans quantité).
5. Il ne met ni lien ni photo, et revient à Recettes : la fiche s'est enregistrée seule dès le nom et le premier ingrédient.
6. **★ La Carte recette « Chili » apparaît dans le catalogue avec le Picto des haricots rouges en repli, en moins d'une minute.**

Échec : un ingrédient n'existe pas → « Créer « … » » l'ajoute au catalogue sans quitter la fiche. Sans nom ou sans ingrédient → la recette n'est pas créée [ASSUMPTION].

### Flux 5 — La recette du mercredi (Antoine, mercredi, la liste de la semaine est déjà validée)

1. Sa femme propose d'ajouter une quiche. Antoine ouvre Recettes et touche la Carte recette « Quiche ».
2. « Valider (1) » apparaît ; il le touche.
3. La Revue ne montre que les ingrédients de la quiche. Il décoche « Œufs » (déjà dans la liste) et laisse le reste.
4. Il touche « Ajouter à la liste ».
5. **★ La liste en cours est complétée sans repartir de zéro : les nouveaux ingrédients rejoignent leurs rayons, les quantités d'un même article s'additionnent.**

Échec : finalement, pas de quiche → il désélectionne la carte ; ses ingrédients non cochés quittent la liste, Snackbar Annuler.

### Flux 6 — Le premier lancement (Antoine, juste après l'installation)

1. Antoine ouvre l'app. Recettes affiche 3 à 5 recettes exemples et la ligne d'accueil.
2. Il touche deux Cartes recette, puis Valider.
3. La Revue s'ouvre ; il touche « Ajouter à la liste » sans rien changer.
4. **★ En moins d'une minute, il voit tout le flux fonctionner : sa première liste triée par rayon, sans avoir rien saisi.**
5. Il revient à Recettes, ouvre une recette exemple par l'icône « modifier » et la supprime depuis la Fiche recette.

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

- Source exacte du pack de pictos et sa licence ; faisabilité du complément en SVG générés dans le même style. Antoine attend des propositions.
- Fiche recette, ingrédient inconnu : « Créer « … » » au catalogue (Flux 4) ou texte libre comme le Panneau + depuis le 2026-10-30 ? À trancher avec l'epic 2.
