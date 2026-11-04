---
title: 'Refactor sweep'
type: 'refactor'
ticket: '8'
created: '2026-11-02'
status: done
baseline_revision: '622cf860a391ade2656440af32871038383a2786'
route: 'full'
route_source: 'auto'
risk: 'low'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** L'epic 2 s'est construit story par story : la coche ronde est recopiée entre la Ligne d'article et la Ligne de Revue, `recettes_repository.dart` (659 lignes) mêle les modèles de quatre écrans et ses requêtes, le tri des recettes par nom normalisé est écrit deux fois, et les tests de Recettes répètent leurs aides de montage et de navigation. Le seul report formel (`deferred` de la story 1 : Revue et article supprimé) attend l'epic 3.

**Approach:** Nettoyage seul, sans aucun changement de comportement visible ni de données : mutualiser, découper, puis vérifier que toute la suite passe à l'identique.

## Boundaries & Constraints

**Always:** comportement, textes, sémantique TalkBack, écritures en base et API publiques des repositories et actions inchangés ; chaque test existant passe, ses assertions intactes (seuls ses imports et ses aides peuvent changer) ; même nombre de tests (615) ; `flutter analyze` propre ; conventions du spine (Material par `package:material_ui/material_ui.dart`, `core` n'importe aucune fonctionnalité, `liste` n'importe pas `recettes`, textes dans `strings_fr.dart`, commentaires à 80 colonnes).

**Never:** aucun ajout de périmètre : les constats rejetés des revues (taps rapides, écrans vides en cas d'échec de lecture, « Annuler » sans effet après Nouvelle liste, pastille de l'icône « modifier », sémantique de « Remplacer » / « Retirer », texte réduit de « Nouvelle liste »), le report de la story 1 et les [ASSUMPTION] à valider par Antoine restent tels quels ; pas de migration ; pas de changement de pubspec.

</intent-contract>

## Code Map

- `lib/features/liste/ui/item_row.dart` (`_checkScale`, `Transform.scale` + `Checkbox` en `CircleBorder` à l'accent du rayon) et `lib/features/recettes/ui/revue_row.dart` (même bloc) -- une seule coche ronde partagée dans `lib/core/ui/` (widget sans fonctionnalité : valeur, `onChanged`, couleur d'accent), mêmes tailles, couleurs, halo et cible de 48 dp.
- `lib/features/recettes/data/recettes_repository.dart` -- déplacer les classes de modèle (`RecipeCardItem`, `RevueSource`, `PendingSelections`, `RecipeSheet`, `RecipeSheetIngredient`, `RecipeDraft`, `RecipeDraftIngredient`, `DeselectedSelections`, `cleanRecipeName`, résultats de suppression…) dans un fichier de modèles voisin, ré-exporté par le repository pour ne changer aucun import appelant ; le tri par nom normalisé de `watchCards` (`_byName`) et de `pendingSelections` passe par une seule fonction.
- `test/features/recettes/*.dart`, `test/app/*_test.dart` -- aides répétées (ouvrir l'onglet Recettes, toucher une carte par son nom, ouvrir la Revue, ouvrir une fiche, trouver un bouton par texte) : les regrouper dans `test/helpers/` quand au moins deux fichiers les copient ; sinon les laisser.
- Snackbars : vérifier que tout snackbar d'erreur passe par `showErrorSnackBar` (`lib/core/ui/error_snackbar.dart`) et tout Annuler par `showUndoSnackBar` ; remplacer une copie si elle existe, sans changer texte ni durée.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/ui/` + `item_row.dart` + `revue_row.dart` -- coche ronde partagée -- duplication
- [x] `recettes_repository.dart` + fichier de modèles -- découpage, tri unique -- lisibilité
- [x] snackbars -- passage par les deux aides existantes s'il reste des copies -- duplication
- [x] `test/helpers/` -- aides communes des tests de Recettes -- duplication des tests
- [x] suite complète -- non-régression

**Acceptance Criteria:**
- Given le code nettoyé, when `flutter analyze` et `flutter test` tournent, then aucun problème et 615 tests verts, sans assertion modifiée.
- Given l'app, then rien ne change pour Antoine : mêmes écrans, textes, gestes et annonces TalkBack.

## Implementation Notes

- Coche ronde : `RoundCheck` (`lib/core/ui/round_check.dart`) porte la cible de 48 dp, l'échelle 24 dp, le contour, le halo et `checkColor` = `surface` ; `ItemRow` et `RevueRow` l'utilisent, `Checkbox` reste dans l'arbre (les finders des tests ne changent pas).
- Modèles : `lib/features/recettes/data/recettes_models.dart` (classes, typedefs, `cleanRecipeName`), ré-exporté par `recettes_repository.dart` ; aucun import appelant touché. Tri par nom normalisé puis id : `_sortedByName` unique pour `watchCards` et `pendingSelections`.
- Snackbars : aucune copie d'erreur ni d'Annuler hors des deux aides. Le seul `SnackBar` direct restant (`liste_screen.dart`, avis « Liste prête ») est une information, pas une erreur : laissé.
- Tests : `test/helpers/recettes.dart` (`tallPhone`, `openTab`, `recipeCard`, `tapRecipeCard`, `editRecipe`, `backFromFiche`, `ficheNameField`, `recipeNamed`) pour les quatre tests d'écran de Recettes ; `test/helpers/failing_clear_selections.dart` pour le faux repository copié dans `nouvelle_liste_test` et `terminer_les_courses_test`. Les `expect` des anciennes aides privées sont déplacés tels quels ; les appels renommés, aucun matcher changé. `_edit` de `supprimer_recette_test` garde son `ensureVisible` propre. Les réglages de vue écrits dans le corps de certains tests et l'enregistreur d'annonces (un seul fichier de Recettes) sont laissés.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `fiche_recette_screen_test.dart` ouvrait encore l'onglet Recettes à la main — remplacé par `openTab`.
  - `[low]` `[patch]` « Ouvrir la Revue » recopié dans trois fichiers de test — aides `validerButton` et `openRevue` dans `test/helpers/recettes.dart`, assertions inchangées.
  - `[low]` `[patch]` Deux liens de doc vers `RecettesRepository` cassés par le déplacement des modèles — passés en code entre backticks.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed, 615
- `git diff --stat` sur `test/` -- expected: seuls imports et aides changent, aucune assertion

## Auto Run Result

- Résumé : nettoyage sans changement visible : coche ronde partagée (`lib/core/ui/round_check.dart`) pour la Ligne d'article et la Ligne de Revue ; modèles de Recettes déplacés dans `recettes_models.dart`, ré-exportés ; tri par nom normalisé unique ; aides de test communes (`test/helpers/recettes.dart`, `failing_clear_selections.dart`). Snackbars déjà mutualisés, rien à changer.
- Fichiers : `round_check.dart`, `item_row.dart`, `revue_row.dart`, `recettes_models.dart`, `recettes_repository.dart` ; tests de Recettes et des actions, `test/helpers/`.
- Revue : 3 correctifs (low), 0 report, 0 rejet.
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 615/615, assertions inchangées.
- Risques : aucun connu.
