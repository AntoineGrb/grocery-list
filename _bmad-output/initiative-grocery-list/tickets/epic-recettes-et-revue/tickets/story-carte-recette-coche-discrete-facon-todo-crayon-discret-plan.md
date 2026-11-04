---
title: 'Carte recette : coche discrète façon todo, crayon discret'
type: 'feature'
ticket: '9'
created: '2026-11-03'
status: done
baseline_revision: 'ced731399072fbc36b62f2da5040ae7e057fc726'
route: 'full'
route_source: 'auto'
risk: 'low'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/epic-recettes-et-revue.md'
warnings: []
deferred:
  - summary: >-
      La coche ronde partagée (RoundCheck, case M3) anime son remplissage même quand les animations Android sont désactivées.
    evidence: |-
      Checkbox M3 n'écoute pas MediaQuery.disableAnimations ; comportement commun à la Liste (epic 1 validé), à la Revue et désormais à la carte. Se tranche par un test widget avec disableAnimations qui mesure l'état de la case après une frame.
    location: >-
      lib/core/ui/round_check.dart
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Au test de fin d'epic, Antoine trouve la pastille noire à coche de la carte sélectionnée laide et confusante, et le crayon « modifier » trop gros et trop voyant (Decision 2026-11-03 de l'epic).

**Approach:** Remplacer la pastille et la bordure de sélection par la coche ronde de la Liste (`RoundCheck` de `lib/core/ui/round_check.dart`), petite, sur chaque carte ; réduire et adoucir l'icône « modifier ».

## Boundaries & Constraints

**Always:**
- Chaque carte porte en haut à gauche la coche ronde de la Liste (24 dp visuels, cible 48 dp) : contour vide si la recette n'est pas sélectionnée, pleine avec la coche si elle l'est. Couleur `on-surface` (contour et remplissage), coche `surface`, jamais d'argile ni couleur de rayon. Plus de bordure de carte ni de pastille de 26 dp.
- Sur une photo, la coche reste lisible : petit disque `surface` translucide derrière elle (même principe que la pastille du crayon sur photo).
- Un tap sur la coche fait comme un tap sur la carte (sélectionner / désélectionner, désélection d'une validée avec Annuler) : un seul chemin, aucun double appel.
- Icône « modifier » : visuel d'au plus 18 dp, `on-surface-variant`, sans fond hors photo ; cible de 48 dp ; lue « Modifier Chili ».
- TalkBack inchangé : la carte reste lue « Chili, sélectionnée » / « Chili, non sélectionnée » avec son tap ; la coche n'ajoute pas de nœud lu en double.
- Le nom n'est jamais masqué par la coche ; police système sans troncature.

**Never:**
- Changer la sélection, la validation ou la Revue ; toucher à la Liste.

</intent-contract>

## Code Map

- `lib/features/recettes/ui/recipe_card.dart` -- `Stack` actuel : pastille 26 dp (`KadiSpacing.recipeMark`) et bordure 2 dp à la sélection ; icône `edit_outlined` avec `IconButton` ; `RecipePhotoImage` pour la photo. Remplacer la marque par `RoundCheck` (`accent: on-surface`), retirer la bordure, réduire l'icône.
- `lib/core/ui/round_check.dart` -- réutiliser tel quel (ne pas changer son rendu dans la Liste ni la Revue).
- `lib/core/theme/kadi_tokens.dart` -- `recipeMark` devient inutile : le retirer s'il n'a plus d'usage.
- `test/features/recettes/recettes_screen_test.dart` -- assertions de pastille et de bordure à adapter à la nouvelle marque ; ajouter coche vide / pleine, taille du crayon, tap sur la coche.

## Tasks & Acceptance

**Execution:**
- [x] `recipe_card.dart`, `kadi_tokens.dart` -- coche ronde, crayon discret
- [x] tests -- coche vide et pleine, sans bordure, tap sur la coche, crayon ≤ 18 dp et cible 48 dp, TalkBack inchangé, police ×2

**Acceptance Criteria:**
- Given Recettes, when aucune recette n'est sélectionnée, then chaque carte montre une coche ronde vide en haut à gauche, sans bordure.
- Given une carte touchée, when elle est sélectionnée, then sa coche ronde est pleine et « Valider (1) » apparaît.
- Given une carte, then le crayon est petit et discret, et le toucher ouvre la fiche sans changer la sélection.

## Implementation Notes

- `RoundCheck` (inchangé) posé en haut à gauche du visuel (`PositionedDirectional` top 0 / start 0, cible 48 dp), `accent: on-surface`, `onChanged: onTap` : le `Stack` ne donne le tap qu'à la coche, donc un seul appel. Enveloppé dans `ExcludeSemantics` : aucun nœud « coché » en plus du nœud de la carte.
- Disque `surface` α 0,8 de 32 dp (`KadiSpacing.recipeDisc`) derrière la coche et derrière le crayon, seulement quand la carte a une photo ; le crayon n'a plus de fond de bouton.
- Crayon : `Icon` de 18 dp (`KadiSpacing.recipeEditIcon`), `on-surface-variant`, dans l'`IconButton` à 48 dp minimum.
- `KadiSpacing.recipeMark` retiré (plus d'usage) ; `recipeEditIcon` et `recipeDisc` ajoutés.
- Tests : `find.byIcon(Icons.check)` remplacé par la valeur de la `Checkbox` de la carte ; helper `recipeCardDiscs` dans `test/helpers/recettes.dart` ; disques vérifiés dans `fiche_recette_photo_test.dart`. Test TalkBack vérifié par mutation (sans `ExcludeSemantics`, il échoue).

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 0, maybe-false 1
- findings:
  - `[low]` `[reject]` DESIGN.md décrit encore la bordure et la pastille de 26 dp — déjà consigné (Decision 2026-11-03 de l'initiative : DESIGN.md et EXPERIENCE.md à remettre à jour avec bmad-ux) ; un compagnon adopté ne s'édite pas ici.
  - `[low]` `[reject]` R3 de l'epic exigeait encore une bordure — corrigé côté tickets (R3 re-rendu dans l'initiative et l'epic, memlog), pas dans le code.
  - `[maybe-false]` `[defer]` La coche anime même animations coupées — comportement partagé de `RoundCheck` (Liste validée à l'epic 1) ; reporté avec ce qui le tranchera.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : chaque carte porte la coche ronde de la Liste (vide / pleine, `on-surface`), sans bordure ni pastille ; crayon de 18 dp `on-surface-variant` sans fond, cible 48 dp ; disque `surface` translucide derrière coche et crayon sur photo.
- Fichiers : `recipe_card.dart`, `kadi_tokens.dart` ; tests `recettes_screen_test.dart`, `fiche_recette_photo_test.dart`, `test/helpers/recettes.dart`.
- Revue : 0 correctif de code, 1 report, 2 rejets (R3 re-rendu dans les tickets).
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 619/619.
- Risques : rendu à juger sur le téléphone.
