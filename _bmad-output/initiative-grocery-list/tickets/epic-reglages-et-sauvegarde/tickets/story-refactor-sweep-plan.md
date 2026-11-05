---
title: 'Refactor sweep'
type: 'refactor'
ticket: '8'
created: '2026-11-05'
status: 'in-progress'
baseline_revision: '8f9636696c2c8ec8f3eaaa860bac69be39c8afd8'
route: 'full'
route_source: 'auto'
risk: 'low'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** les stories 3.1 à 3.7 ont laissé quelques défauts mineurs reportés, deux fichiers non formatés, et EXPERIENCE.md et DESIGN.md décrivent encore des choix abandonnés (Fiche recette enregistrée seule, voile du Panneau +, picto en Revue…) et ignorent les Paramètres construits ; la vérification finale (story 9) s'appuie sur ces documents.

**Approach:** nettoyage seul, sans capacité nouvelle : traiter la portée ci-dessous, chaque point traité ou explicitement reporté avec sa raison dans Implementation Notes ; remettre les deux documents UX en accord avec l'app et les Decisions, directement (Decision 2026-11-05 de l'epic : sans bmad-ux).

## Boundaries & Constraints

**Always:**
- **Code, portée fixée :**
  1. `lib/features/reglages/ui/parcours_screen.dart` (~l. 38) : `_dragFrom` remis à zéro quand un glisser est annulé ou au début de toute action TalkBack, pour qu'un « Monter »/« Descendre » ne suive jamais l'index brut d'un glisser fini ; test qui le prouve.
  2. Positions de fréquents égales après un import ou un report d'article : le fréquent reporté ou importé dont la position est déjà prise dans son rayon passe en dernier (max actif + 1), comme tout fréquent ajouté ou déplacé (AD-17) ; test.
  3. `dart format` sur `lib` et `test` (au moins `lib/features/recettes/data/recettes_repository.dart` et `test/core/backup_import_test.dart` ne le sont pas).
  4. Doublons entre les écrans de `features/reglages` (Articles, Fréquents, Parcours, Paramètres : lignes à Picto, lignes de navigation, champ de recherche) et chaînes inutilisées de `lib/core/strings/strings_fr.dart` : factoriser ou supprimer sans changer le rendu.
  5. Points reportés par la story 7 dans le `deferred` de son plan (`story-parametres-frequents-ouvert-par-gerer-plan.md`), s'il y en a.
- **Docs**, `_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md` et `DESIGN.md` (champ `updated` du frontmatter à 2026-11-05) : chaque ligne contredite par l'app et les Decisions est réécrite selon ce que l'app fait. Au moins : Panneau + sans voile (R15) ; Carte recette à petite coche ronde vide ou pleine, sans bordure, et crayon discret (R3) ; Ligne de Revue sans picto, champ quantité seulement si une quantité existe (C7, story 2.10) ; Fiche recette : ajout d'ingrédient par une popup de recherche, quantité facultative sans focus, bouton « Enregistrer » actif avec un nom et un ingrédient, « Quitter sans enregistrer ? » (R1, stories 2.11, 2.12) — supprimer l'enregistrement automatique des State Patterns et du Flux 4 ; Ligne de résultat sans libellé de rayon (déjà fait) ; « Gérer » mène à Paramètres › Fréquents ; Paramètres tels que construits (Écran allumé, Grouper par rayon, Parcours, Articles, Fréquents, Exporter, Importer, avec leurs aides) ; Paramètres › Articles (recherche, champ vide = tout le catalogue, Fiche article : nom, Picto affiché, rayon, unité pièce · g · ml · sans, Enregistrer) ; Paramètres › Fréquents (liste, retrait avec Annuler, rayon, recherche, Créer) ; Paramètres › Parcours (poignée, Monter/Descendre) ; microcopie nouvelle dans Voice and Tone ; Picto : repli neutre tant que le pack n'est pas choisi (story 5) ; Questions ouvertes : la seconde est tranchée (Créer au catalogue, 2026-11-04), la première reste (pack de pictos). Les marques [ASSUMPTION] confirmées par Antoine (validations des epics 1 et 2) sont retirées.
- Une ligne au memlog UX (`uv run _bmad/scripts/memlog.py append --workspace _bmad-output/initiative-grocery-list/ux-grocery-list --type event --text "…"`) dit que les deux documents ont été remis en accord avec l'app le 2026-11-05 par le Refactor sweep de l'epic 3.

**Never:** comportement nouvel ou modifié visible par Antoine (hors des deux correctifs 1 et 2) ; changement de schéma ; choix de pictos ; toute capacité qui manquerait (elle devient une nouvelle story).

</intent-contract>

## Code Map

