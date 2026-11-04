---
title: 'Exporter mes données dans un fichier de sauvegarde'
type: 'feature'
ticket: '2'
created: '2026-11-04'
status: 'built'
baseline_revision: '27f2c9d35e998415ef314c06315d4acec87ccf79'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** toutes les données de Kadi (recettes et photos, catalogue, fréquents, parcours, réglages, liste en cours) ne vivent que sur le téléphone ; rien ne permet de les sauvegarder avant d'installer une release ou de changer de téléphone.

**Approach:** créer `core/backup` (AD-9) qui écrit une archive zip générique (toutes les tables Drift, lignes brutes, plus les photos) ; une action de `lib/app/actions/` lui fournit le dossier des photos et l'ouvre dans la feuille de partage Android ; une ligne « Exporter mes données » des Paramètres la déclenche.

## Boundaries & Constraints

**Always:**
- Archive `kadi-sauvegarde-AAAA-MM-JJ.zip` (date locale) écrite dans le dossier temporaire de l'app : `data.json` = `{ "format_version": <schemaVersion>, "exported_at": <ms UTC>, "tables": { "<nom SQL de la table>": [ { "<colonne SQL>": valeur, … } ] } }` et `photos/<nom>.jpg` pour chaque fichier du dossier photos (AD-18). Toutes les tables de `AppDatabase.allTables`, lignes supprimées comprises, valeurs telles que SQLite les stocke (entiers, textes, null) : le format ne connaît aucune table en dur, une table future y entre seule.
- Lecture de toutes les tables dans une seule transaction (instantané cohérent). Photo référencée mais absente du disque : ignorée, l'export continue.
- `core/backup` ne dépend d'aucune fonctionnalité (règle d'imports) : le dossier des photos lui est passé par l'action (`photosDirectoryProvider` de `features/recettes`).
- Feuille de partage par le paquet `share_plus` ; zip par le paquet `archive` ; versions épinglées exactes, compatibles Dart 3.13 ; aucune permission Android nouvelle (C2).
- Microcopie dans `strings_fr.dart` : ligne « Exporter mes données » · « Recettes, liste et réglages dans un fichier » ; succès « Sauvegarde prête. » ; échec « Export impossible. ». La ligne est placée sous les deux switches de la story 1, dans l'écran `lib/features/reglages/ui/parametres_screen.dart`.
- Pendant l'export, la ligne est désactivée (pas de double export) ; cible ≥ 48 dp, TalkBack lit le libellé et l'aide.

**Never:** import (story 3) ; chiffrement ou compression des photos ; écriture en dehors du dossier temporaire ; modification des données pendant l'export.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Export complet | base avec recette + photo, sélection, lignes, contributions, fréquents, parcours modifié (`setRouteOrder`), une ligne supprimée | zip avec `data.json` (8 tables, ligne supprimée présente, `format_version` = 3) et la photo sous `photos/` ; feuille de partage appelée avec ce fichier ; snackbar « Sauvegarde prête. » | — |
| Tables exportées | n'importe quelle base | clés de `tables` = noms de `db.allTables` exactement | — |
| Base fraîche sans photo | dossier photos inexistant | zip valide, `photos/` vide ou absent | — |
| Photo manquante | recette référence `x.jpg` absent du disque | export réussi sans `x.jpg` | — |
| Partage annulé | Antoine ferme la feuille (statut `dismissed`) | aucun snackbar | — |
| Échec d'écriture | le service lève | aucun fichier partiel laissé | snackbar « Export impossible. » |

</intent-contract>

## Code Map

