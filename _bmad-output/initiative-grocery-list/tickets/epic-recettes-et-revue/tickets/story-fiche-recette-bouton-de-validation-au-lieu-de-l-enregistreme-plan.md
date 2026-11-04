---
title: "Fiche recette : bouton de validation au lieu de l'enregistrement automatique"
type: 'feature'
ticket: '12'
created: '2026-11-03'
status: done
baseline_revision: 'e42350c871ec5ee75f031c5c43fa12c9cbb7e762'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/epic-recettes-et-revue.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-fiche-recette-creer-et-modifier-une-recette-en-moins-d-une-m-plan.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-photo-et-lien-d-une-recette-plan.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Antoine veut valider une recette par un bouton plutôt qu'un enregistrement automatique à chaque changement (Decision 2026-11-03, R1 re-rendu : « La fiche s'enregistre par un bouton de validation, actif dès qu'elle a un nom et au moins un ingrédient »).

**Approach:** La fiche garde son brouillon en mémoire et n'écrit plus rien avant « Enregistrer » ; le bouton écrit tout en une transaction puis ferme la fiche ; quitter une fiche modifiée sans l'enregistrer demande confirmation.

## Boundaries & Constraints

**Always:**
- Bouton d'action « Enregistrer » (DESIGN `action-button` : plein, argile, pleine largeur, en bas de la fiche, au-dessus du clavier quand il est ouvert), grisé tant que le nom nettoyé est vide ou qu'il n'y a aucun ingrédient. Un tap : nom, ingrédients (ordre, quantités, unités), photo et lien sont écrits en une transaction par `RecettesRepository.saveDraft` (sans changer ses règles : lignes inchangées non réécrites, ingrédients retirés supprimés logiquement), puis la fiche se ferme sur Recettes. Échec : snackbar « Enregistrement impossible. Réessaie. », fiche ouverte, rien d'écrit.
- Plus aucune écriture avant « Enregistrer » : ni frappe, ni ajout, ni retrait, ni quantité, ni photo, ni lien. Les articles créés par « Créer « … » » / Entrée de la popup restent créés au catalogue à l'instant (story 11), même si la fiche est abandonnée.
- Quitter (flèche ou retour Android) une fiche modifiée depuis son ouverture ou son dernier enregistrement : dialogue « Quitter sans enregistrer ? » · « Tes modifications seront perdues. » · « Garder » (repli, `on-surface` ; tap dehors et retour valent Garder) / « Quitter » (`error`), qui ferme sans rien écrire. Fiche non modifiée : on quitte sans question. Exception à C9 notée dans l'epic, à valider par Antoine.
- Photos : une photo choisie puis abandonnée (fiche quittée sans enregistrer, ou remplacée avant d'enregistrer) a son fichier supprimé ; la photo d'avant reste. Après « Enregistrer », l'ancien fichier remplacé ou retiré est supprimé (comportement de la story 6, déclenché par l'enregistrement).
- « Supprimer la recette » (story 7) inchangé : visible seulement pour une recette déjà en base, sans confirmation, avec Annuler ; il n'a plus à attendre d'enregistrement en cours.
- R7 : enregistrer une recette validée ne change pas la liste.
- TalkBack : « Enregistrer » avec son état (désactivé), dialogue lu ; police système sans troncature. Microcopie dans `strings_fr.dart`.

**Never:**
- Enregistrement automatique, partiel ou à la sortie ; confirmation ailleurs que pour quitter une fiche modifiée.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Nouvelle valide | Nom + 2 ingrédients, Enregistrer | Recette créée, fiche fermée, carte visible | Échec : snackbar, fiche ouverte |
| Bouton grisé | Nom vide ou aucun ingrédient | « Enregistrer » désactivé | — |
| Rien avant | Frappes, ajouts, retour + Quitter | Aucune ligne `recipes` ni `recipe_ingredients` écrite | — |
| Garder | Fiche modifiée, retour, Garder | Fiche ouverte, brouillon intact | — |
| Non modifiée | Ouverture puis retour | Fermeture sans dialogue | — |
| Modifier existante | Quantité changée, Enregistrer | Ingrédient mis à jour, liste inchangée (R7) | — |
| Photo abandonnée | Photo choisie, Quitter | Fichier supprimé, ancienne photo gardée | — |
| Article créé | « Piment » créé puis Quitter | Article reste au catalogue | — |

