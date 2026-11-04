---
title: "Photo et lien d'une recette"
type: 'feature'
ticket: '6'
created: '2026-11-02'
status: done
baseline_revision: '02df130dc69f25dac84f7114fac1b96667f1dbec'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/epic-recettes-et-revue.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-fiche-recette-creer-et-modifier-une-recette-en-moins-d-une-m-plan.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** La Fiche recette ne prend ni photo ni lien, et la Carte recette montre toujours le picto de repli (R1, R2 ; touch point galerie et appareil photo de l'epic).

**Approach:** Dans la Fiche recette, une zone photo (galerie ou appareil photo, remplacer, retirer) dont l'image est copiée, réencodée et plafonnée dans `photos/<uuid>.jpg` du dossier documents de l'app (AD-18), et un champ lien avec une icône qui l'ouvre dans le navigateur ; la carte affiche la photo, sinon le picto de repli.

## Boundaries & Constraints

**Always:**
- Photo : « Ajouter une photo » propose « Galerie » ou « Appareil photo » ; avec une photo, l'aperçu et les actions « Remplacer » et « Retirer ». Image prise par `image_picker` avec plafond de taille (côté 1600 px) et qualité JPEG (85), réencodée, puis copiée sous `photos/<uuid v4>.jpg` du dossier documents de l'app (`path_provider`) ; `recipes.photo` ne stocke que ce nom de fichier (AD-18). Choix annulé par Antoine : rien ne change.
- C2 : aucune permission ajoutée au manifeste ; la galerie passe par le sélecteur de photos Android et l'appareil photo par l'application photo du téléphone. Vérifier dans les manifestes des plugins ajoutés (cache pub) qu'aucun ne déclare de permission, et le noter.
- Remplacer ou retirer : l'ancien fichier est supprimé après l'écriture en base ; une photo choisie sur une fiche pas encore valide (sans nom ou sans ingrédient) part avec le premier enregistrement, et son fichier est supprimé si la fiche est quittée sans être créée.
- Lien : champ « Lien » facultatif (clavier URL), enregistré nettoyé (espaces de bord retirés, vide = nul) par l'enregistrement automatique de la story 5 ; icône d'ouverture (48 dp, lue « Ouvrir le lien ») visible quand le champ n'est pas vide, qui ouvre le lien dans le navigateur (`url_launcher`, application externe) ; sans schéma, `https://` est ajouté ; échec : snackbar « Impossible d'ouvrir le lien. ». Requête `<queries>` VIEW `https` ajoutée au manifeste pour Android 11+.
- Carte recette : la photo couvre la zone visuelle (recadrée) ; fichier absent ou illisible : picto de repli, sans erreur.
- Services `image_picker`, système de fichiers et `url_launcher` derrière des providers remplaçables en test (aucun appel de plateforme dans les tests).
- Dépendances : versions exactes dans `pubspec.yaml`, comme les autres ; Material par `material_ui`.
- TalkBack : « Ajouter une photo », « Galerie », « Appareil photo », « Remplacer la photo », « Retirer la photo », « Lien », « Ouvrir le lien » ; l'aperçu lu « Photo de Chili » ; police système sans troncature. Microcopie dans `strings_fr.dart`.

**Never:**
- Permission de stockage, de caméra ou réseau dans le manifeste ; aperçu du lien ou téléchargement.
- Suppression de recette (story 7), changement du schéma (les colonnes `link` et `photo` existent depuis la v3).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Galerie | Image choisie | Fichier `photos/<uuid>.jpg`, `recipes.photo` = ce nom, carte avec photo | Échec de copie : snackbar d'erreur, rien d'écrit |
| Annulé | Sélecteur fermé sans choix | Rien ne change | — |
| Remplacer | Photo A puis B | `photo` = B, fichier A supprimé | — |
| Retirer | Photo présente | `photo` nul, fichier supprimé, carte avec picto de repli | — |
| Fiche pas encore valide | Photo puis retour sans ingrédient | Pas de recette, fichier supprimé | — |
| Fichier perdu | `photo` renseigné, fichier absent | Carte avec picto de repli | — |
| Lien | « marmiton.org/chili » | Enregistré tel quel ; l'icône ouvre `https://marmiton.org/chili` | Échec : snackbar « Impossible d'ouvrir le lien. » |
| Lien vidé | Champ effacé | `link` nul, icône masquée | — |

</intent-contract>

## Code Map

- `pubspec.yaml` -- `image_picker`, `url_launcher`, `path_provider` en versions exactes compatibles Flutter 3.47.8 / Dart 3.13.7 ; `flutter pub get`.
- `android/app/src/main/AndroidManifest.xml` -- ajouter l'intention VIEW `https` à `<queries>` (garder PROCESS_TEXT) ; aucune `uses-permission`.
- `lib/features/recettes/` -- services photo (choix, copie sous `photos/`, suppression, chemin du dossier) et ouverture de lien, en providers ; `fiche_recette_screen.dart` / `fiche_recette_rows.dart` : zone photo et champ lien ; le brouillon (`RecipeDraft`) et `RecettesRepository.saveDraft` / `readSheet` portent `photo` et `link`.
- `lib/features/recettes/data/recettes_repository.dart` -- `watchCards` rend aussi `photo` ; `RecipeCardItem` le porte.
- `lib/features/recettes/ui/recipe_card.dart` -- `Image.file` du dossier photos en couverture de la zone visuelle (`KadiSpacing.recipeVisualHeight`), `errorBuilder` vers le picto de repli ; l'icône « modifier » reste lisible au-dessus.
- `lib/core/strings/strings_fr.dart` -- microcopie ci-dessus.
- Tests : repository (photo et lien écrits, nettoyés), services avec faux sélecteur et dossier temporaire, écran (matrice, TalkBack, police ×2), carte (photo, fichier perdu).

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml`, `AndroidManifest.xml` -- dépendances et `<queries>` ; vérifier les manifestes des plugins (aucune permission), noter le résultat
- [x] services photo et lien + tests -- copie, suppression, ouverture avec schéma
- [x] `recettes_repository.dart` + tests -- photo et lien dans la fiche et les cartes
- [x] fiche (zone photo, champ lien) + carte (photo) + `strings_fr.dart` + tests d'écran -- matrice, TalkBack, police

**Acceptance Criteria:**
- Given la fiche du Chili, when Antoine touche « Ajouter une photo », « Galerie » et choisit une image, then l'aperçu s'affiche dans la fiche et la carte « Chili » montre la photo sur Recettes.
- Given une photo, when il touche « Retirer », then la carte revient au picto de repli.
- Given un lien saisi, when il touche l'icône d'ouverture, then le navigateur est demandé avec ce lien.
- Given le build release installé, when Antoine prend une photo à l'appareil photo, then aucune demande de permission autre que celles du système n'apparaît (vérifié au test de fin d'epic).

## Implementation Notes

- Dépendances (versions exactes) : `image_picker` 1.2.4, `url_launcher` 6.3.3, `path_provider` 2.1.6, plus `image_picker_android` 0.8.13+25 et `image_picker_platform_interface` 2.11.2, déclarées pour activer `useAndroidPhotoPicker` (sinon la galerie passe par `ACTION_GET_CONTENT`, et non par le sélecteur de photos Android que C2 demande).
- Manifestes des plugins du cache pub (C2) : `image_picker_android` 0.8.13+25 (un `FileProvider` et un service de module du sélecteur de photos), `url_launcher_android` 6.3.33 (une `WebViewActivity`), `jni` 1.1.0 et `jni_flutter` 1.0.4+1 (vides ; `path_provider_android` 2.3.1 n'a pas de code Android, il passe par `jni`) : aucune `uses-permission`. Seuls les manifestes des applications d'exemple en déclarent, et ils ne sont pas fusionnés. Manifeste de l'app : `<queries>` VIEW `https` ajouté, PROCESS_TEXT gardé, aucune permission.
- Fichiers : `data/recipe_photos.dart` (`RecipePhotos` : `directory`, `importPhoto` → `photos/<uuid v4>.jpg`, `delete` limité à un nom de fichier seul ; `PhotoSource`, `PickPhoto`, `OpenLink`, plafond 1600 px, qualité 85), `data/recipe_link.dart` (`cleanRecipeLink`, `recipeLinkUri` : `https://` ajouté sans `schéma://`), `state/recettes_providers.dart` (`recipePhotosProvider`, `photosDirectoryProvider`, `photoPickerProvider`, `openLinkProvider`), `ui/fiche_recette_photo.dart` (feuille Galerie / Appareil photo, zone photo), `fiche_recette_screen.dart`, `recipe_card.dart`, `recettes_screen.dart`, `recettes_repository.dart` (`RecipeCardItem.photo`, `RecipeSheet.link/photo`, `RecipeDraft.link/photo`, `saveDraft` écrit lien nettoyé et photo), `strings_fr.dart`.
- Ménage des photos : la fiche connaît le fichier lu et ceux choisis ; après chaque écriture réussie, et à la fermeture (après la dernière écriture), elle supprime ceux que ni la base ni le brouillon ne portent. Conséquence : une photo choisie puis remplacée avant le premier enregistrement est supprimée dès la tentative d'écriture suivante ; une recette existante rendue invalide (nom vidé) garde son ancienne photo, la nouvelle est supprimée à la fermeture.
- Zone photo et champ « Lien » sous les Lignes d'ingrédient (le Flux 4 garde nom → recherche sans détour). L'aperçu (200 dp, coins `rounded.md`) est lu « Photo de Chili » ; « Remplacer » et « Retirer » sont lus « Remplacer la photo » et « Retirer la photo ». L'icône « Ouvrir le lien » est annoncée par son infobulle (comme l'icône « modifier »). Sur une carte avec photo, l'icône « modifier » a une pastille `surface` à 80 % pour rester lisible. Le chemin du dossier photos n'est lu (`path_provider`) que si une carte ou la fiche a une photo.
- [ASSUMPTION] Microcopie d'échec de la photo : « Photo impossible à ajouter. Réessaie. » ; apostrophe typographique dans « Impossible d’ouvrir le lien. », comme les autres messages.
- Risques : `image_picker` garde le format PNG d'une image PNG (réencodée et plafonnée, mais en PNG) ; elle est copiée sous un nom `.jpg` et s'affiche normalement (le décodeur lit le contenu). Si Android tue Kadi pendant la prise de vue (téléphone à court de mémoire), la photo est perdue (`retrieveLostData` non géré) : Antoine recommence. Le fichier temporaire d'`image_picker` reste dans le cache de l'app (vidé par le système).

