# Currency review: architecture-grocery-list

- **Lens:** check that each committed decision was researched on the web or tested against reality, not asserted from training data. That covers current versions, whether each named technology still exists and fits, and the live defaults of the starter (`flutter create`).
- **Reviewed:** `architecture-grocery-list.md` (spine) and `.memlog.md`.
- **Date:** 2026-10-25
- **Method:**
  - Read the pub.dev API JSON for every Stack package and its transitive codegen packages.
  - Read the Flutter release JSON.
  - Read the `flutter create` templates and the Flutter Gradle plugin at tag `3.47.8`.
  - Read the official docs (drift, Riverpod, go_router, material_ui, uuid, Flutter blog and breaking-change notes).
  - Ran `dart pub get --dry-run` on the pinned codegen stack, with and without `riverpod_generator`.
  - Inspected the local SDK at `C:\flutter`.

## Verdict

**Mostly current, with one high-severity gap.** All ten Stack rows match the latest stable releases on 2026-10-25, and the memlog's `version` entry holds up. The named APIs (drift `driftDatabase`/`watch`/`transaction`, Riverpod 3 Notifier, `StatefulShellRoute`, `Uuid().v4()`, `ColorScheme.fromSeed`, `ThemeExtension`) all still exist and fit. Two things were missed:

- **Material has left the Flutter SDK.** It is now the `material_ui` package, and go_router 18 already depends on it. The in-SDK library is scheduled for formal deprecation in the November stable. The spine never mentions this.
- **The deferred Riverpod generator cannot resolve against the pinned `build_runner 2.17.1`.** I confirmed this with a pub solve.

The memlog's `version` entry lists only Flutter, drift, flutter_riverpod and go_router. drift_flutter, drift_dev, build_runner, uuid and the Dart constraints were not recorded as verified. They do check out (see the table below).

## Stack rows: verification

| Row | Spine | Live (2026-10-25) | Published | SDK constraint | Status |
|---|---|---|---|---|---|
| Flutter stable | 3.47.8 | 3.47.8 | 2026-10-23 | n/a | OK |
| Dart | 3.13.7 | 3.13.7 (bundled with 3.47.8) | 2026-10-23 | n/a | OK |
| drift | 2.35.3 | 2.35.3 | 2026-10-23 | `>=3.10.0 <4.0.0` | OK |
| drift_flutter | 0.3.1 | 0.3.1 | 2026-07-11 | `>=3.10.0 <4.0.0` | OK (see F4) |
| drift_dev | 2.35.2 | 2.35.2 | 2026-10-23 | `>=3.10.0 <4.0.0`; drift `>=2.30.0 <2.36.0`; build `>=3.0.0 <6.0.0` | OK, compatible with drift 2.35.3 |
| build_runner | 2.17.1 | 2.17.1 (2.17.0 retracted) | 2026-10-14 | `^3.11.0`; build `>=5.0.0 <5.1.0` | OK alone; conflicts with riverpod_generator (F2) |
| flutter_riverpod | 3.4.3 | 3.4.3 | 2026-09-03 | `^3.12.0` | OK |
| go_router | 18.1.1 | 18.1.1 | 2026-10-20 | `^3.12.0`, Flutter `>=3.44.0` | OK; already on material_ui (F1) |
| uuid | 4.6.0 | 4.6.0 | 2026-07-15 | `>=3.0.0 <4.0.0` | OK |
| Android target | APK signed locally | template signs release builds with the debug key | n/a | n/a | needs a story step (F8) |

**drift 2.35.3 and drift_dev 2.35.2 work together.** drift and drift_dev are versioned separately: drift_dev 2.35.2 accepts drift `>=2.30.0 <2.36.0`. A real solve of `drift 2.35.3 + drift_dev 2.35.2 + build_runner 2.17.1 + uuid 4.6.0 + riverpod 3.4.3` succeeds. It resolves to build 5.0.0, analyzer 14.5.0, source_gen 4.3.1 and sqlite3 3.8.0.

**Dart SDK constraints.** The highest floors in the set are Dart `^3.12.0` (flutter_riverpod, go_router, riverpod_generator) and `^3.13.0` (material_ui, riverpod_lint). Dart 3.13.7 satisfies all of them.

