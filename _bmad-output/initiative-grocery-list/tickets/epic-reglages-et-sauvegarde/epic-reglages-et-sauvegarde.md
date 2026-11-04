---
type: epic
title: "Réglages et sauvegarde"
parent: initiative-grocery-list
covers: [R9, R14, R15, R18, R19, R20, R21, R24]
sources: []
companions: []
after: []
refined: true
risk: medium
---

# Réglages et sauvegarde

## Description

L'epic pose l'écran Paramètres. Antoine peut y garder l'écran allumé pendant les courses, gérer son catalogue d'articles, ses fréquents et le parcours de son magasin, et désactiver le groupement par rayon. Il sauvegarde toutes ses données dans un fichier et les restaure par fusion. Les pictos du pack remplacent le repli neutre. L'epic clôt l'initiative par la vérification de bout en bout des six parcours, en clair et en sombre, et du plancher d'accessibilité, sur la release installée.

## Outcome

Antoine adapte l'app à son magasin et ne perd plus ses recettes en changeant de téléphone. L'export suivi d'un import sur une installation neuve restaure tout. La V1 sert à de vraies courses de la semaine.

## Requirements

- R1 (parent R9) : si le groupement est désactivé dans les Paramètres, les articles de la Liste suivent l'ordre d'ajout, sans en-têtes ; il est activé par défaut.
- R2 (parent R14) : le réglage « Garder l'écran allumé », désactivé par défaut, empêche la mise en veille tant que l'onglet Liste est affiché, et seulement lui.
- R3 (parent R18) : Paramètres › Articles permet de chercher, créer et modifier un article du catalogue (nom, picto, rayon par défaut, unité par défaut) ; une modification vaut pour les ajouts suivants ; un ajout à la liste ne modifie jamais le catalogue.
- R4 (parent R19) : le parcours des 13 rayons s'ordonne par glisser-déposer dans les Paramètres, et la Liste, la Revue et le Panneau + suivent cet ordre.
- R5 (parent R20, R15) : on ajoute ou on retire un fréquent seulement depuis Paramètres › Fréquents, que le bouton « Gérer » du Panneau + ouvre ; l'app n'en ajoute jamais d'elle-même, et leur ordre dans chaque rayon reste stable.
- R6 (parent R21) : depuis les Paramètres, l'export produit un fichier de sauvegarde partagé par la feuille de partage Android, et l'import fusionne ce fichier avec les données existantes ; un fichier invalide affiche une erreur et ne modifie aucune donnée.
- R7 (parent R24) : le glisser-déposer du parcours a les actions TalkBack « Monter » et « Descendre » ; les Paramètres et leurs sous-écrans sont utilisables avec TalkBack et la taille de police système ; le plancher d'accessibilité est vérifié sur toute l'app.
- R8 (parent C7) : les pictos au trait d'un même pack, teintés du rayon, remplacent le repli neutre dans le Panneau +, la Fiche recette, la Fiche article et le visuel de repli de la Carte recette ; le repli neutre ne reste que pour un article sans picto.

## Constraints

- C1 à C10 de l'initiative s'appliquent tels quels ; C2 : export et import passent par la feuille de partage et le sélecteur de fichier Android, sans nouvelle permission.
- L'architecture (AD-1 à AD-19) lie toutes les stories ; cet epic crée la fonctionnalité `reglages` (UI seulement, AD-2) et `core/backup` (AD-9), écrit les réglages par le `SettingsRepository` et le catalogue par le repository `catalogue`.

## Done when

- Un export suivi d'un import sur une installation neuve du build release restaure les recettes, le catalogue, les fréquents, le parcours, les réglages et la liste en cours ; un fichier invalide ne modifie rien.
- Réordonner le parcours change l'ordre des rayons dans la Liste, la Revue et le Panneau + ; les actions Monter et Descendre le font aussi avec TalkBack.
- Écran allumé, une fois activé, empêche la mise en veille seulement sur l'onglet Liste.
- Un article modifié dans Paramètres › Articles arrive avec son nouveau rayon et sa nouvelle unité à l'ajout suivant, sans changer les lignes déjà dans la liste.
- Les six parcours d'EXPERIENCE.md passent de bout en bout en clair et en sombre, et le plancher d'accessibilité est vérifié (TalkBack, cibles de 48 dp, grande taille de police).
- La release est installée sur le téléphone d'Antoine et sert à de vraies courses de la semaine.

## Boundaries

- Parts des exigences partagées : R9 désactivation du groupement ; R15 le bouton « Gérer » mène à Paramètres › Fréquents ; R18 Paramètres › Articles ; R19 parcours par glisser-déposer ; R20 gestion des fréquents ; R24 actions Monter et Descendre, et vérification finale.
- Hors epic : la synchro et le partage du foyer (V2) ; la suppression d'un article du catalogue ; le réordonnancement des fréquents à la main (C10) ; l'affichage ou la purge des articles hors catalogue.
- Touch point: maintien de l'écran allumé (Android) — Écran allumé ; owner: cet epic.
- Touch point: feuille de partage et sélecteur de fichier Android — export et import ; owner: cet epic.
- Touch point: pack de pictos (externe) — C7 ; owner: cet epic, repris de l'epic 1.

## References

