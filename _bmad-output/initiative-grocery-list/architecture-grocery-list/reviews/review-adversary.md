---
review: adversary
target: _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md
inputs:
  - _bmad-output/initiative-grocery-list/initiative-grocery-list.md
  - _bmad-output/initiative-grocery-list/tickets/tickets.toml
date: '2026-10-25'
lens: "Two units one level down (the 3 epics) that each obey every AD to the letter yet build incompatibly"
verdict: 'Not ready to bind. 4 critical and 7 high holes; all can be closed with tightened or new ADs, no paradigm change.'
---

# Adversarial review — grocery-list architecture spine

## Verdict

**Not ready to bind epic planning.** The paradigm (one Drift base, owner repositories, cross-feature actions in `app/actions`) is sound. The holes are in the *data contract*: AD-4/5/6 leave the list-line identity under-specified (checked lines, "sans quantité", manual mode), AD-7/8/9 interact badly (seed timestamps, natural-key duplicates, seed loaded only once), AD-10 does not say *which rows* a snapshot covers, and the dependency graph forbids `liste` and `recettes` from reading the route order and settings that R9/R19 make them consume. Each finding below is a pair of epics (E1 = liste + catalogue + socle, E2 = recettes + Revue, E3 = réglages + sauvegarde) that both comply with every AD and still clash.

Severity: **Critical** = data loss, broken import, or a Done-when criterion fails. **High** = two epics will build different shapes and one must be redone. **Medium** = divergent behaviour visible to the user. **Low** = local ambiguity, cheap to fix later.

## Summary table

| # | Severity | Pair | Hole | AD to change |
|---|---|---|---|---|
| 1 | Critical | E1 seed × E3 import | Seed rows stamped `now()` beat the backup on a fresh install | AD-8, AD-9 |
| 2 | Critical | E1 seed × E2 seed | "Inserted once, at first launch" — E2's example recipes never reach the phone already running E1 | AD-8 |
| 3 | Critical | E1 lines × E3 import | Row-by-id merge creates duplicate natural keys (lines, settings, frequents, selections) → unique violation aborts every import | AD-9, AD-4 |
| 4 | Critical | E1 Panneau + × E2 Revue | Adding (article, unit) when the only matching line is checked | AD-4 |
| 5 | High | E1/E2 readers × E3 owner | `liste`/`recettes` may not depend on `reglages`, yet must read route order, grouping toggle | AD-2, dependency graph, AD-11 |
| 6 | High | E1 edit sheet × E2 deselect | Two legal shapes for "mode manuel" | AD-5 |
| 7 | High | E2 Revue × E1 contribution model | Correcting a Revue row that merges two recipes: whose contribution? | AD-4 |
| 8 | High | E1 Terminer × E2 Terminer/deselect | Undo snapshot scope ("lignes") and slot lifetime | AD-10 |
| 9 | High | E1 quick-add × E2 recipe ingredient | Two encodings of "sans quantité"; SQLite UNIQUE treats NULLs as distinct | AD-6, AD-4 |
| 10 | High | E2 photo × E3 export | Recipe photos are files, not rows; the JSON export loses them | AD-9 |
| 11 | High | E1 lines × E3 grouping toggle | "Ordre d'ajout" has no column; `updated_at` moves on every write | AD-7 / AD-4 |
| 12 | Medium | E3 article edits × E1/E2 copies | Line rayon and ingredient unit: copied or inherited? | new AD |
| 13 | Medium | E2 selection × E1 Terminer | Selection lifecycle: revive vs new row; when `validated` is set | new AD |
| 14 | Medium | E1 cached total × E3 import | Stored line total vs computed sum; meaning of "active contribution" | AD-4 |
| 15 | Medium | E1 frequent state × E2/E3 writers | "In list" stored vs derived; what a tap-to-remove removes | AD-4 / new AD |
| 16 | Medium | all writers × E3 import | Clock: non-monotonic `updated_at`, equal-timestamp ties | AD-7 |
| 17 | Medium | E3 import × E1/E2 readers | FK order during import; active child under deleted parent | AD-9, AD-7 |
| 18 | Medium | E1 Créer × E2 Créer × E3 Articles × import | Article name uniqueness and creation defaults | AD-2 / new AD |
| 19 | Low | E1 edit sheet × AD-4 key | Changing a line's unit collides with an existing twin | AD-4 |
| 20 | Low | E1 sums × E2 split | Decimal REAL arithmetic and zero quantities | AD-6 |
| 21 | Low | E1 frequents × E3 frequents/articles | Frequent order key when re-added or when the article changes rayon | AD-2 |
| 22 | Low | E2 Revue × AD-1 | Revue draft is a UI-held copy of data | AD-1 |