- `lib/core/db/app_database.dart` -- `schemaVersion` (l. ~50) et `allTables` (généré par Drift) : source du format et de la liste des tables ; lecture brute par `customSelect('SELECT * FROM "<table>"')`.
- `lib/core/backup/backup_archive.dart` (nouveau) -- `BackupExporter` : `Future<File> export({required Directory photos, required Directory target, DateTime? now})` ; construit `data.json` + `photos/`, écrit d'abord dans un fichier `.part` puis renomme (pas de fichier partiel). Garder la structure réutilisable par l'import (story 3) : constantes de nom (`data.json`, `photos/`, clés JSON) au même endroit.
- `lib/core/backup/backup_providers.dart` (nouveau) -- provider de l'exporteur, et `shareFileProvider` (typedef `ShareFile = Future<bool> Function(File file)`, vrai sauf partage annulé) surchargeable en test, implémenté par `share_plus`.
- `lib/app/actions/exporter_mes_donnees.dart` (nouveau) -- action `ExporterMesDonnees` sur le modèle de `lib/app/actions/nouvelle_liste.dart` : lit `photosDirectoryProvider` (`lib/features/recettes/state/recettes_providers.dart` l. ~26) et `getTemporaryDirectory` (`path_provider`, déjà en dépendance ; injecté pour les tests), appelle l'exporteur, puis le partage ; rend `ExportResult { shared, dismissed }`.
- `lib/features/reglages/ui/parametres_screen.dart` -- écran posé par la story 1 : ajouter la ligne, l'état « en cours », les snackbars par `showErrorSnackBar` (`lib/core/ui/error_snackbar.dart`) et un `SnackBar` pour le succès.
- `test/helpers/pump_app.dart` -- surcharger `shareFileProvider` et les dossiers par des doubles (dossiers temporaires) par défaut.

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- ajouter `archive` et `share_plus` épinglés ; `flutter pub get`.
- [x] `lib/core/backup/backup_archive.dart`, `lib/core/backup/backup_providers.dart` -- exporteur générique et partage.
- [x] `lib/app/actions/exporter_mes_donnees.dart` -- action.
- [x] `lib/core/strings/strings_fr.dart`, `lib/features/reglages/ui/parametres_screen.dart` -- ligne et snackbars.
- [x] `test/core/backup_export_test.dart` -- lignes Export complet, Tables exportées, Base fraîche, Photo manquante, Échec d'écriture (aucun `.zip` ni `.part` laissé) : décompresser l'archive et vérifier le JSON.
- [x] `test/features/reglages/parametres_export_test.dart` -- ligne visible et lue par TalkBack ; tap → double de partage appelé avec un `.zip`, puis « Sauvegarde prête. » ; partage annulé → rien ; échec → « Export impossible. » ; police ×2 sans débordement.

**Acceptance Criteria:**
- Given une base avec des recettes, une photo et une liste, when Antoine touche « Exporter mes données », then la feuille de partage Android s'ouvre avec `kadi-sauvegarde-<date>.zip`, et au retour « Sauvegarde prête. » s'affiche.
- Given une nouvelle table ajoutée un jour à la base, when on exporte, then elle est dans `data.json` sans changer le code de l'export.

## Implementation Notes

