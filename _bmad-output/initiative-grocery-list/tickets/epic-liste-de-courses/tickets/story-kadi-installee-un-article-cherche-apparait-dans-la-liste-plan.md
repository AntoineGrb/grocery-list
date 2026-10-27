---
title: 'Kadi installée : un article cherché apparaît dans la Liste'
type: 'feature'
ticket: '1'
created: '2026-10-26'
status: done
baseline_revision: 'd79abc80acb8833e4dc2d099fd5efe1bec7aa18d'
route: 'full'
route_source: 'auto'
risk: 'high'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Kadi n'existe pas encore : aucun projet, aucune base, rien d'installé sur le téléphone d'Antoine. Les stories suivantes ont besoin d'un socle qui respecte déjà l'architecture.

**Approach:** Parcours traceur le plus fin à travers toutes les couches : projet Flutter Kadi, thème, routeur, base Drift v1 complète pour l'epic, contenu fourni minimal, recherche dans le Panneau +, ajout d'un article et Liste groupée par rayon, build release installé.

## Boundaries & Constraints

**Always:** respecter AD-1 à AD-18 (tables dans `lib/core/db/tables/`, colonnes `id`/`updated_at`/`deleted_at`, horloge monotone, réglages en ligne unique à id fixe, contenu fourni à UUID figés et `updated_at = 0`, rayons par code, aucun hex hors `lib/core/theme/`, Material par `package:material_ui/material_ui.dart`, microcopie dans `strings_fr.dart`, `Semantics` sur chaque élément interactif, cibles ≥ 48 dp). Versions de la Stack du spine, `build_runner` 2.16.2.

**Never:** pas de générateur Riverpod ; pas de `sqlite3_flutter_libs` ; pas de colonne `dateTime()` ; pas de fréquents, coche, quantité saisie, Créer « … », retrait par second tap, Annuler, Paramètres (stories 1.2 à 1.8, epic 3) ; pas de fonctionnalité Recettes au-delà de son message d'état vide ; pas de réseau.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Premier démarrage | base vide | 7 articles insérés, réglages par défaut, Liste vide avec « Ta liste est vide… » | — |
| Redémarrage | articles déjà présents ou supprimés | rien d'inséré ni modifié | — |
| Recherche | « lait », « LAIT », « lâit » | résultat Lait (picto, nom, Crèmerie) | — |
| Ajout | tap sur Lait | une ligne Lait sous Crèmerie, contribution `ajout` sans quantité | — |
| Second ajout | tap sur Lait déjà en liste | toujours une seule ligne (contribution ajoutée à la ligne non cochée) | — |
| Recherche vide ou sans résultat | « » ou « pesto » | aucune ligne de résultat | — |
| Base illisible | échec d'ouverture ou du chargeur | écran d'erreur bloquant, rien de partiel | transaction annulée |

</intent-contract>

## Code Map

Projet neuf : aucun code existant. Racine du projet Flutter = racine du dépôt (`grocery-list/`), à côté de `_bmad/` et `_bmad-output/`, qui restent intacts. Arborescence cible : Structural Seed du spine.

## Tasks & Acceptance

**Execution:**
- [x] HITL Antoine -- Flutter 3.47.8 / Dart 3.13.7 en place, clé de release créée hors dépôt (`C:/Users/admin/kadi-release.jks`, alias `kadi`), identifiant `fr.antoinegrb.kadi` confirmé (2026-10-26) -- prérequis du build et de material_ui.
- [x] `android/key.properties` -- créer le fichier, ignoré par git, avec `storeFile=C:/Users/admin/kadi-release.jks` et `keyAlias=kadi` ; les deux mots de passe restent vides et Antoine les inscrit lui-même (HITL) -- la clé ne quitte pas son poste.
- [x] racine -- `flutter create --org fr.antoinegrb --project-name kadi --platforms android .`, puis `dart fix --apply --code=migrate_design_widgets` -- starter retenu.
- [x] `pubspec.yaml` -- dépendances épinglées du spine, `assets/seed/` -- Stack.
- [x] `android/app/build.gradle.kts`, `AndroidManifest.xml` -- applicationId `fr.antoinegrb.kadi`, libellé « Kadi », debug `applicationIdSuffix ".debug"`, release signée par `key.properties` -- convention Livraison.
- [x] `lib/core/db/tables/` -- `articles`, `frequents`, `list_lines`, `list_contributions`, `settings` avec les colonnes d'AD-4 à AD-8 et AD-17 -- base v1 de l'epic.
- [x] `lib/core/db/app_database.dart` + `drift_schemas/` -- `schemaVersion = 1`, `driftDatabase`, dump du schéma -- AD-14.
- [x] `lib/core/clock/`, `lib/core/rayons/`, `lib/core/settings/`, `lib/core/units/` (affichage sans quantité seulement) -- AD-7, AD-11, AD-2.
- [x] `lib/core/db/seed/` + `assets/seed/articles.json` -- chargeur à chaque démarrage ; Lait (cremerie, piece), Œufs (cremerie, piece), Tomates (fruits-legumes, g), Courgettes (fruits-legumes, g), Oignons (fruits-legumes, piece), Riz (epicerie-salee, g), Lardons (viande-poisson, g), UUID v4 figés, `seed_version` 1 -- AD-8.
- [x] `lib/core/theme/`, `lib/core/pictos/`, `lib/core/strings/strings_fr.dart` -- tokens clair et sombre, `ThemeExtension` des rayons, résolveur à repli neutre -- AD-12, AD-18.
- [x] `lib/core/router/` + `lib/main.dart` -- `StatefulShellRoute` Recettes / Liste, ouverture sur Liste, écran d'erreur bloquant -- AD-13.
- [x] `lib/features/catalogue/` -- `normalizeName`, recherche sur les articles actifs -- AD-17.
- [x] `lib/features/liste/` -- repository (ajout = ligne + contribution `ajout`), Liste groupée par rayon dans l'ordre du parcours avec compteur, état vide, FAB +, Panneau + (recherche focalisée, lignes de résultat) -- AD-1, AD-4.
- [x] `test/` -- repositories et chargeur sur Drift en mémoire, widgets avec `closeStreamsSynchronously: true`, test d'interdiction d'imports, test de migration v1 -- conventions Tests.
- [ ] HITL Antoine -- `flutter build apk --release`, installer sur le téléphone -- Done when.