---

## Critical

### 1. Seed timestamps beat the backup on a fresh install

- **Units:** E1 (seed loader `core/db/seed`, catalogue + frequents) × E3 (import, `core/backup`).
- **How both obey:** E1 inserts seed rows with the frozen UUIDs of AD-8 and, per AD-7 "toute écriture met `updated_at` à jour", stamps them with `now()`. E3 merges by `id`, most recent `updated_at` wins (AD-9).
- **Clash:** Antoine edits seed article *Tomates* (rayon, unit) at T1 and exports. He installs on a new phone at T2 > T1: the seed inserts *Tomates* again with `updated_at = T2`. Import compares T1 < T2 → **his edit loses**. Same for deleted example recipes (the deletion at T1 loses to the fresh seed row), default settings rows and the default route order. The Done-when "export puis import sur une installation neuve restaure … le catalogue, les fréquents, le parcours, les réglages" fails.
- **Fix (AD-8):** seed rows and every default row created by the app itself are inserted with `updated_at = 0` (and `deleted_at = null`); only a user action gives a row a real timestamp. Import therefore always prefers any user-touched version.

### 2. "Inserted once, at first launch" vs. epics shipped in sequence

- **Units:** E1 (seed loader, first-launch flag, articles/frequents) × E2 (example recipes, R22 first launch on Recettes).
- **How both obey:** E1 builds the single loader of AD-8 and runs it once at first launch, then sets a "seeded" flag. E2 adds `recettes.json` to `assets/seed/` and routes the first launch to Recettes (AD-13).
- **Clash:** E1 is "utilisable seule" and is installed on Antoine's phone first (ticket Decision). When the E2 build is installed as an update, first launch is long past: the example recipes are never inserted, the first-open-on-Recettes never happens, and any later seed addition (new articles, a regenerated AI catalogue) never lands. If the AI catalogue is regenerated during development with new UUIDs for existing names, every reinstall + import duplicates articles — the exact thing AD-8 wants to prevent.
- **Fix (AD-8):** the loader runs at every launch with a per-file `seed_version`; it inserts each seed row whose UUID is absent (soft-deleted counts as present), never updates an existing row, and seed UUIDs are permanent once shipped (regenerating content keeps the UUID of every existing item). "First launch" for R22/AD-13 is a flag the E2 loader sets when it inserts recipes for the first time, not the E1 install.

### 3. Row-by-id merge creates duplicate natural keys

