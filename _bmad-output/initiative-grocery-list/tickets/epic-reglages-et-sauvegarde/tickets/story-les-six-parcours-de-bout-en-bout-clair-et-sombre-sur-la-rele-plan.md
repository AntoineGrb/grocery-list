---
title: 'Les six parcours de bout en bout, clair et sombre, sur la release installée'
type: 'chore'
ticket: '9'
created: '2026-11-05'
status: 'built'
baseline_revision: '30c833bc430973dac0a723aba94f88d4ac57897f'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** chaque story a ses tests, mais rien ne vérifie d'un bout à l'autre les six parcours d'EXPERIENCE.md, en clair et en sombre, ni le plancher d'accessibilité sur toutes les surfaces ; c'est la vérification qui clôt l'initiative.

**Approach:** une suite de bout en bout sur l'app montée entière (`pumpKadi`), lancée par `flutter test` sans appareil, qui rejoue les six Key Flows d'EXPERIENCE.md (version du 2026-11-05) dans les deux thèmes avec une assertion sur chaque moment ★, plus l'aller-retour export → import sur une base neuve et les contrôles d'accessibilité ; la même suite se lance aussi sur le téléphone par `integration_test/`. La part manuelle (release installée, TalkBack, vraies courses) revient à Antoine.

## Boundaries & Constraints

**Always:**
- Fichiers `test/e2e/` : un fichier par flux (`flux_1_dimanche_soir_test.dart` … `flux_6_premier_lancement_test.dart`), chacun joué deux fois, thème clair puis sombre (luminosité de la plateforme du test), avec les gestes réels de l'utilisateur (taps, saisie, glisser), jamais d'écriture directe en base sauf pour poser l'état de départ que le flux suppose (ex. Flux 5 : une liste déjà validée). Chaque moment ★ a son assertion nommée ★ ; chaque « Échec : » du flux est un test aussi.
- `test/e2e/sauvegarde_test.dart` : base remplie par des gestes (recette avec photo, liste, fréquent ajouté, parcours modifié, réglages changés), export par la ligne des Paramètres (double de partage qui garde les octets), import sur une base neuve par la ligne Importer (double du sélecteur) : recettes, photo, catalogue, fréquents, parcours, réglages et liste en cours identiques.
- `test/e2e/accessibilite_test.dart` : sur chaque surface (Liste, Liste avec Panneau +, popup quantité, Feuille d'édition, Recettes, Fiche recette, popup d'ingrédient, Revue, Paramètres et ses sous-écrans, Fiche article, grille de pictos), dans les deux thèmes : `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` ; police ×2 sur 360 dp sans exception de débordement ; animations désactivées (`MediaQuery.disableAnimations`) : une coche et un ajout du panneau aboutissent sans attente d'animation.
- Un défaut d'app trouvé par la suite : corrigé dans l'app s'il est petit et sans ambiguïté (noté dans Implementation Notes), sinon test marqué `skip` avec la raison et noté en `deferred` ; jamais d'assertion affaiblie pour passer.
- `integration_test/parcours_test.dart` : appelle les mêmes scénarios (code partagé dans `test/e2e/`, ou un dossier commun) sous `IntegrationTestWidgetsFlutterBinding`, pour `flutter test integration_test -d <téléphone>` ; `integration_test` (sdk) en dev_dependency. Il tourne sur l'app debug (`applicationIdSuffix ".debug"`), jamais sur les données de la release.
- `README.md` : une section « Vérifier » avec les deux commandes.

**Never:** modifier le comportement de l'app hors correctif de défaut ; `flutter install` ; toucher la release installée d'Antoine.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Flux 1 à 6 | gestes du flux, clair puis sombre | chaque ★ observé | — |
| Échecs des flux | gestes de la ligne « Échec » | comportement décrit | — |
| Aller-retour | export puis import sur base neuve | données identiques | — |
| Plancher a11y | chaque surface, deux thèmes | guidelines tenues, ×2 sans débordement | défaut → corrigé ou noté |

</intent-contract>

## Code Map

- `_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md` -- Key Flows, Accessibility Floor (remis à jour le 2026-11-05).
- `test/helpers/pump_app.dart` -- `pumpKadi` (base en mémoire, contenu fourni, doubles : écran allumé, partage, sélecteur, dossiers), `test/helpers/test_db.dart`, `test/helpers/recettes.dart`.
- Tests d'écran existants, modèles des gestes : `test/features/liste/add_sheet_test.dart`, `test/features/recettes/recettes_screen_test.dart`, `test/features/recettes/fiche_recette_screen_test.dart`, `test/features/reglages/parametres_export_test.dart`, `parametres_import_test.dart`, `parcours_screen_test.dart`.
- `lib/core/strings/strings_fr.dart` -- textes à chercher.

## Tasks & Acceptance

**Execution:**
- [x] `test/e2e/` -- six flux × deux thèmes, leurs échecs, sauvegarde, accessibilité.
- [x] `integration_test/parcours_test.dart`, `pubspec.yaml`, `README.md`.

**Acceptance Criteria:**
- Given le dépôt, when on lance `flutter test`, then les six parcours passent en clair et en sombre, avec l'aller-retour de sauvegarde et le plancher d'accessibilité.

