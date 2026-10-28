---
title: 'Le catalogue et les fréquents fournis'
type: 'feature'
ticket: '3'
created: '2026-10-28'
status: 'built'
baseline_revision: '4358891c95893d3fb94ffa587226cebdfc2b107d'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Le catalogue fourni n'a que les 7 articles du traceur et aucun fréquent : la recherche du Panneau + ne trouve presque rien, et la story des fréquents (1.7) n'a rien à afficher.

**Approach:** Générer le contenu complet (`articles.json` d'environ 200 articles, `seed_version` 2, et un nouveau `frequents.json` d'environ 30 fréquents), puis étendre le chargeur unique d'AD-8 aux fréquents, avec un id de fréquent dérivé de l'article (UUID v5, AD-17).

## Boundaries & Constraints

**Always:** les 7 articles de la story 1 gardent leur UUID, nom, rayon, unité et `picto_key` ; chaque nouvel article a un UUID v4 définitif ; noms en français avec majuscule initiale, pluriel pour ce qui se compte (« Tomates », « Œufs »), singulier pour le reste (« Lait », « Riz ») ; noms normalisés (`normalizeName`) tous distincts ; rayon parmi les 13 codes d'AD-11, au moins 5 articles par rayon sauf `divers` ; unité `g`, `ml`, `piece` ou `null` (sans), choisie comme on achète l'article ; `picto_key` en kebab-case ASCII, unique ; chaque fréquent référence un article du fichier ; fréquents rangés dans le fichier par rayon dans l'ordre par défaut des 13 rayons ; le chargeur reste une transaction unique qui n'écrit rien en cas d'échec ; lignes fournies à `updated_at = 0` ; `core` n'importe aucune fonctionnalité (fonctions injectées depuis `lib/app/startup.dart`).

**Never:** pas d'affichage des fréquents dans le Panneau + (story 1.7) ; pas de `createArticle` ni de Paramètres › Articles ; pas de migration de schéma (la table `frequents` existe en v1) ; pas de pack de pictos ni d'asset image ; pas de mise à jour d'une ligne existante par le chargeur ; pas de recettes exemples (epic 2).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Installation neuve | base vide | ~200 articles et ~30 fréquents insérés, `updated_at = 0`, `seed_versions` `{"articles":2,"frequents":1}` | — |
| Montée de version | base en v1 (7 articles), Lait renommé, Riz supprimé | articles absents insérés ; Lait garde son nom modifié, Riz reste supprimé ; fréquents insérés | — |
| Redémarrage | versions déjà à jour | rien inséré ni modifié | — |
| Fréquent supprimé | un fréquent fourni a `deleted_at`, fichier en version supérieure | il n'est pas recréé (id présent) | — |
| Article d'un fréquent absent de la base | l'article fourni a été sauté (nom normalisé déjà pris par un article actif) | ce fréquent est sauté, le reste est inséré | pas d'erreur de clé étrangère |
| Fichier de fréquents invalide | `article_id` absent d'`articles.json`, ou doublon | rien n'est écrit | `FormatException`, écran d'erreur bloquant |

</intent-contract>

## Code Map