## Findings

### F1: HIGH. Material is now the `material_ui` package; the spine is silent

- **What the web says:**
  - Since August 2026, Material and Cupertino ship as standalone packages: `material_ui` 1.8.0 (2026-10-20, requires Flutter `>=3.47.0` and Dart `^3.13.0`) and `cupertino_ui` 1.1.4.
  - The Flutter 3.47 post says the in-SDK design libraries "are scheduled for formal deprecation in the upcoming Fall stable release in November."
  - The migration command is `dart fix --apply --code=migrate_design_widgets`. It rewrites `package:flutter/material.dart` to `package:material_ui/material_ui.dart`. It has a known pubspec bug: run `flutter pub add material_ui` first.
  - Mixed trees need a `MaterialUiCompatibilityBridge` that "bridges `ThemeData` and `MaterialLocalizations`". This means the `ThemeData` from each library is a separate type, and a theme built with one is not seen by widgets built with the other.
  - go_router 18.0.0 changelog: "Migrates to material_ui and cupertino_ui."
  - The `flutter create` template at 3.47.8 still writes `import 'package:flutter/material.dart';` (checked `templates/app/lib/main.dart.tmpl`).
- **Impact on the spine:**
  - AD-12 makes `lib/core/theme/` the only builder of `ThemeData`, `ColorScheme.fromSeed` and `ThemeExtension`.
  - Every `ui/` folder in all three epics imports Material.
  - If the first story keeps the template import, every file will need migrating about a month into the build, once deprecation warnings land.
  - If epics mix the two imports, the theme silently fails to apply across the boundary. This is the kind of cross-epic divergence the spine exists to prevent.
- **Fix:**
  - Add a Stack row `material_ui | 1.8.0`.
  - Add a Consistency Convention: "Material is imported only through `package:material_ui/material_ui.dart`; never `package:flutter/material.dart`."
  - The first story runs `flutter pub add material_ui`, then the `dart fix` migration, on the generated template.
  - Note that `flutter_localizations` delegates now come from `material_ui` (`GlobalMaterialLocalizations.delegates`) if French locale delegates are used (C4).
  - The alternative is to explicitly record "stay on `flutter/material.dart` until the deprecation, then migrate in one pass", with a rationale. Today the choice is simply missing.

### F2: MEDIUM. `build_runner 2.17.1` cannot resolve with `riverpod_generator`

- **What the web and a reality check say:**
  - Every `riverpod_generator` from 3.0 upward, including the latest 4.0.9 (2026-09-03), requires `build >=3.0.0 <5.0.0`.
  - `build_runner 2.17.1` requires `build >=5.0.0 <5.1.0`. Its changelog says it requires "`build` 5.0.0, which is the retracted `build` 4.1.0 republished as a major version", and that it "allows only one minor version of `build`".
  - Pub solve output: *"riverpod_generator >=3.0.0 is incompatible with build_runner >=2.17.1 … Consider downgrading your constraint on build_runner: dart pub add dev:build_runner:^2.16.2"*.
  - With `build_runner 2.16.2`, the full set (drift_dev 2.35.2, riverpod_generator 4.0.9, riverpod_annotation 4.0.7) resolves to build 4.0.11.
  - drift's own setup page recommends `build_runner: ^2.16.2`, not 2.17.1.
- **Impact:** the Deferred line "Générateur de code Riverpod : au choix de la première story de l'epic 1" is a live decision that the pinned Stack row already blocks. If the first story picks the generator, it must also change a Stack pin.
- **Fix:** do one of the following.
  - Pin `build_runner 2.16.2`, which works with drift_dev and riverpod_generator alike.
  - Annotate the Deferred line: "choosing riverpod_generator requires build_runner ^2.16.2 until riverpod_generator accepts build 5".
  - Decide now not to use Riverpod codegen. Riverpod's docs say codegen is "optional" and advise it "only if you already use code-generation for other things". Drift already uses build_runner, and macros "have been cancelled".

### F3: MEDIUM. The dev machine is on Flutter 3.44.5 / Dart 3.12.2, and `flutter upgrade` is blocked

