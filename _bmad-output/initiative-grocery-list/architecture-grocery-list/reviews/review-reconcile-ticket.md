# Reconciliation review — ticket vs architecture spine

- Spine: `architecture-grocery-list/architecture-grocery-list.md` (draft, 2026-10-25)
- Ticket: `initiative-grocery-list.md` (R1–R24, C1–C10, Boundaries, Notes)
- Epic split: `tickets/tickets.toml`
- Also spot-checked: DESIGN.md rayon tokens (AD-11 codes match all 13 `rayon-*` tokens), EXPERIENCE.md Revue state row (R11 latitude).
- Scope: only gaps that need a shared invariant across epics or features. UI-only details are left to the epics.

## Verdict

**Not ready to bind: revise first.** Coverage is broad: every R and C is listed in `binds`, the 13 rayon codes match DESIGN.md, the epic ownership of the cross-feature actions (AD-3) matches tickets.toml, and the touch points are handed to the right epics. But two rules in the spine break the ticket's own Done-when or the epic split as written:

1. The feature dependency graph forbids `liste` and `recettes` from reading the parcours and settings, which R9, R14, R15 and R19 require (F1).
2. AD-8 + AD-9 as written make "export, then import on a fresh install" lose the user's catalogue, frequents, parcours and settings edits (F2).

Several provenance and uniqueness rules in AD-4, AD-5 and AD-10 also leave cases undefined that epic 1 and epic 2 would each settle on their own, which is exactly what those ADs exist to prevent (F3–F6).

## Findings

### F1 — Feature dependency graph forbids reading parcours and settings where the ticket needs them — **critical**

- Spine: AD-2 gives "les réglages et l'ordre du parcours" to `reglages`. The diagram allows only `recettes→liste`, `recettes→catalogue`, `liste→catalogue`, `reglages→catalogue`. So `liste` and `recettes` may not depend on `reglages`.
- Ticket: R9 (the Liste groups by parcours order; the grouping toggle comes from Paramètres), R15 (Panneau + in parcours order), R19 ("la Liste, la Revue et le Panneau + suivent cet ordre"), R14 (Écran allumé applies only while the Liste tab is shown).
- Epic split: epic 1 delivers the Liste with the default order (R19 part) and grouping (R9). Epic 3 delivers the parcours drag-and-drop, the grouping toggle and Écran allumé. Under AD-2, epic 1 would read a table owned by a feature that does not exist until epic 3, through a dependency the graph forbids. Epic 2's Revue has the same problem.
- Fix: move the parcours order and the read side of settings into `core` (for example `core/rayons` exposes the ordered list as a provider, and `core/settings` holds the settings table and repository, created in epic 1 with its defaults). `features/reglages` becomes UI only and writes through that core repository. AD-2 then needs an explicit line saying epic 1 creates the settings and parcours storage. Put the R14 wakelock hook in the shell or router (it depends on which branch is visible), not in `reglages`.

### F2 — The seed timestamps and fresh-install rows defeat the restore that Done-when requires — **critical**

