---
title: 'Kadi installée : un article cherché apparaît dans la Liste'
type: 'feature'
ticket: '1'
created: '2026-10-26'
status: 'ready-for-dev'
baseline_revision: ''
route: 'full'
route_source: 'auto'
risk: 'high'
review: ''
review_source: ''
lenses_ran: []
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
- [ ] HITL Antoine -- réparer le certificat SSL de git, `flutter upgrade` vers 3.47.8 (Dart 3.13.7), créer la clé de release hors dépôt avec `android/key.properties` ignoré par git, confirmer `fr.antoine.kadi` -- prérequis du build et de material_ui.
- [ ] racine -- `flutter create --org fr.antoine --project-name kadi --platforms android .`, puis `dart fix --apply --code=migrate_design_widgets` -- starter retenu.
- [ ] `pubspec.yaml` -- dépendances épinglées du spine, `assets/seed/` -- Stack.
- [ ] `android/app/build.gradle.kts`, `AndroidManifest.xml` -- applicationId `fr.antoine.kadi`, libellé « Kadi », debug `applicationIdSuffix ".debug"`, release signée par `key.properties` -- convention Livraison.
- [ ] `lib/core/db/tables/` -- `articles`, `frequents`, `list_lines`, `list_contributions`, `settings` avec les colonnes d'AD-4 à AD-8 et AD-17 -- base v1 de l'epic.
- [ ] `lib/core/db/app_database.dart` + `drift_schemas/` -- `schemaVersion = 1`, `driftDatabase`, dump du schéma -- AD-14.
- [ ] `lib/core/clock/`, `lib/core/rayons/`, `lib/core/settings/`, `lib/core/units/` (affichage sans quantité seulement) -- AD-7, AD-11, AD-2.
- [ ] `lib/core/db/seed/` + `assets/seed/articles.json` -- chargeur à chaque démarrage ; Lait (cremerie, piece), Œufs (cremerie, piece), Tomates (fruits-legumes, g), Courgettes (fruits-legumes, g), Oignons (fruits-legumes, piece), Riz (epicerie-salee, g), Lardons (viande-poisson, g), UUID v4 figés, `seed_version` 1 -- AD-8.
- [ ] `lib/core/theme/`, `lib/core/pictos/`, `lib/core/strings/strings_fr.dart` -- tokens clair et sombre, `ThemeExtension` des rayons, résolveur à repli neutre -- AD-12, AD-18.
- [ ] `lib/core/router/` + `lib/main.dart` -- `StatefulShellRoute` Recettes / Liste, ouverture sur Liste, écran d'erreur bloquant -- AD-13.
- [ ] `lib/features/catalogue/` -- `normalizeName`, recherche sur les articles actifs -- AD-17.
- [ ] `lib/features/liste/` -- repository (ajout = ligne + contribution `ajout`), Liste groupée par rayon dans l'ordre du parcours avec compteur, état vide, FAB +, Panneau + (recherche focalisée, lignes de résultat) -- AD-1, AD-4.
- [ ] `test/` -- repositories et chargeur sur Drift en mémoire, widgets avec `closeStreamsSynchronously: true`, test d'interdiction d'imports, test de migration v1 -- conventions Tests.
- [ ] HITL Antoine -- `flutter build apk --release`, installer sur le téléphone -- Done when.

**Acceptance Criteria:**
- Given une installation neuve, when Antoine ouvre Kadi, then la Liste s'affiche avec « Ta liste est vide. Choisis tes recettes de la semaine ou ajoute un article avec +. », et l'onglet Recettes montre « Pas encore de recette. Ajoute ta première avec +. ».
- Given la Liste, when il touche le FAB +, tape « lait » et touche Lait, then le Panneau + reste ouvert et la Liste montre Lait sous la pastille Crèmerie avec le compteur 1.
- Given le téléphone en thème sombre puis clair, when Kadi est ouverte, then les couleurs suivent DESIGN.md dans les deux thèmes, l'argile seulement sur le FAB + et l'onglet actif.
- Given TalkBack actif, when il parcourt la Liste, then il entend « Crèmerie, 1 article » puis « Lait, Crèmerie », et le FAB est annoncé « Ajouter un article ».
- Given la release et la debug installées, when il lance l'une puis l'autre, then elles coexistent sous deux icônes « Kadi ».

## Implementation Notes

## Plan Change Log

## Review Triage Log

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