- **Reality check:**
  - `C:\flutter\bin\cache\flutter.version.json` shows `frameworkVersion 3.44.5`, `dartSdkVersion 3.12.2` (2026-07-06).
  - Running `flutter --version` fails its tag fetch with `SSL certificate problem: unable to get local issuer certificate` against `github.com/flutter/flutter.git`.
  - The pinned Stack needs 3.47.8 / Dart 3.13.7, and `material_ui` (F1) and `riverpod_lint` require Dart `^3.13`.
  - Everything else in the Stack happens to resolve on Dart 3.12.2, so nothing fails loudly. That makes the mismatch easy to miss.
- **Fix:**
  - Add a setup prerequisite before the first story: fix git TLS (for example `git config --global http.sslBackend schannel` on Windows, or install the intercepting root CA), then `flutter upgrade` to 3.47.8.
  - Optionally pin `environment: sdk: ^3.13.0` and `flutter: '>=3.47.0'` in `pubspec.yaml` so a stale SDK fails fast.

### F4: LOW. sqlite3 3.x build hooks: `sqlite3_flutter_libs` is end-of-life, and the first build downloads binaries

- **What the web says:**
  - drift 2.35.3 depends on `sqlite3 ^3.4.0` (3.8.0 resolved).
  - sqlite3 3.x "relies on hooks to automatically bundle a pre-compiled version of SQLite". The prebuilt binaries "are downloaded from the GitHub releases of this package" at build time.
  - `sqlite3_flutter_libs 0.6.0+eol` "no longer does anything". drift_flutter 0.3.1 still pulls it in transitively, which is harmless.
  - The upgrade guide says to stop depending on it and to remove `applyWorkaroundToOpenSqlite3OnOldAndroidVersions` and `open.overrideFor`.
- **Impact:**
  - Older drift tutorials (and training-data habits) add `sqlite3_flutter_libs` and the Android workaround. Both are now wrong.
  - The first `flutter build apk` needs network access to GitHub. Given the TLS problem in F3, it may fail on this machine.
- **Fix:**
  - Add one line to the Stack or Conventions: "do not add `sqlite3_flutter_libs`; no sqlite3 workaround code".
  - Verify the first release build downloads the sqlite3 binaries. If it cannot, use the hook's custom source-build option (the NDK `28.2.13676358` is already set by the template).

### F5: LOW. `path_provider` and the DB directory are not stated

- **What the web says:**
  - drift's Flutter setup lists `path_provider: ^2.1.6` as a direct dependency.
  - Its example sets `native: DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory)`. Otherwise `driftDatabase` stores `<name>.sqlite` in `getApplicationDocumentsDirectory()`.
- **Impact:** a minor choice, but AD-1 owns the single `AppDatabase`. Picking the directory later means a move migration.
- **Fix:** state `driftDatabase(name: 'grocery_list')`, plus the chosen directory. Add `path_provider 2.1.6` to the Stack if the support directory is used.

### F6: LOW. AD-7 millisecond timestamps vs drift's `dateTime()` default

- **What the web says:** drift `dateTime()` columns are stored by default as "INTEGER Unix timestamps in seconds", with "no … sub-second accuracy". `store_date_time_values_as_text` switches to ISO text.
- **Impact:** AD-7 requires `updated_at` and `deleted_at` to be integer milliseconds UTC. AD-9's "most recent `updated_at` wins" merge depends on that precision. A story that uses `dateTime()` gets seconds and breaks the tie-breaking. Another story that uses `integer()` gets ms, so epics diverge.
- **Fix:** add to the Données & formats convention: "`updated_at`/`deleted_at` are `IntColumn` (`integer()`) holding `DateTime.now().toUtc().millisecondsSinceEpoch`; no `dateTime()` columns."

### F7: LOW. Test convention: in-memory DB must close streams synchronously

