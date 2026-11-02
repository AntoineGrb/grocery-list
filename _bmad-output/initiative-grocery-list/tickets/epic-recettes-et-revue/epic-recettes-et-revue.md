---
type: epic
title: "De la recette à la liste"
parent: initiative-grocery-list
covers: [R1, R2, R3, R4, R5, R6, R7, R8, R11, R12, R22, R23, R24]
sources: []
companions: []
after: []
refined: true
risk: high
---

# De la recette à la liste

## Description

Antoine saisit ses recettes, avec une photo prise dans la galerie ou à l'appareil photo, et sélectionne celles de la semaine. Il valide, décoche en Revue ce qu'il a déjà et retrouve les ingrédients fusionnés dans la liste en cours de l'epic 1. Désélectionner une recette validée retire ses quantités, grâce à la provenance posée par l'epic 1. L'epic livre aussi le premier lancement avec 3 à 5 recettes exemples générées par IA, Nouvelle liste, et la remise à zéro de la sélection par Terminer les courses. Il réutilise la recherche d'article et la création au catalogue de l'epic 1.

## Outcome

Le dimanche soir, Antoine et sa femme obtiennent la liste de la semaine fusionnée et triée par rayon, sans aucun classement manuel. Le signal est le moment ★ des Flux 1, 4, 5 et 6 d'EXPERIENCE.md.

## Requirements

- R1 (parent R1) : on crée, modifie et supprime une recette avec un nom, des ingrédients pris dans le catalogue par recherche + tap avec quantité facultative, un lien facultatif et une photo facultative prise dans la galerie ou à l'appareil photo, et rien d'autre ; la fiche s'enregistre automatiquement dès qu'elle a un nom et au moins un ingrédient ; une recette de 5 ingrédients se saisit en moins d'une minute.
- R2 (parent R2) : l'onglet Recettes affiche les recettes en cartes sur 2 colonnes, avec la photo ou, à défaut, le picto de l'ingrédient principal teinté de son rayon.
- R3 (parent R3) : un tap sur une carte la sélectionne ou la désélectionne pour la semaine ; une carte sélectionnée porte une coche et une bordure, sans distinguer validée et à valider ; « Valider (n) » n'apparaît que si n recettes sélectionnées ne sont pas encore validées ; la fiche s'ouvre par l'icône « modifier » de la carte.
- R4 (parent R4) : Valider ouvre la Revue avec les seuls ingrédients des recettes nouvellement validées, groupés par rayon dans l'ordre du parcours, tous cochés ; les quantités d'un même article dans la même unité sont additionnées.
- R5 (parent R5) : en Revue, on décoche ce qu'on a déjà et on remplace une quantité ; « Ajouter à la liste » ajoute à la liste en cours les seuls ingrédients cochés, avec leur quantité, puis ouvre la Liste avec « Ta liste est prête. ».
- R6 (parent R6) : désélectionner une recette déjà validée retire de la liste ses ingrédients non cochés et réduit d'autant les quantités fusionnées ; le Snackbar Annuler rétablit l'état précédent.
- R7 (parent R7) : modifier ou supprimer une recette déjà validée ne change pas la liste en cours ; une modification vaut pour les validations suivantes.
- R8 (parent R8) : l'action Nouvelle liste de Recettes demande confirmation, puis efface tous les articles de la liste, cochés ou non, et la sélection de la semaine ; « Garder » ne change rien.
- R9 (parent R11) : en Revue, un même article dans la même unité s'additionne ; dans des unités différentes, il donne deux lignes, jamais une somme ; aucune conversion entre pièces, poids et volumes.
- R10 (parent R12) : « Terminer les courses » vide la liste et la sélection de la semaine, et le Snackbar Annuler restaure les deux.
- R11 (parent R22) : au premier lancement, l'app s'ouvre sur Recettes avec 3 à 5 recettes exemples supprimables et la ligne d'accueil ; le catalogue et les fréquents sont déjà en place ; on obtient une première liste triée par rayon en moins d'une minute, sans rien saisir ; les lancements suivants s'ouvrent sur la Liste.
- R12 (parent R23) : Recettes sans recette affiche son message et au plus une action, avec la microcopie de Voice and Tone.
- R13 (parent R24) : Recettes, la Fiche recette et la Revue sont utilisables avec TalkBack (libellés annoncés, actions à la place des gestes), avec la taille de police système et sans animation quand elles sont désactivées.

## Constraints

- C1, C3 à C10 de l'initiative s'appliquent tels quels ; C2 : les seules permissions demandées sont la galerie et l'appareil photo, pour la photo de recette.
- L'architecture (AD-1 à AD-19) lie toutes les stories ; cet epic crée la fonctionnalité `recettes`, ses tables (`recipes`, `recipe_ingredients`, `week_selections`, par une migration v3) et les actions Ajouter à la liste, désélection d'une recette validée et Nouvelle liste ; il complète Terminer les courses.

## Done when

