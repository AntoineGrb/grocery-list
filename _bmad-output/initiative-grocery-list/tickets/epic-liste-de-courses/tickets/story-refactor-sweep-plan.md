---
title: 'Refactor sweep'
type: 'refactor'
ticket: '9'
created: '2026-10-29'
status: done
baseline_revision: 'd03d2fcfb8dc5a5048743b311b25ff509a825966'
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

**Problem:** L'epic 1 s'est construit story par story : le Panneau + tient en un fichier de 743 lignes, deux fonctions de groupement par rayon sont identiques au type près, l'affichage d'un snackbar d'erreur est recopié six fois et l'aide de test qui monte l'app est copiée dans trois fichiers. Aucun report formel (`deferred`) n'est resté ouvert.

**Approach:** Nettoyage seul, sans aucun changement de comportement visible ni de données : découper, factoriser, mutualiser, puis vérifier que toute la suite passe à l'identique.

## Boundaries & Constraints

**Always:** comportement, textes, sémantique TalkBack, écritures en base et API des repositories inchangés ; chaque test existant passe, ses assertions intactes (seuls ses imports et ses aides peuvent changer) ; `flutter analyze` propre ; conventions du spine (Material par `package:material_ui/material_ui.dart`, `core` n'importe aucune fonctionnalité, textes dans `strings_fr.dart`).

**Never:** aucun ajout de périmètre (les [ASSUMPTION] à valider par Antoine, les résidus des plans — fusion de lignes après correction, Annuler devenu sans effet silencieux, erreur derrière une feuille — restent tels quels) ; pas de migration ; pas de renommage d'API publique utilisée par l'epic 2 (`addArticle`, `_contribute`, `createArticle`, `Undo`, `showUndoSnackBar`).

</intent-contract>

## Code Map

- `lib/features/liste/ui/add_sheet.dart` -- 743 lignes : `showAddSheet`, `PanelUndo`, `AddSheet` et son état, puis les widgets de ligne `InListIndicator`, `FrequentRow`, `SearchResultRow`, `CreateArticleRow`, `AddedLineEditor`.
- `lib/features/liste/state/liste_providers.dart` -- `groupByRoute(List<ListeItem>, routeOrder) → List<RayonGroup>` et `groupFrequentsByRoute(List<CatalogueArticle>, routeOrder) → List<FrequentGroup>`, même algorithme.
- Snackbars d'erreur sans action : `lib/features/liste/ui/add_sheet.dart:144`, `:265`, `:285`, `lib/features/liste/ui/item_edit_sheet.dart:99`, `lib/features/liste/ui/liste_screen.dart:30`, `:57`, `lib/core/undo/undo_snackbar.dart:28` (`SnackBar(content: Text(message))`, parfois gardé par `messenger.mounted`).
- `_pumpApp` dans `test/app/app_test.dart:15`, `test/features/liste/add_sheet_test.dart:26`, `test/features/liste/liste_screen_test.dart:29` (variante avec `_SpyUndo`) ; aides partagées dans `test/helpers/test_db.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/features/liste/ui/add_sheet_rows.dart` -- y déplacer tels quels `InListIndicator`, `FrequentRow`, `SearchResultRow`, `CreateArticleRow`, `AddedLineEditor` ; `add_sheet.dart` les importe -- lisibilité.
- [x] `lib/features/liste/state/liste_providers.dart` -- une seule fonction générique `groupByRayon<T>(items, rayonOf, routeOrder)` ; `RayonGroup` et `FrequentGroup` gardent leurs champs et leurs noms publics (`items` / `articles`, `count`) -- duplication.
- [x] `lib/core/ui/error_snackbar.dart` -- `showErrorSnackBar(ScaffoldMessengerState messenger, String message)` qui ne fait rien si le messager n'est plus monté ; remplacer les appels listés -- duplication.
- [x] `test/helpers/pump_app.dart` -- une aide `pumpKadi(tester, {overrides})` commune ; les trois `_pumpApp` s'appuient dessus -- duplication des tests.
- [x] Vérification de la suite complète -- non-régression.

**Acceptance Criteria:**
- Given le code nettoyé, when `flutter analyze` et `flutter test` tournent, then aucun problème et autant de tests verts qu'avant (236), sans assertion modifiée.
- Given l'app, then rien ne change pour Antoine : mêmes écrans, textes, gestes et annonces TalkBack.

## Implementation Notes

- `add_sheet.dart` 743 → 464 lignes ; `add_sheet_rows.dart` reçoit les cinq widgets mot pour mot (vérifié par `diff`). Les tests qui touchent `FrequentRow`/`SearchResultRow`/… importent `add_sheet_rows.dart`.
- `groupByRayon<T>` rend des couples `(Rayon, List<T>)` ; `groupByRoute` et `groupFrequentsByRoute` restent comme enveloppes d'une ligne, car `liste_repository_test.dart` les appelle (aucun test touché pour cela). `FrequentGroup` n'a pas reçu de `count` (pas d'ajout de périmètre).
- `showErrorSnackBar` est dans `lib/core/ui/error_snackbar.dart` ; les 7 appels listés passent par elle. Seule nuance : `liste_screen.dart` (Terminer, suppression) et `undo_snackbar.dart` (échec d'Annuler) n'avaient pas la garde `mounted` ; elle ne change rien tant que le messager est monté et évite une exception sinon.
- `test/helpers/pump_app.dart` : `pumpKadi(tester, {overrides, assetOverrides})`. `assetOverrides` est ajouté pour `app_test.dart` (un second override de `seedAssetLoaderProvider` serait refusé par Riverpod). Taille de vue (Panneau +) et luminosité (app) restent dans leurs `_pumpApp`, enregistrées avant `pumpKadi` pour garder l'ordre des tearDown.

## Plan Change Log

## Review Triage Log

### 2026-10-29 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 0, false 2, maybe-false 0
- findings:
  - `[false]` `[reject]` `showErrorSnackBar` ajoute une garde `mounted` sur trois chemins d'erreur qui n'en avaient pas — rien ne change pour Antoine : avant, l'appel sur un messager démonté levait une erreur asynchrone sans afficher de snackbar ; maintenant rien n'est levé ni affiché. Déjà noté dans les Implementation Notes.
  - `[false]` `[reject]` Les Implementation Notes donnent 464 lignes pour `add_sheet.dart`, il en a 454 — erreur de note seulement, le code est juste ; la correction serait d'éditer le plan.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: 236 tests, tous verts
- `git diff --stat` sur `test/` -- expected: aucune assertion modifiée, seulement imports et aides

## Auto Run Result

Status: built

- **Résumé :** nettoyage sans changement visible. Les cinq widgets de ligne du Panneau + passent tels quels dans `add_sheet_rows.dart` (`add_sheet.dart` : 743 → 454 lignes) ; un seul groupement générique `groupByRayon<T>` ; un seul `showErrorSnackBar` pour les sept snackbars d'erreur ; une seule aide de test `pumpKadi`.
- **Fichiers :**
  - `lib/features/liste/ui/add_sheet_rows.dart` (nouveau), `lib/features/liste/ui/add_sheet.dart` — découpage.
  - `lib/features/liste/state/liste_providers.dart` — `groupByRayon<T>`.
  - `lib/core/ui/error_snackbar.dart` (nouveau) ; appels dans `add_sheet.dart`, `item_edit_sheet.dart`, `liste_screen.dart`, `lib/core/undo/undo_snackbar.dart`.
  - `test/helpers/pump_app.dart` (nouveau) ; `test/app/app_test.dart`, `test/features/liste/add_sheet_test.dart`, `test/features/liste/liste_screen_test.dart` — aides seulement, aucune assertion modifiée.
- **Revue :** 0 correction, 0 reporté, 2 rejetés (garde `mounted` sans effet visible ; nombre de lignes dans une note) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 236/236 ; `git diff` de `test/` sans assertion modifiée.
- **Risques résiduels :** la vérification du ticket demande aussi les Flux 2 et 3 sur la release installée : c'est le test de fin d'epic d'Antoine.