- **What the web says:** drift's testing guide uses `AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true))`. It notes that by default a stream stays open "for one event loop iteration", and in widget tests "it's illegal to keep these timers open after a test concludes".
- **Impact:** the convention calls for "tests … sur une base Drift en mémoire" and "un test de widget par écran". Screens watch streams (AD-1), so widget tests will fail with pending-timer errors unless this flag is set.
- **Fix:**
  - Add the exact constructor to the Tests convention.
  - The `AppDatabase([QueryExecutor? e])` constructor pattern from the drift setup docs makes the executor injectable.

### F8: INFO. `flutter create` 3.47.8 Android defaults: no conflict, two story steps

- **Defaults (verified from the templates and `FlutterExtension.kt` at tag 3.47.8):**
  - Kotlin DSL (`build.gradle.kts`, `settings.gradle.kts`).
  - `minSdk = flutter.minSdkVersion` = 24; `compileSdk`/`targetSdk` = 36; `ndkVersion` = `28.2.13676358`.
  - Java 17.
  - AGP 9.1.0 / KGP 2.4.0 / Gradle 9.3.1, per the 3.47 post. The Gradle error floors are AGP 8.11.1, KGP 2.2.20 and Gradle 8.14.
- **Conflicts:** none with drift, sqlite3 hooks, Riverpod or go_router.
- **Story steps:**
  1. The template's release `buildTypes` uses `signingConfig = signingConfigs.getByName("debug")`. The delivery decision ("APK release signé localement, clé hors dépôt") needs a story that adds a `release` signingConfig loaded from a gitignored `key.properties`. Kotlin DSL syntax applies, not the Groovy snippets in older guides.
  2. `gradle.properties` ships `android.newDsl=false` and `android.builtInKotlin=false` compatibility flags for AGP 9. The deferred epic-specific plugins (photo, keep-screen-on, share, file picker) must be checked for AGP 9 / KGP 2.4 compatibility when chosen. For example, `wakelock_plus` 1.8.2 (2026-10-22) requires Flutter `>=3.44`.

### F9: INFO. AD-12 APIs are current; two clarifications

- **What the web says:**
  - `ColorScheme.fromSeed` exists in material_ui 1.8.0 and is not deprecated. Its parameters include `dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot` and `contrastLevel`; `surfaceTint` is a plain, non-deprecated override.
  - `ThemeExtension<T>` exists (override `copyWith` and `lerp`; register via `ThemeData.extensions`; read via `Theme.of(context).extension<T>()`).
  - Since Flutter 3.22, "the default surfaceTintColor for all widgets is now null", and M3 surfaces come from the tone-based `surfaceContainer*` roles.
- **Clarifications:**
  1. `tonalSpot` (the default) shifts the seed, and "the seed color may not appear unchanged". If DESIGN.md's `primary` hex must be exact, the "puis surcharges" step must override `primary` (and related roles) explicitly, or use `DynamicSchemeVariant.fidelity`.
  2. Setting `surfaceTint` to transparent is now redundant but harmless. Keep it as belt-and-braces.

### F10: INFO. Riverpod 3, go_router, drift streams, uuid: current

- **Riverpod 3.4.3:**
  - Notifier / AsyncNotifier / StreamNotifier are the current API.
  - `StateProvider`, `StateNotifierProvider` and `ChangeNotifierProvider` moved to `package:riverpod/legacy.dart` "to highlight that those providers are not recommended anymore".
  - Since 3.0, providers that fail on init auto-retry with exponential backoff (200 ms to 6.4 s).
  - Listeners pause when their widget is not visible (TickerMode). An offstage `StatefulShellRoute.indexedStack` branch therefore pauses its `watch` providers. This fits AD-1, since the DB stays the source of truth and the stream re-emits a snapshot on resume.
  - Suggested convention: "no `legacy.dart` providers". Also note that auto-retry does not apply to commands, so the snackbar convention stands.
- **go_router 18.1.1:**
  - `StatefulShellRoute` / `.indexedStack` (recommended), `StatefulShellBranch` and `StatefulNavigationShell.goBranch(index)` are current and not deprecated.
  - 18.1.1 "Preserves and updates loaded `StatefulShellRoute` branches when the routing configuration changes".
  - URLs have been case-sensitive since 15.0.0.
