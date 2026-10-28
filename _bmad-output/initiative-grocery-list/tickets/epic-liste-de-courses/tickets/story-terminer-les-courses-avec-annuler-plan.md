---
title: 'Terminer les courses, avec Annuler'
type: 'feature'
ticket: '5'
created: '2026-10-28'
status: 'built'
baseline_revision: '4350d2a015c806f47c0333e9f302cf16191a763c'
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

**Problem:** Quand tout est coché, la Liste reste pleine : rien ne permet de la vider (R4), et il n'existe aucun mécanisme Annuler, alors que les stories 6 et 7 en ont besoin.

**Approach:** Poser le service Annuler d'AD-10 dans `lib/core/undo/` (un seul emplacement, état d'avant de chaque ligne touchée, restauré dans une transaction) avec un snackbar réutilisable, puis l'action transverse Terminer les courses d'AD-3 dans `lib/app/actions/`, déclenchée par un Bouton d'action qui n'apparaît que quand tout est coché.

## Boundaries & Constraints

**Always:** l'action vide la liste dans une seule transaction Drift : toutes les lignes actives (cochées ou non) et leurs contributions actives prennent `deleted_at` (suppression logique, AD-7) ; seul `ListeRepository` écrit `list_lines` et `list_contributions` (AD-2), seul le service Undo réécrit l'état d'avant ; toute écriture horodatée par `Clock.stamp` ; Annuler réécrit l'état d'avant avec un `updated_at` neuf, et une ligne créée par l'action est supprimée logiquement ; un seul emplacement, vidé par toute autre écriture, par la fin du snackbar et par un nouveau snackbar Annuler ; Annuler restaure la liste telle quelle (lignes, quantités, cochées et ordre) ; textes dans `strings_fr.dart` ; Material par `package:material_ui/material_ui.dart`.

