---
type: epic
title: "La liste de courses au magasin"
parent: initiative-grocery-list
covers: [R9, R10, R11, R12, R13, R15, R16, R17, R18, R19, R20, R23, R24]
sources: []
companions: []
after: []
refined: true
risk: high
---

# La liste de courses au magasin

## Description

Installée sur le téléphone d'Antoine, l'app tient une seule liste en cours, groupée par rayon dans l'ordre par défaut des 13 rayons. On la remplit à la main par le Panneau + (recherche, création à la volée avec quantité et rayon facultatifs, fréquents fournis) et on la coche d'une main jusqu'à Terminer les courses. L'epic livre aussi le socle que les epics 2 et 3 réutilisent : le projet Flutter et un build release installable, les thèmes clair et sombre, le stockage local prêt pour la synchro, le modèle d'unités et la fusion dans la liste (avec la provenance de chaque quantité), la recherche et la création d'article, le catalogue et les fréquents générés par IA.

## Outcome

Antoine remplace son app todo par la Liste pour ses courses : il ajoute un article en un tap depuis le Panneau + et coche tout d'une main au magasin. Le signal est le moment ★ des Flux 2 et 3 d'EXPERIENCE.md.

## Requirements

- R1 (parent R9) : la Liste montre une seule liste en cours, groupée sous des en-têtes de rayon dans l'ordre du parcours (par défaut, l'ordre des 13 rayons) ; chaque en-tête compte ses articles non cochés ; seuls les rayons non vides s'affichent.
- R2 (parent R10) : seul un tap sur la case coche un article ; l'article coché rejoint la section « Cochés (n) », repliée par défaut en bas de la liste ; décoché depuis cette section, il retourne dans son rayon ; un rayon entièrement coché disparaît.
- R3 (parent R11) : une quantité est en g, en ml, en pièces ou absente, sans conversion ; l'unité par défaut de l'article est préremplie ; un même article dans la même unité s'additionne, dans deux unités il donne deux lignes ; la Liste affiche les quantités arrondies pour la lecture (1,5 kg, 20 cl).
- R4 (parent R12) : la liste ne se vide jamais seule ; quand tout est coché, « Terminer les courses » apparaît et vide la liste, et le Snackbar Annuler la restaure.
- R5 (parent R13) : glisser un article vers la gauche le supprime, avec Snackbar Annuler ; un appui long ouvre une feuille pour changer la quantité (la ligne passe alors en mode manuel), changer le rayon ou supprimer l'article.
- R6 (parent R15) : le FAB + de la Liste ouvre le Panneau + avec le champ de recherche focalisé, clavier ouvert, et les fréquents en liste compacte groupée par rayon dans l'ordre du parcours ; le panneau reste ouvert après un ajout.
- R7 (parent R16) : un tap sur un fréquent l'ajoute à la liste, ou retire l'article de la liste s'il y est déjà, avec Annuler ; son état suit la Liste dans les deux sens.
- R8 (parent R17) : chaque frappe filtre tout le catalogue et un tap sur un résultat l'ajoute, ou retire l'article s'il est déjà dans la liste, avec Annuler ; sans correspondance exacte, « Créer « … » » crée l'article (Divers, sans unité si rien n'est choisi) et l'ajoute ; après un ajout, la ligne propose une quantité et un rayon, facultatifs.
- R9 (parent R18) : un catalogue unique d'environ 200 articles (nom, picto, rayon par défaut, unité par défaut) est fourni à l'installation ; un article créé à la volée rejoint ce catalogue.
- R10 (parent R20) : environ 30 fréquents sont fournis, dans un ordre stable par rayon ; l'app n'en ajoute jamais d'elle-même.
- R11 (parent R23) : la Liste vide, le Panneau + sans fréquent et le Panneau + sans résultat affichent leur message et au plus une action, avec la microcopie de Voice and Tone.
- R12 (parent R24) : la Liste et le Panneau + sont utilisables avec TalkBack (libellés annoncés, actions « Supprimer » et « Modifier » à la place des gestes), avec la taille de police système et sans animation quand elles sont désactivées.

## Constraints

- C1, C3, C4, C5, C6, C7, C8, C9, C10 de l'initiative s'appliquent tels quels ; C2 vaut pour cet epic sans permission demandée à l'utilisateur.
- L'architecture (AD-1 à AD-18) lie toutes les stories ; cet epic crée `core/` (base, tables, réglages, horloge, Annuler, thème, routeur, contenu fourni) et les fonctionnalités `catalogue` et `liste`.

## Done when

- Le build release est installé sur le téléphone d'Antoine et s'ouvre en thème clair comme en thème sombre, selon le réglage système.
- Les Flux 2 (au magasin à une main) et 3 (l'ajout éclair) d'EXPERIENCE.md passent de bout en bout, moment ★ observé.
- Le catalogue d'environ 200 articles et les ~30 fréquents générés sont présents, chacun avec un rayon et une unité.
- Chaque élément stocké porte un UUID, une date de modification et une suppression logique ; une ligne de liste garde la provenance de ses quantités.
- Les tests automatisés du socle, de la Liste et du Panneau + passent, et TalkBack lit la Liste et le Panneau +.

## Boundaries

- Parts des exigences partagées : R9 groupement par rayon (sa désactivation est à l'epic 3) ; R11 unités, arrondi et fusion dans la liste (la fusion en Revue est à l'epic 2) ; R12 vider la liste avec Annuler (la remise à zéro de la sélection est à l'epic 2) ; R18 catalogue fourni et création à la volée (Paramètres › Articles est à l'epic 3) ; R19 ordre par défaut (le glisser-déposer est à l'epic 3) ; R20 fréquents fournis (leur gestion est à l'epic 3) ; R23 états vides de la Liste et du Panneau + ; R24 sur ses surfaces.
- Hors epic : les recettes, la Revue, Nouvelle liste et le premier lancement (epic-recettes-et-revue) ; l'écran Paramètres, Écran allumé, la sauvegarde (epic-reglages-et-sauvegarde).
- Touch point: pack de pictos (externe, choix reporté) — consommé par le catalogue ; owner: cet epic.

## References

- parent — _bmad-output/initiative-grocery-list/initiative-grocery-list.md, section Requirements
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Liste, Panneau +, Flux 2 et 3
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md
- mockups — _bmad-output/initiative-grocery-list/ux-grocery-list/.working/key-liste.html, key-panneau-plus.html
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, AD-1 à AD-18 (cet epic pose core/, catalogue, liste et Terminer les courses)

## Notes

- Assumption: identifiant Android `fr.antoine.kadi`, définitif dès la première installation ; à confirmer par Antoine dans la story 1.

- Decision: 2026-10-25 — les décisions partagées sont tranchées dans l'architecture (AD-1 à AD-18) ; cet epic pose le noyau : base, tables, réglages et parcours par défaut, contenu fourni, horloge, Annuler, thème, routeur.
- Decision: 2026-10-25 — story traceur : « Kadi installée : un article cherché apparaît dans la Liste » (socle, base v1, chargeur de contenu, Panneau + réduit à la recherche, Liste, release installée) ; la suivante est la moins sûre, les quantités et contributions.
- Decision: 2026-10-25 — la base v1 de la story 1 crée toutes les tables de l'epic ; une story suivante n'ajoute une migration que si elle change le schéma.
- Decision: 2026-10-25 — l'accessibilité (TalkBack, taille de police, animations) et la microcopie se construisent dans chaque story d'écran, sans story dédiée.
- Decision: 2026-10-25 — le choix du pack de pictos reste hors de l'epic : les stories utilisent le résolveur à repli neutre et les picto_key du contenu fourni.
- Decision: 2026-10-25 — une story « Refactor sweep » clôt l'epic ; pas de suite de bout en bout ici, elle est dans l'epic 3.
- Decision: 2026-10-26 — découpage en 9 stories approuvé ; construction en boucle automatique (bmad-build-auto) ; relecture du plan avant les stories 1 et 2 (les plus risquées), pause après les stories 1 et 3 (installation et relecture du contenu par Antoine).
- Decision: 2026-10-25 — l'app s'appelle « Kadi » (nom affiché sur le téléphone).
- Decision: 2026-10-25 — pas de générateur de code Riverpod ; Drift garde le sien.
- Decision: 2026-10-25 — le contenu fourni (~200 articles, ~30 fréquents) est une story à part, générée par IA et relue par Antoine.
- Decision: 2026-10-25 — étape faite par Antoine avant la première story : réparer le certificat SSL de git sur le poste, puis passer Flutter de 3.44.5 à 3.47.8.