- Plans de l'epic, dossier `_bmad-output/initiative-grocery-list/tickets/epic-reglages-et-sauvegarde/tickets/` : sections `deferred`, Implementation Notes et Review Triage Log, source de la portée.
- `lib/features/catalogue/data/catalogue_repository.dart` -- `_moveFrequents` (report d'article), ajout de fréquent (story 7), positions.
- `lib/core/backup/backup_import.dart`, `lib/app/actions/importer_une_sauvegarde.dart` -- où les fréquents importés arrivent (fusion générique par id, puis réconciliations).
- `lib/features/reglages/ui/*.dart` -- écrans à dédoublonner.
- Docs : `_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md` (Information Architecture, Voice and Tone, Component Patterns, State Patterns, Key Flows, Questions ouvertes), `DESIGN.md` (Components : `add-sheet` et son `barrier`, `recipe-card`, `review-row`, `settings-row`, `route-row`, `article-sheet`) ; Decisions de `_bmad-output/initiative-grocery-list/initiative-grocery-list.md` et des trois epics.

## Tasks & Acceptance

**Execution:**
- [x] points 1 à 5 du code, avec leurs tests.
- [x] EXPERIENCE.md et DESIGN.md, puis la ligne au memlog UX.

**Acceptance Criteria:**
- Given EXPERIENCE.md, when on suit le Flux 4 et les State Patterns de la Fiche recette, then ils décrivent le bouton « Enregistrer » et la popup d'ajout, comme l'app.
- Given le code, when `dart format --set-exit-if-changed lib test` tourne, then il réussit.

## Implementation Notes

**Ce qu'Antoine voit.** Rien de neuf à l'écran, sauf deux correctifs rares : dans Paramètres › Parcours, après un glisser interrompu (doigt perdu), « Descendre » TalkBack ne déplace plus qu'un cran (avant : le rayon partait en dernier) ; après un import, un fréquent importé ou reporté sur une position déjà prise dans son rayon passe en dernier de ce rayon au lieu d'être départagé par son id.

**Point par point.**
1. `_dragFrom` (`parcours_screen.dart`) : la liste ne signale pas un glisser annulé (pas d'`onReorderEnd`), et une action TalkBack passe par `onReorderItem` sans aucun rappel préalable : on ne peut donc pas remettre `_dragFrom` à zéro « au début » de l'un ou de l'autre. Décision : un drapeau `_dropping`, levé seulement par un `onReorderEnd` qui déplace la ligne et consommé par le `onReorderItem` qui suit (le déposer appelle toujours `onReorderEnd` avant `onReorderItem`). Tout autre déplacement est une action TalkBack, un cran ; `_dragFrom` est remis à zéro à chaque fin de glisser et à chaque déplacement. Un glisser annulé laisse `_dragFrom` posé, sans effet : il n'entre plus dans la décision. Pourquoi c'était visible : « Descendre » porte aussi l'action « à la fin » de la liste (même libellé, la dernière posée gagne), donc suivre l'index brut envoyait le rayon en dernier. Test : `parcours_screen_test.dart`, « après un glisser annulé, « Descendre » reste un seul cran » (glisser commencé sur Crèmerie, `gesture.cancel()`, puis « Descendre » sur Fruits et légumes : 2e, pas 13e).
2. Positions égales : `CatalogueRepository.reconcileImportedArticles` reçoit `insertedFrequents` (ids de fréquents insérés par la fusion, `inserted['frequents']` passé par `ImporterUneSauvegarde`) ; `_moveFrequents` rend les ids des fréquents reportés sur l'article gardé ; puis `_separateFrequentPositions` regroupe les fréquents actifs d'article actif par (rayon de l'article, position) : dans chaque groupe, le fréquent déjà là avant l'import garde sa place (sinon le plus petit id), les autres passent en dernier (max actif + 1, puis +2…), dans l'ordre position puis id. Le passage tourne à chaque import, même sans doublon d'article. Tests : `backup_import_test.dart`, « Fréquent importé à une position déjà prise dans son rayon… » (Corde de A sur la position de Ficelle de B, toutes deux en Divers : Corde passe à 41 ; Bougie de A à la même position mais en Entretien ne bouge pas) et « Fréquent reporté sur l'article gardé à une position déjà prise… » (le fréquent de Ficelle reporté sur 42, occupé par Bougie en Divers : 43). Les tests existants ne bougent pas : le contenu fourni n'a aucun fréquent en Divers et ses positions sont uniques.
3. `dart format lib test` : `recettes_repository.dart`, `backup_import_test.dart` et les fichiers touchés ici reformatés ; `dart format --set-exit-if-changed lib test` passe.
4. Dédoublonnage (`features/reglages`), rendu inchangé : `article_lines.dart` gagne `_LineFrame` (cadre commun d'`ArticleLine` et `CreateArticleLine`), `ArticleList` (la `ListView` des résultats et des fréquents, ligne « Créer « … » » en tête : trois copies dans Articles et Fréquents) et `ArticleSheetTitle` (Picto + titre lu comme titre, copié dans la Fiche article et le Choix de rayon d'un fréquent) ; les `ExcludeSemantics` autour du `Picto` sont retirés, `Picto` exclut déjà sa sémantique. `parametres_screen.dart` : `_NavigationRow`, `_ExportRow` et `_ImportRow` passent par un seul `_SettingsRow` (chevron facultatif, `onTap` nul = désactivée, comme avant), libellé et aide par `_RowTitle` / `_RowHelp`, partagés avec `_SettingsSwitch`. Parcours n'a rien de commun avec les autres écrans. `strings_fr.dart` : les 158 constantes sont toutes utilisées (`articles` l'est en interne par `cochesLu`) et aucune valeur n'est en double : rien supprimé.
5. Story 7 : `deferred: []`, ni report dans ses Implementation Notes : rien à faire. Le seul autre report de l'epic (import sur le fil UI, story 3, low) n'est pas dans la portée.

**Docs.** EXPERIENCE.md réécrit en entier sur la même structure, DESIGN.md par retouches ; `updated: 2026-11-05`. Fiche recette (bouton « Enregistrer », popup d'ajout, quantité sans focus, « Quitter sans enregistrer ? », « Supprimer la recette »), Carte recette (coche ronde, crayon 18 dp, sans bordure), Ligne de Revue (sans Picto, champ rempli seulement chiffré, deux lignes pour deux unités), « Gérer », Paramètres et ses trois sous-écrans, Ligne du catalogue (`catalogue-row`, nouveau), Popup d'ajout d'ingrédient (`ingredient-sheet`, nouveau), Fiche article et Choix de rayon d'un fréquent, Picto en repli neutre jusqu'à la story 3.5, microcopie (toutes les chaînes des Paramètres et de la Fiche recette), Questions ouvertes (la seconde tranchée). [ASSUMPTION] des epics 1 et 2 retirés ; les choix de l'epic 3 sont regroupés sous une seule marque dans Information Architecture, et l'import (« la plus récente l'emporte ») garde la sienne, faute de validation d'Antoine. Corrections relevées en lisant l'app : le Champ d'ajout du Panneau + n'a pas d'icône +, l'import invalide est un snackbar neutre (pas `{colors.error}`), « Enregistrer » de la Fiche article est un Bouton d'action argile (ajouté à la règle de l'argile), 4 recettes exemples, Valider masqué sans recette à valider.

**Écart à la portée, à trancher.** La portée demande « Panneau + sans voile (R15) », mais l'app pose un voile léger (scrim 20 % en clair, 32 % en sombre, `add_sheet.dart` et `ingredient_sheet.dart`), ajouté à la revue finale de l'epic 1 le 2026-11-02 (commit `63a2027`), après la Decision R15 du 2026-11-01, et validé par Antoine avec l'epic 1. La règle de la portée (« réécrite selon ce que l'app fait ») et le Never (aucun comportement modifié) l'emportent : les deux documents décrivent le voile léger (la ligne « Liste | Panneau + ouvert | sans voile » d'EXPERIENCE devient « sous un voile léger »). R15 de l'initiative dit encore « sans voile » : à corriger dans l'initiative, ou à remettre en question avec Antoine.