- **Units:** E1 (list lines unique on (article, unit), frequents, settings) × E3 (import).
- **How both obey:** E1 enforces AD-4 uniqueness with a partial unique index `(article_id, unit) WHERE deleted_at IS NULL`, each row with its own UUID v4 (AD-7, AD-8 "donnée créée par l'utilisateur reçoit un UUID v4 neuf"). E3 merges strictly by `id` (AD-9) in one transaction.
- **Clash:** the backup holds an active line *Lait/piece* (id A); the target phone has its own active *Lait/piece* (id B). Different ids → both kept → the unique index fires → AD-9 rolls back the **whole** import, every time, for any user who has a list on both sides. Without the index, the list silently shows two *Lait* lines and AD-4 is broken. The same happens to: one-per-key settings rows (two "Écran allumé" rows, two route orders), frequents (same article twice), and week selections (same recipe selected twice). A fresh install also has its own default settings/route rows with fresh UUIDs (see #1).
- **Fix (AD-9 + AD-7):** rows that are singletons or have a natural key get a **deterministic id** (UUID v5 of the natural key: setting key, `route_order`, frequent's `article_id`); for list lines and selections, the import ends — in the same transaction, before commit — with an owner-repository `reconcileAfterImport()` that merges duplicate active rows on the natural key (moving contributions to the survivor, soft-deleting the loser). Natural-key uniqueness is then checked by the reconcile step, not by an immediate SQLite UNIQUE index during the merge.

### 4. Adding to an (article, unit) whose only line is checked

- **Units:** E1 (Panneau +, frequents, R10/R16) × E2 (Ajouter à la liste from Revue).
- **How both obey:** AD-4 says the line is unique among **non-deleted** lines — checked lines are non-deleted. E1 implements "tap a frequent that shows *hors liste*" (R16: checking the article put it hors liste) by **unchecking** the existing checked line and adding a `manuel` contribution. E2 implements Revue's add by **adding a contribution to the existing line** and leaves `checked` alone (AD-4 says nothing about checked state).
- **Clash:** for the same situation the two epics produce opposite results: E1 resurrects the line (with the already-bought quantity summed back in), E2 adds 300 g to a line that stays in "Cochés" — the user never sees it and doesn't buy it. AD-5's "retire … des seules lignes non cochées" then makes deselection behave differently depending on which path created the state.
- **Fix (AD-4):** identity is (article, unit) **among non-deleted, unchecked lines**; a contribution whose only match is checked creates a new unchecked line. Unchecking a line from "Cochés" when an unchecked twin exists merges the two (contributions moved to the twin, the checked one soft-deleted).

## High

### 5. Readers of route order and settings cannot depend on their owner

- **Units:** E1 (Liste grouping, Panneau + order, R19 "ordre par défaut") and E2 (Revue order, R4) × E3 (`reglages` owns "l'ordre du parcours" and the grouping toggle, AD-2).
- **How both obey:** the dependency graph allows `liste → catalogue` and `recettes → liste, catalogue` only. So E1 hard-codes the enum order of `core/rayons` (AD-11) for grouping, and E2 does the same in Revue. E3 then creates a `reglages` table for the route order and the grouping toggle (R9) and the keep-screen-on flag (R14).
- **Clash:** to honour R19 ("la Liste, la Revue et le Panneau + suivent cet ordre") and R9 (grouping off), E1 and E2 must import `reglages` — forbidden — or E3 must write into `liste`/`recettes` — forbidden by AD-1/AD-2. Either way E1 and E2 are redone. R14 (screen on while Liste shows) has the same shape.
- **Fix (AD-2 + graph):** route order and the app settings are a **core** concern: `lib/core/settings/` owns the `settings` table (route order as one row holding the ordered list of the 13 codes, grouping, screen-on) with a read provider every feature may use; `reglages` is UI only and writes through that core repository. E1 creates the table with the default order (updated_at 0, deterministic id).

### 6. Two legal shapes for "mode manuel"

- **Units:** E1 (Feuille d'édition, AD-5) × E2 (deselect, AD-5 "non manuelles"; later validations "ajoute encore").
- **How both obey:** AD-4 says the displayed quantity is the sum of active contributions; AD-5 says the quantity *becomes* the entered value and later recipes still add. E1 implements manual as: flag `is_manual` + soft-delete every active contribution + one `manuel` contribution holding the value. A just-as-legal E1 keeps the contributions and stores `manual_quantity` that overrides the sum. E2 reads whichever it guessed.
- **Clash:** under shape B, E2's "a later recipe adds its quantity" computes `manual_quantity + Σ(contributions created after the edit)`, which needs a timestamp boundary E1 never stored; under shape A, E2's deselect skip is consistent. Also the word `manuel` names both a contribution source (Panneau +) and a line mode: E2 may skip any line holding a `manuel` contribution, E1 only lines edited in the sheet. And AD-10 (snapshot of "lignes") under shape A must restore contributions too (see #8).
- **Fix (AD-5):** manual edit = in one transaction, soft-delete all active contributions of the line, insert one contribution with source `edition` and the entered value, set `list_lines.manual_at`. Display is always Σ active contributions. Deselect skips lines with `manual_at` set. Panneau + contributions keep source `manuel` and do not make the line manual.

### 7. Correcting a Revue row that merges several recipes

- **Units:** E2 Revue (R4 sums same article+unit across the newly validated recipes) × E1 contribution model (one contribution per source per line) and E2 deselect.
- **How both obey:** AD-4: "une correction faite en Revue fixe la quantité de la contribution de la recette". Revue shows *Tomates 500 g* = recipe A 300 + recipe B 200; the user types 400.
- **Clash:** "la contribution de la recette" is singular; there are two. One implementation writes 400 on A and 0 on B, another splits 240/160, another writes one contribution with no recipe source. Deselecting A later removes 400, 240, or nothing. Undo of that deselect and the Revue display of the next week differ accordingly.
- **Fix (AD-4):** a corrected merged Revue row is split across its recipes proportionally to their original quantities, rounded in the unit, the last recipe in Revue order absorbing the remainder; a recipe whose ingredient had no quantity gets none. An unchecked Revue row creates no contribution for any of its recipes.

### 8. Undo snapshot scope and slot lifetime

- **Units:** E1 (creates Terminer les courses, swipe-delete, edit sheet with Undo) × E2 (adds the selection reset to Terminer, deselect with Undo).
- **How both obey:** AD-10: the action hands Undo "l'état d'avant des lignes qu'elle touche". E1 reads *lignes* as **list lines** and types the snapshot as `List<ListLine>`. E2 extends Terminer (AD-3) and needs to restore `week_selections` and `list_contributions` too.
- **Clash:** E2 must change E1's Undo API or ship a Terminer whose Annuler restores the list but not the selection (R12 fails), and a deselect whose Annuler restores lines but not contributions (R6 fails). Further: (a) AD-10 says only a new *undoable* action clears the slot; a non-undoable write in between (Panneau + add, Ajouter à la liste, Nouvelle liste, an import) leaves a stale snapshot that Annuler then writes over newer data — e.g. swipe *Lait*, re-add *Lait* from Panneau +, tap Annuler → two active *Lait* lines. (b) Restoring the snapshot verbatim brings back old `updated_at` values, so the next import lets the exported deletion win and undoes the undo.
- **Fix (AD-10):** the snapshot is a map table → prior full rows (or "absent") for **every table** the action writes; restore writes those values with a fresh `updated_at`. Any write that is not itself the undoable action clears the slot (including import and Nouvelle liste), and the slot expires with its snackbar.

### 9. Two encodings of "sans quantité"; NULL in the unique key

- **Units:** E1 (Panneau + quick-add, R17 "unité par défaut préremplie") × E2 (recipe ingredient "quantité facultative", R1).
- **How both obey:** AD-6 allows unit `null` (sans quantité) **and** quantity `null` (si sans quantité). E1 stores a quick-add without a typed quantity as (article, `g`, quantity null) because the unit was prefilled. E2 stores an ingredient without quantity as (article, unit null, quantity null).
- **Clash:** *Sel* from the Panneau + and *Sel* from a recipe become two lines — (Sel, g) and (Sel, null) — both legal under AD-4/AD-6. Worse, SQLite UNIQUE indexes treat NULLs as distinct, so a unique index on (article_id, unit) never stops two (Sel, null) lines either.
- **Fix (AD-6 + AD-4):** quantity null ⇔ unit null, always together; the key is stored with a non-null sentinel (`unit_key = coalesce(unit, '-')`). A no-quantity contribution attaches to the article's existing unchecked line whatever its unit; a quantified contribution attaches to an existing (article, null) line and gives it its unit.

### 10. Recipe photos are not rows

- **Units:** E2 (photo from gallery/camera, R1) × E3 (export/import, AD-9).
- **How both obey:** E2 copies the picked photo into app storage and stores its path in `recipes.photo_path`. E3 exports every table as JSON (AD-9) — the path is exported, not the image.
- **Clash:** restoring on a fresh install yields recipes pointing at missing files; Done-when "restaure les recettes" fails on the most visible element of R2. Alternatively E2 stores the bytes as a BLOB, and E3's JSON either base64-inflates the backup or breaks.
- **Fix (AD-9):** photos live in `app_documents/photos/<photo_uuid>.jpg` referenced by uuid; the backup is a zip holding `backup.json` plus `photos/`, and import copies missing photo files before committing the row merge.

### 11. "Ordre d'ajout" has no column

- **Units:** E1 (list lines, AD-7 columns only) × E3 (grouping off → "les articles suivent l'ordre d'ajout", R9).
- **How both obey:** AD-7 guarantees `id`, `updated_at`, `deleted_at`; the spine says only AD-4/5/6/7 columns are invariants. E1 orders lines within a rayon by name and stores no creation time. E3 sorts by `updated_at` (the only time available) — UUID v4 is not ordered.
- **Clash:** every check, quantity change or new contribution moves a line to the bottom; the ungrouped list reshuffles while shopping.
- **Fix (AD-4):** `list_lines.added_at` (ms UTC) is set at line creation and never changed; ungrouped order and within-rayon order both sort by `added_at`. Same rule for `frequents.position` (see #21).

## Medium

### 12. Copied or inherited: line rayon, ingredient unit

- **Units:** E3 (Paramètres › Articles edits default rayon/unit, R18) × E1 (line rayon, R13) and E2 (ingredient unit, Revue grouping).
- **How both obey:** AD-11 says the base stores "rayon d'un article ou d'une ligne". E1 stores `list_lines.rayon = null` meaning "follow the article" and only sets it when the user moves the line. E2 stores ingredients with `unit = null` meaning "article default". Both legal.
- **Clash:** E3 changes *Tomates* from `piece` to `g`: every recipe's *Tomates* ingredient silently changes unit, and every inherited list line jumps rayon — contradicting R18 "une modification vaut pour les ajouts suivants" and R7. Another E1 copies the rayon, and the two behaviours coexist.
- **Fix (new AD):** a list line copies its rayon and a recipe ingredient copies its unit at creation (both non-null except the null "sans quantité" unit); editing an article never rewrites existing lines or ingredients. Revue groups by the article's current default rayon; the resulting line takes that rayon only when created.

### 13. Selection lifecycle and "validated"

- **Units:** E2 (selection, Valider, deselect, reselect) × E1 (Terminer action that E2 extends; contributions referencing the selection).
- **How both obey:** AD-4: a contribution carries "la sélection de recette qui l'a apportée". E2 sets `validated_at` when Valider opens the Revue; deselecting soft-deletes the selection row and reselecting **revives** it (same id, avoiding a second row for the recipe).
- **Clash:** (a) quitting the Revue ("n'ajoute rien") leaves the recipe validated with no contribution and Valider (n) can never offer it again. (b) A revived selection shares its id with contributions still alive on **checked** lines (AD-5 left them there); if such a line is later unchecked and the recipe deselected again, the old contribution is removed too. (c) Terminer resets the selection — by clearing `validated_at` or by soft-deleting rows — and the two choices change what Undo must restore.
- **Fix (new AD in recettes):** each select creates a new `week_selections` row (never revived except by Undo); deselect and Terminer/Nouvelle liste soft-delete it. `validated_at` is set only by Ajouter à la liste, in its transaction, for every recipe of that Revue, even with zero checked rows.

### 14. Stored total vs computed sum; "active contribution"

- **Units:** E1 (line quantity) × E3 (import) and E2 (recipe deletion).
- **How both obey:** E1 caches the total in `list_lines.quantity`, updated by the repository on every contribution change (AD-1: only the repository writes). E3 merges `list_lines` and `list_contributions` row by row. E2, on recipe deletion, soft-deletes the recipe's `week_selections` and E1's sum filters contributions by "active" = contribution alive **and** its selection alive.
- **Clash:** after import the cached total and the merged contributions disagree; R7 ("supprimer une recette validée ne change pas la liste") breaks under the join definition of "active".
- **Fix (AD-4):** the line total is never stored; it is always `Σ quantity of contributions with deleted_at IS NULL`. "Active contribution" means exactly that — a source's deletion never deactivates contributions implicitly.

### 15. Frequent "in list": stored or derived, and what a tap removes

- **Units:** E1 (Panneau +, R16) × E2 (Revue adds) and E3 (frequents management, import).
- **How both obey:** E1 stores `frequents.in_list` (catalogue table, written through `CatalogueRepository`, AD-2) and flips it on Panneau + taps and on check. E2's Revue add does not know to set it; Terminer (AD-3) does not reset it. Alternatively E1 derives it — but then "tap to remove" is undefined when the article has two lines (g and piece) or recipe contributions.
- **Clash:** frequents show *hors liste* for articles the Revue just added, or stay *en liste* after Terminer; a tap removes either the whole line (recipe quantities included) or only the `manuel` contribution.
- **Fix (AD-4):** "in list" is always derived: an unchecked active line exists for the article (any unit); never stored. A tap on an in-list frequent or search result soft-deletes all unchecked lines of that article with their contributions — the same operation as swipe-delete, undoable.

### 16. Clock

- **Units:** every writer (E1, E2, E3) × E3 import.
- **How both obey:** AD-7 "Toute écriture met `updated_at` à jour" with `DateTime.now()`; AD-9 compares timestamps.
- **Clash:** the phone clock jumps back (manual change, NTP correction) → a newer edit gets a smaller `updated_at` and loses at the next import; two writes in the same millisecond tie and AD-9 does not say who wins, so E3 may keep local while a test expects file.
- **Fix (AD-7):** one `Clock` in `lib/core/` writes `updated_at = max(now, row.updated_at + 1)`; on an equal timestamp at import, the local row wins.

### 17. Import order, foreign keys and orphans

- **Units:** E3 (import) × E1/E2 (FKs between lines, contributions, selections, ingredients).
- **How both obey:** E1/E2 declare Drift `references(...)` with `PRAGMA foreign_keys = ON`; E3 inserts tables in map order (AD-9 doesn't fix one). AD-7 filters each table independently.
- **Clash:** a contribution imported before its line fails the FK → whole import rolls back. Row-level LWW can also keep an active ingredient under a recipe whose deletion won, or an active contribution under a deleted line; readers that filter only their own table show ghosts (e.g. a Revue of a deleted recipe).
- **Fix (AD-9 + AD-7):** import writes tables in dependency order (articles, recipes, ingredients, selections, lines, contributions, frequents, settings) — or defers FKs and runs `PRAGMA foreign_key_check` before commit; the reconcile step of #3 soft-deletes every active child whose parent is deleted.

### 18. Article name uniqueness and creation defaults

- **Units:** E1 (Panneau + "Créer « … »", R17) × E2 (ingredient picker reusing search, R1) × E3 (Paramètres › Articles, import).
- **How both obey:** AD-2 makes `catalogue` the only writer, but not the only *rule*: E1 matches "correspondance exacte" case-insensitively; E3's editor creates by exact string; E2's picker creates with the default unit `piece`. The import brings user articles from another phone with different UUIDs.
- **Clash:** *tomate*, *Tomate*, *Tomates* coexist; a recipe's *Créer* gets a unit while the Panneau + one gets none (R17 "Divers, sans unité"); importing yields two *Avocat* articles that never merge.
- **Fix (new AD in catalogue):** one `normalizeName()` (trim, lowercase, no accents) in catalogue; one `createArticle(name, {rayon = divers, unit = null})` used by every caller; names unique by normalized form among active articles, and import reconciliation merges same-name user articles by re-pointing references to the older id.

## Low

### 19. Changing a line's unit in the edit sheet

E1's sheet (R13) may allow a unit change *g → piece*; if an active (article, piece) line exists, the key collides. **Fix (AD-4):** the edit sheet changes quantity only within the line's unit, or a unit change merges into the twin line, which becomes manual.

### 20. Decimal arithmetic

AD-6 "nombre décimal" lets E1 use `REAL`; E2's proportional split (#7) and repeated sums drift (0.1 + 0.2), and a Revue correction to 0 yields a "0 g" line. **Fix (AD-6):** store quantities as integers in g, ml, or thousandths of a piece; a quantity of 0 in Revue or the sheet means "sans quantité".

### 21. Frequent order key

R20 "ordre stable dans chaque rayon": E1 seeds `position`; E3 re-adds a removed frequent as a new row (new position) or revives it; changing an article's rayon (E3) drops it into another group at an arbitrary position. **Fix (AD-2):** one frequent per article (deterministic id, #3), revived on re-add; order within a rayon by `position`, a newly added or moved frequent going last.

### 22. Revue draft vs AD-1

AD-1 says the screen "ne garde aucune copie des données", yet the Revue's decoched rows and corrected quantities exist only until Ajouter à la liste. One E2 implementation keeps it in a Riverpod notifier, another writes a `revue_drafts` table (then it needs AD-7 columns and an export entry under AD-9). **Fix (AD-1):** state explicitly that the Revue draft is transient UI state, not persisted and not exported.

---

## Proposed AD deltas (consolidated)

1. **AD-4 (tightened):** key = (article_id, unit_key) among active **unchecked** lines, `unit_key = coalesce(unit,'-')`; total always computed from active contributions; `added_at` immutable; checked twin merge on uncheck; Revue correction split rule; "in list" derived; Panneau + remove = swipe-delete.
2. **AD-5 (tightened):** manual edit = soft-delete contributions + one `edition` contribution + `manual_at`.
3. **AD-6 (tightened):** quantity null ⇔ unit null; integer storage; no-quantity attaches to existing line.
4. **AD-7 (tightened):** monotonic `Clock`; local wins ties; children of deleted parents are dead.
5. **AD-8 (rewritten):** versioned seed run at every launch, insert-if-absent, `updated_at = 0`, permanent UUIDs; defaults likewise.
6. **AD-9 (tightened):** zip with photos; dependency order; deterministic ids for natural-key rows; `reconcileAfterImport()` per owner in the same transaction; import clears Undo.
7. **AD-10 (tightened):** multi-table snapshot, restore with fresh `updated_at`, slot cleared by any other write and expired with its snackbar.
8. **AD-2 + graph (changed):** `core/settings` owns settings and route order, readable by all features.
9. **New AD — copy at creation:** line rayon and ingredient unit are copied, article edits never rewrite them.
10. **New AD — selection lifecycle:** new row per select, `validated_at` set by Ajouter à la liste only.
11. **New AD — article identity:** single normalization and creation function, name uniqueness, import merge by name.