**Never:** pas de remise à zéro de la sélection de la semaine (epic 2, la table n'existe pas encore) ; pas de Nouvelle liste ; pas de vidage automatique ; pas d'Annuler sur la coche ; pas de dialogue de confirmation ; pas de migration de schéma.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Terminer | Tomates 500 g et Riz cochées, une ligne Lait déjà supprimée | les 2 lignes actives et leurs contributions actives supprimées logiquement ; `watchUnchecked` et `watchChecked` vides ; Lait inchangée | — |
| Annuler | juste après Terminer | lignes et contributions de nouveau actives, `checked_at`, `added_at`, quantités identiques, `updated_at` neufs (> ceux de l'action) ; Lait reste supprimée ; `undo` rend `true` | — |
| Liste vide | aucune ligne active | rien n'est écrit, rien n'est mis dans l'emplacement ; l'action rend `null` | — |
| Écriture entre-temps | Terminer, puis `addArticle(Tomates)` | `undo` rend `false`, rien n'est restauré, la nouvelle ligne Tomates reste seule | — |
| Fin du snackbar | Terminer, puis `clear(entrée)` | `undo` rend `false` | — |
| Nouvelle action | entrée A, puis entrée B enregistrée | `undo(A)` rend `false` ; `clear(A)` ne vide pas B ; `undo(B)` fonctionne | — |
| Ligne créée par l'action | entrée avec une ligne « absente » avant l'action | Annuler la supprime logiquement | — |
| Échec d'écriture | la transaction de l'action ou d'Annuler lève | rien n'est écrit (transaction annulée) | snackbar d'erreur |

</intent-contract>

## Code Map

- `lib/core/clock/clock.dart` -- `Clock.stamp`, `_last` (dernier horodatage émis) : exposer `int get last` ; toute écriture de l'app passe par `stamp`, c'est le témoin « une autre écriture a eu lieu ».
- `lib/core/db/db_providers.dart` -- `databaseProvider`, `clockProvider` : modèle pour `undoProvider`.
- `lib/core/db/tables/sync_columns.dart` -- colonnes `id`, `updated_at`, `deleted_at` communes à toutes les tables (noms SQL utilisés par la restauration générique).
- `lib/features/liste/data/liste_repository.dart` -- `ListeRepository` (transactions, `_clock.stamp(ancien)`, `check`/`uncheck` de la story 4) : ajouter `clearList()`.
- `lib/features/liste/state/liste_providers.dart` -- `listeRepositoryProvider`, `listeGroupsProvider`, `listeCheckedProvider`.
- `lib/features/liste/ui/liste_screen.dart` -- `Scaffold` de la Liste (FAB +, `ListView` des groupes puis `CheckedSection`) : y placer le Bouton d'action dans `bottomNavigationBar` du `Scaffold`, pour que le FAB et le snackbar remontent au-dessus.
- `lib/features/liste/ui/add_sheet.dart` -- montre déjà un snackbar d'erreur (`ScaffoldMessenger`, `StringsFr.ajoutImpossible`) : modèle.
- `lib/core/theme/kadi_theme.dart` -- `snackBarTheme` déjà conforme (fond `onSurface`, action argile du thème opposé) ; ajouter un `filledButtonTheme` pour le Bouton d'action (fond `primary`, texte `onPrimary`, `labelLarge`, hauteur 48 dp, `KadiRadius.full`).
- `lib/app/` -- `kadi_app.dart`, `startup.dart` ; créer `lib/app/actions/` (AD-3). `features/liste` peut importer `app/actions` ; `core` n'importe aucune fonctionnalité (`test/architecture/imports_test.dart`).
- Tests : `test/helpers/test_db.dart` (`seededDatabase`, `SeedIds`), `test/features/liste/liste_repository_test.dart`, `test/features/liste/liste_screen_test.dart` (`_pumpApp`, `_tapBox`, `_pumpWithTomatesCourgettes`).
- Flutter 3.47.8 : `SnackBar(persist:)` vaut `true` par défaut dès qu'il y a une action ; passer `persist: false` pour la durée M3 par défaut (4 s), Flutter garde le snackbar tant que la navigation accessible est active.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/clock/clock.dart` -- `int get last` -- témoin d'écriture d'AD-10.
- [x] `lib/core/undo/undo.dart` -- `UndoRow`, `UndoEntry`, service `Undo` et `undoProvider` selon Design Notes -- AD-10.
- [x] `lib/core/undo/undo_snackbar.dart` -- `showUndoSnackBar(context, message, entry)` réutilisable par les stories 6 et 7 -- AD-10.
- [x] `lib/core/strings/strings_fr.dart` -- `terminerLesCourses` « Terminer les courses », `coursesTerminees` « Courses terminées. Bon appétit ! », `annuler` « Annuler », `terminerImpossible` « Impossible de terminer les courses. Réessaie. », `annulationImpossible` « Annulation impossible. Réessaie. » -- Textes.
- [x] `lib/core/theme/kadi_theme.dart` -- `filledButtonTheme` du Bouton d'action -- DESIGN `action-button`.
- [x] `lib/features/liste/data/liste_repository.dart` -- `Future<List<UndoRow>> clearList()` : à appeler dans une transaction ; supprime logiquement les lignes actives et leurs contributions actives, rend leur état d'avant -- AD-2, AD-10.
- [x] `lib/app/actions/terminer_les_courses.dart` -- action `TerminerLesCourses` + provider : transaction autour de `clearList()`, puis `undo.record(...)` après validation ; rend l'entrée, ou `null` si rien n'a été vidé -- AD-3.
- [x] `lib/features/liste/ui/liste_screen.dart` -- Bouton d'action « Terminer les courses » pleine largeur (marges `KadiSpacing.margin`) quand il n'y a aucune ligne non cochée et au moins une cochée ; au tap, l'action puis `showUndoSnackBar` ; snackbar d'erreur en cas d'échec -- R4.
- [x] `test/core/undo_test.dart` -- lignes Annuler, Écriture entre-temps, Fin du snackbar, Nouvelle action, Ligne créée par l'action, échec d'Annuler -- AD-10.
- [x] `test/app/terminer_les_courses_test.dart` -- lignes Terminer, Annuler, Liste vide, échec de l'action -- AD-3.
- [x] `test/features/liste/liste_screen_test.dart` -- tests de widget des critères ci-dessous -- vérification du ticket.

**Acceptance Criteria:**
- Given Tomates et Courgettes dans la liste, when une seule est cochée, then aucun bouton « Terminer les courses » ; when les deux sont cochées, then le bouton apparaît en bas de la Liste, au-dessus de la Barre de navigation, et TalkBack l'annonce comme bouton « Terminer les courses ».
- Given tout coché, when Antoine touche « Terminer les courses », then la Liste affiche « Ta liste est vide… », le bouton disparaît et un snackbar montre « Courses terminées. Bon appétit ! » avec l'action « Annuler ».
- Given ce snackbar, when Antoine touche « Annuler », then la Liste revient telle quelle : « Cochés (2) » repliée, Tomates 500 g et Courgettes dedans, le bouton « Terminer les courses » de nouveau visible.
- Given le snackbar fermé à la fin de sa durée, then plus rien ne peut restaurer la liste vidée.

## Implementation Notes

- `UndoRow.before` lit l'état d'avant par `toColumns(false)`, pas `toColumns(true)` : sur une classe de données drift, `true` omet les colonnes nulles, et Annuler ne remettait alors ni `deleted_at` ni `checked_at` à nul.
- La restauration est un `INSERT … ON CONFLICT(id) DO UPDATE` en SQL (`customInsert`, `updates: {table}`), pas `into(table).insertOnConflictUpdate` : l'insertion typée de drift omet aussi les nulles d'une classe de données, et refuse un `RawValuesInsertable<dynamic>` (contrôle de type de `validateIntegrity`) dès que la table est vue comme `TableInfo<Table, dynamic>`.
- `clearList` prend un seul horodatage, `Clock.stamp(max des anciens updated_at)`, pour toutes les lignes et contributions vidées.
- La Liste a son propre `ScaffoldMessenger` (un `Builder` donne un contexte sous lui, qui reste monté quand le Bouton d'action disparaît) : snackbars Annuler et d'erreur dans le Scaffold de la Liste, au-dessus du Bouton d'action ; le snackbar Annuler est flottant pour se poser au-dessus du FAB + (DESIGN `undo-snackbar`).
- `annulationImpossible` vaut « Annulation impossible. » : l'emplacement est déjà vidé, rien à retenter.
- Test de widget « fin du snackbar » : `undoProvider` remplacé par un espion qui garde la dernière entrée ; l'API du service reste celle des Design Notes.

## Plan Change Log

## Review Triage Log

### 2026-10-28 — Review pass
- verdicts: 7 findings — high 0, medium 1, low 6, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Le snackbar Annuler s'affiche dans le `Scaffold` de la coque et couvre le FAB + (DESIGN : « Au-dessus du FAB »), au moment où + est la seule action — corrigé : la Liste a son propre `ScaffoldMessenger` (contexte d'un `Builder` sous lui), le snackbar Annuler est flottant au-dessus du FAB ; test de position ajouté.
  - `[low]` `[patch]` En cas d'échec, le snackbar « Impossible de terminer… Réessaie. » couvre le bouton à réessayer — même cause, même correction ; test de position ajouté.
  - `[low]` `[patch]` « Annulation impossible. Réessaie. » invite à un nouvel essai impossible (emplacement déjà vidé, snackbar fermé) — texte ramené à « Annulation impossible. ».
  - `[low]` `[reject]` `lib/app/actions/terminer_les_courses.dart` importe `features/liste/state` (le schéma du spine ne trace que `ACT --> DATA`) — `listeRepositoryProvider` est l'unique point de construction du repository ; le dupliquer dans l'action créerait une seconde source, sans dommage nommé à éviter.
  - `[low]` `[patch]` Le test « Annuler juste après Terminer » ne vérifie pas les `updated_at` neufs des contributions — assertion ajoutée.
  - `[low]` `[patch]` La ligne « Écriture entre-temps » de la matrice n'était pas testée telle quelle — test réécrit : Terminer, `addArticle(Tomates)`, `undo` rend `false`, seule la nouvelle ligne Tomates est active.
  - `[low]` `[patch]` Aucun test d'interface pour l'échec d'Annuler — test de widget ajouté (déclencheur SQLite) : « Annulation impossible. » s'affiche.

## Design Notes

Service `Undo` (`core/undo`, sans dépendance aux fonctionnalités) :

```dart
class UndoRow { UndoRow.before(table, Insertable row); UndoRow.absent(table, String id); }
class UndoEntry { /* lignes + Clock.last au moment de l'enregistrement */ }
class Undo {
  UndoEntry record(List<UndoRow> rows); // remplace l'emplacement
  Future<bool> undo(UndoEntry e);        // false si e n'est plus l'emplacement ou si Clock.last a bougé
  void clear([UndoEntry? e]);            // ne vide que si e est l'emplacement (ou sans e)
}
```

`undo` vide l'emplacement de façon synchrone avant d'écrire, puis, dans une transaction, réécrit chaque ligne : état d'avant par `into(table).insertOnConflictUpdate` sur ses colonnes (`toColumns(true)`) avec `updated_at` remplacé par `_clock.stamp()` ; ligne absente par `deleted_at` et `updated_at` neufs (une requête avec `updates: {table}` pour notifier les flux). Un échec lève et n'écrit rien.

`showUndoSnackBar` : `hideCurrentSnackBar()` puis `showSnackBar(SnackBar(content, action: Annuler, persist: false))` ; `closed` → `undo.clear(entry)` (jamais l'emplacement d'une action plus récente) ; Annuler → `undo.undo(entry)`, snackbar `annulationImpossible` s'il lève. Un Annuler devenu sans effet (autre écriture entre-temps) ne fait rien.

Le service n'a pas de témoin des écritures autre que `Clock.last` : toute écriture de l'app prend son horodatage par `Clock.stamp` (AD-7), y compris celles d'Annuler, ce qui vide aussi l'emplacement.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent, dont les 123 existants avant la story

## Auto Run Result

Status: built

- **Résumé :** quand tout est coché, un Bouton d'action « Terminer les courses » pleine largeur apparaît en bas de la Liste, le FAB + remontant au-dessus. Il vide la liste (lignes et contributions supprimées logiquement, une transaction, action `lib/app/actions/`) et affiche « Courses terminées. Bon appétit ! » avec « Annuler », qui restaure la liste telle quelle. Le service Annuler d'AD-10 (`lib/core/undo/`) a un seul emplacement, vidé par toute autre écriture (témoin `Clock.last`), par la fin du snackbar et par un nouveau snackbar ; `showUndoSnackBar` est prêt pour les stories 6 et 7.
- **Fichiers :**
  - `lib/core/clock/clock.dart` — `last`, témoin d'écriture.
  - `lib/core/undo/undo.dart` — `UndoRow`, `UndoEntry`, service `Undo`, `undoProvider` (restauration SQL générique, colonnes nulles comprises).
  - `lib/core/undo/undo_snackbar.dart` — snackbar Annuler réutilisable, flottant au-dessus du FAB.
  - `lib/core/strings/strings_fr.dart` — textes du bouton, du snackbar et des erreurs.
  - `lib/core/theme/kadi_theme.dart` — `filledButtonTheme` du Bouton d'action.
  - `lib/features/liste/data/liste_repository.dart` — `clearList()`.
  - `lib/app/actions/terminer_les_courses.dart` — action transverse et provider.
  - `lib/features/liste/ui/liste_screen.dart` — bouton, `ScaffoldMessenger` propre à la Liste, snackbars.
  - Tests : `test/core/undo_test.dart`, `test/app/terminer_les_courses_test.dart`, `test/features/liste/liste_screen_test.dart`.
- **Revue :** 6 corrections appliquées (1 medium, 5 low), 0 reporté, 1 rejeté (import de `features/liste/state` par l'action : seul point de construction du repository) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — une seule correction medium, aucune high.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 140/140 après corrections.
- **Risques résiduels :** remise à zéro de la sélection de la semaine à ajouter par l'epic 2 dans la même action ; un Annuler devenu sans effet (autre écriture entre-temps) ne dit rien ; position et lecture TalkBack du snackbar non vérifiées sur téléphone (test de fin d'epic).
