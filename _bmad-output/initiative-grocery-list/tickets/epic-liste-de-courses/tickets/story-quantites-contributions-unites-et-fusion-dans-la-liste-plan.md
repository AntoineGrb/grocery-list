---
title: 'Quantités : contributions, unités et fusion dans la liste'
type: 'feature'
ticket: '2'
created: '2026-10-27'
status: done
baseline_revision: '4876bde24eff70b91a67996f1da7e7f4a47249c6'
route: 'full'
route_source: 'auto'
risk: 'high'
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

**Problem:** La story 1 n'écrit que des contributions sans quantité et `formatQuantity` lève sur une quantité chiffrée. Sans quantités, unités et fusion conformes à AD-4 et AD-6, la Liste ne peut pas montrer « Tomates 500 g » et l'epic 2 n'a pas de modèle de provenance sur lequel s'appuyer.

**Approach:** Étendre l'ajout du repository de la Liste à une quantité entière facultative dans une unité, avec les règles de fusion d'AD-4 (même unité = même ligne, unité différente = nouvelle ligne, ligne sans quantité adoptée), et écrire l'unique fonction d'arrondi de lecture d'AD-6, déjà branchée sur la Ligne d'article.

## Boundaries & Constraints

**Always:** quantités entières (g, ml, millièmes de pièce : 2 pièces = `2000`) ; quantité et unité nulles ensemble, une quantité 0 vaut « sans quantité » ; la quantité d'une ligne reste la somme des contributions actives, jamais stockée ; une ligne cochée n'est jamais complétée ; toute écriture dans une transaction, horodatée par `Clock.stamp()` ; un `updated_at` mis à jour sur la ligne dont l'unité change ; textes d'unité dans `strings_fr.dart` ; conversion de lecture uniquement dans `lib/core/units/` ; Material par `package:material_ui/material_ui.dart`.

**Never:** pas de Champ quantité, de Choix de rayon ni d'unité par défaut préremplie dans le Panneau + (story 1.8) ; pas de coche ni de fusion au décochage (story 1.4) ; pas d'édition manuelle ni `manual_at` (story 1.6) ; pas de contribution `week_selection` appelée depuis l'UI (epic 2) ; pas de migration de schéma (la base v1 a déjà `quantity` et `unit`) ; pas de conversion entre unités dans les sommes ; pas de contrainte d'unicité en base.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Même unité | Tomates 300 g puis 200 g | une ligne `unit = g`, deux contributions, quantité 500 | — |
| Autre unité | Tomates 500 g en liste, puis 2 pièces (`2000`) | seconde ligne `unit = piece`, quantité 2000 | — |
| Ligne sans quantité adoptée | Tomates sans quantité, puis 300 g | une ligne, qui prend `unit = g` (et un nouvel `updated_at`) ; quantité 300 | — |
| Sans quantité sur ligne chiffrée | Tomates 300 g, puis sans quantité | même ligne, quantité toujours 300 | — |
| Quantité 0 | Tomates `0` g | traité comme sans quantité (contribution `quantity` et `unit` nulles) | — |
| Ligne cochée | seule ligne Tomates g cochée (posée en base), puis 200 g | nouvelle ligne non cochée g, quantité 200 ; la cochée inchangée | — |
| Entrée incohérente | quantité sans unité, unité sans quantité, quantité négative | rien n'est écrit | `ArgumentError` |
| Contribution supprimée | une des deux contributions g a `deleted_at` | quantité = somme des seules actives | — |

</intent-contract>

## Code Map

