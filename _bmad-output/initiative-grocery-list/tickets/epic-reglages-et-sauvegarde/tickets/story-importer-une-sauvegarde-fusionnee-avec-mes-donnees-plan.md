---
title: 'Importer une sauvegarde, fusionnée avec mes données'
type: 'feature'
ticket: '3'
created: '2026-11-04'
status: 'in-review'
baseline_revision: 'ec611d90550f318380f9087b348901f2c70d1560'
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
- [x] `pubspec.yaml` -- `file_picker` épinglé ; `flutter pub get`.
- [x] `lib/core/backup/backup_import.dart` -- validation et fusion génériques.
- [x] repositories `catalogue`, `liste`, `recettes` -- réconciliations.
- [x] `lib/app/actions/importer_une_sauvegarde.dart` -- action, photos, Annuler.
- [x] `lib/core/strings/strings_fr.dart`, `lib/features/reglages/ui/parametres_screen.dart` -- ligne et snackbars.
- [x] `test/core/backup_import_test.dart` -- chaque ligne de la matrice, aller-retour réel par l'exporteur de la story 2 ; pour « Invalide » et « Échec », comparer un instantané complet des tables et du dossier photos avant/après.
- [x] `test/features/reglages/parametres_import_test.dart` -- ligne, succès, invalide, annulé, TalkBack, police ×2.

**Acceptance Criteria:**
- Given un export de son téléphone, when Antoine l'importe sur une installation neuve, then il retrouve ses recettes avec photos, son catalogue, ses fréquents, son parcours, ses réglages et sa liste en cours.
- Given un fichier qui n'est pas une sauvegarde Kadi, when il l'importe, then « Ce fichier n'est pas une sauvegarde Kadi. » s'affiche et rien ne change.

## Implementation Notes

