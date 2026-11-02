---
title: 'Désélectionner une recette validée retire ses quantités, avec Annuler'
type: 'feature'
ticket: '3'
created: '2026-11-02'
status: 'built'
baseline_revision: '1568758c4285bc01154d604e173e2bc05433ff85'
route: 'full'
route_source: 'auto'
risk: 'high'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/epic-recettes-et-revue.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-une-recette-exemple-selectionnee-et-validee-arrive-dans-la-l-plan.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Un tap sur une carte déjà validée ne fait rien (story 1) : Antoine ne peut pas revenir sur une recette validée par erreur ou abandonnée (R6, échecs des Flux 1 et 5).

**Approach:** Une action transverse « désélectionner une recette validée » (AD-3), en une transaction : la sélection est supprimée logiquement (AD-16) et ses contributions quittent les seules lignes non cochées et non manuelles (AD-4, AD-5) ; l'état d'avant va au service Annuler (AD-10) et Recettes montre « Ingrédients de « Chili » retirés de la liste » · « Annuler ».

## Boundaries & Constraints

**Always:**
- Seules les contributions actives `week_selection` portant l'id de cette sélection sont supprimées logiquement, et seulement sur des lignes actives, non cochées (`checked_at` nul) et non manuelles (`manual_at` nul). Lignes cochées et lignes corrigées à la main : rien ne change.
- Une ligne qui n'a plus aucune contribution active est supprimée logiquement. Une ligne qui garde des contributions mais aucune chiffrée perd son unité (sans quantité), pour qu'une contribution chiffrée suivante la rejoigne (AD-4).
- Une transaction ; `updated_at` par l'horloge ; l'état d'avant de chaque ligne touchée (sélection, contributions, lignes) est rendu en `UndoRow` et enregistré par `Undo.record` après la transaction ; Annuler rend exactement l'état d'avant (lignes, contributions, sélection).
- Snackbar Annuler (`showUndoSnackBar`) sur Recettes : « Ingrédients de « Chili » retirés de la liste » (guillemets français avec espaces insécables, comme `StringsFr.ajouterNom`) · « Annuler », même si aucune ligne n'a changé. Échec : rien d'écrit, snackbar d'erreur.
- Désélectionner une carte non validée reste sans snackbar (story 1). Valider ensuite une autre recette ne renvoie en Revue que ses ingrédients (Flux 5).
- TalkBack : la carte est relue « Chili, non sélectionnée » après la désélection ; le snackbar est annoncé.
- `features/liste` n'importe jamais `features/recettes`.

**Never:**
- Toucher à Nouvelle liste ou à Terminer les courses (story 4), à la Fiche recette (story 5).
- Supprimer physiquement quoi que ce soit, ou réactiver une sélection autrement que par Annuler (AD-16).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Quantités fusionnées | Tomates 300 g (Chili) + 200 g (Quiche), désélectionner Chili | « Tomates 200 g » | — |
| Ligne seule | Ingrédient présent seulement dans Chili | Ligne supprimée logiquement | — |
| Ligne cochée | Une ligne du Chili cochée | Reste cochée avec sa quantité | — |
| Ligne manuelle | Ligne corrigée à la main (`manual_at`) | Garde sa quantité et ses contributions | — |
| Mêlée à un ajout | Chili 300 g + ajout Panneau + sans quantité | Ligne gardée, sans quantité ni unité | — |
| Annuler | Juste après | Lignes, contributions et sélection exactement comme avant ; carte resélectionnée | Autre écriture entre-temps : Annuler sans effet (AD-10) |
| Non validée | Carte sélectionnée non validée | Comme story 1, sans snackbar | — |
| Échec | Écriture qui lève | Rien d'écrit, snackbar d'erreur, carte toujours sélectionnée | — |

</intent-contract>

## Code Map