- `lib/core/units/unit.dart` -- `Unit` (`g`, `ml`, `piece`), `unitKey`, `formatQuantity(int?, Unit?)` qui lève aujourd'hui sur une quantité chiffrée : à remplacer par l'arrondi de lecture. Garder la signature et le retour `''` sans quantité.
- `lib/core/strings/strings_fr.dart` -- `StringsFr` : y ajouter les suffixes d'unité (g, kg, ml, cl, l, pièce, pièces).
- `lib/features/liste/data/liste_repository.dart` -- `ContributionSource`, `ListeItem`, `ListeRepository.addArticle(articleId)` (choisit la plus ancienne ligne non cochée par `added_at`, `id`, sinon en crée une ; insère une contribution `ajout`). `watchUnchecked()` calcule déjà la somme des contributions actives (`c.quantity.sum()` en jointure gauche) et `_toItem` met `quantity` à `null` quand la ligne n'a pas d'unité : à conserver.
- `lib/features/liste/ui/item_row.dart` -- affiche déjà `formatQuantity(item.quantity, item.unit)` à droite du nom et l'ajoute au libellé TalkBack ; aucune modification attendue au-delà d'un éventuel `softWrap: false` sur la quantité.
- `lib/features/liste/ui/add_sheet.dart` -- appelle `addArticle(article.id)` sans quantité : doit continuer à compiler tel quel (paramètres nommés facultatifs).
- `test/helpers/test_db.dart` -- `seededDatabase()`, `memoryDatabase()`, `SeedIds.tomates` (Tomates, fruits-legumes, unité par défaut `g`), `SeedIds.lait`, etc.
- `test/features/liste/liste_repository_test.dart` -- tests du repository sur Drift en mémoire avec `Clock(now: () => now)` : à étendre.
- `test/app/app_test.dart` -- montre comment monter l'app avec `ProviderScope(overrides: …)` sur une base en mémoire ; modèle pour le test de widget de la Liste.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/strings/strings_fr.dart` -- ajouter les suffixes d'unité -- convention Textes.
- [x] `lib/core/units/unit.dart` -- implémenter `formatQuantity` selon les règles de Design Notes -- AD-6, seule fonction de lecture.
- [x] `lib/features/liste/data/liste_repository.dart` -- `addArticle(articleId, {int? quantity, Unit? unit})` : normaliser (0 → sans quantité), valider (`ArgumentError` si l'un sans l'autre ou négatif), puis appliquer les règles de fusion d'AD-4 dans une seule transaction ; isoler le choix et l'écriture dans une méthode privée paramétrée par la source, réutilisable par l'epic 2 -- AD-4.
- [x] `test/core/units_test.dart` -- table des cas de `formatQuantity` (Design Notes) -- AD-6.
- [x] `test/features/liste/liste_repository_test.dart` -- un test par ligne de la matrice I/O -- AD-4.
- [x] `test/features/liste/liste_screen_test.dart` -- test de widget : Liste montée sur une base en mémoire, après les ajouts du repository, affiche « Tomates » avec « 500 g », une seconde ligne « Tomates » avec « 2 pièces », et 1500 g d'un autre article s'affiche « 1,5 kg » -- vérification du ticket.

**Acceptance Criteria:**
- Given Tomates ajouté avec 300 g puis 200 g, when la Liste s'affiche, then une seule ligne Tomates sous Fruits & légumes montre « 500 g » et l'en-tête compte 1.
- Given cette ligne, when Tomates est ajouté avec 2 pièces, then une seconde ligne Tomates montre « 2 pièces » et l'en-tête compte 2.
- Given un article à 1500 g, when la Liste s'affiche, then sa quantité se lit « 1,5 kg » ; TalkBack annonce « Riz, 1,5 kg, Épicerie salée » (libellé parlé du rayon tel qu'existant).
- Given un ajout sans quantité depuis le Panneau +, when il est fait, then le comportement de la story 1 est inchangé (tests existants verts).

## Implementation Notes

