---
title: 'Ajouts fréquents en liste plate, en-têtes de rayon sans compteur'
type: 'feature'
ticket: '12'
created: '2026-10-30'
status: done
baseline_revision: 'fa6b82fa847804090b71638c6ab6e0d3e5b4f11f'
route: 'full'
route_source: 'auto'
risk: 'low'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Au Panneau +, les fréquents ressemblent à la Liste (en-têtes de rayon puis lignes) et rien ne dit ce qu'ils sont ; dans la Liste, le compteur des en-têtes de rayon encombre.

**Approach:** Section titrée « Ajouts fréquents » avec un crayon à droite (sans action jusqu'à l'epic 3), fréquents en liste plate dans l'ordre du parcours, sans en-tête ni libellé de rayon. En-têtes de rayon sans compteur, annoncés par leur seul nom.

## Boundaries & Constraints

**Always:** ordre des fréquents = rayons dans l'ordre du parcours de `settings`, puis `position` dans un rayon (comme aujourd'hui, sans les en-têtes) ; chaque ligne garde +, coche et crayon de la story 11 ; « Cochés (n) » garde son compteur ; textes dans `strings_fr.dart` ; DESIGN `frequents-title`, `rayon-header` ; cibles 48 dp ; TalkBack et taille de police système ; tests de widgets.

**Never:** le crayon du titre n'ouvre rien et ne mène nulle part (pas d'écran Paramètres, pas de snackbar) ; pas de changement de la Ligne saisie, des résultats ni de la Feuille d'édition ; pas d'argile.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ouverture | fréquents Lait (Crèmerie), Pommes (Fruits & légumes) | Titre « Ajouts fréquents » + crayon, puis Pommes puis Lait (ordre du parcours), aucun En-tête de rayon, aucun libellé de rayon | — |
| Parcours modifié | parcours avec Crèmerie avant Fruits & légumes | Lait puis Pommes | — |
| Aucun fréquent | table vide | Message « Pas encore de fréquents… » ; titre absent [ASSUMPTION] | — |
| Saisie | texte dans le champ | Titre et fréquents laissent la place aux résultats | — |
| Crayon du titre | tap | Rien ne se passe ; TalkBack le lit « Modifier les ajouts fréquents » | — |
| En-tête de la Liste | Crèmerie avec 2 articles | « Crèmerie » sans chiffre ; TalkBack « Crèmerie », titre | — |
| Cochés | 3 articles cochés | « Cochés (3) » inchangé | — |

</intent-contract>

## Code Map

- `lib/features/liste/ui/rayon_header.dart` -- retirer `count` et le compteur ; annonce = `rayon.spokenLabel` seul. Appels : `lib/features/liste/ui/liste_screen.dart:107` (`count: group.count`), `lib/features/liste/ui/add_sheet.dart:304`.
- `lib/features/liste/state/liste_providers.dart:75-105` -- `FrequentGroup`, `frequentGroupsProvider`, `groupFrequentsByRoute` : remplacer par un `frequentsInRouteProvider` qui rend la liste plate (groupes aplatis dans l'ordre du parcours) ; garder `groupByRayon<T>` ; `RayonGroup.count` peut rester s'il sert ailleurs, sinon le retirer.
- `lib/features/liste/ui/add_sheet.dart:265-310` -- contenu sans saisie : titre puis lignes `FrequentRow` à plat ; état vide inchangé.
- `lib/features/liste/ui/add_sheet_rows.dart` -- nouveau `FrequentsTitle` (texte `titleSmall` `on-surface-variant`, marge `KadiSpacing.margin`, `IconButton` `Icons.edit_outlined` `on-surface-variant` cible 48 dp, `onPressed` vide mais non nul pour rester un bouton actif, tooltip et TalkBack `StringsFr.modifierLesAjoutsFrequents`), titre annoncé comme en-tête.
- `lib/core/strings/strings_fr.dart` -- `ajoutsFrequents = 'Ajouts fréquents'`, `modifierLesAjoutsFrequents = 'Modifier les ajouts fréquents'` ; `articles(n)` reste si « Cochés » l'utilise.
- Tests : `test/features/liste/add_sheet_test.dart`, `liste_screen_test.dart`, `liste_repository_test.dart` (appels à `groupFrequentsByRoute`).

## Tasks & Acceptance

**Execution:**
- [x] `lib/features/liste/ui/rayon_header.dart`, `liste_screen.dart` + tests -- en-tête sans compteur -- R1.
- [x] `lib/features/liste/state/liste_providers.dart`, `add_sheet.dart`, `add_sheet_rows.dart`, `strings_fr.dart` + tests -- « Ajouts fréquents », liste plate, crayon sans action -- R6, R7.

**Acceptance Criteria:**
- Given le Panneau + ouvert sans saisie, when Antoine regarde sous le champ, then il voit « Ajouts fréquents » et un crayon, puis les fréquents en une seule liste sans en-tête de rayon.
- Given la Liste avec des articles, when il la regarde, then les en-têtes de rayon n'ont pas de chiffre et « Cochés (n) » garde le sien.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 0 findings — high 0, medium 0, low 0, false 0, maybe-false 0
- findings: aucune ; la revue confirme les deux critères d'acceptation et la couverture de chaque ligne de la matrice.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous verts

## Auto Run Result

Status: built

- **Visible sur le téléphone :** au Panneau +, sans saisie, le titre « Ajouts fréquents » avec un crayon à droite (sans action jusqu'à l'epic 3), puis les fréquents en une seule liste dans l'ordre du parcours, sans en-tête ni libellé de rayon ; dans la Liste, les en-têtes de rayon n'ont plus de chiffre, « Cochés (n) » garde le sien.
- **Fichiers :** `rayon_header.dart`, `liste_screen.dart` (sans compteur) ; `liste_providers.dart` (`frequentsInRouteProvider`, `frequentsInRoute`, retrait de `FrequentGroup` et de `RayonGroup.count`) ; `add_sheet.dart`, `add_sheet_rows.dart` (`FrequentsTitle`) ; `strings_fr.dart` ; tests.
- **Revue :** 0 correction, 0 reporté, 0 rejeté.
- **Revue de suivi recommandée :** non.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 299/299.
- **Risques résiduels :** le titre défile avec les fréquents (il n'est pas fixe) ; rien vérifié sur téléphone.