**Fichiers touchés.** `lib/features/reglages/ui/parcours_screen.dart`, `lib/features/catalogue/data/catalogue_repository.dart`, `lib/app/actions/importer_une_sauvegarde.dart`, `lib/features/reglages/ui/article_lines.dart`, `articles_screen.dart`, `frequents_screen.dart`, `article_sheet.dart`, `parametres_screen.dart`, `lib/features/recettes/data/recettes_repository.dart` (format seul) ; `test/features/reglages/parcours_screen_test.dart`, `test/core/backup_import_test.dart` ; `_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md`, `DESIGN.md`, `.memlog.md`.

**Vérification.** `flutter analyze` : aucun problème. `dart format --set-exit-if-changed lib test` : 0 fichier changé. `grep -rn "Ã\|â€" lib test _bmad-output/initiative-grocery-list/ux-grocery-list/*.md` : aucun résultat. Tests écrits, non lancés (l'orchestrateur lance la suite).

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `dart format --set-exit-if-changed lib test` -- expected: aucun fichier à reformater.
- `grep -rn "Ã\|â€" lib test _bmad-output/initiative-grocery-list/ux-grocery-list/*.md` -- expected: aucun résultat.
- Tests : écrits, lancés une seule fois à la fin des stories 3.6 à 3.8.
