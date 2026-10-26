# Rubric review — architecture-grocery-list (spine, altitude initiative)

Reviewer: rubric walker (good-spine checklist, reviewer-gate.md).
Inputs: spine, initiative ticket, tickets.toml (3 epics), run memlog.
Date: 2026-10-25.

## Verdict

The spine is solid on the domain side (ownership, provenance, units, undo, theme, navigation, rayons). It is **not ready to hand off yet**. The operational envelope has a hole that the delivery plan exposes: the app is in daily use on the phone from epic 1 onward, and the spine has no rule for schema migrations or seed upgrades. AD-8 and AD-9 as written also fail the ticket's own "export then import on a fresh install" Done-when. On top of that, the dependency graph contradicts the ownership map: `liste` and `recettes` need the route order and the settings that `reglages` owns, and `core/db` needs the feature tables. That is 4 high findings, 6 medium, 4 low.

---

## Checklist walk

| Checklist item | Result |
|---|---|
| Fixes the real divergence points for the epics and misses none | Partly. Most are fixed. Missed: migrations and seed upgrades (H2), photo storage (H3), settings and route-order ownership vs build order (H4), adding to a checked line (M1), line rayon snapshot vs override (M2), Revue correction on a merged line (M3), picto reference format (M5). |
| Every AD Rule is enforceable and actually prevents its divergence | Mostly. AD-8 and AD-9 together do not prevent the divergence they target (H1). AD-10 is silent on `updated_at` and on rows the action created (M4). The layer and dependency rules have no enforcement mechanism (L1). |
| Nothing in Deferred lets two epics diverge | Two leaks. "Variantes de build" deferred leaves the debug-over-release trap (M6). "Pack de pictos … leur source ne change aucun AD" is true for the source but not for the reference format that three epics share (M5). "Schéma détaillé des colonnes" hides the line-rayon and week-selection state semantics (M2). |
| Named tech is verified-current | Partly. The memlog records verification for Flutter, Dart, drift, flutter_riverpod and go_router only. drift_flutter 0.3.1, drift_dev 2.35.2, build_runner 2.17.1 and uuid 4.6.0 are unrecorded (L3). |
| Ratifies rather than contradicts a brownfield codebase | N/A (greenfield). |
| Covers every requirement in the ticket | Nearly. R21 plus Done-when ("restaure … le parcours, les réglages") is broken by H1. R1 photo through backup is not covered (H3). R22 on an already-installed phone is not covered (H2). R24 "coche instantanée sans animations" has no convention (L4). Every other R and C is mapped. |
| No new AD weakens an inherited one | N/A (no parent spine). |
| Every dimension the altitude owns is decided, deferred or open | Gaps: **schema migrations** (silent; only a `migrations` folder in the seed), **seed upgrade on app update** (AD-8 says "once, at first launch", which contradicts incremental delivery), **media storage** (silent), **signing-key custody / app id** (partly). Deployment, environments, CI (deferred), logging (none, decided) and error handling (convention) are covered, if thinly. |

---

## Findings

### H1 — Seed timestamps and singleton ids break the import Done-when [high]

**Where:** AD-7, AD-8, AD-9.

**Problem.**
1. Seed rows are inserted at first launch. Under AD-7 their `updated_at` is therefore the install time. Take an export made on phone A, where Antoine edited a seed article or deleted an example recipe at time T1. Import it on a fresh install B, which was seeded at T2 > T1. Last-writer-wins keeps B's pristine seed row: the edit is lost and the deleted recipe comes back. That fails the ticket's Done-when: "Un export suivi d'un import sur une installation neuve restaure les recettes, le catalogue, les fréquents…".
2. AD-8 fixes the UUIDs of seed content only. The `settings` row and the route order (R19) are created per install with fresh v4 UUIDs, so importing them adds a second settings row and a second route order instead of replacing them. That fails "restaure … le parcours, les réglages".

**Fix (autofix into AD-8):**
- "Seed rows are inserted with `updated_at = 0` (or a fixed seed timestamp written in the asset), so any user change wins on import."
- "Singleton rows (settings, route order) use fixed, well-known UUIDs written in the code, the same on every install."
- If the route order is stored as one row per rayon, say so and give each row a fixed id derived from the rayon code. Otherwise store it as a single row.

### H2 — No rule for schema migrations or seed upgrades, while the app ships to the phone from epic 1 [high]

**Where:** AD-8, Structural Seed (`core/db/ … migrations`), Deferred. Epic 1 delivers "L'app, installée sur le téléphone d'Antoine".

**Problem.**
- Epic 2 adds `recipes`, `recipe_ingredients` and `week_selections`. Epic 3 may add columns. Nothing says how the installed database is upgraded, so each epic could choose differently: a destructive recreate, ad-hoc `onUpgrade`, or a reinstall that wipes the real list.
- AD-8 says seed content is inserted "une fois, au premier lancement". On the phone that already runs the epic-1 build, epic 2's `recettes.json` would never be inserted. The deferred picto pack will also change article picto references after the catalogue is already seeded.
- The "first launch opens on Recettes" flag (R22, AD-13) has no owner. An epic-1 install may or may not count as "launched" once epic 2 arrives.

