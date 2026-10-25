---
type: epic
title: "La liste de courses au magasin"
parent: initiative-grocery-list
covers: [R9, R10, R11, R12, R13, R15, R16, R17, R18, R19, R20, R23, R24]
sources: []
companions: []
after: []
refined: false
risk: medium
---

# La liste de courses au magasin

## Description

Installée sur le téléphone d'Antoine, l'app tient une seule liste en cours, groupée par rayon dans l'ordre par défaut des 13 rayons. On la remplit à la main par le Panneau + (recherche, création à la volée avec quantité et rayon facultatifs, fréquents fournis) et on la coche d'une main jusqu'à Terminer les courses. L'epic livre aussi le socle que les epics 2 et 3 réutilisent : le projet Flutter et un build release installable, les thèmes clair et sombre, le stockage local prêt pour la synchro, le modèle d'unités et la fusion dans la liste (avec la provenance de chaque quantité), la recherche et la création d'article, le catalogue et les fréquents générés par IA.

## Outcome

Antoine remplace son app todo par la Liste pour ses courses : il ajoute un article en un tap depuis le Panneau + et coche tout d'une main au magasin. Le signal est le moment ★ des Flux 2 et 3 d'EXPERIENCE.md.

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

## Notes

- Waits on architecture because: le stockage, le modèle de données prêt pour la synchro, les unités et la fusion, la gestion d'état et les tokens de thème sont tranchés par bmad-architecture avant la planification des stories.