- `lib/app/actions/` -- nouvelle action (modèle `terminer_les_courses.dart` et `ajouter_a_la_liste.dart`) : transaction qui appelle `RecettesRepository` (supprimer la sélection validée, rendre ses `UndoRow`) puis `ListeRepository` (retirer les contributions de cette sélection), rend l'entrée Annuler ; provider à côté.
- `lib/features/recettes/data/recettes_repository.dart` -- `deselect` ne touche qu'aux sélections non validées : ajouter la suppression logique de la sélection validée d'une recette, à appeler dans la transaction de l'action, avec son `UndoRow.before` (`lib/core/undo/undo.dart`).
- `lib/features/liste/data/liste_repository.dart` -- nouvelle méthode, à appeler dans une transaction, qui retire les contributions d'un `week_selection_id` selon les règles ci-dessus et rend les `UndoRow` (modèle `removeArticle` / `clearList` : un horodatage postérieur à chaque ancien `updated_at`). Ne rien changer aux autres méthodes.
- `lib/features/recettes/ui/recettes_screen.dart` -- `_toggle` : carte validée → l'action puis `showUndoSnackBar` ; le snackbar s'affiche au-dessus du Bouton d'action, sous un messager propre à Recettes comme `liste_screen.dart` (son `ScaffoldMessenger` + `Builder`).
- `lib/core/strings/strings_fr.dart` -- chaîne de la désélection.
- `lib/core/undo/undo_snackbar.dart` -- réutiliser tel quel.
- Tests : `test/features/liste/liste_repository_test.dart` (retrait), un test de l'action dans `test/app/` (matrice, dont un instantané complet des tables `list_lines`, `list_contributions`, `week_selections` avant la désélection égal à celui d'après Annuler, `updated_at` exclus), `test/features/recettes/recettes_screen_test.dart` (snackbar, Annuler, TalkBack, Flux 5).

## Tasks & Acceptance

**Execution:**
- [ ] `liste_repository.dart` + test -- retrait des contributions d'une sélection -- AD-4, AD-5
- [ ] `recettes_repository.dart` + test -- suppression de la sélection validée avec état d'avant -- AD-16
- [ ] action de désélection + test -- matrice et instantané Annuler -- AD-3, AD-10
- [ ] `recettes_screen.dart`, `strings_fr.dart` + tests d'écran -- snackbar, Annuler, TalkBack, Flux 5

**Acceptance Criteria:**
- Given Carbonara et Quiche validées (Lardons 400 g dans la Liste), when Antoine touche la carte Carbonara, then la carte perd sa coche, la Liste montre « Lardons 200 g » et Recettes affiche « Ingrédients de « Pâtes carbonara » retirés de la liste » avec « Annuler ».
- Given ce snackbar, when il touche « Annuler », then la carte est de nouveau sélectionnée sans « Valider » et la Liste montre de nouveau « Lardons 400 g ».
- Given une recette validée puis désélectionnée, when il sélectionne une autre recette et touche « Valider (1) », then la Revue ne montre que les ingrédients de cette recette.

## Implementation Notes

- Implémenté par un sous-agent : `ListeRepository.removeSelectionContributions`, `RecettesRepository.deselectValidated`, action `lib/app/actions/deselectionner_une_recette.dart`, messager propre à Recettes, chaîne `ingredientsRetires`. Un échec réutilise « Modification impossible. Réessaie. ». Le test de la story 1 « carte validée : rien » est remplacé par la désélection.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Une ligne qui perd sa dernière quantité passe sans unité même si l'article a déjà une ligne non cochée sans unité : deux « Lardons » sans quantité (AD-4) — corrigé : la ligne garde alors son unité, sans quantité affichée ; test de la séquence dans `retrait d'une sélection`.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : un tap sur une carte validée la désélectionne ; l'action transverse supprime la sélection et retire ses contributions des lignes non cochées et non manuelles (ligne vidée supprimée, ligne sans quantité restante sans unité sauf jumeau) ; snackbar « Ingrédients de « … » retirés de la liste » · « Annuler », qui rend l'état exact d'avant.
- Fichiers : `liste_repository.dart`, `recettes_repository.dart`, `deselectionner_une_recette.dart` (nouveau), `recettes_screen.dart`, `strings_fr.dart` ; tests `liste_repository_test.dart`, `recettes_repository_test.dart`, `deselectionner_une_recette_test.dart` (nouveau), `recettes_screen_test.dart`.
- Revue : 1 correctif (low, jumeau sans unité), 0 report, 0 rejet.
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 521/521.
- Risques : deux taps rapides sur une carte validée : le second ne fait rien.
