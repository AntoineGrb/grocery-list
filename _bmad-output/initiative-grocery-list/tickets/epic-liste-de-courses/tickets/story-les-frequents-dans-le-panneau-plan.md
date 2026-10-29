---
title: 'Les fréquents dans le Panneau +'
type: 'feature'
ticket: '7'
created: '2026-10-29'
status: 'built'
baseline_revision: '51fe103811c17257cc9a7d4067a58c535959bc08'
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

**Problem:** Le Panneau + n'a que la recherche : les ~30 fréquents fournis n'y apparaissent pas, un tap ajoute toujours (même un article déjà dans la liste) et rien n'indique ce qui est déjà dans la liste (R6, R7, R11).

**Approach:** Le Panneau + montre, sous le Champ de recherche focalisé, les fréquents groupés par rayon dans l'ordre du parcours, chacun avec son état « dans la liste » calculé (AD-4). Un tap sur un fréquent ou un résultat ajoute l'article, ou le retire de la liste s'il y est déjà, avec le Snackbar Annuler de la story 5. Le panneau reste ouvert ; état vide sans fréquent.

## Boundaries & Constraints

**Always:** « dans la liste » = il existe une ligne active non cochée de l'article (une ligne cochée ou supprimée ne compte pas) ; l'état suit la Liste dans les deux sens (flux Drift) ; retirer = supprimer logiquement toutes les lignes non cochées de l'article et leurs contributions actives, dans une transaction, en enregistrant leur état d'avant dans `Undo` (AD-10), snackbar « Retiré de la liste : Lait » · « Annuler » ; ajouter = `addArticle(articleId)` sans quantité (inchangé) ; fréquents = fréquents actifs d'articles actifs, groupés par le rayon par défaut de l'article dans l'ordre du parcours de `settings`, et dans un rayon par `position` ; seul `CatalogueRepository` lit `frequents`, seul `ListeRepository` écrit la liste ; le panneau reste ouvert après un tap ; les fréquents laissent la place aux résultats dès qu'une recherche est saisie ; les snackbars du panneau s'affichent dans le panneau, visibles au-dessus de lui ; pictos par `Picto` (résolveur à repli neutre) ; textes dans `strings_fr.dart` ; cibles ≥ 48 dp.

**Never:** pas de Champ quantité ni de Choix de rayon après un ajout, pas de « Créer « … » » ni d'état vide sans résultat (story 8) ; pas d'appui long sur un fréquent ; pas de gestion des fréquents ni d'action vers les Paramètres (epic 3) ; l'app n'ajoute jamais de fréquent ; pas de choix du pack de pictos ; pas de migration de schéma.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fréquents | contenu fourni, un fréquent dont l'article est supprimé, un fréquent supprimé | les autres, groupés par rayon dans l'ordre du parcours, par `position` dans un rayon ; les deux exclus | — |
| Aucun fréquent | tous les fréquents supprimés | message « Pas encore de fréquents. Ajoute-les dans les paramètres. », sans action | — |
| Dans la liste | Lait : une ligne non cochée | `inList` contient Lait | — |
| Coché | Lait : seule ligne cochée | Lait n'est pas dans la liste | — |
| Ajouter | tap sur Lait hors liste | une ligne Lait sans quantité sous Crèmerie, l'état passe à « dans la liste » | snackbar `ajoutImpossible` |
| Retirer | Lait dans la liste en g et en pièces, plus une ligne Lait cochée | les deux lignes non cochées et leurs contributions supprimées logiquement, la cochée intacte ; snackbar Annuler | snackbar `suppressionImpossible` |
| Annuler | juste après le retrait | les deux lignes reviennent telles quelles | snackbar `annulationImpossible` |
| Résultat | recherche « lait », Lait dans la liste, tap sur le résultat | Lait retiré, même règle | — |

</intent-contract>

## Code Map

