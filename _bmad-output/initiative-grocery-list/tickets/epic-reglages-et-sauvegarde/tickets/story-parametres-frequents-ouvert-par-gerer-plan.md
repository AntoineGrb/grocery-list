---
title: 'Paramètres › Fréquents, ouvert par « Gérer »'
type: 'feature'
ticket: '7'
created: '2026-11-05'
status: 'in-review'
baseline_revision: '1d142e970c6d61809d9246460eb3cc28d7c943c7'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** les ~30 fréquents fournis sont figés : Antoine ne peut ni en ajouter, ni en retirer, ni changer leur rayon, et le bouton « Gérer » du Panneau + ne fait rien.

**Approach:** une ligne « Fréquents » des Paramètres et le bouton « Gérer » poussent Paramètres › Fréquents : la liste des fréquents dans l'ordre du parcours, avec retrait (Annuler), changement de rayon, et un Champ de recherche pour en ajouter depuis le catalogue ou créer l'article.

## Boundaries & Constraints

**Always:**
- Route poussée `/parametres/frequents` (`AppRoutes`, `GoRoute` dans `lib/app/kadi_app.dart`), titre « Fréquents », flèche retour. Ligne « Fréquents » · « Tes ajouts fréquents du bouton + » (chevron) juste sous « Articles ».
- « Gérer » (`lib/features/liste/ui/add_sheet_rows.dart`, `onPressed` vide aujourd'hui) ferme le Panneau + puis pousse la route ; au retour, la Liste est affichée, panneau fermé. `liste` ne dépend pas de `reglages` : il ne connaît que la constante de route de `core`.
- Liste des fréquents actifs dans l'ordre du parcours (comme les Ajouts fréquents du panneau : `frequentsInRoute` de `lib/features/liste/state/liste_providers.dart` montre la règle ; `reglages` ne dépend pas de `liste`, donc la règle de tri est reprise côté `catalogue` ou `core`, ou déplacée dans `catalogue` et réutilisée par `liste`), chaque ligne : Picto, nom, nom du rayon (`body-medium`, `on-surface-variant`), icône de retrait à droite (cible 48 dp, lue « Retirer Lait des fréquents »). Lue « Lait, Crèmerie ».
- Retirer : suppression logique du fréquent, par le repository `catalogue`, enregistrée au service Annuler (AD-10) ; snackbar « Retiré des fréquents : Lait » · « Annuler » (`showUndoSnackBar`), qui le remet à sa place (même position).
- Tap sur la ligne : Choix de rayon (`lib/core/ui/rayon_picker.dart`) dans une feuille ; choisir un autre rayon change le rayon par défaut de l'article et passe le fréquent en dernier de son nouveau rayon, par `updateArticle` du repository `catalogue` (story 6 : nom et unité actuels, nouveau rayon ; même chemin que la Fiche article). Le rayon des lignes déjà dans la liste ne change pas (AD-15).
- Champ de recherche en haut (DESIGN `search-field`, loupe, ×, « Ajouter un fréquent ») ; pendant la saisie, les résultats (articles du catalogue, `watchSearch`) remplacent la liste : Picto, nom, rayon, et à droite un + (pas encore fréquent) ou une coche (déjà fréquent, tap sans effet, lu « Lait, déjà dans les fréquents »). Tap sur un + : ajoute le fréquent en dernier de son rayon (id dérivé de l'article, réactivé s'il existait, AD-17 : `frequentId`) puis vide le champ. Sans article de ce nom normalisé exact au catalogue : « Créer « … » » crée l'article au catalogue (`createArticle`, Divers, sans unité) puis le fréquent, en une transaction.
- Sans fréquent et sans saisie : message d'état vide « Pas encore de fréquents. Cherche un article pour l'ajouter. ».
- L'app n'ajoute jamais de fréquent d'elle-même ; aucun réordonnancement manuel (C10).
- Écritures en échec : snackbar « Fréquent impossible à enregistrer. ». TalkBack ; police système ×2 sans débordement.

**Never:** glisser-déposer ; appui long ; nom libre comme fréquent ; modification des lignes de la liste.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Gérer | Panneau + ouvert, tap « Gérer » | panneau fermé, Fréquents affiché ; retour → Liste | — |
| Retirer | Lait retiré | absent des Ajouts fréquents du panneau ; Annuler le remet à sa place | — |
| Ajouter | recherche « pil », tap + sur Piles | Piles en dernier d'Entretien, dans le panneau aussi ; champ vidé | — |
| Réactiver | fréquent retiré puis ajouté de nouveau | même id, actif, en dernier de son rayon | — |
| Déjà fréquent | résultat Lait (fréquent) | coche, tap sans effet | — |
| Créer | « Kombucha » → Créer « Kombucha » | article du catalogue (Divers, sans unité) et fréquent | — |
| Rayon | Lait → Boissons | Lait en dernier de Boissons, prochain ajout de Lait en Boissons, ligne existante inchangée, ordre des autres fréquents inchangé | — |
| Vide | tous les fréquents retirés | message d'état vide | — |
| Échec | écriture qui lève | rien d'écrit | snackbar d'erreur |

</intent-contract>

## Code Map

- `lib/features/catalogue/data/catalogue_repository.dart` -- `watchFrequents` (par `position`), `createArticle`, `watchSearch`, `updateArticle` (story 6 : changement de rayon avec fréquent en dernier), `createCatalogueArticle`, `watchCatalogue` ; y ajouter ajout/réactivation et retrait d'un fréquent (positions : max actif + 1).
- `lib/features/catalogue/data/frequent_id.dart` -- `frequentId(articleId)`.
- `lib/core/undo/undo.dart`, `lib/core/undo/undo_snackbar.dart` -- enregistrement de l'état d'avant (`UndoRow`) et snackbar ; voir un appelant existant (par ex. la suppression d'une ligne de liste dans `lib/features/liste/`) pour le motif.
- `lib/features/liste/state/liste_providers.dart` l. ~120 -- `frequentsInRoute` (tri des fréquents par parcours).
- `lib/features/liste/ui/add_sheet_rows.dart` l. ~145 -- bouton « Gérer » ; `lib/features/liste/ui/add_sheet.dart` -- fermeture du panneau.
- `lib/features/reglages/ui/articles_screen.dart` (story 6) -- recherche et lignes à reprendre (factoriser plutôt que copier).
- `lib/features/reglages/ui/parametres_screen.dart`, `lib/core/router/app_router.dart`, `lib/app/kadi_app.dart`, `lib/core/strings/strings_fr.dart`.
- Nouveau : `lib/features/reglages/ui/frequents_screen.dart`.

## Tasks & Acceptance

**Execution:**
- [x] repository `catalogue` -- ajout/réactivation, retrait avec état d'avant pour Annuler.
- [x] route, chaînes, ligne « Fréquents », bouton « Gérer ».
- [x] `lib/features/reglages/ui/frequents_screen.dart`.
- [x] tests du repository et `test/features/reglages/frequents_screen_test.dart` -- chaque ligne de la matrice (Gérer et Retirer vérifiés jusque dans le Panneau +), TalkBack, police ×2.

**Acceptance Criteria:**
- Given le Panneau + ouvert, when Antoine touche « Gérer », retire Lait, ajoute Piles et revient, then les Ajouts fréquents du panneau n'ont plus Lait et ont Piles dans Entretien.

## Implementation Notes

**Fichiers touchés.** `lib/features/catalogue/data/catalogue_repository.dart` (`addFrequent`, `createFrequentArticle`, `removeFrequent`, `_addFrequent`, `_nextFrequentPosition` ; `_moveFrequentLast` le réutilise), `lib/features/catalogue/state/catalogue_providers.dart` (`frequentsInRouteProvider` et `frequentsInRoute` y sont déplacés depuis `liste`), `lib/core/rayons/rayon.dart` (`groupByRayon` déplacé depuis `liste_providers.dart`), `lib/features/liste/state/liste_providers.dart` (définitions retirées, imports nettoyés), `lib/features/recettes/state/revue.dart` (n'importe plus `liste_providers` : `groupByRayon` vient de `core`), `lib/features/liste/ui/add_sheet_rows.dart` (« Gérer »), `lib/core/router/app_router.dart` (`AppRoutes.frequents`), `lib/app/kadi_app.dart` (`GoRoute`), `lib/core/strings/strings_fr.dart` (microcopie Fréquents), `lib/features/reglages/ui/parametres_screen.dart` (ligne « Fréquents » sous « Articles »), nouveaux `lib/features/reglages/ui/article_lines.dart` (widgets factorisés) et `frequents_screen.dart`, `lib/features/reglages/ui/articles_screen.dart` (réécrit sur les widgets factorisés). Tests : `test/features/catalogue/catalogue_test.dart` (nouveau groupe Paramètres › Fréquents), nouveau `test/features/reglages/frequents_screen_test.dart`, `test/features/liste/add_sheet_test.dart` (le test « Gérer : rien ne se passe » devient « Gérer ferme le panneau et ouvre Fréquents »), `test/features/liste/liste_repository_test.dart` et `test/features/reglages/articles_screen_test.dart` (imports seulement).

**Décisions.**
- Règle de tri : `frequentsInRoute` et `frequentsInRouteProvider` déménagent dans `catalogue_providers.dart` (`catalogue` lit `core/settings`) ; le Panneau + (déjà importateur de `catalogue_providers`) et Paramètres › Fréquents les partagent. `groupByRayon`, générique et utilisé aussi par la Liste et la Revue, passe dans `lib/core/rayons/rayon.dart`. `liste` ne réexporte rien.
- Repository : `addFrequent(articleId)` (transaction ; déjà fréquent actif → rien ; sinon id `frequentId(articleId)`, inséré ou réactivé, `position` = max actif + 1, 0 sans fréquent ; article absent ou supprimé → `StateError`). `createFrequentArticle(name)` : `createArticle` (Divers, sans unité ; un hors-catalogue entre au catalogue, même id) puis l'ajout, une transaction. `removeFrequent(articleId)` : supprime logiquement tout fréquent actif de l'article, rend ses `UndoRow.before` (liste vide sans fréquent actif) ; Annuler réécrit la ligne d'avant, donc la même `position`.
- Rayon d'un fréquent : `updateArticle(id, name: nom actuel, rayon: choisi, unit: unité actuelle)`, le même chemin que la Fiche article ; même rayon touché → rien n'est écrit. Le Choix de rayon est une feuille modale du navigateur racine (`FrequentRayonSheet` : Picto, nom lu comme titre, « Rayon par défaut », `RayonPicker`) ; toucher une pastille ferme la feuille et rend le rayon, puis l'écran écrit (l'éventuel snackbar d'erreur s'affiche donc sur l'écran, la feuille étant fermée).
- « Gérer » : `GoRouter.of(context)` lu, puis `Navigator.pop(context)` (le panneau est la feuille du dessus du navigateur racine), puis `router.push(AppRoutes.frequents)`. `liste` ne connaît que `core/router`. `showAddSheet` fait ensuite son travail habituel (`panel.close()`, Annuler du panneau encore possible remontré sur la Liste).
- Factorisation (`article_lines.dart`) : `hasExactName`, `CatalogueSearchField` (loupe, ×, texte indicatif lu comme libellé), `ArticleLine` (gagne `label`, `onTapHint`, `trailing` ; `onTap` devient facultatif ; la ligne n'exclut plus toute la sémantique : Picto et textes sont exclus un à un pour qu'un bouton en `trailing` garde sa lecture), `CreateArticleLine`. Articles et Fréquents s'en servent ; lecture et apparence d'Articles inchangées.
- Ligne de fréquent (`FrequentLine`) : `ArticleLine` + `IconButton` `remove_circle_outline` en `on-surface-variant`, 48 dp, infobulle « Retirer Lait des fréquents ». Ligne de résultat (`FrequentResultLine`) : toute la ligne est la cible du + (lue « Piles, Divers », indication TalkBack « ajouter aux fréquents ») ; déjà fréquent : coche, aucune action, lue « Lait, déjà dans les fréquents ». La coche est une `Icons.check` neutre : l'indicateur rond à l'accent du rayon du panneau vit dans `liste`, que `reglages` ne peut pas importer.
- Champ vidé seulement si l'écriture réussit (sur un échec, la saisie reste pour réessayer). Échec : snackbar « Fréquent impossible à enregistrer. » pour l'ajout, la création, le retrait et le changement de rayon.
- Le message d'état vide ne s'affiche que champ vide ; la recherche reste possible.

**Surprises.**
- La matrice parle de « Piles en dernier d'Entretien », mais Piles est en **Divers** dans `assets/seed/articles.json`. Les tests vérifient Piles « en dernier de son rayon (Divers) » et utilisent **Lessive** (Entretien, non fréquent) pour le critère d'acceptation « … ont Piles dans Entretien ».
- L'ancien test `add_sheet_test.dart` « bouton Gérer : rien ne se passe » contredisait la story : réécrit.
- Le panneau sans fréquent n'affiche ni le titre ni « Gérer » (état vide existant, « Ajoute-les dans les paramètres. ») : on y arrive alors par Paramètres › Fréquents. Non modifié.

**Vérification.** `flutter analyze` : aucun problème. `grep -rn "Ã\|â€" lib test` : aucun résultat. `dart format` passé sur les fichiers touchés. Tests écrits, non lancés (lancés une fois après 3.6 à 3.8).

## Plan Change Log

## Review Triage Log

## Design Notes

- [ASSUMPTION] Aide « Tes ajouts fréquents du bouton + », texte indicatif « Ajouter un fréquent », message vide et tap sans effet sur un résultat déjà fréquent : Antoine les valide au test de fin d'epic.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- Tests : écrits, lancés une seule fois à la fin des stories 3.6 à 3.8.
