---
type: initiative
title: grocery-list
parent: none
sources:
  - _bmad-output/forge-grocery-list/forge-grocery-list.md
  - _bmad-output/forge-grocery-list/.memlog.md
  - _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md
  - _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md
  - _bmad-output/initiative-grocery-list/ux-grocery-list/.memlog.md
companions:
  - _bmad-output/initiative-grocery-list/glossary.md
  - _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md
  - _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md
  - _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md
after: []
risk: medium
---

# grocery-list — V1

## Description

Une app Android (Flutter) de liste de courses pour le foyer d'Antoine. On choisit les recettes de la semaine, on valide, on décoche en Revue ce qu'on a déjà, et la liste apparaît fusionnée et triée par rayon dans l'ordre du magasin, sans classement manuel. Au magasin, on coche d'une main. Entre deux semaines, on ajoute un article en un tap avec le bouton +. La V1 tourne sur un seul téléphone, sans compte, et prépare ses données pour le partage à deux de la V2. Elle répond au besoin d'Antoine avec le moins de friction possible ; battre Bring!, Paprika ou Jow n'est pas le but (brief, Statut et But).

## Outcome

Pour Antoine et son foyer, préparer la liste de la semaine à partir des recettes puis faire les courses demande moins de saisies et de clics que leur app todo actuelle. Le signal, ce sont les moments ★ des parcours d'EXPERIENCE.md, en particulier le dimanche soir (Flux 1) et la recette saisie en moins d'une minute (Flux 4).

## Requirements