- `lib/features/liste/ui/add_sheet.dart` -- `showAddSheet` (feuille sur le navigateur racine, 0,9 de hauteur), `AddSheet` (champ autofocus, `articleSearchProvider`, `_lastResults` contre le clignotement, `_add` + snackbar `ajoutImpossible` via `ScaffoldMessenger.maybeOf`), `SearchResultRow` (`Semantics(button, label: 'Lait, Crèmerie')`, `Picto`) : y ajouter les fréquents, l'état et la bascule.
- `lib/features/catalogue/data/catalogue_repository.dart` -- `CatalogueArticle` (`id`, `name`, `rayon`, `unit`, `pictoKey`), `_toModel`, `watchSearch` : ajouter `watchFrequents()`. `lib/features/catalogue/state/catalogue_providers.dart` -- `catalogueRepositoryProvider`.
- `lib/core/db/tables/frequents.dart` -- `articleId`, `position` (index dans `assets/seed/frequents.json`, 31 fréquents).
- `lib/features/liste/data/liste_repository.dart` -- `removeLine` (modèle : suppression logique + `UndoRow.before`, `_activeContributions`, `_deleteContributions`, `_latest`), `addArticle` : ajouter `watchInListArticleIds()` et `removeArticle(articleId)`.
- `lib/features/liste/state/liste_providers.dart` -- `groupByRoute` (pour `ListeItem`), `listeGroupsProvider` qui attend `settingsProvider` pour `routeOrder` : modèle du groupement des fréquents.
- `lib/features/liste/ui/liste_screen.dart` -- suppression avec `undo.record` + `showUndoSnackBar` (modèle de la bascule « retirer »).
- `lib/core/undo/undo.dart`, `lib/core/undo/undo_snackbar.dart` -- `Undo.record`, `showUndoSnackBar(context, message, entry)` : le `context` doit être sous le `ScaffoldMessenger` qui affiche dans le panneau.
- `lib/features/liste/ui/rayon_header.dart` -- `RayonHeader(rayon, count: null)` : en-tête sans compteur du Panneau +.
- `lib/core/pictos/picto.dart` -- `Picto(pictoKey, rayon)`, repli neutre. `lib/core/theme/kadi_colors.dart` -- accent du rayon pour la coche.
- `lib/core/strings/strings_fr.dart` -- `retireDeLaListe(name)`, `suppressionImpossible`, `annulationImpossible`, `ajoutImpossible` existent.
- Tests : `test/features/liste/liste_screen_test.dart` (`_pumpApp`), `test/features/catalogue/catalogue_test.dart`, `test/features/liste/liste_repository_test.dart`, `test/helpers/test_db.dart` (`SeedIds.lait` en Crèmerie, fréquent).

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/strings/strings_fr.dart` -- `pasDeFrequents` « Pas encore de fréquents. Ajoute-les dans les paramètres. », `dansLaListe` « dans la liste » -- Voice and Tone.
- [x] `lib/features/catalogue/data/catalogue_repository.dart` -- `watchFrequents()` : `CatalogueArticle` des fréquents actifs d'articles actifs, par `position` -- AD-2.
- [x] `lib/features/catalogue/state/catalogue_providers.dart` -- `frequentsProvider` -- flux du panneau.
- [x] `lib/features/liste/data/liste_repository.dart` -- `watchInListArticleIds() → Stream<Set<String>>`, `removeArticle(articleId) → List<UndoRow>` -- AD-4, AD-10.
- [x] `lib/features/liste/state/liste_providers.dart` -- `inListProvider` ; `frequentGroupsProvider` (fréquents groupés par rayon dans l'ordre du parcours, rayons vides absents) -- R6.
- [x] `lib/features/liste/ui/add_sheet.dart` -- section des fréquents (`RayonHeader` sans compteur, `FrequentRow`), état vide, bascule ajouter / retirer sur fréquents et résultats, snackbars dans le panneau (Design Notes) -- R6, R7, R11, R12.
- [x] `test/features/catalogue/catalogue_test.dart` -- ligne Fréquents de la matrice -- AD-2.
- [x] `test/features/liste/liste_repository_test.dart` -- lignes Dans la liste, Coché, Retirer, Annuler -- AD-4.
- [x] `test/features/liste/add_sheet_test.dart` -- tests de widget des critères ci-dessous et des lignes Aucun fréquent, Ajouter, Résultat -- vérification du ticket.

**Acceptance Criteria:**
- Given le Panneau + ouvert, then le Champ de recherche est focalisé et, dessous, les fréquents sont groupés sous des en-têtes de rayon sans compteur, dans l'ordre du parcours (Fruits & légumes avant Crèmerie), chacun avec Picto, nom et indicateur « + ».
- Given Lait hors liste, when Antoine touche Lait dans les fréquents, then le panneau reste ouvert, la ligne Lait montre la coche à l'accent de Crèmerie, et la Liste montre Lait sous Crèmerie.
- Given Lait dans la liste, when il touche Lait de nouveau, then Lait quitte la Liste, l'indicateur revient à « + » et un snackbar visible dans le panneau montre « Retiré de la liste : Lait » avec « Annuler » ; when il touche « Annuler », then Lait revient dans la Liste et la coche réapparaît.
- Given Lait dans la liste, when Antoine coche Lait dans la Liste puis rouvre le Panneau +, then le fréquent Lait montre « + ».
- Given une recherche « lai », then les fréquents laissent la place aux résultats, et le résultat Lait suit la même règle de bascule.
- Given TalkBack, then un fréquent dans la liste est lu « Lait, dans la liste » et hors liste « Lait » ; un résultat dans la liste « Lait, Crèmerie, dans la liste » ; tous comme boutons.

## Implementation Notes

- `frequentGroupsProvider` est un `FutureProvider` qui attend `settingsProvider.future` et `frequentsProvider.future` : il se recalcule à chaque émission de l'un ou l'autre (vérifié par un test jetable : supprimer tous les fréquents vide les groupes).
- `removeArticle` reprend le modèle de `clearList` (un seul horodatage postérieur à chaque ancien `updated_at`) ; sans ligne non cochée, rien n'est écrit et la liste rendue est vide (pas de snackbar).
- `watchInListArticleIds` ignore aussi les lignes dont l'article est supprimé, comme `watchUnchecked` (AD-7).
- `AddSheet` : `ScaffoldMessenger` + `Scaffold` transparent, contenu sous un `Builder` dont le contexte sert aux snackbars ; les `ref.watch` restent dans `build` de l'état. Un second tap sur un article dont l'écriture est en cours est ignoré (ensemble `_pending`), pour éviter un double ajout sur un état « dans la liste » pas encore à jour.
- Indicateur partagé `InListIndicator` (fréquent et résultat). `SearchResultRow.inList` vaut `false` par défaut.
- Tests de widget du panneau dans une vue de 800 × 3000 dp logiques, pour que les 31 fréquents soient construits sans défilement.
- Correctifs de revue : `showAddSheet` possède un `PanelUndo` (dernier Annuler du panneau) ; à la fermeture du panneau, si `Undo.canUndo(entry)`, le snackbar « Retiré de la liste : … » est remontré sur la Liste, sinon l'emplacement est vidé ; le holder est vidé quand le snackbar du panneau se ferme normalement. `showUndoSnackBar` rend son contrôleur. Snackbars d'erreur seulement si le messager du panneau est encore monté. Un tap est ignoré tant que l'état « dans la liste » n'est pas connu.
- `flutter analyze` : aucun problème ; `flutter test` : 196 tests attendus (173 + 23).

## Plan Change Log

## Review Triage Log

### 2026-10-29 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Fermer le Panneau + pendant le snackbar Annuler le fait disparaître avec le messager du panneau : le retrait ne peut plus être annulé et l'emplacement Undo n'est jamais vidé (AD-10) — corrigé : `showAddSheet` garde la dernière entrée (`PanelUndo`) et, à la fermeture, la remontre sur la Liste si `Undo.canUndo(entry)`, sinon vide l'emplacement ; `showUndoSnackBar` rend son contrôleur ; deux tests ajoutés.
  - `[low]` `[patch]` Un snackbar d'erreur après fermeture du panneau s'affichait sur un messager démonté (exception) — garde `messenger.mounted`.
  - `[low]` `[reject]` Un second tap entre la fin de l'écriture et la réémission du flux `inListProvider` lit l'ancien état et ajoute au lieu de retirer — fenêtre de quelques millisecondes (requête Drift locale), bien plus courte qu'un double tap humain ; la corriger demande de suivre chaque émission par article.
  - `[low]` `[patch]` Avant la première valeur de `inListProvider`, un tap était traité comme « hors liste » — le tap est ignoré tant que l'état est inconnu.

## Design Notes

Snackbars dans le panneau : la feuille vit sur le navigateur racine, au-dessus du `Scaffold` de la Liste ; un snackbar envoyé au messager de la Liste ou à celui de l'app resterait sous la barrière. Envelopper le contenu du Panneau + dans son propre `ScaffoldMessenger` + `Scaffold` transparent (fond de la feuille conservé), et prendre le contexte des snackbars sous lui. Le `Scaffold` gère la marge du clavier (`resizeToAvoidBottomInset`), à la place du `Padding` actuel sur `viewInsets`.

Bascule : l'état vient de `inListProvider` au moment du tap ; dans la liste → `removeArticle` dans sa transaction, `undo.record(rows)` si non vide, `showUndoSnackBar(… retireDeLaListe(name) …)` ; sinon `addArticle(id)`. Un échec montre `ajoutImpossible` ou `suppressionImpossible`.

`FrequentRow` : `InkWell` pleine largeur, hauteur ≥ 48 dp, `Picto`, nom en `bodyLarge`, indicateur à droite : `Icons.check` à l'accent du rayon dans la liste, `Icons.add` en `onSurfaceVariant` hors liste. `SearchResultRow` garde nom et rayon, et prend le même indicateur à droite **[ASSUMPTION]** (DESIGN ne le montre que sur le fréquent, mais un tap qui retire doit se voir avant d'être fait). Libellé TalkBack hors liste : le nom seul **[ASSUMPTION]** (EXPERIENCE ne fixe que « Lait, dans la liste »).

Groupement : le rayon d'un fréquent est le rayon par défaut de son article (le Panneau + montre le catalogue, pas les lignes) ; ordre du parcours depuis `settingsProvider`, comme `listeGroupsProvider`.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent, dont les 173 existants avant la story

## Auto Run Result

Status: built

- **Résumé :** le Panneau + s'ouvre champ focalisé sur les 31 fréquents, groupés sous des en-têtes de rayon sans compteur dans l'ordre du parcours, chacun avec Picto (repli neutre), nom et indicateur (« + » hors liste, coche à l'accent du rayon dans la liste). Un tap sur un fréquent ou un résultat ajoute l'article, ou retire toutes ses lignes non cochées avec le snackbar « Retiré de la liste : Lait » · « Annuler », affiché dans le panneau puis remontré sur la Liste si le panneau est fermé avant sa fin. « Dans la liste » se calcule sur les lignes non cochées et suit la Liste dans les deux sens. État vide « Pas encore de fréquents… ».
- **Fichiers :**
  - `lib/features/catalogue/data/catalogue_repository.dart`, `state/catalogue_providers.dart` — `watchFrequents`, `frequentsProvider`.
  - `lib/features/liste/data/liste_repository.dart` — `watchInListArticleIds`, `removeArticle`.
  - `lib/features/liste/state/liste_providers.dart` — `inListProvider`, `frequentGroupsProvider`.
  - `lib/features/liste/ui/add_sheet.dart` — fréquents, indicateur, bascule, messager propre au panneau, `PanelUndo`.
  - `lib/core/undo/undo.dart`, `undo_snackbar.dart` — `canUndo`, contrôleur rendu.
  - `lib/core/strings/strings_fr.dart` — textes.
  - Tests : `test/features/catalogue/catalogue_test.dart`, `test/features/liste/liste_repository_test.dart`, `test/features/liste/add_sheet_test.dart` (nouveau), `test/features/liste/liste_screen_test.dart`.
- **Revue :** 3 corrections appliquées (1 medium, 2 low), 0 reporté, 1 rejeté (course de quelques millisecondes sur un double tap) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — une seule correction medium, aucune high.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 196/196 après corrections.
- **Risques résiduels :** indicateur aussi sur les résultats et libellé TalkBack « Lait » hors liste [ASSUMPTION à valider par Antoine] ; clavier et `Scaffold` du panneau non vérifiés sur téléphone ; le snackbar remontré sur la Liste repart pour une durée complète.