**Fix:** add an AD for "Schema and seed upgrades".
- A single Drift `schemaVersion` in `core/db`, with stepwise `MigrationStrategy.onUpgrade` (one step per story that changes the schema). Schema snapshots via `drift_dev schema dump`, plus a generated migration test per step.
- The seed loader runs on every start and keys on a `seed_version` per asset, stored in settings. It inserts the seed UUIDs that are missing. It never overwrites a row the user changed (`updated_at > 0`) and never resurrects a row with `deleted_at`.
- The first-launch flag lives in the settings singleton, and epic 1 creates it.
- Also state how `format_version` relates to `schemaVersion`. An import of an older known `format_version` is migrated, not rejected.

### H3 — Recipe photo storage and its backup are undecided [high]

**Where:** R1, R21, Done-when ("restaure les recettes"), AD-9 (JSON of tables only).

**Problem.** Epic 2 stores photos and epic 3 exports them, which makes this a cross-epic seam. A photo from the gallery or the camera is a file. If epic 2 stores a content URI or an absolute cache path, it will not survive reinstall or import. The JSON export of tables carries no image bytes, so restoring a backup on a fresh install gives recipes with dangling or missing photos.

**Fix:** add a rule, either in AD-9 or in a new AD.
- "A recipe photo is copied into the app documents directory as `photos/<recipe-photo-uuid>.jpg` (re-encoded and size-capped). The table stores only that relative name."
- "The export is a single archive (zip) holding `data.json` plus `photos/`. The import restores both in the same all-or-nothing step." Base64 inside the JSON would also work.
- Name the owner: epic 2 writes the photo files, `core/backup` exports them.

### H4 — The dependency graph contradicts the ownership map and the build order [high]

**Where:** the Invariants diagram, AD-2, AD-1, Structural Seed.

**Problem.**
1. AD-2 gives the route order and the settings to `reglages`. But `liste` (grouping R9, Panneau + R15, keep-awake R14, disabling grouping R9) and `recettes` (Revue grouping R4) must read them. The diagram allows only `liste -> catalogue` and `recettes -> liste, catalogue`, so both reads are forbidden. In addition, `reglages` is built by epic 3, yet epic 1 needs the default route order and epic 2 needs the first-launch flag. Every epic will improvise its own read path or its own temporary order.
2. Drift's `@DriftDatabase(tables: [...])` in `lib/core/db/` has to import the table classes. If those classes live in `features/*/data/` (Layer table), then `core` depends on features, which inverts the solid arrow `DATA -> CORE`. `core/backup` has the same problem, since it reads every feature's table.

**Fix:**
- Move settings and the route order into `lib/core/settings/`, with a `SettingsRepository` created by epic 1 that holds defaults, the first-launch flag and `seed_version`. Epic 3 adds only the UI and the remaining settings. Alternatively, allow the arrows `liste -> reglages` and `recettes -> reglages` and state that epic 1 creates the `reglages` data layer.
- Declare all Drift table definitions in `lib/core/db/tables/`, with ownership enforced by "only the owner's repository writes them". Otherwise, move `AppDatabase` and `backup` up to `lib/app/`.
- Update the Layer table, the diagram and AD-2 to match.

### M1 — Adding an item that is already checked [medium]

**Where:** AD-4 (uniqueness "parmi les lignes non supprimées"), R10, R16, R5.

**Problem.** Take a checked line in « Cochés » and a new contribution for the same (article, unit). It can come from a frequent tap or search in epic 1, or from "Ajouter à la liste" in epic 2. Nothing says whether the contribution adds to the hidden checked line, unchecks it, or creates a new line. Epic 1 and epic 2 will each pick one. R16 ("cocher repasse le fréquent à hors liste") suggests that a later tap should make the item reappear.

**Fix (AD-4):** "Adding a contribution to a checked line unchecks it, and the line returns to its rayon." Alternatively: "Uniqueness applies to unchecked lines; a checked line is never added to." Also define frequent and search "retirer" (R16, Notes): it removes the manual contribution only, or it soft-deletes the whole line.

### M2 — Line rayon: snapshot or override? [medium]

**Where:** AD-11 ("rayon d'un article ou d'une ligne"), R13, R18, Notes Assumption, Deferred "schéma détaillé".