- **drift:**
  - `watch()`, `watchSingle()` and `watchSingleOrNull()` emit an initial snapshot. Invalidation is per table; custom queries need `readsFrom`.
  - Inside `transaction(() async {...})` every query must be awaited. Outside streams see changes only after commit. Nested transactions are supported on `NativeDatabase`, which fits AD-3 actions that call repositories that themselves open transactions.
  - Transactions "can't schedule timers", so the AD-10 Undo snackbar timer must live outside the transaction.
- **uuid 4.6.0:** `Uuid().v4()` uses a cryptographically strong RNG. Drift supports a text primary key via `primaryKey => {id}` plus `clientDefault(() => uuid.v4())`. The drift docs note that `clientDefault` runs only in Dart, which suits AD-8, because seeded rows carry their own fixed UUIDs.

## Sources

- Flutter releases JSON: https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json
- pub.dev API (versions, dates, constraints): https://pub.dev/api/packages/{drift,drift_flutter,drift_dev,build_runner,flutter_riverpod,riverpod_generator,riverpod_annotation,riverpod_lint,go_router,uuid,sqlite3,sqlite3_flutter_libs,source_gen,material_ui,cupertino_ui,path_provider,wakelock_plus}
- Flutter 3.47 release post: https://flutter.dev/blog/whats-new-in-flutter-3-47
- Material/Cupertino decoupling: https://flutter.dev/blog/decoupling-material-cupertino
- material_ui: https://pub.dev/packages/material_ui
- ColorScheme.fromSeed (material_ui): https://pub.dev/documentation/material_ui/latest/material_ui/ColorScheme/ColorScheme.fromSeed.html
- ColorScheme.surfaceTint: https://pub.dev/documentation/material_ui/latest/material_ui/ColorScheme/surfaceTint.html
- ThemeExtension: https://pub.dev/documentation/material_ui/latest/material_ui/ThemeExtension-class.html
- New ColorScheme roles (3.22 surface tint change): https://docs.flutter.dev/release/breaking-changes/new-color-scheme-roles
- flutter create templates @3.47.8: https://github.com/flutter/flutter/tree/3.47.8/packages/flutter_tools/templates/app (`lib/main.dart.tmpl`, `android-kotlin.tmpl/app/build.gradle.kts.tmpl`, `android.tmpl/settings.gradle.kts.tmpl`, `android.tmpl/gradle.properties.tmpl`)
- Flutter Gradle defaults: https://github.com/flutter/flutter/blob/3.47.8/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt, https://github.com/flutter/flutter/blob/3.47.8/packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt
- drift setup: https://drift.simonbinder.eu/setup/
- drift testing: https://drift.simonbinder.eu/testing/
- drift transactions: https://drift.simonbinder.eu/dart_api/transactions/
- drift streams: https://drift.simonbinder.eu/dart_api/streams/
- drift tables (DateTime storage, text PK): https://drift.simonbinder.eu/dart_api/tables/
- drift_flutter: https://pub.dev/packages/drift_flutter
- sqlite3: https://pub.dev/packages/sqlite3
- sqlite3 v3 upgrade notes: https://github.com/simolus3/sqlite3.dart/blob/main/UPGRADING_TO_V3.md
- sqlite3_flutter_libs (EOL): https://pub.dev/packages/sqlite3_flutter_libs
- Riverpod 3 what's new: https://riverpod.dev/docs/whats_new
- Riverpod code generation: https://riverpod.dev/docs/concepts/about_code_generation
- riverpod_generator changelog: https://pub.dev/packages/riverpod_generator/changelog
- build_runner changelog: https://pub.dev/packages/build_runner/changelog
- go_router StatefulShellRoute: https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html
- go_router changelog: https://pub.dev/packages/go_router/changelog
- uuid: https://pub.dev/packages/uuid
- Local reality checks:
  - `C:\flutter\bin\cache\flutter.version.json`.
  - `dart pub get --dry-run` on scratch pubspecs: drift 2.35.3 / drift_dev 2.35.2 / build_runner 2.17.1 / uuid 4.6.0 / riverpod 3.4.3 resolves; adding riverpod_generator 4.0.9 fails; with build_runner 2.16.2 it resolves.