- parent — _bmad-output/initiative-grocery-list/initiative-grocery-list.md, section Requirements
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Information Architecture (Paramètres), Component Patterns (Ligne de paramètre, Ligne de parcours, Fiche article, Champ de recherche), State Patterns (Paramètres), Accessibility Floor, Key Flows
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md, Components settings-row, route-row, article-sheet, search-field, Picto
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, surtout AD-2, AD-7, AD-9, AD-10, AD-11, AD-13, AD-14, AD-15, AD-17, AD-18

## Notes

- Waits on epic-liste-de-courses because: il gère le catalogue, les fréquents, l'ordre par défaut du parcours et le stockage que l'epic 1 pose.
- Waits on epic-recettes-et-revue because: l'export et l'import portent aussi les recettes, leurs photos et la sélection.
- Decision: 2026-11-04 — epics 1 et 2 validés par Antoine ; epic affiné sans arrêt (il enchaîne les étapes et teste l'epic entier à la fin) : Requirements rendus depuis les lignes de l'initiative ; les points ouverts sont tranchés par les hypothèses ci-dessous, qu'Antoine valide au test de fin d'epic.
- Decision: 2026-11-04 — le pack de pictos (touch point de l'epic 1, jamais choisi : tous les pictos sont le repli neutre) entre dans cet epic, avant Paramètres › Articles dont la Fiche article choisit un picto dans la grille du pack. R8 rend C7.
- Assumption: 2026-11-04 — Paramètres › Articles garde sa place : la Fiche recette crée au catalogue des articles en Divers et sans unité, qu'il faut pouvoir corriger. Il ne montre que les articles du catalogue (AD-17) ; les articles hors catalogue n'y apparaissent pas et ne sont jamais purgés en V1. Répond à la question ouverte de l'initiative (R18).
- Assumption: 2026-11-04 — un fréquent est toujours un article du catalogue : Paramètres › Fréquents ajoute par le Champ de recherche, et « Créer « … » » y crée d'abord l'article au catalogue (Divers, sans unité), jamais un nom libre. Répond à la question ouverte de l'initiative (R20).
- Assumption: 2026-11-04 — Paramètres › Fréquents est un sous-écran : les fréquents en liste plate dans l'ordre du parcours (Picto, nom, rayon écrit), une icône de retrait par ligne avec Snackbar Annuler (C9), et le Choix de rayon par un tap sur la ligne, qui change le rayon par défaut de l'article (« seule la gestion des fréquents mémorise », Decision 2026-11-01) ; un fréquent ajouté ou déplacé de rayon passe en dernier de son rayon (AD-17).
- Assumption: 2026-11-04 — « Gérer » ferme le Panneau + et ouvre Paramètres › Fréquents ; au retour, la Liste est affichée, panneau fermé. Le message « Pas encore de fréquents… » du panneau garde son texte, sans action.
- Assumption: 2026-11-04 — l'écran Paramètres, dans cet ordre : Garder l'écran allumé (switch, « Pendant que la liste est affichée »), Grouper par rayon (switch), Parcours, Articles, Fréquents (navigation), puis Exporter mes données et Importer une sauvegarde ; chaque ligne arrive avec sa story.
- Assumption: 2026-11-04 — l'import ne demande pas de confirmation (C9 : il fusionne, il n'écrase pas) ; il vide le service Annuler (AD-10) et confirme par un snackbar ; l'export confirme par un snackbar au retour de la feuille de partage.
- Assumption: 2026-11-04 — pack de pictos proposé : Tabler Icons (licence MIT, au trait, nombreux aliments), un picto par `picto_key` du catalogue fourni, plusieurs clés pouvant partager un picto ; les clés sans équivalent gardent le repli neutre ou un SVG dessiné dans le même style. La story montre à Antoine deux ou trois packs comparés ; il tranche au test de fin d'epic, et changer de pack ne change que le résolveur et les assets (AD-18).
- Assumption: 2026-11-04 — la vérification finale suit les parcours d'EXPERIENCE.md tels que les Decisions de l'initiative les ont modifiés (2026-11-03 : la Fiche recette s'enregistre par un bouton, coche ronde sur la carte) ; ces Decisions priment sur EXPERIENCE.md et DESIGN.md, que la story 8 remet à jour par bmad-ux.
- Decision: 2026-11-04 — découpage en 9 stories dans une seule voie (toutes partagent l'écran Paramètres et strings_fr) ; traceur : story 1, ⚙ jusqu'à Paramètres avec Écran allumé et le groupement, effet sur la Liste ; puis export et import, les plus risqués et le filet de sécurité avant toute release ; parcours ; pictos avant Articles (grille de la Fiche article) ; Fréquents ; Refactor sweep ; vérification finale de bout en bout sur la release installée, hitl.
- Assumption: 2026-11-04 — à l'import, la ligne de réglages prend toujours les champs de l'utilisateur du fichier (parcours, groupement, Écran allumé) et garde les champs système locaux (premier lancement, seed_version) : sinon le premier lancement d'une installation neuve, écrit après l'export, ferait perdre les réglages (précision d'AD-9, relevée par la vérification du découpage).
- Decision: 2026-11-04 — l'aller-retour export puis import sur la release, que les tests d'intégration ne couvrent pas en mode release, est une étape hitl de la story 9 : export depuis la release installée, import sur une installation neuve de la même release sur émulateur, comparaison.
