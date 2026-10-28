---
title: 'Cocher au magasin'
type: 'feature'
ticket: '4'
created: '2026-10-28'
status: 'built'
baseline_revision: 'fb2d39d8b38d62b0342afbff3ced468931d36775'
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

**Problem:** La Liste n'affiche que des lignes non cochées et n'a pas de case : au magasin, Antoine ne peut rien cocher, et rien n'applique la règle d'AD-4 « décocher une ligne qui a un jumeau non coché la fusionne dans ce jumeau ».

**Approach:** Ajouter au repository de la Liste le cochage et le décochage (avec fusion dans le jumeau), un flux des lignes cochées, puis une case à cocher sur la Ligne d'article et une Section Cochés repliable en bas de la Liste, avec l'animation courte et TalkBack.

## Boundaries & Constraints

**Always:** seul un tap sur la case (ou l'action TalkBack de la ligne) coche ou décoche, jamais un tap sur le nom ; toute écriture dans une transaction, horodatée par `Clock.stamp(ancien updated_at)` ; `added_at` ne change jamais, donc une ligne décochée reprend sa place dans son rayon ; jumeau = autre ligne active non cochée du même article et de même `unit_key` (unité, ou les deux sans unité) ; les en-têtes de rayon ne comptent que les non cochées (inchangé) ; textes dans `strings_fr.dart` ; couleurs par `KadiColors` et le thème ; Material par `package:material_ui/material_ui.dart` ; cibles ≥ 48 dp ; état replié/déplié de la Section Cochés gardé dans le widget, jamais persisté.

**Never:** pas de « Terminer les courses », de Snackbar ni de service Annuler (story 1.5) ; pas de glisser pour supprimer ni d'appui long (story 1.6) ; pas de `manual_at` ; pas de migration de schéma (`checked_at` existe) ; pas de vibration ni de son ; pas d'Annuler sur la coche.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cocher | ligne Tomates 500 g non cochée | `checked_at` et `updated_at` fixés ; absente de `watchUnchecked`, présente dans `watchChecked` avec 500 g | — |
| Décocher sans jumeau | Tomates g cochée seule | `checked_at` remis à nul ; de retour dans `watchUnchecked` à sa place d'ajout | — |
| Décocher avec jumeau | Tomates 300 g cochée, puis ajout de 200 g (nouvelle ligne non cochée) | les contributions actives de la cochée passent sur le jumeau ; la cochée est supprimée logiquement ; une seule ligne Tomates g non cochée, quantité 500 | — |
| Jumeau sans quantité | Tomates sans quantité cochée + Tomates sans quantité non cochée | fusion dans la non cochée, une seule ligne | — |
| Unité différente | Tomates g cochée + Tomates pièce non cochée | pas de fusion : deux lignes non cochées (g et pièce) | — |
| Idempotence | cocher une ligne déjà cochée, décocher une non cochée, id inconnu ou ligne supprimée | rien n'est écrit | aucune erreur |
| Ordre des cochés | Tomates cochée puis Riz cochée | `watchChecked` rend Riz puis Tomates (dernier coché en tête) | — |

</intent-contract>

## Code Map

- `lib/features/liste/data/liste_repository.dart` -- `ListeItem` (ajouter `checked`), `ListeRepository._contribute` (modèle de transaction et de `Clock.stamp(previous)`), `watchUnchecked()` + `_toItem` : factoriser la requête en `_watch({required bool checked})` ; garder `watchUnchecked()` (ordre `added_at`, `id`) et ajouter `watchChecked()` (ordre `checked_at` desc, `id`).
- `lib/features/liste/state/liste_providers.dart` -- `listeRepositoryProvider`, `listeGroupsProvider`, `groupByRoute` : ajouter `listeCheckedProvider` (StreamProvider de `watchChecked()`).
- `lib/features/liste/ui/liste_screen.dart` -- `ListView` des groupes ; état vide quand les groupes sont vides : il ne doit l'être que si aucune ligne cochée non plus ; ajouter la Section Cochés en dernier enfant.
- `lib/features/liste/ui/item_row.dart` -- `Semantics(label: spoken, excludeSemantics: true)` sur toute la ligne, nom en `Expanded`, quantité hors `Expanded` : ajouter la case en tête de ligne et l'état coché (barré).
- `lib/features/liste/ui/rayon_header.dart` -- modèle de style (pastille, `KadiColors.of(context).rayon(r)`), à ne pas modifier.
- `lib/core/theme/kadi_colors.dart` -- `KadiColors.checked` (texte coché) et `rayon(r).accent` (case) ; `lib/core/theme/kadi_tokens.dart` -- `KadiSpacing.margin`, `touchTarget`, `rowMinHeight`, `s1..s6`.
- `lib/core/strings/strings_fr.dart` -- `StringsFr.articles(n)` réutilisable pour l'annonce de la section.
- `test/helpers/test_db.dart` -- `seededDatabase()`, `memoryDatabase()`, `SeedIds.tomates`, `courgettes`, `riz`.
- `test/features/liste/liste_repository_test.dart` -- tests du repository avec `Clock(now: () => now)` : à étendre.
- `test/features/liste/liste_screen_test.dart` -- `_pumpApp` (app sur base en mémoire), `_rowWith` : à étendre.
- API Flutter 3.47.8 : `Semantics(checked:, button:, onTap:)`, `MediaQuery.disableAnimationsOf(context)`, `SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr)` (`announce` est déprécié).

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/strings/strings_fr.dart` -- ajouter `cochesTitre(n)` « Cochés (n) », `afficher` « Afficher », `replier` « Replier », l'annonce de la section « Cochés, n articles, replié|déplié », et les annonces de changement « Tomates, coché » / « Tomates, non coché » -- convention Textes.
- [x] `lib/features/liste/data/liste_repository.dart` -- `ListeItem.checked` ; `check(lineId)`, `uncheck(lineId)` (fusion dans le jumeau selon Design Notes) ; `watchChecked()` -- AD-4.
- [x] `lib/features/liste/state/liste_providers.dart` -- `listeCheckedProvider` -- flux de la section.
- [x] `lib/features/liste/ui/item_row.dart` -- devenir un `StatefulWidget` : case M3 en tête (bordure et remplissage à l'accent du rayon, coche `colorScheme.surface`), animation puis écriture (Design Notes), ligne cochée barrée en `KadiColors.checked` (nom et quantité), `Semantics` avec `checked` et `onTap`, annonce du changement -- R2, R12.
- [x] `lib/features/liste/ui/checked_section.dart` -- nouvelle Section Cochés : filet `outline` au-dessus, en-tête 48 dp (chevron, « Cochés (n) » en `labelLarge` `onSurfaceVariant`, « Afficher » / « Replier » à droite), repliée par défaut, tap sur l'en-tête = déplier / replier, lignes `ItemRow` cochées dessous quand dépliée ; en-tête `Semantics(button: true)` annoncé « Cochés, 2 articles, replié » -- R2.
- [x] `lib/features/liste/ui/liste_screen.dart` -- lire `listeCheckedProvider` ; Section Cochés après les groupes si au moins une ligne cochée ; état vide seulement sans aucune ligne -- R2.
- [x] `test/features/liste/liste_repository_test.dart` -- un test par ligne de la matrice I/O -- AD-4.
- [x] `test/features/liste/liste_screen_test.dart` -- tests de widget des critères ci-dessous -- vérification du ticket.

**Acceptance Criteria:**
- Given Tomates et Courgettes dans la liste, when Antoine touche la case de chacune et l'animation se termine, then l'en-tête Fruits & légumes disparaît et la section affiche « Cochés (2) » repliée, sans les lignes.
- Given la section repliée, when Antoine touche son en-tête, then elle se déplie, montre Tomates et Courgettes barrées avec leur case pleine, et l'indice passe de « Afficher » à « Replier ».
- Given la section dépliée, when Antoine décoche Tomates, then Tomates revient sous Fruits & légumes (compteur 1) et la section affiche « Cochés (1) ».
- Given une ligne non cochée, when TalkBack la lit, then il entend « Tomates, 500 g, Fruits et légumes » avec l'état non coché, et l'action d'activation coche la ligne ; l'en-tête de section est lu « Cochés, 2 articles, replié ».
- Given les animations coupées (`disableAnimations`), when Antoine touche la case, then la ligne rejoint Cochés sans délai d'animation.
- Given un tap sur le nom d'une ligne, then rien ne change.
- Given toutes les lignes cochées, then la Liste montre la seule Section Cochés, pas le message de liste vide.

## Implementation Notes

- `check` fixe `checked_at = updated_at = stamp(ancien)` ; `uncheck` avec jumeau donne à chaque contribution déplacée et à la ligne supprimée leur propre `stamp(ancien)` : l'horloge étant strictement croissante, ces horodatages diffèrent de 1 ms dans une même transaction.
- `ItemRow` devient un `ConsumerStatefulWidget` (il lit `listeRepositoryProvider`) ; dépôt, `View` et délai sont capturés au tap, l'écriture et l'annonce ne dépendent donc pas du montage. Pas de snackbar d'erreur (hors périmètre) : un échec remet seulement `_pending` à nul.
- Le barré suit `item.checked` (l'état en base), la case suit `_pending ?? item.checked`.
- `CheckedSection` porte une `ValueKey` dans la `ListView` et garde son état en vie (`AutomaticKeepAliveClientMixin`) : elle reste dépliée quand un rayon réapparaît au-dessus d'elle ou quand elle sort de l'écran.
- `ListeScreen` lit `.value` des deux flux : l'écran ne se vide pas pendant un rechargement.
- Chevron : `chevron_right` repliée, `expand_more` dépliée (maquette key-liste) ; indice en `labelMedium`.
- Tests de widget : les quantités lues utilisent l'espace insécable de `formatQuantity` ; `isSemantics` remplace `containsSemantics` (déprécié).
- Revue : le nom porte à nouveau `KadiSpacing.s2` de marge verticale (la case de 48 dp n'en a pas) ; une ligne d'une ligne reste à 48 dp.

## Plan Change Log

## Review Triage Log

### 2026-10-28 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 4, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` Un échec d'écriture de `check`/`uncheck` n'est pas affiché (la convention Erreurs de l'architecture demande un snackbar) — réel, mais un échec d'écriture SQLite locale est improbable au quotidien et la correction ajoute un chemin d'erreur et un texte ; le snackbar arrive avec le service Annuler de la story 1.5, à brancher là.
  - `[low]` `[reject]` `_pending` reste bloqué et l'annonce part quand `check`/`uncheck` n'écrit rien — n'arrive que si la base est déjà dans l'état visé alors que le flux affiche l'inverse (course entre deux écritures) ; une ligne supprimée sort du flux et se démonte ; la correction ajoute un retour à l'API du repository.
  - `[low]` `[patch]` La marge verticale de la ligne a disparu : avec une grande police, un nom sur plusieurs lignes touche les bords — corrigé : `Padding` vertical `KadiSpacing.s2` autour du nom.
  - `[low]` `[reject]` La Liste reste blanche si `listeCheckedProvider` charge ou échoue — même comportement qu'avant la story pour le flux des groupes (`_ => SizedBox.shrink()`), les deux flux viennent de la même base locale et un échec de requête `watch` est improbable.

## Design Notes

Coche : au tap, la case passe tout de suite à l'état visé (état local `_pending`, la case M3 anime remplissage et tracé), puis l'écriture `check`/`uncheck` part après `_checkDelay = Duration(milliseconds: 300)` (case M3 ≈ 200 ms, plus un temps de lecture) ; sans délai quand `MediaQuery.disableAnimationsOf(context)`. Le minuteur n'est pas lié au montage (la ligne peut être reconstruite ailleurs). Un second tap pendant l'attente est ignoré. `didUpdateWidget` remet `_pending` à nul quand `item.checked` change. En cas d'échec d'écriture, `_pending` revient à nul si la ligne est encore montée.

Décocher (AD-4), dans une transaction : charger la ligne active cochée (sinon rien) ; chercher le jumeau (actif, non coché, même `article_id`, même unité ou les deux nulles, `id` différent ; le plus ancien par `added_at`, `id`). Avec jumeau : chaque contribution active de la ligne passe sur le jumeau (`line_id`, `updated_at = stamp(ancien)`), puis la ligne cochée prend `deleted_at` et `updated_at = stamp(ancien)`. Sans jumeau : `checked_at = null`, `updated_at = stamp(ancien)`.

Ordre de la Section Cochés : dernier coché en tête **[ASSUMPTION — à valider par Antoine au test de fin d'epic]** ; les sources ne fixent pas cet ordre, et il met en haut l'article coché par erreur (Flux 2, étape 4).

TalkBack : le libellé de ligne reste « Nom, quantité, rayon » ; l'état est porté par le drapeau `checked` (TalkBack dit « coché » / « non coché ») et non répété dans le libellé. Comme la ligne quitte l'écran après la coche, l'écriture est suivie d'une annonce « Tomates, coché » / « Tomates, non coché ».

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent, dont les 111 existants avant la story

## Auto Run Result

Status: built

- **Résumé :** on coche au magasin. Chaque Ligne d'article a une case à la couleur du rayon ; un tap la remplit, puis 300 ms plus tard (tout de suite si les animations sont coupées) la ligne rejoint « Cochés (n) », repliée en bas de la Liste. Déplier montre les lignes barrées ; décocher renvoie la ligne à sa place dans son rayon, fusionnée avec un jumeau non coché du même article et de la même unité (AD-4). Un rayon tout coché disparaît. TalkBack lit l'état coché, coche par double tap et annonce le changement.
- **Fichiers :**
  - `lib/features/liste/data/liste_repository.dart` — `ListeItem.checked`, `check`, `uncheck` avec fusion dans le jumeau, `watchChecked`.
  - `lib/features/liste/state/liste_providers.dart` — `listeCheckedProvider`.
  - `lib/features/liste/ui/item_row.dart` — case, animation puis écriture, barré, TalkBack et annonce.
  - `lib/features/liste/ui/checked_section.dart` — nouvelle Section Cochés repliable.
  - `lib/features/liste/ui/liste_screen.dart` — section en bas, état vide seulement sans aucune ligne.
  - `lib/core/strings/strings_fr.dart` — textes de la section et des annonces.
  - `test/features/liste/liste_repository_test.dart` — 7 tests, un par ligne de la matrice I/O.
  - `test/features/liste/liste_screen_test.dart` — 5 tests de widget sur les critères d'acceptation.
- **Revue :** 1 correction appliquée (low, marge verticale), 0 reporté, 3 rejetés (erreur d'écriture non affichée, `_pending` bloqué sur une course improbable, écran blanc si un flux échoue) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — aucune correction high ni medium.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 123/123 après correction.
- **Risques résiduels :** ordre « dernier coché en tête » de la section à valider par Antoine ; aucun retour visible si une écriture de coche échoue (à brancher sur le snackbar de la story 1.5) ; rendu et TalkBack réels non vérifiés sur téléphone (test prévu en fin d'epic).
