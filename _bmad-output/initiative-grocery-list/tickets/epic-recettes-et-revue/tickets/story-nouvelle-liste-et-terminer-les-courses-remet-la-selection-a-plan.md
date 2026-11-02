---
title: 'Nouvelle liste, et Terminer les courses remet la sélection à zéro'
type: 'feature'
ticket: '4'
created: '2026-11-02'
status: 'built'
baseline_revision: 'a4198ee0e7f2d458ee0fda4b04355845be3c86dd'
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
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-deselectionner-une-recette-validee-retire-ses-quantites-avec-annuler-plan.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** La sélection de la semaine ne se remet jamais à zéro : Terminer les courses (epic 1) ne vide que la liste, et Recettes n'a pas d'action Nouvelle liste (R8, R10).

**Approach:** Une action transverse Nouvelle liste (AD-3), lancée par une action texte de la Barre d'application de Recettes après un Dialogue de confirmation, qui efface toutes les lignes et toutes les sélections ; Terminer les courses supprime aussi les sélections dans sa transaction, et son Annuler les restaure avec la liste.

## Boundaries & Constraints

**Always:**
- Action Nouvelle liste (DESIGN `action-nouvelle-liste`) : action texte « Nouvelle liste » dans la Barre d'application de Recettes, `label-large` `on-surface`, jamais d'argile, cible ≥ 48 dp, lue « Nouvelle liste » par TalkBack ; toujours visible.
- Dialogue de confirmation (DESIGN `confirm-dialog`, EXPERIENCE Voice and Tone) : titre « Nouvelle liste ? », texte « La liste en cours et la sélection de la semaine seront effacées. », actions « Garder » (repli : `on-surface` ; retour Android et tap hors du dialogue valent « Garder ») et « Effacer et recommencer » (destructive, `error`). Seule action confirmée de l'app (C9) : pas de snackbar Annuler ensuite.
- Confirmée : une transaction (AD-3) supprime logiquement toutes les lignes actives, cochées ou non, et leurs contributions (`ListeRepository.clearList` existant), et toutes les sélections actives, validées ou non (AD-16). « Garder » n'écrit rien.
- Terminer les courses : dans la même transaction que `clearList`, toutes les sélections actives sont supprimées logiquement, et leur état d'avant rejoint les `UndoRow` de l'entrée Annuler ; Annuler rend liste et sélection exactement. Le reste de Terminer les courses (apparition, texte, snackbar) ne change pas.
- Les sélections sont écrites par `RecettesRepository` seul (AD-2), avec l'horloge (AD-7) ; `features/liste` n'importe jamais `features/recettes` (l'action vit dans `lib/app/actions/`).

**Never:**
- Supprimer des recettes, toucher la Fiche recette (story 5) ou ajouter l'icône ⚙ (epic 3).
- Un Annuler pour Nouvelle liste.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Effacer | 2 recettes validées, 1 sélectionnée non validée, liste en partie cochée | Liste vide, aucune carte sélectionnée, pas de « Valider » | Échec : rien d'écrit, snackbar d'erreur sur Recettes |
| Garder | Même état | Rien ne change | — |
| Retour / tap dehors | Dialogue ouvert | Comme Garder | — |
| Déjà vide | Liste vide, aucune sélection | Dialogue puis rien à écrire, pas d'erreur | — |
| Terminer | Tout coché, 2 recettes validées | Liste vide, cartes désélectionnées, « Courses terminées. Bon appétit ! » | Échec : rien d'écrit (comportement existant) |
| Annuler Terminer | Juste après | Lignes cochées et cartes sélectionnées (validées) exactement comme avant | Autre écriture entre-temps : sans effet (AD-10) |

</intent-contract>

## Code Map

- `lib/app/actions/terminer_les_courses.dart` -- ajouter `RecettesRepository` : sélections supprimées dans la transaction de `clearList`, leurs `UndoRow` ajoutés ; rendre `null` seulement si rien n'a été écrit. Mettre à jour le commentaire « L'epic 2 y ajoutera… ».
- `lib/app/actions/` -- nouvelle action Nouvelle liste (modèle `terminer_les_courses.dart`), sans Annuler.
- `lib/features/recettes/data/recettes_repository.dart` -- nouvelle méthode, à appeler dans la transaction d'une action, qui supprime logiquement toutes les sélections actives et rend leur `UndoRow.before` (modèle `deselectValidated` et `ListeRepository.clearList` : un horodatage postérieur à chaque ancien `updated_at`).
- `lib/features/recettes/ui/recettes_screen.dart` -- action texte dans `AppBar.actions`, dialogue (`showDialog` sur le navigateur racine), erreurs sous le messager propre à Recettes (déjà en place).
- `lib/core/strings/strings_fr.dart` -- « Nouvelle liste », « Nouvelle liste ? », le texte, « Garder », « Effacer et recommencer », un message d'échec.
- `lib/features/liste/ui/liste_screen.dart` -- ne pas modifier (Terminer s'appelle déjà par son provider).
- Tests : `test/app/terminer_les_courses_test.dart` (sélections supprimées, Annuler les rend, instantané), un test de l'action Nouvelle liste dans `test/app/`, `test/features/recettes/recettes_repository_test.dart`, `test/features/recettes/recettes_screen_test.dart` (dialogue, Garder, retour, Effacer, TalkBack, police ×2), et un test d'écran Liste → Recettes pour Terminer + Annuler.

## Tasks & Acceptance

**Execution:**
- [x] `recettes_repository.dart` + test -- suppression de toutes les sélections avec état d'avant
- [x] `terminer_les_courses.dart` + test -- sélections dans la transaction et dans Annuler
- [x] action Nouvelle liste + test -- matrice
- [x] `recettes_screen.dart`, `strings_fr.dart` + tests d'écran -- action texte, dialogue, TalkBack

**Acceptance Criteria:**
- Given deux recettes validées et une liste en partie cochée, when Antoine touche « Nouvelle liste » puis « Effacer et recommencer », then la Liste affiche son message de liste vide et aucune carte n'est sélectionnée.
- Given le dialogue ouvert, when il touche « Garder » ou le retour, then la liste et les cartes sont inchangées.
- Given deux recettes validées et tout coché, when il touche « Terminer les courses », then la liste se vide et les cartes sont désélectionnées ; when il touche « Annuler », then les lignes cochées reviennent et les deux cartes sont de nouveau sélectionnées sans « Valider ».

## Implementation Notes

- Implémenté par un sous-agent : `RecettesRepository.clearSelections` (toutes les sélections actives, un horodatage, `UndoRow.before`), `TerminerLesCourses` reçoit `RecettesRepository` et ajoute ses `UndoRow` dans la même transaction que `clearList`, action `lib/app/actions/nouvelle_liste.dart` (`nouvelleListeProvider`), action texte et `_NouvelleListeDialog` dans `recettes_screen.dart`, chaînes dans `strings_fr.dart` (échec : « Impossible d’effacer la liste. Réessaie. »).
- Nouvelle liste vide l'emplacement Annuler après sa transaction (même sans rien écrire) : un Annuler de Terminer les courses encore affiché ne rend plus ce qui vient d'être effacé ; le snackbar courant de Recettes est masqué.
- Police agrandie : l'action est bornée à la moitié de la largeur et son texte réduit (`FittedBox` `scaleDown`) seulement s'il n'y tient pas ; sans cela, la Barre d'application débordait à ×2 et ×3 sur 360 dp (le titre de l'AppBar plafonne déjà sa police).
- Le dialogue fixe lui-même ses couleurs (`surface-container`, `xl`, `on-surface` / `error`) : pas de `dialogTheme` ajouté au thème.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 3, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` Après Terminer puis Nouvelle liste depuis Recettes, le snackbar « Courses terminées » figé sous l'onglet Liste montre un « Annuler » sans effet — aucune donnée fausse (AD-10 admet un Annuler sans effet) et la séquence est rare ; vider le messager de la Liste depuis Recettes demanderait un signal de plus entre fonctionnalités.
  - `[low]` `[reject]` « Nouvelle liste » se réduit sous la taille de police système à ×2 sur 360 dp pour tenir dans la Barre d'application — compromis contre le débordement, police par défaut d'Antoine ; à juger au test de fin d'epic.
  - `[low]` `[patch]` « Nouvelle liste ? » avec une espace ordinaire : le « ? » peut passer seul à la ligne — corrigé par une espace insécable dans `strings_fr.dart` (appliqué directement, une ligne).

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : action texte « Nouvelle liste » dans la Barre d'application de Recettes, dialogue « Nouvelle liste ? » (Garder / Effacer et recommencer) qui efface liste et sélection sans Annuler ; Terminer les courses remet aussi la sélection à zéro, et Annuler rend les deux.
- Fichiers : `recettes_repository.dart` (`clearSelections`), `terminer_les_courses.dart`, `nouvelle_liste.dart` (nouveau), `recettes_screen.dart`, `strings_fr.dart` ; tests `nouvelle_liste_test.dart`, `terminer_les_courses_test.dart`, `recettes_repository_test.dart`, `recettes_screen_test.dart`, `undo_test.dart`.
- Revue : 1 correctif (low, espace insécable), 0 report, 2 rejets motivés.
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 539/539.
- Risques : texte de l'action réduit en très grande police ; un « Annuler » de la Liste peut rester affiché sans effet après Nouvelle liste.