- `assets/seed/articles.json` -- `{"seed_version":1,"articles":[{id,name,rayon,unit,picto_key}]}` avec les 7 articles du traceur : passer à `seed_version` 2 et ~200 articles.
- `assets/seed/frequents.json` -- nouveau : `{"seed_version":1,"frequents":[{"article_id":…}]}` ; la position d'un fréquent est son index dans le fichier. Déclarer le fichier sous `assets/seed/` dans `pubspec.yaml` s'il n'y est pas couvert par le dossier.
- `lib/core/db/seed/seed_loader.dart` -- `SeedLoader(db, settings, loadAsset, normalizeName)`, `run()` : lit et valide hors transaction, puis insère par fichier dont la version dépasse `settings.seedVersions[fichier]`. `_insertArticles` saute les UUID présents (supprimés compris) et les noms normalisés pris. Ajouter le fichier `frequents` (constantes `frequentsFile`, `frequentsPath`), un paramètre injecté `frequentId` (même schéma que `normalizeName`), l'insertion après les articles, en sautant les ids présents et les fréquents dont l'article n'est pas en base.
- `lib/core/db/tables/frequents.dart` -- `article_id`, `position` ; id = UUID v5 de l'article (AD-17).
- `lib/features/catalogue/data/` -- y créer la seule fonction `frequentId(articleId)` : UUID v5 (paquet `uuid` 4.6.0, déjà en dépendance) sur un espace de noms Kadi figé en constante, à ne jamais changer.
- `lib/app/startup.dart` -- câble `SeedLoader` ; y passer `frequentId`.
- `test/helpers/test_db.dart` -- `seedLoader(db, {clock, loadAsset})`, `diskAssetLoader`, `SeedIds` : passer `frequentId` ; ajouter un chargeur d'assets par chemin (contenu donné pour un chemin, disque pour les autres).
- **Chargeurs de test à adapter** : `test/core/seed_loader_test.dart` (`loadAsset: (_) async => v2` et `bad`), `test/app/app_test.dart:30` (`loadAsset ?? (_) async => seed`) et `test/features/liste/liste_screen_test.dart` (`(_) async => seed`) renvoient le même texte pour tout chemin : ils casseraient dès que le chargeur lit `frequents.json`. Les rendre sensibles au chemin, sans changer ce qu'ils vérifient.
- **Tests dépendants du contenu** : `test/features/catalogue/catalogue_test.dart:32-37` attend `hits.single` pour « lait » (faux dès qu'il existe « Lait de coco ») → vérifier que le premier résultat est Lait ; `catalogue_test.dart:46` et `test/app/app_test.dart:100` utilisent « pesto » comme recherche sans résultat → garder l'intention avec une recherche absente du catalogue ; `seed_loader_test.dart` (« premier démarrage : 7 articles », `{'articles': 1}`) → adapter au nouveau contenu.

## Tasks & Acceptance

**Execution:**
- [x] `assets/seed/articles.json` -- générer ~200 articles selon Always, en gardant les 7 existants à l'identique, `seed_version` 2 -- R9 (R18 parent).
- [x] `assets/seed/frequents.json` -- ~30 fréquents d'usage courant (lait, pain, œufs, beurre, bananes, papier toilette…), rangés par rayon dans l'ordre par défaut -- R10.
- [x] `lib/features/catalogue/data/frequent_id.dart` -- `frequentId(articleId)` en UUID v5 -- AD-17.
- [x] `lib/core/db/seed/seed_loader.dart` -- lecture, validation et insertion des fréquents (matrice I/O) -- AD-8.
- [x] `lib/app/startup.dart` -- injecter `frequentId` -- `core` n'importe pas `catalogue`.
- [x] `test/helpers/test_db.dart` + chargeurs des tests listés au Code Map -- chargeur par chemin, `frequentId` injecté.
- [x] `test/core/seed_loader_test.dart` -- un test par ligne de la matrice I/O, plus `frequentId` stable et déterministe.
- [x] `test/core/seed_content_test.dart` -- contrôle des deux fichiers réels : 180 à 220 articles, 25 à 35 fréquents, contraintes de Always (UUID v4 distincts, 7 articles d'origine intacts, noms normalisés et `picto_key` uniques, rayons et unités valides, ≥ 5 articles par rayon hors `divers`, fréquents référençant un article et triés par rayon).
- [x] `test/features/catalogue/catalogue_test.dart`, `test/app/app_test.dart` -- adapter les tests dépendants du contenu (Code Map).

**Acceptance Criteria:**
- Given une installation neuve, when Antoine tape « cou » dans le Panneau +, then Courgettes apparaît avec son rayon, parmi d'autres articles du catalogue complet.
- Given une recherche d'un article courant de chaque rayon (par exemple « beurre », « baguette », « jambon », « papier »), when les résultats s'affichent, then chacun montre le rayon attendu.
- Given le téléphone d'Antoine déjà en v1, when il installe cette version, then sa liste en cours est intacte et la recherche trouve les nouveaux articles.
- Given la story terminée, when Antoine relit `articles.json` et `frequents.json`, then il valide le contenu (étape HITL, `done_checkpoint`).

## Implementation Notes

- Contenu : 208 articles (7 d'origine identiques, 201 nouveaux en UUID v4 générés par script Python), 31 fréquents. Apostrophe droite dans les noms (« Huile d'olive ») pour que la recherche tapée au clavier les trouve. `frequents.json` ne contient que les `article_id` (format du Code Map) : pour la relecture HITL, les noms se lisent dans `articles.json`.
- Espace de noms v5 figé : `kadiFrequentNamespace = 082c8fba-0bf2-4d09-9021-d42623d4c4f3` ; `frequentId(Lait)` figé dans le test (`1265e470-f634-566b-a103-339309569e28`).
- Chargeur : les fréquents sont validés contre les ids d'`articles.json` hors transaction ; insérés après les articles ; un fréquent dont l'article est en base mais supprimé est inséré (il compte comme supprimé, AD-7).
- Tests : chargeurs de test sensibles au chemin (`assetLoaderWith`, `readSeedAssets`) ; « pesto » remplacé par « kumquat » (Pesto est au catalogue) ; `app_test` « lait » et `catalogue_test` « début de nom en premier » adaptés au catalogue complet ; recherche d'un article par rayon (13 rayons) ajoutée à `catalogue_test`.

## Plan Change Log

## Review Triage Log

### 2026-10-28 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` Pluriel appliqué de façon inégale dans `articles.json` (« Salade », « Poulet », « Quiche », « Cidre »… au singulier malgré `piece`) — réel au regard de la règle Always, mais ce sont les formes usuelles d'une liste de courses (« une salade », « un poulet ») et Antoine a relu et validé le contenu tel quel le 2026-10-28 (critère 4) ; le changer irait contre sa validation.
  - `[low]` `[reject]` Unités incohérentes (« Vinaigre » sans unité, « Vinaigre blanc » en pièce ; condiments sans unité, Pesto en g) — réel mais sans effet avant la saisie de quantité (story 1.8, unité modifiable) et validé par Antoine ; Paramètres › Articles (epic 3) permettra de corriger une unité par défaut.
  - `[low]` `[patch]` Le test « fréquent supprimé : pas recréé par une version supérieure » utilise les mêmes `article_id` en v2 qu'en v1 et ne distingue pas « absents insérés » de « rien inséré » — corrigé : un fréquent nouveau (Courgettes) est ajouté au fichier v2 et son insertion vérifiée, le fréquent Lait restant supprimé.

## Design Notes

Un fréquent n'a pas de rayon propre : il suit le rayon actuel de son article. La position globale (index dans le fichier) suffit à ordonner les fréquents dans chaque rayon. Le chargeur insère les articles avant les fréquents dans la même transaction, pour que la clé étrangère soit satisfaite. Générer les UUID v4 par script (Dart ou Python), jamais à la main.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent

**Manual checks (if no CLI):**
- Relire `articles.json` : noms naturels en français, rayon et unité plausibles pour chaque article.

## Auto Run Result

Status: built

### Finalize (2026-10-28)

- **Résumé :** catalogue complet et fréquents fournis. `articles.json` passe à 208 articles (`seed_version` 2, les 7 de la story 1 intacts), nouveau `frequents.json` de 31 fréquents rangés par rayon. Le chargeur d'AD-8 insère les fréquents après les articles dans la même transaction, avec un id UUID v5 dérivé de l'article (`frequentId`, injecté depuis `startup.dart`), en sautant les ids présents et les fréquents dont l'article n'est pas en base.
- **Fichiers :**
  - `assets/seed/articles.json` — 208 articles, `seed_version` 2.
  - `assets/seed/frequents.json` — 31 fréquents, `seed_version` 1.
  - `lib/features/catalogue/data/frequent_id.dart` — seule dérivation de l'id d'un fréquent (espace de noms figé).
  - `lib/core/db/seed/seed_loader.dart` — lecture, validation et insertion des fréquents.
  - `lib/app/startup.dart` — injection de `frequentId`.
  - `test/helpers/test_db.dart` — chargeur d'assets par chemin, articles d'origine, `frequentId`.
  - `test/core/seed_loader_test.dart`, `test/core/seed_content_test.dart` — matrice I/O et contrôle du contenu réel.
  - `test/app/app_test.dart`, `test/features/catalogue/catalogue_test.dart`, `test/features/liste/liste_screen_test.dart` — adaptés au catalogue complet.
- **HITL :** Antoine a relu la liste (tableau par rayon) et validé le contenu sans remarque le 2026-10-28.
- **Revue :** 1 correction appliquée (low), 0 reporté, 2 rejetés (pluriels et unités : formes usuelles validées par Antoine) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — aucune correction high ni medium.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 111/111 après correction.
- **Risques résiduels :** montée de version v1 → v2 sur le téléphone d'Antoine couverte par test mais pas encore faite en vrai (Antoine teste l'epic à la fin) ; fréquents non visibles avant la story 1.7.