- Done-when: "Un export suivi d'un import sur une installation neuve restaure les recettes, le catalogue, les fréquents, le parcours, les réglages et la liste en cours."
- Spine: AD-8 inserts the seed with frozen UUIDs at first launch. AD-9 merges by `id` and the newest `updated_at` wins. AD-7 says every write sets `updated_at`.
- Problem: on the fresh phone, the seed rows (articles, frequents, example recipes) get `updated_at` = install time, which is newer than the user's edits on the old phone. Seed rows therefore win: catalogue edits are lost, deleted example recipes and removed frequents come back (their tombstones lose), and so on. Singleton rows (settings, parcours) get a fresh UUID v4 on each install, so the merge yields **two** settings or parcours rows instead of restoring one.
- Fix: seed rows carry a fixed `updated_at` from the seed file (for example 0, or the seed version's date), not the install time. Singleton or default rows (settings, parcours entries keyed by rayon code) get fixed, well-known ids. Add a merge test to AD-9: "fresh install + import = old phone state".

### F3 — The (article, unit) uniqueness collides with checked lines — **high**

- Spine AD-4: a line is unique per (article, unit) among non-deleted lines. Checked lines are not deleted (they sit in "Cochés", R10), and the list only empties through Terminer or Nouvelle liste (R12, C10).
- Ticket R16: checking an article sets its frequent back to "hors liste", so a tap adds it again. R17 search results and R4/R5 recipe validation can also target an article that is checked.
- Undefined: does a new add uncheck the existing line, add a contribution to the checked line, or create a second line (which AD-4 forbids)? Epic 1 (frequent and search) and epic 2 (Ajouter à la liste) would each decide on their own.
- Fix: define uniqueness among **unchecked** non-deleted lines, or state that adding to a checked (article, unit) unchecks it and adds the contribution. Define "en liste" for R16/R17 at the same time: an unchecked line exists for the article, in any unit?

### F4 — Removing a line through a frequent or search tap is undefined under provenance — **high**

- Ticket R16 and the Notes decision: a tap on a frequent or a search result that is already in the list **removes** it.
- Spine: AD-4 and AD-5 only define removal by recipe deselection. A line can carry recipe contributions, a manual contribution, or both, and an article can have two lines (two units, AD-6).
- Undefined: does the tap remove the whole line (every contribution, all units) or only the `manuel` contribution? Is it undoable (AD-10 binds only R6, R12, R13)? This decides what a later R6 deselection does to that line.
- Fix: one sentence in AD-4, for example "a tap removal soft-deletes every unchecked line of the article with all its contributions; it is not undoable".

### F5 — AD-4 and AD-5 disagree on how a line's quantity is computed, and Revue corrections are ambiguous — **high**

- AD-4: the displayed quantity is the sum of the active contributions. AD-5: a manual line's quantity is the entered value, yet a recipe validated later "ajoute encore sa quantité". Two models of the same column. Is the manual value a base plus later contributions? Is it stored on the line or as a contribution? R11 (sum) and R6 ("réduit d'autant") depend on the answer.
- AD-4: "une correction faite en Revue fixe la quantité de la contribution de la recette". But a Revue line can be the **sum** of several newly validated recipes (R4). Which recipe's contribution receives the correction? A proportional split, the first recipe, or a separate correction contribution? This drives what R6 later removes.
- Null quantity: R1 makes the quantity optional and AD-6 allows `null`. AD-6 conflates "unit `null`" with "no quantity". Undefined: is an ingredient with no quantity on an article whose default unit is `g` the line (article, g) with qty null, or (article, null)? How do null and 200 g sum? Epic 1 (Panneau + quantity is optional, R17) and epic 2 (Revue) must merge the same way.
- Fix: state the line quantity formula once (for example `manual_base ?? 0 + Σ active contributions`, null + x = x, all-null = null). Treat a Revue correction as a contribution of its own, or apply it to one named recipe. Put fusion (not only display rounding) in one `core/units` function used by both the Liste and the Revue. That is what AD-6's "Prevents" claims but its Rule does not say.

### F6 — The single-slot Undo can restore stale rows over later writes — **medium**

- AD-10 restores "l'état d'avant des lignes qu'elle touche". Non-undoable writes can happen while the snackbar is still up: a check, a frequent tap, an R16 removal. Example: Terminer, then a frequent tap re-adds (lait, ml), then Annuler. The old line is restored next to the new one, which breaks AD-4 uniqueness.
- Fix: the slot is cleared by any later write to the same tables, or when the snackbar is dismissed, the tab changes, or an import runs.

### F7 — Recipe photos are outside the data model, the export and C3 — **high**

- Ticket: R1 has a photo from the gallery or the camera (touch point owned by epic 2). Done-when says export + import "restaure les recettes". C3 says "chaque élément stocké porte un UUID…".
- Spine: AD-9 exports only JSON tables. The photo storage location (app documents dir vs a gallery URI) is not stated, and the photo binary is in no export. On a fresh install, restored recipes have dangling photo paths. Deferred puts only the *package* choice with epic 2, but where and how the photo is stored crosses epic 2 and epic 3 (export).
- Fix: an AD line saying photos are copied into app storage under `<photo_uuid>.jpg` and referenced by id, and the export is a zip (JSON + photos) or embeds base64. Or record explicitly that the backup drops photos, as a ticket change.

### F8 — The export module arrives last, but AD-9 says each table joins it when created — **medium**

- AD-9: "Toute nouvelle table est ajoutée à l'export et à l'import dans la story qui la crée." `core/backup` is built by epic 3 (R21; tickets.toml says epic 3 is after epic 2 "pour l'export et l'import"). Epic 1 and epic 2 stories cannot add tables to a module that does not exist yet.
- Fix: the export and import iterate over all tables of `AppDatabase` generically (no per-table list). Or epic 1 creates the `core/backup` skeleton with its table registry. Either way the rule becomes enforceable.

### F9 — Import merge vs live invariants — **medium**

- Merging by row `id` can produce two non-deleted, unchecked lines for the same (article, unit) with different ids (the old phone's list and the new phone's list), which breaks AD-4 uniqueness. The same goes for week selections of the same recipe.
- Fix: after the row merge, run a reconcile pass in the same transaction (merge the colliding lines and move their contributions). Or state that the list tables are replaced rather than merged. Also clear the Undo slot.

### F10 — Schema migrations across epics on a phone in real use — **medium**

- Epic 1 ships a release that Antoine uses for real shopping (Done-when; epic 1 opens with the release build). Epics 2 and 3 add tables and columns. The spine lists `migrations` in the seed folder but has no rule: Drift `schemaVersion` bumps, tested step migrations, no destructive migration.
- AD-8 seeds "une fois, au premier lancement". Example recipes come with epic 2, after first launch has already happened on the phone, so they would never be inserted. The "first launch" flag (R22/AD-13) also needs a home (settings, see F1).
- Fix: the seed is idempotent per dataset (insert missing UUIDs per seed version), plus a migration rule in AD-1 or AD-7.

### F11 — "Ordre d'ajout" (R9) and stable frequent order (R20) need columns the invariants omit — **medium**

- R9: with grouping off, articles follow the order they were added. AD-7 provides only `updated_at`, which changes on every check or edit. A shared `created_at` or position is needed (the Liste is epic 1, the toggle is epic 3).
- R20 and C10: the frequent order within a rayon stays stable and is never by frequency. Frequents are seeded (epic 1) and managed (epic 3), so an explicit `position` column is needed. Undefined: what happens to the order when an article's default rayon changes (R18)?
- Deferred says only the AD-4–AD-7 columns are invariants, so these columns are not guaranteed.

### F12 — The line-level rayon override is not in the invariant columns — **medium**

- R13: changing the rayon of a list item moves it to another group. The Assumption says the rayon chosen in quick-add becomes the default only for an article created on the fly, and otherwise changes only the list line. AD-11 mentions a "rayon d'une ligne", but AD-4 does not make it a line column, and nothing says whether the Revue and recipe merges (epic 2) keep a line's overridden rayon or the article default.
- Fix: add `rayon` (nullable override) to the AD-4 line columns and state the precedence: line override, then the article default.

### F13 — AD-6 narrows R11 without recording it — **low**

- R11 and EXPERIENCE (Revue row) allow "une ligne à deux quantités **ou** deux lignes". AD-6 forbids the first option. That is a valid choice inside the ticket's latitude, but it should be logged as a decision (it also shapes the R9 header counts and the R16 "en liste" check).

### F14 — The `liste` → `recettes` data reference is implicit — **low**

- The ER diagram links `WEEK_SELECTIONS` to `LIST_CONTRIBUTIONS`, and the source of a contribution is a week selection. The diagram text says "`liste` ne dépend jamais de `recettes`". Clarify that the source is an opaque `source_id` + `source_kind` with no Dart import or foreign key into the recettes tables. Otherwise epic 1 cannot create the table before epic 2 creates `week_selections`.

### F15 — Smaller items without a home in the spine — **low**

- Assumption (snackbar = inverse colours, inverse-primary action; contrast checked at build time): AD-12 is silent on the snackbar and on contrast checks. Add it to AD-12 or the Tests convention.
- C2: no rule forbids packages that add the INTERNET permission or analytics. Add a one-line convention: "aucune permission ni dépendance réseau ; seules galerie et appareil photo".
- C8 (48 dp targets, thumb zone): the Accessibilité convention cites C8 but covers only gesture equivalents. Add a minimum target size in the theme (`materialTapTargetSize`, min sizes).
- AD-13: epic 1 ships the shell before the Recettes branch exists. State whether epic 1 has a one-branch shell, or a placeholder Recettes branch so the first-launch rule holds.
- The Revue validation state (R3 "pas encore validées" vs "quitter la Revue n'ajoute rien"): whether leaving the Revue counts as validated is internal to epic 2. It is fine to leave it to the epic, but only if AD-3 says validation is committed by Ajouter à la liste.

## What did land correctly

- All 13 rayon codes (AD-11) match the DESIGN.md tokens, and AD-12 gives the theme a single owner. The C6 argile restriction is enforced by "no hex outside `core/theme`".
- AD-3's ownership (epic 1 creates Terminer, epic 2 adds the selection reset; Nouvelle liste and désélection go to epic 2) matches tickets.toml.
- C9 (only Nouvelle liste asks for confirmation) is consistent: AD-10 excludes R8.
- The four touch points sit with the epics named in the ticket (Deferred line). The picto pack being deferred matches the Notes decision.
- C4 microcopy goes through `strings_fr.dart`. The six-flow integration tests in epic 3 match the Decision.
- The tone ("le moins de friction possible", not competing) is respected: no backend, a single Undo, local-only data.