- **Paquet** : `file_picker: 13.3.2` (SDK >=3.10, Flutter >=3.38), dernière version de pub.dev au 2026-11-04 ; `flutter pub get` passe. Depuis la 13, le paquet est fédéré : l'implémentation Android est `android_file_picker 2.1.3`, dont le manifeste ne déclare que des `<queries>` (GET_CONTENT, OPEN_DOCUMENT…), **aucune permission** (C2). API statique `FilePicker.pickFile()` → `PlatformFile?`, lu par `readAsBytes()`. Build Android non lancé (pièges Gradle du poste) : son `build.gradle.kts` déclare AGP 8.5.2 / Kotlin 1.8.22 en classpath, à confirmer au premier `flutter build apk`.
- **`lib/core/backup/backup_import.dart`** : `BackupImporter(db, settingsRepository)` en trois temps, appelés par l'action. `read(bytes)` (synchrone, aucune écriture) : `ZipDecoder().decodeBytes(bytes, verify: true)` (strict + CRC : un non-zip, un zip vide, tronqué ou corrompu lève, vérifié par un script hors projet) ; `data.json` objet JSON ; `format_version` entier ; `tables` objet de listes d'objets ; puis la chaîne de `migrations` (`const Map<int, BackupMigration> = {}`, la migration `n` mène de `n` à `n+1` ; version > `schemaVersion` ou sans migration : refusée) ; enfin chaque ligne est validée contre `table.$columns` et **complétée** (colonne absente : défaut `Constant` ou `clientDefault`, sinon null si nullable). Entrées `photos/` : nom simple (ni `/`, ni antislash, ni `..`, ni NUL ; `archive` convertit l'antislash en `/`, rejeté aussi) ; toutes les photos sont décompressées pendant la validation (une photo corrompue rend le fichier invalide avant toute écriture). Les autres entrées du zip sont ignorées, jamais extraites. `copyMissingPhotos` copie les photos absentes (par nom) en E/S synchrones et supprime ce qu'elle a copié si elle échoue ; `deletePhotos` sert au retour arrière. `merge` (dans la transaction) : ordre `mergeOrder` (les 8 tables du plan ; une table future absente de la liste est fusionnée après, avant les réglages), lecture des `id, updated_at` locaux puis `INSERT` de toutes les colonnes, ou `UPDATE … WHERE id = ?` si `updated_at` importé > local, par `customInsert`/`customUpdate` avec `updates: {table}` (les flux sont notifiés). Rend les ids insérés par table, pour garder la ligne locale d'un doublon. Les réglages ne passent pas par la fusion générique : la ligne `id = 'settings'` du fichier est remise à `SettingsRepository.applyImported`.
- **Validation plus stricte que le plan** (décision) : en plus des règles listées, une valeur du mauvais type (texte dans une colonne entière, booléen hors 0/1 ; `true`/`false` JSON acceptés et convertis), une colonne requise absente sans défaut, un `id` vide ou en double dans sa table rendent le fichier invalide. Raison : SQLite accepterait une valeur mal typée (affinité) et l'app planterait ensuite à la lecture Drift. Blob : refusé (JSON ne le porte pas ; aucune colonne blob aujourd'hui).
- **`SettingsRepository.applyImported`** : écrit `route_order` (normalisé par `decodeRouteOrder`, toujours 13 rayons), `group_by_rayon`, `keep_screen_on` avec `updated_at` par l'horloge, **toujours** (même inchangé, comme le veut la ligne Idempotence) ; `first_launch` et `seed_versions` locaux intacts. Sans ligne locale (impossible après le démarrage), insère d'abord les défauts.
- **Réconciliations** (AD-2, chacune « à appeler dans la transaction de l'import ») : `CatalogueRepository.reconcileImportedArticles(insertedIds)` rend `{idSupprimé: idGardé}` : par `normalized_name` parmi les actifs, garde un article non inséré par l'import (sinon, et entre eux, le plus petit id), `in_catalogue` vrai si l'un l'était, les autres supprimés logiquement ; le fréquent actif d'un article supprimé est reporté sous `frequentId(gardé)` (inséré, ou réactivé à la même position s'il était supprimé) puis supprimé ; si le gardé a déjà un fréquent actif, celui en double est seulement supprimé. `RecettesRepository.reconcileImported(articles)` rend `{sélectionSupprimée: gardée}` : reporte les ingrédients actifs, puis garde une sélection active par recette (validée d'abord, puis `validated_at`, `updated_at`, id croissants). `ListeRepository.reconcileImported(articles:, selections:)` : reporte les lignes actives et les `week_selection_id` des contributions actives, puis fusionne les lignes actives non cochées de même (`article_id`, `unit` ou `-`) dans la plus ancienne (`added_at`, id) : contributions actives déplacées, `manual_at` = le plus ancien des autres si la gardée n'en avait pas, autres supprimées logiquement. Toute écriture est horodatée `clock.stamp(ancien updated_at)`. `liste` ne reçoit que des maps d'ids : il n'importe pas `recettes`.
- **`lib/app/actions/importer_une_sauvegarde.dart`** : `ImporterUneSauvegarde` (constructeur positionnel comme `NouvelleListe`) rend `ImportResult { imported, cancelled }`. Sélecteur, puis `read` (lève `InvalidBackupException`), copie des photos, une `db.transaction` (fusion, articles, recettes, liste) ; un échec supprime les photos copiées et relance ; succès : `undo.clear()`. Dossier des photos par `recipePhotosProvider.directory`, relu à chaque import (même écart léger que l'export, voir story 2).
- **`lib/core/backup/backup_providers.dart`** : `PickBackupFile = Future<List<int>?> Function()` (contenu en mémoire plutôt qu'un chemin : Android peut rendre une URI `content://`), `pickBackupFileProvider` (`FileType.any` : un filtre `zip` peut griser le fichier selon le gestionnaire ; la validation refuse le reste) et `backupImporterProvider`.
- **UI** : `_ImportRow` dans `parametres_screen.dart`, sur le modèle de `_ExportRow`, placée dessous ; `on InvalidBackupException` : « Ce fichier n’est pas une sauvegarde Kadi. », toute autre erreur : « Import impossible. », succès : `SnackBar` « Sauvegarde importée. », sélecteur fermé : rien. Chaînes `importerUneSauvegarde`, `importerUneSauvegardeDetail`, `sauvegardeImportee`, `pasUneSauvegardeKadi`, `importImpossible`.
- **`test/helpers/pump_app.dart`** : paramètre `pickBackupFile` (défaut : double « fermé sans choix »), passé en paramètre comme `shareFile`.
- **Tests écrits, pas lancés** (consigne) : `test/core/backup_import_test.dart`, aller-retour réel par `BackupExporter` : Restauration (tables sauf `settings` égales ligne à ligne à A, réglages utilisateur de A, `first_launch`/`seed_versions` de B, photo copiée), Local plus récent, Fichier plus récent, égalité de `updated_at`, Suppression, Articles en double (ligne fusionnée à 5000, ingrédient et fréquent reportés) et fréquent en double, Lignes en double (550 g, manuelle), Sélections en double (×2), Idempotence, colonnes absentes à leur défaut, 18 cas Invalides avec instantané complet tables + dossier photos (et rien écrit à côté du dossier), Échec en transaction (`_FailingListe` qui écrit puis lève : base et photos identiques), seules les photos absentes copiées, Annulé, Annuler vidé (service sur sa propre horloge). `test/features/reglages/parametres_import_test.dart` : ligne sous Exporter et ≥ 48 dp, succès (switches Écran allumé et Grouper basculés, photo copiée), invalide, version 99, annulé, échec (« Import impossible. » par un dossier documents illisible), ligne désactivée pendant l'import, TalkBack, police ×2.
- **Vérification** : `flutter analyze` sans problème ; grep des accents corrompus dans `lib test` sans résultat ; comportement d'`archive` 4.6.0 vérifié par un script Dart hors projet (non-zip, vide, tronqué : `ArchiveException` ; octet corrompu : `ArchiveChecksumException` ; noms `photos/../x` conservés tels quels, donc bien rejetés).
- **Surprises / risques** : une ligne du fichier qui référence un parent absent (clé étrangère) lève dans la transaction : « Import impossible. » et non « fichier invalide » (rien n'est changé dans les deux cas). Une ligne `settings` d'un autre id est ignorée. Archive et photos décompressées sont tenues en mémoire pendant l'import. L'import bloque l'UI le temps de la copie des photos (E/S synchrones, comme l'export). Entre deux sélections validées, la plus ancienne par `validated_at` est gardée, choix que le plan ne précisait pas.

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