</intent-contract>

## Code Map

- `lib/features/recettes/ui/fiche_recette_screen.dart` -- `_changed` / `_flush` / `_flushing` déclenchent l'enregistrement automatique : les remplacer par un état « modifié » et une écriture au tap ; `PopScope` pour le dialogue ; bouton en `bottomNavigationBar` avec la marge du clavier (`MediaQuery.viewInsetsOf`), comme `revue_screen.dart` ; `_delete` n'attend plus d'écriture en cours ; nettoyage des photos (`_cleanPhotos`) déplacé à l'enregistrement et à la sortie.
- `lib/features/recettes/data/recettes_repository.dart` -- `saveDraft` réutilisé tel quel (photo et lien compris).
- `lib/features/recettes/ui/fiche_recette_photo.dart`, `lib/features/recettes/data/recipe_photos.dart` -- règles de suppression des fichiers non utilisés : base et brouillon.
- `lib/core/strings/strings_fr.dart` -- « Enregistrer », « Quitter sans enregistrer ? », « Tes modifications seront perdues. », « Quitter » ; « Garder » existe (Nouvelle liste).
- Tests : `fiche_recette_screen_test.dart`, `fiche_recette_repository_test.dart` si besoin, `fiche_recette_photo_test.dart`, `supprimer_recette_test.dart` — les tests qui comptaient sur l'enregistrement automatique passent par « Enregistrer » (assertion de résultat inchangée) ; matrice ; TalkBack ; police ×2 ; clavier ouvert.

## Tasks & Acceptance

**Execution:**
- [x] `fiche_recette_screen.dart`, `strings_fr.dart` -- bouton, état modifié, dialogue de sortie, plus d'écriture automatique
- [x] photos -- suppression des fichiers abandonnés à la sortie, des anciens à l'enregistrement
- [x] tests -- matrice, parcours adaptés, TalkBack, police

**Acceptance Criteria:**
- Given une fiche neuve avec un nom et deux ingrédients, when Antoine touche « Enregistrer », then la fiche se ferme et la carte apparaît sur Recettes.
- Given une fiche modifiée, when il touche retour, then « Quitter sans enregistrer ? » s'affiche ; « Quitter » ferme sans rien écrire, « Garder » le laisse sur la fiche.
- Given une fiche sans nom ou sans ingrédient, then « Enregistrer » est grisé.

## Implementation Notes