- `_contribute({articleId, source, quantity, unit})` dans `ListeRepository` : validation, normalisation (0 → sans quantité) et fusion d'AD-4 ; elle suppose une transaction ouverte par l'appelant (`addArticle` l'ouvre). Le paramètre `weekSelectionId` n'est pas encore là : un paramètre privé jamais passé déclenche `unused_element_parameter` ; l'epic 2 l'ajoute.
- Une erreur de validation est levée dans la transaction : elle l'annule, rien n'est écrit, et `addArticle` rend un `Future` en échec (`ArgumentError`).
- Ligne adoptée : `updated_at = Clock.stamp(ancien updated_at)` ; la contribution prend un stamp suivant.
- `formatQuantity` : arrondi demi vers le haut au centième ; « pièces » quand la valeur affichée (arrondie) est ≥ 2 ; espace insécable aussi entre l'entier et la fraction (« 1 ½ pièce »).
- `item_row.dart` inchangé : la quantité, hors `Expanded`, ne passe pas à la ligne et l'espace insécable tient le nombre avec son unité.
- Vérification : `flutter analyze` sans problème ; `flutter test` 85 tests verts (41 de la story 1 + 33 `units_test` + 10 repository + 1 widget).

## Plan Change Log

## Review Triage Log

### 2026-10-27 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` `formatQuantity` affiche « 0 pièce » pour 1 à 4 millièmes de pièce — réel mais inatteignable aujourd'hui (aucun chemin ne crée de fraction de pièce ; la saisie de la story 1.8 est en pièces entières) et la correction ajoute une branche ; à revoir si la répartition au prorata de l'epic 2 produit de tels restes.
  - `[low]` `[patch]` Le test de widget ne relie pas la ligne « 500 g » à Fruits & légumes (critère 1, « sous Fruits & légumes ») — corrigé : attente du libellé TalkBack `Tomates, 500 g, Fruits et légumes` juste après les vérifications d'en-tête.
  - `[false]` `[reject]` Les Implementation Notes compteraient mal les tests de `units_test` (34 annoncés par le relecteur, total 86) — la table compte 4 + 9 + 8 + 10 = 31 cas, plus 2 tests, soit 33 ; `flutter test` affiche bien 85 ; une correction ne toucherait de toute façon que le plan.

## Design Notes

Règles d'arrondi de lecture **[ASSUMPTION — à valider par Antoine]** ; les sources ne fixent que les exemples « 500 g », « 1 kg », « 1,5 kg », « 20 cl », « 40 cl », « 2 pièces », « 6 pièces », « ½ ». Virgule décimale française, espace insécable (U+00A0) entre nombre et unité, zéros de fin retirés.

| Unité | Valeur stockée | Affichage |
|---|---|---|
| g | < 1000 | `N g` (300 → « 300 g ») |
| g | ≥ 1000 | kg, au plus 2 décimales arrondies (1000 → « 1 kg », 1500 → « 1,5 kg », 1234 → « 1,23 kg ») |
| ml | < 1000, multiple de 10 | cl (200 → « 20 cl », 250 → « 25 cl ») |
| ml | < 1000, sinon | `N ml` (15 → « 15 ml ») |
| ml | ≥ 1000 | l, au plus 2 décimales (1000 → « 1 l », 1500 → « 1,5 l ») |
| piece | millièmes | nombre au plus 2 décimales ; partie fractionnaire 250/500/750 → ¼ ½ ¾ (500 → « ½ pièce », 1500 → « 1 ½ pièce ») ; « pièces » à partir de 2 (2000 → « 2 pièces », 1000 → « 1 pièce ») |

Fusion (AD-4) : une contribution sans quantité rejoint la plus ancienne ligne non cochée de l'article, quelle que soit son unité, sinon crée une ligne sans unité ; une contribution chiffrée rejoint la ligne non cochée de son unité, sinon la ligne non cochée sans unité (qui prend l'unité), sinon crée une ligne dans son unité. Ordre de choix entre candidates : `added_at` puis `id`.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent, dont les 41 de la story 1

## Auto Run Result

Status: ready-for-dev
Halt reason: plan_checkpoint = true on this entry (epic decision 2026-10-26: relecture du plan avant les stories 1 et 2) — Antoine relit le plan avant l'implémentation. Point à valider en priorité : les règles d'arrondi de lecture de Design Notes, marquées [ASSUMPTION] (seuils kg / cl / l, 2 décimales, fractions ¼ ½ ¾ pour les pièces, « pièces » à partir de 2).

### Finalize (2026-10-27)

- **Résumé :** quantités et unités dans la Liste. `addArticle` accepte une quantité entière facultative dans une unité (0 = sans quantité, incohérence → `ArgumentError`) et applique la fusion d'AD-4 dans une transaction : même unité = même ligne, autre unité = nouvelle ligne, ligne sans quantité adoptée, ligne cochée jamais complétée. `formatQuantity` applique l'arrondi de lecture validé par Antoine (kg, cl, l, ¼ ½ ¾, « pièces » à partir de 2, espace insécable).
- **Fichiers :**
  - `lib/core/strings/strings_fr.dart` — suffixes d'unité.
  - `lib/core/units/unit.dart` — arrondi de lecture.
  - `lib/features/liste/data/liste_repository.dart` — `addArticle` avec quantité, `_contribute` privé paramétré par la source (réutilisable par l'epic 2).
  - `test/core/units_test.dart` — 33 tests d'affichage.
  - `test/features/liste/liste_repository_test.dart` — un test par ligne de la matrice I/O.
  - `test/features/liste/liste_screen_test.dart` — vérification du ticket à l'écran et par TalkBack.
- **Revue :** 1 correction appliquée (low), 0 reporté, 2 rejetés (« 0 pièce » inatteignable aujourd'hui ; décompte des tests erroné) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — aucune correction high ni medium.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 85/85 après correction.
- **Risques résiduels :** `_contribute` ne prend pas encore `weekSelectionId` (l'epic 2 l'ajoutera) ; « 0 pièce » pour un reste de 1 à 4 millièmes si l'epic 2 en produit ; rendu sur téléphone et TalkBack réel non vérifiés (aucune installation requise par cette story).