**Acceptance Criteria:**
- Given une installation neuve, when Antoine ouvre Kadi, then la Liste s'affiche avec « Ta liste est vide. Choisis tes recettes de la semaine ou ajoute un article avec +. », et l'onglet Recettes montre « Pas encore de recette. Ajoute ta première avec +. ».
- Given la Liste, when il touche le FAB +, tape « lait » et touche Lait, then le Panneau + reste ouvert et la Liste montre Lait sous la pastille Crèmerie avec le compteur 1.
- Given le téléphone en thème sombre puis clair, when Kadi est ouverte, then les couleurs suivent DESIGN.md dans les deux thèmes, l'argile seulement sur le FAB + et l'onglet actif.
- Given TalkBack actif, when il parcourt la Liste, then il entend « Crèmerie, 1 article » puis « Lait, Crèmerie », et le FAB est annoncé « Ajouter un article ».
- Given la release et la debug installées, when il lance l'une puis l'autre, then elles coexistent sous deux icônes « Kadi ».

## Implementation Notes

- **Schéma v1** : toutes les tables ont `id`/`updated_at`/`deleted_at` (mixin `SyncColumns`). `list_lines` : `article_id`, `rayon` (copié), `unit` (nulle = `unit_key` `-`), `added_at`, `checked_at`, `manual_at`. `list_contributions` : `line_id`, `source` (`week_selection`/`ajout`/`edition`), `week_selection_id` (texte sans clé étrangère, la table arrive avec l'epic 2), `quantity`, `unit`. `settings` (id fixe `settings`) : `route_order` (13 codes séparés par `,`), `group_by_rayon`, `keep_screen_on`, `first_launch`, `seed_versions` (JSON par fichier, `{"articles":1}`). Aucune contrainte d'unicité en base sur le nom normalisé ni sur (`article_id`, `unit_key`) : elle casserait la fusion d'import d'AD-9 ; le repository la garantit. `PRAGMA foreign_keys = ON`.
- **Dépendance core → catalogue** : `SeedLoader` (core) a besoin de `normalizeName` (catalogue). Il la reçoit en paramètre, câblée dans `lib/app/startup.dart` : une seule implémentation, et `core` n'importe aucune fonctionnalité. Même principe pour le routeur : `createAppRouter` reçoit les écrans depuis `lib/app/kadi_app.dart`.
- **Chargeur** : un article fourni dont le nom normalisé existe déjà parmi les articles actifs n'est pas inséré (AD-17). Les réglages par défaut sont insérés avec `updated_at = 0` et les `seed_version` déjà à jour ; une montée de version ultérieure passe par l'horloge.
- **`normalizeName`** retire tous les espaces (« Crème fraîche » → `cremefraiche`), lecture littérale d'AD-17.
- **`formatQuantity`** ne gère que « sans quantité » ; une quantité chiffrée lève `UnimplementedError` (aucun chemin n'en crée dans cette story).
- **Recettes** n'a pas de FAB (la Fiche recette est hors périmètre), bien que son message d'état vide mentionne « + ».
- **Panneau +** : aucune zone de fréquents ni message « Pas encore de fréquents » (story fréquents). Un échec d'ajout affiche « Ajout impossible. Réessaie. » (microcopie ajoutée à `strings_fr.dart`).
- **Pictos** : pas de pack, `PictoResolver.assetFor` renvoie toujours `null` → repli neutre (cercle au trait teinté du rayon).
- **Build Android sur ce poste** : Avast intercepte TLS ; Gradle ne fait pas confiance à sa racine. Vérifié avec un truststore temporaire (copie du `cacerts` du JBR + racine Avast) passé par `JAVA_TOOL_OPTIONS`, sans changer la config du poste. Le wrapper passe de `gradle-9.3.1-all` à `gradle-9.3.1-bin` (seule distribution complète en cache). La plateforme SDK `android-35` (demandée par le plugin `jni`) a été installée par `sdkmanager`.

## Plan Change Log

## Review Triage Log

### 2026-10-26 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 4, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` Panneau + ouvert sur le navigateur de la branche Liste : la barrière ne couvre pas la NavigationBar, toucher « Recettes » change d'onglet et laisse le panneau ouvert — corrigé : `useRootNavigator: true` dans `showAddSheet`.
  - `[low]` `[patch]` Les résultats de recherche disparaissent une image à chaque frappe (nouvelle instance autoDispose en chargement) — corrigé : `_lastResults` garde les derniers résultats pendant le chargement ; requête vide = liste vide.
  - `[low]` `[reject]` `exists()` compte une ligne de réglages supprimée alors que `read()` la filtre — aucun chemin de la V1 ne supprime la ligne de réglages ; correction hors de l'usage courant.
  - `[low]` `[reject]` Dossier `lib/core/ui/` absent du Structural Seed — l'arborescence du spine est une graine de départ, pas une liste fermée ; aucune règle enfreinte ni dommage nommé.
  - `[false]` `[reject]` Textes absents de Voice and Tone (écran d'erreur, « Effacer la recherche », noms lus par TalkBack) — la convention exige la microcopie dans `strings_fr.dart` et la reprise des moments listés ; ces moments n'y figurent pas et les textes sont bien centralisés.
  - `[low]` `[reject]` Critère 5 (release et debug côte à côte) non vérifié — étape HITL d'Antoine (mots de passe de `key.properties`, installation), suivie par le `done_checkpoint` ; la configuration (`.debug`, libellé, signature) est en place.

## Design Notes

L'ordre des groupes vient de `settings.route_order` (les 13 codes d'AD-11), jamais de l'énumération directement. Le compteur d'en-tête compte les lignes actives non cochées du rayon. La quantité affichée se calcule à partir des contributions (AD-4), même si elle est vide dans cette story.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent
- `flutter build apk --release` -- expected: APK signé par la clé locale

**Manual checks (if no CLI):**
- Sur le téléphone : les quatre premiers critères d'acceptation, en clair et en sombre.

## Auto Run Result

Status: ready-for-dev
Halt reason: plan_checkpoint = true on this entry — the plan is reviewed by Antoine before implementation. The two HITL prerequisites (git TLS repair + Flutter 3.47.8, release key + applicationId confirmation) must be done before step 3; this machine is on Flutter 3.44.5 / Dart 3.12.2 (checked 2026-10-26), and material_ui 1.8.0 requires Flutter 3.47 or later.

### Finalize (2026-10-26)

- **Résumé :** socle Kadi posé de bout en bout : projet Flutter (material_ui, thèmes clair et sombre, deux onglets), base Drift v1 avec toutes les tables de l'epic, horloge, réglages, chargeur de contenu fourni (7 articles), recherche du Panneau +, ajout d'un article, Liste groupée par rayon, états vides, écran d'erreur bloquant.
- **Fichiers :** `pubspec.yaml`, `build.yaml`, `android/` (id `fr.antoinegrb.kadi`, `.debug`, signature par `key.properties`), `assets/seed/articles.json`, `lib/app/` (démarrage, racine), `lib/core/` (db, tables, seed, clock, settings, rayons, units, theme, pictos, router, strings, ui), `lib/features/catalogue/`, `lib/features/liste/`, `lib/features/recettes/ui/`, `drift_schemas/`, `test/` (41 tests).
- **Revue :** 2 corrections appliquées (1 medium, 1 low), 0 reporté, 4 rejetés (raisons dans le Review Triage Log).
- **Revue de suivi recommandée :** non — aucune correction high, une seule medium.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 41/41 ; build debug réussi côté agent (`fr.antoinegrb.kadi.debug`, libellé « Kadi ») ; build release bloqué à la signature tant que les mots de passe de `android/key.properties` sont vides (prévu).
- **Risques résiduels :** installation release non faite (HITL) ; TalkBack réel et rendu sur téléphone non vérifiés ; Gradle a besoin du certificat racine d'Avast (ou de couper l'analyse HTTPS) sur ce poste ; `formatQuantity` lève sur une quantité chiffrée jusqu'à la story 1.2.