- Implémenté par un sous-agent sur la base e42350c. Fichiers : `fiche_recette_screen.dart` (plus de `_changed` / `_flush` / `_flushing` / `_pendingSave` ; `_save` au tap, `_onBack` sous un `PopScope(canPop: false)`, `_signature` / `_modified` / `_canSave`, bouton en `bottomNavigationBar` avec la marge du clavier comme la Revue), `fiche_recette_rows.dart` (`IngredientRow.onChanged` retiré, plus utile), `core/ui/confirm_dialog.dart` (nouveau : `ConfirmDialog` + `showConfirmDialog`, extrait du dialogue de Nouvelle liste de `recettes_screen.dart`, qui l'utilise maintenant), `strings_fr.dart` (`enregistrer`, `quitterSansEnregistrerTitre` avec espace insécable avant « ? », `quitterSansEnregistrerTexte`, `quitter`).
- « Modifiée » = l'état montré (nom, lien, photo, ingrédients dans l'ordre avec leur quantité stockée) diffère de celui de l'ouverture : une quantité changée puis rétablie, ou un ingrédient ajouté puis retiré, ne demande rien. Une unité changée sans quantité n'est pas une modification (rien ne s'écrirait).
- `saveDraft` inchangé ; s'il rend faux (recette supprimée entre-temps), même snackbar d'échec que pour une erreur. Pendant un enregistrement, le retour, « Supprimer » et un second tap sont ignorés ; le bouton est grisé.
- Photos : `_cleanPhotos` garde la photo en base et, fiche ouverte, celle du brouillon ; appelé après un choix, un retrait, un enregistrement réussi et à la fermeture. Une photo choisie puis remplacée ou retirée avant d'enregistrer est supprimée tout de suite ; une photo en base remplacée ou retirée reste sur le disque jusqu'à « Enregistrer » (supprimée alors), ou reste tout court si la fiche est quittée. « Supprimer la recette » après un choix de photo : la photo choisie, jamais enregistrée, est supprimée ; Annuler rend la recette telle qu'en base.
- `ConfirmDialog` est `scrollable` : à ×3 sur 360 dp, le titre du dialogue de sortie débordait (480 px) ; il défile maintenant, les actions restent à portée. Vaut aussi pour Nouvelle liste.
- Tests : `fiche_recette_screen_test.dart` (Flux 4 jusqu'à « Enregistrer », bouton grisé, rien avant, Garder / tap dehors / retour Android / Quitter, non modifiée et rétablie, article créé gardé, échec puis réessai, clavier ouvert, TalkBack état désactivé / actif et dialogue, police ×1,3 / ×2 / ×3 avec le bouton et le dialogue), `fiche_recette_photo_test.dart` (photo et lien écrits seulement à « Enregistrer », photo abandonnée, ancienne supprimée après l'enregistrement, Supprimer après un choix), `supprimer_recette_test.dart` (fiche neuve enregistrée puis rouverte), helpers `saveFiche`, `quitFiche`, `saveButton`, `saveEnabled`, `quitDialog`.
- Vérification : `flutter analyze` sans problème ; `flutter test` 624/624.
- Après revue : un choix de photo en cours grise « Enregistrer » et compte comme une modification (le retour demande confirmation) ; pendant l'écriture, la fiche est inerte (`AbsorbPointer`, qui bloque aussi les actions TalkBack ; focus rendu ; popup, retrait, unité, photo ignorés par leurs gestionnaires). Doc de `saveDraft` remise à « Enregistrer ». Tests : choix de photo en attente, fenêtre d'écriture.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` « Enregistrer » actif pendant l'import d'une photo et fiche vivante pendant l'enregistrement : photo enregistrée supprimée, fichier orphelin ou choix perdu — corrigé : bouton grisé pendant un import, import en cours compté comme modification, fiche inerte pendant l'enregistrement ; deux tests.
  - `[low]` `[patch]` Doc de `saveDraft` décrivant encore l'enregistrement automatique — reformulée.
  - `[low]` `[patch]` Nom du test Flux 4 parlant encore de « retour » — renommé.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : la fiche n'écrit plus rien avant « Enregistrer » (bouton plein en bas, au-dessus du clavier, grisé sans nom, sans ingrédient ou pendant l'import d'une photo) ; une transaction écrit nom, ingrédients, photo et lien puis ferme la fiche ; quitter une fiche modifiée demande « Quitter sans enregistrer ? » (Garder / Quitter) ; dialogue de confirmation partagé avec Nouvelle liste (`lib/core/ui/confirm_dialog.dart`, défilant en très grande police).
- Fichiers : `fiche_recette_screen.dart`, `fiche_recette_rows.dart`, `recettes_screen.dart`, `confirm_dialog.dart` (nouveau), `strings_fr.dart`, `recettes_repository.dart` (doc) ; tests `fiche_recette_screen_test.dart`, `fiche_recette_photo_test.dart`, `supprimer_recette_test.dart`, `test/helpers/recettes.dart`.
- Revue : 3 correctifs (1 medium, 2 low), 0 report, 0 rejet.
- Revue de suivi recommandée : non (un medium corrigé et couvert par deux tests).
- Vérification : `flutter analyze` sans problème ; `flutter test` 626/626.
- Risques : une photo choisie puis la recette supprimée sans enregistrer : Annuler rend la recette sans cette photo ; dialogue à faire défiler à ×3.
