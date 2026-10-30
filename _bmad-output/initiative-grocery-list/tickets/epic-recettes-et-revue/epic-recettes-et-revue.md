---
type: epic
title: "De la recette à la liste"
parent: initiative-grocery-list
covers: [R1, R2, R3, R4, R5, R6, R7, R8, R11, R12, R22, R23, R24]
sources: []
companions: []
after: []
refined: false
risk: high
---

# De la recette à la liste

## Description

Antoine saisit ses recettes, avec une photo prise dans la galerie ou à l'appareil photo, et sélectionne celles de la semaine. Il valide, décoche en Revue ce qu'il a déjà et retrouve les ingrédients fusionnés dans la liste en cours de l'epic 1. Désélectionner une recette validée retire ses quantités, grâce à la provenance posée par l'epic 1. L'epic livre aussi le premier lancement avec 3 à 5 recettes exemples générées par IA, Nouvelle liste, et la remise à zéro de la sélection par Terminer les courses. Il réutilise la recherche et la création d'article de l'epic 1.

## Outcome

Le dimanche soir, Antoine et sa femme obtiennent la liste de la semaine fusionnée et triée par rayon, sans aucun classement manuel. Le signal est le moment ★ des Flux 1, 4, 5 et 6 d'EXPERIENCE.md.

## Done when

- Les Flux 1 (le dimanche soir), 4 (saisir une recette), 5 (la recette du mercredi) et 6 (le premier lancement) d'EXPERIENCE.md passent de bout en bout sur le build release installé, moment ★ observé.
- Une recette de 5 ingrédients se saisit en moins d'une minute.
- Désélectionner une recette validée, puis Annuler, laisse la liste exactement dans son état précédent.
- Les tests automatisés de la Revue, de la fusion et de la désélection passent, et TalkBack lit Recettes, la Fiche recette et la Revue.

## Boundaries

- Parts des exigences partagées : R11 fusion des quantités en Revue ; R12 remise à zéro de la sélection par Terminer les courses, et sa restauration par Annuler ; R23 états vides de Recettes ; R24 sur ses surfaces.
- Hors epic : la Liste, la coche et le Panneau + (epic-liste-de-courses) ; les Paramètres et la sauvegarde (epic-reglages-et-sauvegarde) ; le planning par jour (hors V1).
- Touch point: galerie et appareil photo Android — photo de recette ; owner: cet epic.

## References

- parent — _bmad-output/initiative-grocery-list/initiative-grocery-list.md, section Requirements
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Recettes, Fiche recette, Revue, Flux 1, 4, 5 et 6
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md
- mockups — _bmad-output/initiative-grocery-list/ux-grocery-list/.working/key-recettes.html, key-revue.html
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, surtout AD-3, AD-4, AD-5, AD-16, AD-18

## Notes

- Waits on epic-liste-de-courses because: il ajoute à la liste en cours (avec provenance des quantités) et réutilise la recherche, la création d'article, le catalogue et le socle.
- Open question: 2026-10-30 — depuis la revue de l'epic 1, la liste accepte des lignes libres hors catalogue ; un ingrédient de recette peut-il aussi être un texte libre, ou seulement un article du catalogue ? (initiative R1, R25) ; la « création d'article » réutilisée de l'epic 1 n'existe plus au Panneau +.