**Problem.** Epic 1 (quick-add rayon, R13 change of rayon), epic 2 (lines created from Revue) and epic 3 (editing an article's default rayon, R18 "vaut pour les ajouts suivants") must agree on one point. Does a line copy its rayon at creation, or hold a nullable override on top of the article's rayon? With an override, editing an article in epic 3 moves existing list lines. With a snapshot, it does not.

**Fix:** "A line stores its rayon code, copied from the article when the line is created. Editing an article never changes existing lines."

### M3 — A Revue correction on an ingredient merged from several recipes [medium]

**Where:** AD-4 ("une correction en Revue fixe la quantité de la contribution de la recette"), R4 (Revue adds up quantities across the newly validated recipes), R6.

**Problem.** A Revue row can merge two recipes. When it is corrected, "the recipe's contribution" is ambiguous, and deselecting one of the two recipes later removes an undefined amount.

**Fix:** pick one rule and write it in AD-4. Option 1: the corrected value is split across the merged recipes in proportion to their original quantities. Option 2: it is assigned to the first recipe, and the others contribute 0.

### M4 — AD-10 Undo is silent on `updated_at` and on created rows [medium]

**Problem.**
- If Undo restores old row values verbatim, including the old `updated_at`, it breaks AD-7 ("toute écriture met `updated_at` à jour") and the import merge.
- For rows the action created (contributions, lines), the "état d'avant" is "did not exist". The rule does not say these rows are soft-deleted.
- Terminer les courses touches `list_lines` and `week_selections`. In "lignes qu'elle touche", "lignes" can be read as list lines only.

**Fix:** "Undo rewrites the snapshot of every row the action touched, in any table, with a fresh `updated_at`. Rows the action created are soft-deleted. An import clears the Undo slot."

### M5 — Picto reference format shared by three epics, left in Deferred [medium]

**Problem.** Epic 1 (catalogue, Panneau +), epic 2 (Revue, card fallback R2) and epic 3 (picto grid in Fiche article) all read the article's picto field before the pack exists. Deferred says the source "ne change aucun AD", but the reference format is a seam, and the AI-generated seed has to fill it now.

**Fix:** "An article stores a stable `picto_key` (kebab-case). A single resolver `lib/core/pictos/` maps keys to assets and falls back to a neutral placeholder tinted with the rayon colour. Changing the pack changes only the resolver and the assets."

### M6 — Debug builds can wipe the real data on the phone [medium]

**Where:** Deferred ("variantes de build"), the delivery diagram (locally signed release APK).

**Problem.** Antoine develops on the same phone he shops with. The debug and release builds share one applicationId but different signatures, so `flutter run` over the release fails with a signature mismatch. The usual way out is to uninstall, which deletes the database. If the local signing key is lost, no update can be installed either, and an uninstall plus loss of data follows.

**Fix:** under Stack or Delivery, write: "Release applicationId `<id>`. Debug uses `applicationIdSuffix '.debug'` so both apps coexist. The release keystore is backed up outside the dev machine, and its location is recorded outside the repository. Export a backup before every release install." This is the one build variant worth deciding now.

### L1 — The layer and ownership rules are not mechanically enforced [low]

AD-1, AD-2 and the diagram rely on discipline. **Fix:** add a test (or an `analysis_options` custom lint) that scans the imports of `lib/features/liste/**` for `features/recettes`, and widget files for `Repository` writes. Add an export test asserting that the set of exported tables equals `db.allTables`, which makes AD-9's "toute nouvelle table" self-enforcing.

### L2 — An import can break the (article, unit) uniqueness [low]

When the import merges into a non-empty list from another phone, two live lines with different UUIDs for the same (article, unit) can survive and violate AD-4. **Fix:** "After an import, live lines with the same (article, unit) are merged: their contributions are moved to the line with the most recent `updated_at`, and the others are soft-deleted." Alternatively, document that the current list from the file replaces the local one.

### L3 — Unrecorded version checks [low]

drift_flutter 0.3.1, drift_dev 2.35.2 (the minor differs from drift 2.35.3, which is normal but should be confirmed as compatible), build_runner 2.17.1 and uuid 4.6.0 have no verification line in the memlog. **Fix:** verify them on pub.dev and log each one.

### L4 — Small coverage tails [low]

- R24 "coche instantanée quand les animations sont désactivées" has no convention. Add one under Accessibility: honour `MediaQuery.disableAnimations`.
- R20 "leur ordre dans chaque rayon reste stable" implies a `position` column on `frequents` that epic 1 seeds and epic 3 edits. Name it as an invariant column in the Deferred schema line.
- The error convention does not cover a failed seed or database open at startup. Add: blocking error screen, no partial seed (seed in one transaction).

---

## Coverage map check

Every R1–R24 and C1–C10 is bound by some AD, convention or Deferred entry. However, C2 (no permissions beyond gallery and camera) and C10 have no row in the Capability map. That is acceptable, since C10 is UX-only, but C2 should point to the Deferred "paquets propres à un epic" entry with a note: "photo picker must not request storage permission beyond gallery and camera". Coverage gaps where a requirement is mapped but the architecture does not actually deliver it: R21 plus Done-when (H1, H3) and R22 on an upgraded install (H2).

## Suggested order of fixes

H4 first (it reshapes AD-2 and the layer table), then H2 and H1 (a new AD plus edits to AD-8), then H3. The mediums are one or two sentences each in AD-4, AD-10 and AD-11, plus a new picto line and a Delivery line.