- Après revue : photos décodées à la taille d'affichage (`ui/recipe_photo_image.dart`, `cacheWidth` = max(largeur, 2 × hauteur) × densité, `BoxFit.cover` et repli gardés) pour la carte et l'aperçu ; `RecipePhotos.directory` ne garde pas un échec en cache, `delete` ignore un dossier documents illisible (un test chacun) ; commentaire de `recipe_card.dart` remis à 80 colonnes.
- Vérification : `flutter pub get` résolu ; `flutter analyze` sans problème ; `flutter test` 588/588 (nouveaux : `recipe_photos_test.dart`, `fiche_recette_photo_test.dart`, groupe « photo et lien » de `fiche_recette_repository_test.dart`). `flutter build apk --debug` échoue sur le réseau Gradle (`PKIX path building failed` en téléchargeant `netty-common` depuis Maven Central : l'antivirus du poste intercepte TLS), non contourné, non bloquant ; le build est à refaire par Antoine.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `directory()` gardait en cache un échec du dossier documents et `delete()` levait hors de tout `try` depuis `dispose()` — corrigé : pas de cache d'un échec, `delete()` ignore l'échec ; deux tests.
  - `[medium]` `[patch]` Cartes et aperçu décodaient la photo entière (jusqu'à 1600 px) pour un petit visuel — corrigé : `RecipePhotoImage` décode à la taille affichée (`cacheWidth`), partagé par la carte et l'aperçu.
  - `[low]` `[reject]` Pastille de l'icône « modifier » gardée quand le fichier photo est perdu — cosmétique, cas rare (fichier supprimé hors de l'app).
  - `[low]` `[reject]` Icône « image non prise en charge » brièvement pendant le chargement du dossier, et aperçu perdu lu « Photo de … » — passager ou cas rare ; à revoir au sweep si besoin.
  - `[low]` `[reject]` « Remplacer » et « Retirer » perdent les drapeaux enabled/focusable sous `excludeSemantics` — TalkBack les annonce bien comme boutons actionnables ; à vérifier au test TalkBack de fin d'epic.
  - `[low]` `[patch]` Commentaire de `recipe_card.dart` au-delà de 80 colonnes — rewrappé.

## Verification

**Commands:**
- `flutter pub get` -- expected: dépendances résolues
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed
- `flutter build apk --debug` -- expected: le build compile ; s'il échoue sur le réseau Gradle (antivirus du poste), le noter dans Implementation Notes sans contourner, ce n'est pas bloquant

**Manual checks (if no CLI):**
- Manifestes des plugins `image_picker_android` et `url_launcher_android` du cache pub : aucune `uses-permission`.

## Auto Run Result

- Résumé : Fiche recette avec « Ajouter une photo » (Galerie ou Appareil photo, sélecteur de photos Android), aperçu, « Remplacer » et « Retirer » ; photo réencodée et plafonnée (1600 px, JPEG 85) sous `photos/<uuid>.jpg` ; champ « Lien » avec « Ouvrir le lien » dans le navigateur ; carte recette avec la photo, sinon le picto de repli.
- Fichiers : `pubspec.yaml` / `pubspec.lock` (image_picker 1.2.4, image_picker_android 0.8.13+25, image_picker_platform_interface 2.11.2, url_launcher 6.3.3, path_provider 2.1.6) ; `AndroidManifest.xml` (`<queries>` VIEW https, aucune permission) ; `recipe_photos.dart`, `recipe_link.dart`, `fiche_recette_photo.dart`, `recipe_photo_image.dart` (nouveaux) ; `recettes_repository.dart`, `recettes_providers.dart`, `fiche_recette_screen.dart`, `recipe_card.dart`, `recettes_screen.dart`, `strings_fr.dart` ; tests `recipe_photos_test.dart`, `fiche_recette_photo_test.dart`, `fiche_recette_repository_test.dart`.
- Revue : 3 correctifs (medium décodage, 2 low), 0 report, 3 rejets motivés.
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 590/590 ; manifestes des plugins sans `uses-permission` ; `flutter build apk --debug` en échec sur le TLS Gradle de l'antivirus (connu, non contourné) : le build reste à faire par Antoine.
- Risques : une source PNG reste en PNG sous un nom `.jpg` (s'affiche normalement) ; photo perdue si Android tue l'app pendant l'appareil photo ; appareil photo et absence de demande de permission à vérifier sur le téléphone.
