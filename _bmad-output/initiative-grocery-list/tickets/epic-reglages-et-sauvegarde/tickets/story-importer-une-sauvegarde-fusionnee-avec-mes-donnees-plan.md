---
title: 'Importer une sauvegarde, fusionnée avec mes données'
type: 'feature'
ticket: '3'
created: '2026-11-04'
status: 'draft'
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
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** l'export de la story 2 ne sert à rien sans retour : Antoine doit pouvoir restaurer une sauvegarde sur une installation neuve, ou la fusionner avec ses données, sans jamais corrompre ce qu'il a.

**Approach:** dans `core/backup`, un importeur qui valide toute l'archive avant d'écrire, puis fusionne ligne par ligne par `id` en une transaction (AD-9) et réconcilie les doublons de clé naturelle ; une action de `lib/app/actions/` ouvre le sélecteur de fichier et le lance depuis la ligne « Importer une sauvegarde » des Paramètres.

## Boundaries & Constraints

**Always:**
- **Validation complète avant toute écriture** : zip lisible ; `data.json` présent, objet JSON ; `format_version` entier connu (aujourd'hui seulement 3 = `schemaVersion` ; une table `version → migration` vide est prête pour les prochains schémas, une version absente de la table ou supérieure est refusée) ; `tables` ne nomme que des tables de `allTables`, chaque ligne ne porte que des colonnes de sa table, avec `id` texte et `updated_at` entier ; entrées `photos/` à nom de fichier simple (ni `/`, ni `\`, ni `..`), sinon le fichier est invalide.
- **Fusion** en une transaction, dans l'ordre articles, recipes, recipe_ingredients, week_selections, list_lines, list_contributions, frequents, settings : ligne absente localement → insérée telle quelle ; présente → remplacée seulement si `updated_at` importé > local (égalité : la locale reste) ; suppressions logiques comprises (AD-7). Colonnes absentes d'une ligne importée : valeur par défaut de la colonne.
- **Réglages** (exception, Assumption 2026-11-04 de l'epic) : la ligne `settings` prend toujours `route_order`, `group_by_rayon` et `keep_screen_on` du fichier et garde `first_launch` et `seed_versions` locaux ; `updated_at` par l'horloge (AD-7).
- **Réconciliation** après la fusion, dans la même transaction, chaque propriétaire par son repository ou une fonction de son dossier `data/` : articles actifs de même `normalized_name` → un seul gardé (celui qui existait localement avant l'import, sinon le plus petit `id`), `in_catalogue` vrai si l'un l'était, références (`list_lines`, `recipe_ingredients`, `frequents`) reportées, l'autre supprimé logiquement ; un fréquent en double sur l'article gardé est supprimé logiquement (id du fréquent dérivé de l'article, AD-17 : réutiliser `lib/features/catalogue/data/frequent_id.dart`) ; lignes non cochées actives de même (`article_id`, `unit_key`) → la plus ancienne (`added_at`) garde les contributions de l'autre, devient manuelle si l'une l'était, l'autre supprimée logiquement ; sélections actives de la même recette → une gardée (validée de préférence, sinon la plus ancienne), contributions reportées.
- **Photos** : copier dans le dossier photos les seules photos absentes, avant la transaction ; si la transaction échoue, supprimer celles copiées. Un fichier invalide ne touche ni la base ni le dossier photos.
- Après un import réussi : vider le service Annuler (AD-10), snackbar « Sauvegarde importée. ». Fichier invalide : snackbar « Ce fichier n'est pas une sauvegarde Kadi. ». Échec d'écriture : « Import impossible. », rien de changé. Sélecteur annulé : rien. Pas de confirmation (C9).
- Sélecteur par le paquet `file_picker` (épinglé, compatible Dart 3.13, aucune permission nouvelle, C2), injecté par un provider surchargeable. Ligne « Importer une sauvegarde » · « Fusionnée avec tes données » sous « Exporter mes données » ; désactivée pendant l'import ; TalkBack et police système.

**Never:** suppression physique ; écrasement sans comparer `updated_at` (sauf les trois champs de réglages) ; écriture avant la fin de la validation ; extraction d'une entrée zip hors du dossier photos.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Restauration | export d'une base A ; import sur une base neuve semée (premier lancement écrit après l'export) | tables métier égales à A (recettes, photo, catalogue, fréquents, lignes, contributions, sélections) ; parcours, groupement et Écran allumé de A ; `first_launch`/`seed_versions` locaux | — |
| Local plus récent | même recette modifiée localement après l'export | version locale gardée | — |
| Fichier plus récent | ligne locale plus ancienne | ligne du fichier | — |
| Suppression | ligne supprimée dans le fichier, plus récente | supprimée localement | — |
| Articles en double | « Tomates » id X local, id Y dans le fichier, lignes et ingrédients sur Y | un seul article X, lignes et ingrédients reportés sur X, Y supprimé logiquement | — |
| Lignes en double | deux lignes non cochées Lait / g après fusion | une ligne, contributions réunies, quantité = somme | — |
| Sélections en double | deux sélections actives de Chili | une seule, contributions reportées | — |
| Idempotence | même fichier importé deux fois | même état qu'après un import (hors `updated_at` des réglages) | — |
| Invalide | zip sans `data.json` ; JSON tronqué ; `format_version` 99 ; table ou colonne inconnue ; entrée `photos/../x` ; fichier non zip | base et dossier photos identiques à avant | « Ce fichier n'est pas une sauvegarde Kadi. » |
| Échec en transaction | une écriture lève | base inchangée, photos copiées supprimées | « Import impossible. » |
| Annulé | sélecteur fermé | rien | — |

</intent-contract>

## Code Map

- `lib/core/backup/backup_archive.dart` -- créé par la story 2 : réutiliser les constantes de format (noms `data.json`, `photos/`, clés JSON) ; y ajouter ou mettre à côté `BackupImporter` (`lib/core/backup/backup_import.dart`).
- `lib/core/db/app_database.dart` -- `allTables`, `schemaVersion` ; colonnes par `table.$columns` (nom SQL `column.name`) pour la validation et l'insertion brute (`customStatement`/`customInsert` avec variables).
- `lib/core/db/tables/*.dart` -- colonnes : `articles.normalized_name`, `in_catalogue` ; `list_lines.article_id, unit, added_at, checked_at, manual_at` ; `list_contributions.line_id, week_selection_id` ; `week_selections.recipe_id, validated_at` ; `frequents.article_id, position`. `unit_key` = `unit` ou `-` (AD-4).
- `lib/features/catalogue/data/catalogue_repository.dart`, `lib/features/liste/data/liste_repository.dart`, `lib/features/recettes/data/recettes_repository.dart` -- y ajouter la réconciliation de chaque propriétaire (AD-2) ; `core/backup` ne les importe pas (`core` ne dépend d'aucune fonctionnalité) : l'action de `lib/app/actions/` enchaîne fusion (core) puis réconciliations (repositories) dans une seule `db.transaction`.
- `lib/core/settings/settings_repository.dart` -- appliquer les trois champs utilisateur (setters de la story 1 ou une méthode dédiée).
- `lib/core/undo/undo.dart` -- `clear()` après l'import.
- `lib/app/actions/importer_une_sauvegarde.dart` (nouveau) -- sur le modèle de `lib/app/actions/nouvelle_liste.dart` ; dossier photos par `photosDirectoryProvider` (`lib/features/recettes/state/recettes_providers.dart`).
- `lib/features/reglages/ui/parametres_screen.dart` -- ligne Importer et snackbars.
- `test/helpers/pump_app.dart` -- double du sélecteur de fichier.

## Tasks & Acceptance

**Execution:**
- [ ] `pubspec.yaml` -- `file_picker` épinglé ; `flutter pub get`.
- [ ] `lib/core/backup/backup_import.dart` -- validation et fusion génériques.
- [ ] repositories `catalogue`, `liste`, `recettes` -- réconciliations.
- [ ] `lib/app/actions/importer_une_sauvegarde.dart` -- action, photos, Annuler.
- [ ] `lib/core/strings/strings_fr.dart`, `lib/features/reglages/ui/parametres_screen.dart` -- ligne et snackbars.
- [ ] `test/core/backup_import_test.dart` -- chaque ligne de la matrice, aller-retour réel par l'exporteur de la story 2 ; pour « Invalide » et « Échec », comparer un instantané complet des tables et du dossier photos avant/après.
- [ ] `test/features/reglages/parametres_import_test.dart` -- ligne, succès, invalide, annulé, TalkBack, police ×2.

**Acceptance Criteria:**
- Given un export de son téléphone, when Antoine l'importe sur une installation neuve, then il retrouve ses recettes avec photos, son catalogue, ses fréquents, son parcours, ses réglages et sa liste en cours.
- Given un fichier qui n'est pas une sauvegarde Kadi, when il l'importe, then « Ce fichier n'est pas une sauvegarde Kadi. » s'affiche et rien ne change.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- Réconciliation par propriétaire : AD-2 interdit à `core/backup` d'écrire les règles métier d'une table ; il ne fait que la fusion générique par `id`.
- [ASSUMPTION] Aide « Fusionnée avec tes données » et messages de succès et d'erreur (absents de Voice and Tone) ; Antoine les valide au test de fin d'epic.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- Tests : écrits, lancés une seule fois à la fin des stories 3.1 à 3.4.