- Les Flux 1 (le dimanche soir), 4 (saisir une recette), 5 (la recette du mercredi) et 6 (le premier lancement) d'EXPERIENCE.md passent de bout en bout sur le build release installé, moment ★ observé.
- Une recette de 5 ingrédients se saisit en moins d'une minute.
- Désélectionner une recette validée, puis Annuler, laisse la liste exactement dans son état précédent.
- Les tests automatisés de la Revue, de la fusion et de la désélection passent, et TalkBack lit Recettes, la Fiche recette et la Revue.

## Boundaries

- Parts des exigences partagées : R11 fusion des quantités en Revue ; R12 remise à zéro de la sélection par Terminer les courses, et sa restauration par Annuler ; R23 états vides de Recettes ; R24 sur ses surfaces.
- Hors epic : la Liste, la coche et le Panneau + (epic-liste-de-courses) ; les Paramètres, l'icône ⚙ et la sauvegarde (epic-reglages-et-sauvegarde) ; le planning par jour (hors V1) ; la suite de bout en bout des six parcours (epic-reglages-et-sauvegarde).
- Touch point: galerie et appareil photo Android — photo de recette ; owner: cet epic.

## References

- parent — _bmad-output/initiative-grocery-list/initiative-grocery-list.md, section Requirements
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Recettes, Fiche recette, Revue, Flux 1, 4, 5 et 6
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md, Components recipe-card, review-row, ingredient-row
- mockups — _bmad-output/initiative-grocery-list/ux-grocery-list/.working/key-recettes.html, key-revue.html
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, surtout AD-3, AD-4, AD-5, AD-8, AD-10, AD-13, AD-15, AD-16, AD-17, AD-18

## Notes

- Decision: 2026-11-02 — epic affiné sans arrêt (demande d'Antoine : enchaîner les étapes, il teste l'epic entier à la fin) : Requirements rendus depuis les lignes de l'initiative ; les points ouverts sont tranchés par les hypothèses ci-dessous, qu'Antoine valide au test de fin d'epic.
- Decision: 2026-11-02 — découpage en 8 stories, dans une seule voie (Recettes, Revue et actions partagent l'écran Recettes) ; traceur : story 1, « une recette exemple sélectionnée et validée arrive dans la Liste » (migration v3 jusqu'à la Liste) ; puis la Revue et la désélection, les plus risquées (prorata et provenance, AD-4, AD-5).
- Decision: 2026-11-02 — les stories forment une seule voie dans leurs prérequis (chacune attend la précédente) : elles partagent l'écran Recettes, la Revue, les repositories et les chaînes ; la vérification du découpage l'a demandé.
- Decision: 2026-11-02 — la part manuelle de Done when (Flux 1, 4, 5 et 6 sur la release installée, passage TalkBack, galerie et appareil photo) est faite par Antoine à la clôture de l'epic, comme pour l'epic 1.
- Decision: 2026-11-02 — pas de suite de bout en bout ici : elle est dans l'epic 3 (architecture, convention Tests) ; la story 8 « Refactor sweep » clôt l'epic.
- Decision: 2026-11-02 — l'accessibilité (TalkBack, taille de police, animations) et la microcopie se construisent dans chaque story d'écran, sans story dédiée, comme à l'epic 1.
- Assumption: 2026-11-02 — un ingrédient inconnu passe par « Créer « … » » dans la Fiche recette et rejoint le catalogue (rayon Divers, sans unité), comme le Flux 4 et AD-17, et non une ligne libre : une recette se revalide chaque semaine, et un article du catalogue se retrouve à la recherche et se corrige dans Paramètres › Articles (epic 3). Répond à la question ouverte de l'initiative (R1).
- Assumption: 2026-11-02 — Ligne d'ingrédient : le Champ quantité préchoisit l'unité de l'article, sinon la pièce ; un tap sur son unité ouvre le Choix d'unité de l'epic 1 (pièce, g, kg, ml, L), pour tenir R11 (unité au choix libre).
- Assumption: 2026-11-02 — un article ne figure qu'une fois dans une recette : un tap sur un résultat déjà ingrédient ne l'ajoute pas de nouveau.
- Assumption: 2026-11-02 — supprimer une recette depuis sa fiche ne demande pas de confirmation (C9) : retour à Recettes avec « Recette supprimée : Chili » · « Annuler ».
- Assumption: 2026-11-02 — le lien d'une recette se saisit dans la fiche, et une icône l'ouvre dans le navigateur du téléphone.
- Assumption: 2026-11-02 — en Revue, un article dans deux unités donne deux lignes (AD-4, AD-6) ; la variante « une ligne à deux quantités » d'EXPERIENCE.md est écartée ; la quantité s'y corrige dans l'unité de la ligne, sans Choix d'unité.
- Assumption: 2026-11-02 — 4 recettes exemples simples, générées par IA avec les articles du catalogue fourni ; Antoine les relit au test de fin d'epic.