- R1 (brief Fiche recette ; experience Flux 4 ; Decision 2026-10-25, 2026-11-03) : on crée, modifie et supprime une recette avec un nom, des ingrédients ajoutés par une popup de recherche sur le catalogue avec quantité facultative, un lien facultatif et une photo facultative prise dans la galerie ou à l'appareil photo, et rien d'autre. La fiche s'enregistre par un bouton de validation, actif dès qu'elle a un nom et au moins un ingrédient. Une recette de 5 ingrédients se saisit en moins d'une minute.
- R2 (ux-memlog Catalogue de recettes ; Decision 2026-10-25) : l'onglet Recettes affiche les recettes en cartes sur 2 colonnes, avec la photo ou, à défaut, le picto de l'ingrédient principal teinté de son rayon.
- R3 (ux-memlog Carte recette sélectionnée ; experience Carte recette ; Decision 2026-11-03) : un tap sur une carte la sélectionne ou la désélectionne pour la semaine. Chaque carte porte une petite coche ronde comme la Liste, vide ou pleine, sans distinguer validée et à valider. « Valider (n) » n'apparaît que si n recettes sélectionnées ne sont pas encore validées. La fiche s'ouvre par l'icône « modifier » de la carte.
- R4 (brief Une seule liste ; experience Revue, Flux 1 et 5) : Valider ouvre la Revue avec les seuls ingrédients des recettes nouvellement validées, groupés par rayon dans l'ordre du parcours, tous cochés. Les quantités d'un même article dans la même unité sont additionnées.
- R5 (brief Revue ; experience Ligne de Revue) : en Revue, on décoche ce qu'on a déjà et on remplace une quantité. « Ajouter à la liste » ajoute à la liste en cours les seuls ingrédients cochés, avec leur quantité, puis ouvre la Liste avec « Ta liste est prête. ».
- R6 (ux-memlog Désélection d'une recette validée) : désélectionner une recette déjà validée retire de la liste ses ingrédients non cochés et réduit d'autant les quantités fusionnées. Le Snackbar Annuler rétablit l'état précédent.
- R7 (ux-memlog Modifier une recette validée ; Decision 2026-10-25) : modifier ou supprimer une recette déjà validée ne change pas la liste en cours ; une modification vaut pour les validations suivantes.
- R8 (brief Une seule liste ; ux-memlog Nouvelle liste) : l'action Nouvelle liste de Recettes demande confirmation, puis efface tous les articles de la liste, cochés ou non, et la sélection de la semaine. « Garder » ne change rien.
- R9 (brief Rayons ; experience Liste ; Decision 2026-10-30) : la Liste montre une seule liste en cours, groupée sous des en-têtes de rayon dans l'ordre du parcours, sans compteur. Si le groupement est désactivé dans les Paramètres, les articles suivent l'ordre d'ajout, sans en-têtes.
- R10 (ux-memlog Cochés, seule la case coche) : seul un tap sur la case coche un article. L'article coché rejoint la section « Cochés (n) », repliée par défaut en bas de la liste. Décoché depuis cette section, il retourne dans son rayon.
- R11 (brief Unités ; forge-memlog Unités ; Decision 2026-10-30) : une quantité se saisit en pièces, g, kg, ml ou L, ou reste absente ; l'unité se choisit librement, celle de l'article est préchoisie, sinon la pièce. kg et L ne sont que des saisies de g et de ml : aucune conversion entre pièces, poids et volumes. Un même article dans la même unité s'additionne ; dans des unités différentes, il donne deux lignes, jamais une somme. La Liste affiche les quantités arrondies pour la lecture (1,5 kg, 20 cl).
- R12 (ux-memlog Fin de liste, Terminer les courses) : la liste ne se vide jamais seule. Quand tout est coché, « Terminer les courses » apparaît : il vide la liste et la sélection de la semaine, et le Snackbar Annuler restaure les deux.
- R13 (ux-memlog Édition d'un article ; experience Feuille d'édition d'article ; Decision 2026-10-30) : glisser un article vers la gauche le supprime, avec Snackbar Annuler. Un appui long ouvre la Feuille d'édition, une feuille courte qui monte du bas de l'écran : quantité, unité, rayon (l'article change alors de groupe) et Supprimer. Changer l'unité d'une ligne la fusionne avec la ligne non cochée du même article dans cette unité, s'il y en a une.
- R14 (ux-memlog Écran allumé) : le réglage « Garder l'écran allumé », désactivé par défaut, empêche la mise en veille tant que l'onglet Liste est affiché, et seulement lui.
- R15 (brief Bouton + ; ux-memlog Panneau +, focus ; Decision 2026-11-01, 2026-11-05) : le FAB + de la Liste ouvre le Panneau +, un panneau bas qui laisse la Liste visible au-dessus de lui, derrière un voile léger : champ « Ajouter un article » focalisé, clavier ouvert, ses deux tags (R28), puis la section « Ajouts fréquents », titrée, avec un bouton « Gérer » à droite du titre qui mènera à la gestion des fréquents. Les fréquents y forment une liste plate dans l'ordre du parcours, sans en-tête ni libellé de rayon, distincte à l'œil de la Liste. Le panneau reste ouvert après un ajout.
- R16 (brief Bouton + ; experience Ligne de fréquent ; Decision 2026-10-30) : un tap sur un fréquent l'ajoute à la liste, son + devenant une coche, ou l'en retire s'il y est déjà, avec Annuler. Son état suit la Liste dans les deux sens : cocher l'article dans la Liste repasse le fréquent à « hors liste ».
- R17 (brief Bouton + ; experience Champ de recherche ; Decision 2026-11-01) : en plus d'ajouter, chaque frappe dans « Ajouter un article » filtre tout le catalogue ; un tap sur un résultat l'ajoute à la liste avec les tags de R28, ou l'en retire s'il y est déjà, avec Annuler. Le Panneau + ne crée jamais d'article au catalogue.
- R18 (brief Catalogue ; ux-memlog Catalogue d'articles ; Decision 2026-10-30) : un catalogue unique d'environ 200 articles (nom, picto, rayon par défaut, unité par défaut) est fourni à l'installation et sert à la recherche ; un ajout à la liste ne le modifie jamais. Paramètres › Articles permet de chercher, créer et modifier un article ; une modification vaut pour les ajouts suivants.
- R19 (ux-memlog Rayons ; brief Rayons) : il y a 13 rayons fixes. Le parcours s'ordonne par glisser-déposer dans les Paramètres, et la Liste, la Revue et le Panneau + suivent cet ordre.
- R20 (brief Fréquents ; ux-memlog Fréquents) : environ 30 fréquents sont fournis. On en ajoute ou on en retire seulement depuis les Paramètres ; l'app n'en ajoute jamais d'elle-même, et leur ordre dans chaque rayon reste stable.
- R21 (brief Données V1 ; experience Paramètres ; Decision 2026-10-25) : depuis les Paramètres, l'export produit un fichier de sauvegarde partagé par la feuille de partage Android, et l'import fusionne ce fichier avec les données existantes. Un fichier invalide affiche une erreur et ne modifie aucune donnée.
- R22 (ux-memlog Premier lancement ; experience Flux 6 ; Decision 2026-10-25) : au premier lancement, l'app s'ouvre sur Recettes avec 3 à 5 recettes exemples supprimables et la ligne d'accueil ; le catalogue et les fréquents sont déjà en place. On obtient une première liste triée par rayon en moins d'une minute, sans rien saisir. Les lancements suivants s'ouvrent sur la Liste.
- R23 (experience Voice and Tone, State Patterns) : chaque état vide (Recettes, Liste, Panneau + sans fréquent ou sans résultat) affiche son message et au plus une action. La microcopie des moments listés suit le tableau Voice and Tone.
- R24 (experience Accessibility Floor) : tout est faisable avec TalkBack : libellés annoncés, actions « Supprimer », « Modifier », « Monter » et « Descendre » à la place des gestes. La taille de police système est respectée sans troncature, et la coche est instantanée quand les animations sont désactivées.
- R25 (Decision 2026-11-01) : Entrée dans « Ajouter un article » ajoute le texte saisi, qu'un résultat s'affiche ou non : l'article du catalogue qui porte exactement ce nom (casse et accents ignorés), sinon une ligne libre de la liste, qui n'entre pas au catalogue et dont le rayon n'est jamais mémorisé. Un article déjà dans la liste n'est ni ajouté une seconde fois ni retiré : sans tag, rien ne change ; avec des tags, leur quantité et leur rayon remplacent ceux de sa ligne. Après Entrée, le champ se vide et le clavier reste ouvert.
- R26 (Decision 2026-11-01) : dans le Panneau +, tout article déjà dans la liste (fréquent ou résultat) montre sa coche et un tag quantité : « Qté » en contour sans quantité, la quantité en plein sinon. Ce tag ouvre la popup quantité, au-dessus du panneau : quantité et unité, jamais le rayon. La Feuille d'édition de R13 ne s'ouvre plus depuis le panneau.
- R27 (Decision 2026-11-01) : tout ajout depuis le Panneau + se voit aussitôt dans la Liste derrière lui : la ligne arrive animée et brièvement surlignée, juste au-dessus du panneau si elle serait masquée, la Liste défilant alors jusqu'à elle ; sinon rien ne défile. Sans animation quand elles sont désactivées.
- R28 (Decision 2026-11-01) : sous « Ajouter un article », un tag Quantité ouvre la popup quantité de R26 et un tag Rayon ouvre une liste déroulante des 13 rayons. Rayon affiche le rayon de l'article au nom exact, sinon Divers. Un tag choisi passe de contour à plein. Le choix ne vaut que pour la ligne ajoutée suivante, par Entrée ou tap sur un résultat, jamais pour le catalogue ; les tags reviennent ensuite à zéro. Un tap sur un fréquent ne les utilise pas.

## Constraints

- C1 (brief Cible ; experience Foundation) : Flutter, téléphone Android seulement. Composants Material 3 standard ; le delta est dans DESIGN.md et EXPERIENCE.md.
- C2 (brief Données V1 ; Decision 2026-10-25) : la V1 est entièrement locale, sans compte et sans réseau requis. Les seules permissions demandées à l'utilisateur sont la galerie et l'appareil photo, pour la photo de recette.
- C3 (brief Données V1 ; forge-memlog V1 locale) : chaque élément stocké porte un UUID, une date de modification et une suppression logique, pour la synchro de la V2.
- C4 (experience Foundation, Voice and Tone) : français seulement, tutoiement, ni emoji ni jargon.
- C5 (design Colors ; ux-memlog Thème) : thèmes clair et sombre conçus ensemble, qui suivent le réglage système, avec les tokens de DESIGN.md. La couleur appartient aux 13 rayons, et le nom du rayon est toujours écrit à côté.
- C6 (design Colors ; ux-memlog Argile étendue) : l'argile n'apparaît que sur le FAB +, l'indicateur d'onglet actif, les boutons d'action (Valider, Ajouter à la liste, Terminer les courses) et l'action des snackbars.
- C7 (brief Pictos ; design Picto ; ux-memlog Lignes de la Liste ; Decision 2026-11-03) : pictos au trait d'un même pack, teintés du rayon, jamais d'emoji. Ils sont absents des lignes de la Liste et de la Revue, et présents dans le Panneau + et la Fiche recette.
- C8 (experience Accessibility Floor) : usage à une main : les actions fréquentes sont dans la zone du pouce, et toute cible tactile fait au moins 48 dp.
- C9 (experience Interaction Primitives) : annuler plutôt que confirmer ; seule Nouvelle liste demande une confirmation.
- C10 (experience Interaction Primitives, Interdits) : ni appui long sur un fréquent ou une carte recette, ni glisser-déposer hors parcours, ni vidage automatique, ni entrée automatique dans les fréquents, ni tri par fréquence, ni suggestions dans la Liste, ni tuiles.

## Done when

- Les six parcours d'EXPERIENCE.md (Key Flows) passent de bout en bout sur un téléphone Android, en thème clair et en thème sombre, chaque moment ★ observé.
- Sur une installation neuve, une première liste triée par rayon est obtenue à partir des recettes exemples en moins d'une minute, sans rien saisir.
- Une recette de 5 ingrédients se saisit en moins d'une minute.
- Un export suivi d'un import sur une installation neuve restaure les recettes, le catalogue, les fréquents, le parcours, les réglages et la liste en cours.
- Le plancher d'accessibilité d'EXPERIENCE.md est vérifié : TalkBack, cibles de 48 dp, grande taille de police.
- Une version release est installée sur le téléphone d'Antoine et sert à de vraies courses de la semaine.

## Boundaries

- Hors V1 : la V2, c'est-à-dire le foyer rejoint par code ou QR code, le partage en temps réel, la coche à deux et le backend de synchro. La V3 (Play Store, freemium) aussi.
- Hors V1 : le planning par jour par glisser-déposer.
- Jamais : l'inscription ou le compte, le contenu commercial, les suggestions de recettes.
- Jamais : les étapes de préparation, les portions, les temps de préparation, les tags ou catégories de recettes (« ce n'est pas une app de cuisine »).
- Jamais : l'import de recettes par URL, l'inventaire de stock ou le drapeau « placard », plusieurs magasins, la conversion d'unités.
- Jamais : les onglets Boissons, Divers ou « Habituels », ni de tiroir de navigation. Il y a deux onglets seulement.
- Touch point: maintien de l'écran allumé (Android) — utilisé par Écran allumé (R14) ; owner: epic-reglages-et-sauvegarde
- Touch point: pack de pictos (externe, à choisir) — consommé par le catalogue (C7) ; owner: epic-reglages-et-sauvegarde (repris de l'epic 1 le 2026-11-04)
- Touch point: galerie et appareil photo Android — photo de recette (R1) ; owner: epic-recettes-et-revue
- Touch point: feuille de partage et sélecteur de fichier Android — export et import (R21) ; owner: epic-reglages-et-sauvegarde
- Parcours traceur : une recette exemple sélectionnée, validée, passée en Revue, ajoutée à la Liste triée par rayon, cochée, puis Terminer les courses ; la Liste vient de l'epic 1, le reste de l'epic 2.

## References

- brief — _bmad-output/forge-grocery-list/forge-grocery-list.md, sections Décisions, Rejeté, Ouvert
- forge-memlog — _bmad-output/forge-grocery-list/.memlog.md
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Information Architecture, Component Patterns, State Patterns, Key Flows, Accessibility Floor
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md, sections Colors, Components
- ux-memlog — _bmad-output/initiative-grocery-list/ux-grocery-list/.memlog.md (ses décisions les plus récentes priment sur DESIGN.md et EXPERIENCE.md)
- mockups — _bmad-output/initiative-grocery-list/ux-grocery-list/.working/key-liste.html, key-revue.html, key-recettes.html, key-panneau-plus.html (choix provisoires indiqués en légende ; le spine prime)
- glossary — _bmad-output/initiative-grocery-list/glossary.md
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, AD-1 à AD-18

## Notes

- Decision: 2026-10-25 — confirmées : FAB + de Recettes = fiche recette vide, ⚙ sur Liste et Recettes ; pas d'enregistrement sans nom, suppression depuis la fiche ; quitter la Revue ou tout décocher n'ajoute rien ; seuls les rayons non vides s'affichent, un rayon tout coché disparaît, pas de section Cochés sans coche ; un tap sur un résultat déjà en liste le retire ; parcours par défaut = ordre des 13 rayons ; un tap sur le nom d'un article ne fait rien.
- Decision: 2026-10-25 — un article créé à la volée sans rayon choisi va dans Divers, sans unité ; l'ajout rapide propose quantité et rayon, en facultatif (R17).
- Decision: 2026-10-25 — le contenu fourni (~200 articles avec rayon, unité et picto, ~30 fréquents, 3 à 5 recettes exemples) sera généré par une IA pendant le développement.
- Decision: 2026-10-25 — les noms des 13 rayons sont définitifs, tels que validés à l'UX (tableau Colors de DESIGN.md).
- Decision: 2026-10-25 — l'import fusionne (R21) ; photo depuis la galerie et l'appareil photo (R1, C2) ; enregistrement automatique avec un nom et au moins un ingrédient (R1) ; visuel de repli = picto de l'ingrédient principal (R2) ; supprimer une recette validée ne touche pas la liste (R7) ; hors premier lancement, l'app s'ouvre sur la Liste (R22, réponse « onglet todo »).
- Decision: 2026-10-25 — mise en page des maquettes retenue : Nouvelle liste en action texte dans la barre d'application, à gauche de ⚙ ; FAB + empilé au-dessus du bouton d'action ; Revue en écran poussé plein écran, avec flèche retour et sans barre de navigation.
- Decision: 2026-10-25 — les deux conflits de sources (argile étendue dans DESIGN.md, points tranchés dans EXPERIENCE.md) sont corrigés en remettant les deux documents à jour avec bmad-ux.
- Decision: 2026-10-25 — découpage en 3 epics par capacité livrée ensemble, la Liste d'abord parce qu'elle est utilisable seule : epic-liste-de-courses, epic-recettes-et-revue, epic-reglages-et-sauvegarde (tickets/tickets.toml).
- Decision: 2026-10-25 — les décisions techniques partagées (stockage et modèle prêt pour la synchro, unités et fusion, gestion d'état, tokens de thème) sont tranchées par bmad-architecture avant la planification de l'epic 1.
- Decision: 2026-10-25 — le pack de pictos ne bloque pas l'epic 1 ; choix reporté.
- Decision: 2026-10-25 — Écran allumé (R14), réglage facultatif, va dans l'epic 3 avec l'écran Paramètres.
- Decision: 2026-10-25 — le socle (projet Flutter, build release installable) ouvre l'epic 1 ; la vérification finale des six parcours et de l'accessibilité clôt l'epic 3.
- Decision: 2026-10-25 — architecture finalisée (bmad-architecture). Comportements tranchés avec elle : un article déjà coché qu'une recette ajoute de nouveau crée une nouvelle ligne non cochée ; un tap sur un fréquent ou un résultat déjà dans la liste retire toutes les lignes non cochées de l'article, quantités de recettes comprises, avec Annuler ; une correction en Revue d'un ingrédient partagé se répartit entre les recettes au prorata ; corriger une quantité dans la Liste passe la ligne en mode manuel, que les désélections ne touchent plus.
- Decision: 2026-10-25 — l'app s'appelle « Kadi ».
- Decision: 2026-10-30 — revue de l'app par Antoine après l'epic 1 : l'ajout au Panneau + doit être le plus rapide possible. Un ajout se fait en un geste et se précise ensuite (Feuille d'édition courte, unité au choix parmi pièce, g, kg, ml, L) ; Entrée ajoute le texte saisi, en ligne libre hors catalogue s'il ne correspond à aucun article (jamais de création au catalogue : doublons d'orthographe) ; en-têtes sans compteur ; « Ajouts fréquents » en liste plate avec icône de modification, sans action pour l'instant ; picto de repli inchangé. Remplace la création à la volée du 2026-10-25 (R17, R18).
- Decision: 2026-10-30 — l'architecture (AD-4, AD-17 : une ligne de liste référence toujours un article) et EXPERIENCE.md (Panneau +, ligne de fréquent, champ quantité, en-tête de rayon, feuille ouverte sur le Panneau +) ne suivent plus ces exigences : à remettre à jour avec bmad-architecture et bmad-ux avant de découper.
- Decision: 2026-10-30 — Panneau + sans résultat : une ligne « Ajouter « … » » qui fait comme Entrée (bmad-ux) ; architecture et EXPERIENCE.md remis à jour le jour même (AD-4 à AD-6, AD-8, AD-13, AD-14, AD-17).
- Decision: 2026-11-01 — 2e revue de l'app par Antoine : voir l'ajout en direct dans la Liste (R27), panneau bas sans voile (R15), tags Quantité et Rayon sous le champ (R28), tag quantité sur les lignes et popup au lieu de la feuille empilée (R26), plus de Ligne saisie ; Entrée sur un article déjà dans la liste remplace sa quantité et son rayon si des tags sont choisis (R25) ; le rayon d'un article hors catalogue n'est jamais mémorisé, seule la gestion des fréquents mémorise (R25) ; tout est livré en un lot. L'architecture (AD-5, AD-13), DESIGN.md et EXPERIENCE.md ne suivent plus : à remettre à jour avec bmad-architecture et bmad-ux avant de découper.
- Decision: 2026-11-03 — revue de l'epic 2 par Antoine (premiers retours) : coche discrète façon todo et crayon discret sur la carte recette ; Revue sans picto, champ quantité seulement s'il y a une quantité, petit champ arrondi à fond grisé ; Fiche recette : quantité facultative sans focus après un ajout, ajout d'ingrédient par une popup de recherche comme le Panneau +, bouton de validation au lieu de l'enregistrement automatique (R1, C7). DESIGN.md et EXPERIENCE.md (Carte recette, Ligne de Revue, Fiche recette, Ligne d'ingrédient, Champ de recherche) ne suivent plus : à remettre à jour avec bmad-ux ; les stories 2.9 à 2.12 portent le détail.
- Assumption: 2026-11-03 — quitter une Fiche recette modifiée sans la valider demande « Quitter sans enregistrer ? » (Garder / Quitter) : exception à C9 pour ne pas perdre une saisie ; Antoine la valide au test.
- Assumption: l'ingrédient principal est le premier ingrédient de la recette.
- Assumption: une nouvelle recette sans nom ou sans ingrédient n'est pas créée ; une recette existante garde sa dernière version valide.
- Assumption: l'import fusionne par UUID ; la date de modification la plus récente l'emporte, suppressions logiques comprises.
- Assumption: dans les Paramètres, Articles, Fréquents et Parcours sont des sous-écrans ; la Fiche article est une feuille modale, et le picto se choisit dans une grille du pack avec recherche.
- Assumption: les rôles M3 dérivés viennent de ColorScheme.fromSeed, surchargés par DESIGN.md ; le Snackbar a un fond on-surface, un texte surface et une action en argile du thème opposé (inverse-primary) ; contrastes vérifiés au build.
- Open question: source et licence du pack de pictos, et faisabilité du complément en SVG générés : Antoine attend des propositions. C7 attend.
- Assumption: 2026-11-02 — un ingrédient de recette inconnu passe par « Créer « … » » et rejoint le catalogue (Divers, sans unité), comme le Flux 4 et AD-17, pas une ligne libre (R1, epic 2) ; Antoine le valide au test de fin d'epic 2.
- Open question: Paramètres › Articles a-t-il encore lieu si la liste n'alimente plus le catalogue, et un fréquent peut-il être un nom libre ? R18, R20, epic 3.
- Decision: 2026-11-04 — Antoine valide les epics 1 et 2 ; les hypothèses à valider au test de fin d'epic 2 (« Quitter sans enregistrer ? », ingrédient inconnu créé au catalogue) sont confirmées.
- Decision: 2026-11-04 — le pack de pictos, jamais choisi pendant l'epic 1, passe à l'epic 3 (story 3.5) ; les questions ouvertes sur Paramètres › Articles et les fréquents sont tranchées par des hypothèses de l'epic 3, qu'Antoine valide au test de fin d'epic.
- Decision: 2026-11-05 — R15 dit « voile léger » au lieu de « sans voile » : le voile posé à la revue finale de l'epic 1 (2026-11-02) a été validé par Antoine avec l'epic. Panneau + en grande police : le budget de hauteur mesure la vraie hauteur des tags, pour qu'un résultat unique ne disparaisse jamais (R24 ; revient sur le rejet de la story 1.15).

- V2 visuelle (2026-11-09) : la refonte `redesign/` change le texte de R2 (lignes avec monogramme au lieu de cartes sur 2 colonnes), R3 (bouton « Ajouter / Ajoutée », la ligne ouvre la fiche), R15 (fréquents en pastilles derrière le tag ⚡ Fréquents, plus affichés par défaut) et R26 (Module quantité au lieu de la popup). Le détail est dans DESIGN.md et EXPERIENCE.md, § V2 visuelle.
- Retours de test V2 (2026-11-10) : trois onglets Liste · Recettes · Paramètres, ouverture toujours sur la Liste ; « Nouvelle liste » remplacée par « Vider les recettes » (seuls leurs ingrédients quittent la liste) et « Vider la liste » ; tri par nom dans un rayon ; suppression d'un article du catalogue ; seuls les Paramètres ajoutent au catalogue ; photo de recette depuis un lien (première fonction réseau). Détail : EXPERIENCE.md § Retours de test.
