---
type: epic
title: "Réglages et sauvegarde"
parent: initiative-grocery-list
covers: [R9, R14, R18, R19, R20, R21, R24]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# Réglages et sauvegarde

## Description

L'epic pose l'écran Paramètres. Antoine peut y garder l'écran allumé pendant les courses, gérer son catalogue d'articles, ses fréquents et le parcours de son magasin, et désactiver le groupement par rayon. Il sauvegarde toutes ses données dans un fichier et les restaure par fusion. L'epic clôt l'initiative par la vérification de bout en bout des six parcours, en clair et en sombre, et du plancher d'accessibilité.

## Outcome

Antoine adapte l'app à son magasin et ne perd plus ses recettes en changeant de téléphone. L'export suivi d'un import sur une installation neuve restaure tout.

## Done when

- Un export suivi d'un import sur une installation neuve du build release restaure les recettes, le catalogue, les fréquents, le parcours, les réglages et la liste en cours ; un fichier invalide ne modifie rien.
- Réordonner le parcours change l'ordre des rayons dans la Liste, la Revue et le Panneau + ; les actions Monter et Descendre le font aussi avec TalkBack.
- Écran allumé, une fois activé, empêche la mise en veille seulement sur l'onglet Liste.
- Les six parcours d'EXPERIENCE.md passent de bout en bout en clair et en sombre, et le plancher d'accessibilité est vérifié (TalkBack, cibles de 48 dp, grande taille de police).

## Boundaries

- Parts des exigences partagées : R9 désactivation du groupement ; R18 Paramètres › Articles ; R19 parcours par glisser-déposer ; R20 gestion des fréquents ; R24 actions Monter et Descendre, et vérification finale.
- Hors epic : la synchro et le partage du foyer (V2).
- Touch point: maintien de l'écran allumé (Android) — Écran allumé ; owner: cet epic.
- Touch point: feuille de partage et sélecteur de fichier Android — export et import ; owner: cet epic.

## References

- parent — _bmad-output/initiative-grocery-list/initiative-grocery-list.md, section Requirements
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Paramètres, Accessibility Floor, Key Flows
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, surtout AD-2, AD-9, AD-14, AD-17

## Notes

- Waits on epic-liste-de-courses because: il gère le catalogue, les fréquents, l'ordre par défaut du parcours et le stockage que l'epic 1 pose.
- Waits on epic-recettes-et-revue because: l'export et l'import portent aussi les recettes.
- Open question: 2026-10-30 — depuis la revue de l'epic 1, la liste n'alimente plus le catalogue ; Paramètres › Articles garde-t-il sa place, et un fréquent peut-il être un nom libre ? (initiative R18, R20) ; l'icône de modification d'« Ajouts fréquents » (posée sans action par l'epic 1) doit mener à la gestion des fréquents.