- **Paquets** : `archive: 4.6.0` (Dart pur, SDK >=3.0) et `share_plus: 13.3.1` (SDK >=3.10, Flutter >=3.38.1, minSdk 21), dernières versions de pub.dev au 2026-11-04 ; `flutter pub get` passe. Le manifeste de `share_plus` ne déclare qu'un `FileProvider` et un receiver, aucune permission (C2). Build Android non lancé (pièges Gradle du poste) : à confirmer au premier `flutter build apk`.
- **`lib/core/backup/backup_archive.dart`** : `BackupFormat` regroupe les noms (`data.json`, `photos/`, `.part`) et les clés JSON (`format_version`, `exported_at`, `tables`) pour l'import de la story 3, et `fileName(at)` (date locale). `BackupExporter.readTables()` lit `allTables` par `SELECT * FROM "<actualTableName>"` dans une seule transaction (lignes brutes `QueryRow.data`, booléens en 0/1 comme SQLite les stocke). `export()` écrit le zip dans `<nom>.zip.part` par `ZipFileEncoder` en flux (les photos ne sont pas chargées en mémoire), puis supprime un zip du même jour et renomme ; sur un échec, le `.part` est fermé et supprimé, puis l'erreur remonte. `data.json` est compressé (deflate), les photos sont stockées sans compression (`ZipFileEncoder.store`). Les photos viennent de **tous les fichiers du dossier** (pas seulement ceux référencés), triés par nom ; un fichier disparu entre la lecture du dossier et son ajout est ignoré.
- **E/S synchrones** dans l'exporteur (comme `_TempPhotos` des tests de la Fiche) : la zone de test des widgets n'attend pas les E/S asynchrones, et l'export est court. Revers : l'écriture du zip bloque l'UI le temps de copier les photos (court pour quelques dizaines de photos de 1600 px).
- **`lib/core/backup/backup_providers.dart`** : `backupExporterProvider`, `exportDirectoryProvider` (`getTemporaryDirectory`, remplacé en test) et `shareFileProvider` (`SharePlus.instance.share` avec `XFile(…, mimeType: 'application/zip')` ; vrai sauf `ShareResultStatus.dismissed`, donc `unavailable` compte comme partagé).
- **`lib/app/actions/exporter_mes_donnees.dart`** : constructeur positionnel comme `NouvelleListe`. Écart léger avec le Code Map : le dossier des photos est pris par `recipePhotosProvider.directory` (ce qu'enveloppe `photosDirectoryProvider`) et relu à chaque export, pour ne pas garder un échec de lecture dans le `FutureProvider` ; la source reste `features/recettes`, `core/backup` n'importe aucune fonctionnalité.
- **`parametres_screen.dart`** : `_ExportRow` (`ConsumerStatefulWidget`, `ListTile` titre `body-large` + aide `body-medium on-surface-variant`, comme les switches), placé après les deux switches. `enabled: false` et `onTap: null` pendant l'export ; succès par `SnackBar` « Sauvegarde prête. », échec par `showErrorSnackBar` « Export impossible. », rien si le partage est fermé.
- **`strings_fr.dart`** : `exporterMesDonnees`, `exporterMesDonneesDetail`, `sauvegardePrete`, `exportImpossible`.
- **`test/helpers/pump_app.dart`** : nouveaux paramètres `shareFile` (défaut : double qui rend « partagé ») et `exportDirectory` (défaut : dossier temporaire créé au premier export, supprimé en fin de test). Passés en paramètres et non par `overrides`, car Riverpod refuse deux surcharges du même provider. Le dossier des photos n'a pas de défaut dans `pumpKadi` : `fiche_recette_photo_test` surcharge déjà `recipePhotosProvider` par `overrides` (même conflit) ; `parametres_export_test` le surcharge lui-même.
- **Tests écrits, pas lancés** (consigne) : `test/core/backup_export_test.dart` (Export complet : 8 tables comparées ligne par ligne à `SELECT *`, quiche supprimée présente, `format_version` = 3, parcours inversé, sources `ajout` et `week_selection`, photo intacte et non compressée ; Tables exportées = `allTables` = tables de `sqlite_master` ; Base fraîche ; Photo manquante ; export du même jour qui remplace ; deux échecs d'écriture sans `.zip` ni `.part` laissé) et `test/features/reglages/parametres_export_test.dart` (ligne sous les switches, ≥ 48 dp ; partage d'un `.zip` qui contient `data.json` et la photo, puis « Sauvegarde prête. » ; ligne désactivée pendant l'export, second toucher sans effet ; partage annulé ; échec ; TalkBack ; police ×2).
- **Vérification** : `flutter analyze` sans problème ; `grep -rn "Ã\|â€" lib test` sans résultat ; le schéma d'écriture du zip (`createWithStream` + `addArchiveFile` + `addFileSync(store)` + `closeSync`, puis `ZipDecoder`) vérifié par un script Dart hors projet : JSON UTF-8 relu, photo stockée sans compression, fichiers refermés (dossier supprimable sous Windows).
- **Surprises / à suivre** : les archives de jours différents restent dans le dossier temporaire (Android peut le vider) ; un export du même jour remplace le précédent. Une future colonne BLOB ferait échouer `jsonEncode` (« Export impossible. ») : aucune aujourd'hui.

## Plan Change Log

## Review Triage Log

- 2026-11-04 — revue unique du lot 3.1 à 3.4 (demande d'Antoine : tests et revue à la fin du lot). Première passe de tests : 725 passent, 6 échouent, tous des défauts de test (article « Piles » déjà fourni, lignes hors écran en police ×2, libellé ⚙ porté par le tooltip, tap sous l'AppBar) ; tests corrigés sans affaiblir d'assertion. Revue de code : high 0, medium 0, low 6. Patchés : photo de recette validée comme simple nom de fichier, entrée `photos/.` refusée, ingrédient en double dans une recette après report d'article supprimé (tests ajoutés). Reportés (deferred) : positions de fréquents égales, gel bref à l'import, drapeau de glisser du Parcours. Suite complète : 734 tests passent.

## Design Notes

- Lignes brutes SQL plutôt que les classes Drift : l'import (story 3) réinsère les mêmes clés colonne par colonne, et le test d'AD-9 devient « clés de `tables` == `allTables` ».
- [ASSUMPTION] Aide de la ligne « Recettes, liste et réglages dans un fichier » et succès « Sauvegarde prête. » (absents de Voice and Tone) ; Antoine les valide au test de fin d'epic.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- Tests : écrits mais lancés une seule fois à la fin des stories 3.1 à 3.4 (demande d'Antoine, 2026-11-04).