## Implementation Notes

**Fichiers.** `test/e2e/e2e_harness.dart` (`testBothThemes` : chaque scénario déclaré deux fois, clair puis sombre, par `platformBrightnessTestValue` ; `pumpE2e` vérifie que le thème affiché suit la plateforme ; gestes communs) ; `flux_1_dimanche_soir_test.dart` … `flux_6_premier_lancement_test.dart`, `sauvegarde_test.dart`, `accessibilite_test.dart` (chacun expose une fonction de scénarios, appelée par son `main` et par `integration_test/parcours_test.dart`) ; `test/helpers/pump_app.dart` (`seedAssetsReader` : lecture du contenu fourni remplaçable, le bundle de l'app sur le téléphone) ; `pubspec.yaml` + `pubspec.lock` (`integration_test` sdk en dev) ; `README.md` (section « Vérifier ») ; correctif `lib/features/liste/ui/quantity_input.dart`. 36 tests (18 scénarios × 2 thèmes).

**Décisions.**
- Flux adaptés au contenu fourni : Flux 1, les recettes exemples n'ont pas de tomates communes ; la fusion se montre sur Oignons et Poivrons (3 pièces), Lardons (400 g) ; Œufs 6 → 4 (les recettes donnent 6, pas 8). Flux 4 : « Épices » n'est pas au catalogue, elle passe par « Créer « Épices » » (couvre aussi la ligne Échec « ingrédient inconnu »).
- États de départ écrits en base, seulement ceux que le flux suppose : Flux 1 une ligne de la semaine passée (avant Nouvelle liste) ; Flux 2 Écran allumé actif ; Flux 3 une liste de 12 fruits et légumes et « Piles » retiré du catalogue (le flux suppose « piles » inconnu) ; Flux 4 « Haricots rouges » au catalogue. Les listes validées des Flux 2 et 5 sont faites par les gestes.
- Flux 3 : le clavier est simulé par `viewInsets` (300 dp sur 412 × 914) ; le tap sur « Ajouts fréquents » ferme le clavier, la marge est alors retirée à la main.
- Le défilement des fréquents du panneau remonte par petits glissements (jamais le glissement vers le bas qui fermerait le panneau), puis descend.
- Sauvegarde : comparaison ligne à ligne de toutes les tables hors réglages, plus parcours, groupement et Écran allumé ; photo comparée octet par octet ; base neuve = premier lancement (`firstLaunch`).
- Accessibilité : 15 surfaces visitées par les gestes (dont Section Cochés dépliée en plus de la liste demandée) ; guidelines évaluées par `guideline.evaluate` ; police ×2 sur 360 dp par `takeException` à chaque surface ; animations coupées : ligne ajoutée opaque et sans surlignage dès son apparition, coche sans délai (pas `hasRunningAnimations` : le curseur du champ focalisé clignote par une animation).

**Défaut trouvé et corrigé.** Popup quantité : les puces resserrées du Choix d'unité (`VisualDensity.compact`) n'avaient qu'une cible de 40 dp (« g » 46 × 40), sous le plancher de 48 dp (EXPERIENCE, Cibles tactiles ; le code annonçait déjà « La cible reste de 48 dp »). Correctif : en mode resserré, chaque puce est entourée d'une zone de 48 × 48 dp, lue comme la puce (bouton, libellé, état choisi) et qui la choisit, sur le modèle d'`AddTag`. La puce garde son dessin ; la rangée passe de 40 à 48 dp. `quantity_popup_test`, `add_panel_tags_test`, `liste_screen_test`, `fiche_recette_screen_test` repassent. Aucun autre défaut : toutes les autres surfaces tiennent les trois guidelines dans les deux thèmes, aucune ne déborde en police ×2.

**Surprises.** Le Write d'une espace insécable littérale l'a changée en espace simple : `' '` dans le code. Un premier run de Flux 3 est resté bloqué (boucle de défilement sans borne, corrigée) ; son `flutter_tester` orphelin verrouille `build/native_assets/windows/sqlite3.dll` et n'a pas pu être arrêté (refusé par le garde-fou) : la suite a donc été lancée sur une copie du dépôt (lib, test, assets, .dart_tool) dans le dossier temporaire, `flutter test test/e2e` → 36/36. `integration_test` n'a pas été lancé (aucun téléphone).

## Plan Change Log

## Review Triage Log

- 2026-11-05 — suite complète dans le dépôt : 854 tests passent (trois fichiers relancés seuls après une erreur de chargement du banc, « Connection closed »). Part manuelle en attente d'Antoine : release installée, TalkBack, vraies courses, revalidation des pictos et des hypothèses de l'epic.

## Design Notes

- Part manuelle, par Antoine : release installée (`adb install -r`, export avant), passage des parcours avec TalkBack, une vraie semaine de courses ; validation de la correspondance des pictos et des hypothèses de l'epic.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `dart format --set-exit-if-changed lib test integration_test` -- expected: aucun fichier à reformater.
- `flutter test test/e2e` -- expected: tout passe (un seul processus de test à la fois).
