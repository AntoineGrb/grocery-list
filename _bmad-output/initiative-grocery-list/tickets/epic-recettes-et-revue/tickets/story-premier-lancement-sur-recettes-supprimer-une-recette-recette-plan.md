---
title: 'Premier lancement sur Recettes, supprimer une recette, Recettes vide'
type: 'feature'
ticket: '7'
created: '2026-11-02'
status: 'built'
baseline_revision: '05897e99360fd6b5de8a2cc2336999cc30b737f8'
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
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** L'app s'ouvre toujours sur la Liste, même au premier lancement qui montre les recettes exemples (R11, AD-13), et une recette ne se supprime pas (R1, Flux 6 étape 5).

**Approach:** Le chargeur de contenu lève le drapeau de premier lancement quand il insère des recettes exemples ; le démarrage le lit, ouvre l'app sur Recettes avec la ligne d'accueil et le baisse. La Fiche recette gagne « Supprimer la recette », sans confirmation, avec un snackbar Annuler sur Recettes.

## Boundaries & Constraints

**Always:**
- AD-13 : le chargeur d'AD-8 (`lib/core/db/seed/seed_loader.dart`) lève `settings.first_launch`, dans sa transaction, quand il insère au moins une recette exemple (installation neuve, ou téléphone qui tournait déjà l'epic 1 et reçoit le fichier de recettes pour la première fois). Au démarrage, si le drapeau est levé, l'app s'ouvre sur l'onglet Recettes et le drapeau est baissé (écriture par `SettingsRepository`, horloge) ; sinon elle s'ouvre sur la Liste. Le drapeau baissé, les lancements suivants s'ouvrent sur la Liste.
- Ligne d'accueil « Voici quelques recettes pour essayer. Supprime-les quand tu veux. » en haut de Recettes, au-dessus des cartes, seulement pendant la session qui a baissé le drapeau (état de session, jamais persisté) et tant qu'il y a des recettes ; non interactive, lue par TalkBack.
- Supprimer : bouton « Supprimer la recette » (`error`, cible ≥ 48 dp) en bas de la Fiche recette, seulement pour une recette déjà enregistrée. Un tap, sans confirmation (C9) : la recette est supprimée logiquement (AD-7 : ses ingrédients et sélections comptent comme supprimés par leur parent, aucune autre ligne écrite), la fiche se ferme et Recettes montre « Recette supprimée : Chili » · « Annuler » sous son propre messager. Annuler rend la recette (AD-10) ; une sélection active de la recette redevient visible avec elle.
- R7 : supprimer une recette, validée ou non, ne change jamais la liste en cours. Le fichier photo est gardé (Annuler).
- Recettes sans recette : message « Pas encore de recette. Ajoute ta première avec +. » et le FAB + (déjà en place) ; la ligne d'accueil disparaît.
- Tests existants qui supposent l'ouverture sur la Liste : l'aide `pumpKadi` (`test/helpers/pump_app.dart`) garde ce comportement par défaut (par exemple en baissant le drapeau avant de monter l'app), avec une option explicite pour tester le premier lancement.
- Microcopie dans `strings_fr.dart` ; TalkBack : « Supprimer la recette », snackbar annoncé ; police système sans troncature.

**Never:**
- Confirmation de suppression ; suppression physique ; suppression du fichier photo à la suppression de la recette.
- Changer le comportement du chargeur pour les articles et les fréquents.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Installation neuve | Base vide | Ouverture sur Recettes, ligne d'accueil ; drapeau baissé | — |
| Lancement suivant | Drapeau baissé | Ouverture sur la Liste, pas de ligne d'accueil | — |
| Téléphone de l'epic 1 | Réglages sans version `recettes` | Recettes insérées, ouverture sur Recettes une fois | — |
| Recettes déjà chargées | Version `recettes` à jour | Drapeau non levé | — |
| Supprimer | Chili validé, liste avec ses lignes | Carte disparue, liste identique, snackbar | Échec : snackbar d'erreur, fiche ouverte, rien d'écrit |
| Annuler | Juste après | Carte de retour, sélectionnée si elle l'était | Autre écriture entre-temps : sans effet (AD-10) |
| Fiche neuve | Pas encore enregistrée | Pas de bouton « Supprimer la recette » | — |
| Tout supprimé | Dernière recette supprimée | Message d'état vide et FAB + ; ligne d'accueil absente | — |

</intent-contract>

## Code Map

- `lib/core/db/seed/seed_loader.dart` -- `_insertRecettes` sait s'il a inséré ; lever `first_launch` dans la même transaction (nouvelle écriture du `SettingsRepository`, ou valeur passée à `insertDefaults` pour une base neuve).
- `lib/core/settings/settings_repository.dart` -- écriture du drapeau (horloge, AD-7).
- `lib/app/startup.dart` -- après le chargeur, lire le drapeau, le baisser, rendre « premier lancement » au démarrage.
- `lib/app/kadi_app.dart` -- le routeur (`createAppRouter(initialLocation: …)`, `lib/core/router/app_router.dart`) se crée après le démarrage avec Recettes ou Liste ; l'état de session « afficher l'accueil » est exposé à Recettes par un provider.
- `lib/features/recettes/data/recettes_repository.dart` -- suppression logique d'une recette avec son `UndoRow.before` (`lib/core/undo/undo.dart`).
- `lib/features/recettes/ui/fiche_recette_screen.dart` -- bouton en bas ; à la suppression, la fiche se ferme en rendant le résultat (nom, entrée Annuler) à Recettes, qui attend `context.push` (`recettes_screen.dart`, FAB et crayon) et montre `showUndoSnackBar`.
- `lib/features/recettes/ui/recettes_screen.dart` -- ligne d'accueil, snackbar de suppression.
- `test/helpers/pump_app.dart` -- défaut inchangé, option premier lancement.
- Tests : chargeur (drapeau levé ou non selon la matrice), démarrage (Recettes puis Liste), repository (suppression, Annuler), écrans (suppression, Annuler, R7, état vide, accueil, TalkBack, police ×2).

## Tasks & Acceptance

**Execution:**
- [x] `seed_loader.dart`, `settings_repository.dart` + tests -- drapeau levé à l'insertion des recettes
- [x] `startup.dart`, `kadi_app.dart`, `pump_app.dart` + tests -- ouverture sur Recettes une fois, accueil de session
- [x] `recettes_repository.dart` + test -- suppression et Annuler
- [x] `fiche_recette_screen.dart`, `recettes_screen.dart`, `strings_fr.dart` + tests d'écran -- matrice

**Acceptance Criteria:**
- Given une installation neuve, when Antoine ouvre Kadi, then l'onglet Recettes s'affiche avec la ligne d'accueil et les recettes exemples ; when il relance l'app, then elle s'ouvre sur la Liste sans ligne d'accueil.
- Given Chili con carne validé, when il ouvre sa fiche et touche « Supprimer la recette », then la carte disparaît, la Liste est identique et Recettes affiche « Recette supprimée : Chili con carne » · « Annuler » ; when il touche « Annuler », then la carte revient.
- Given toutes les recettes supprimées, when il regarde Recettes, then il voit « Pas encore de recette. Ajoute ta première avec +. » et le FAB +.

## Implementation Notes

- Drapeau : `SettingsRepository.insertDefaults(firstLaunch:)` (base neuve) et `setSeedVersions(raiseFirstLaunch:)` (téléphone de l'epic 1) le lèvent en une seule écriture des réglages ; `setFirstLaunch(false)` le baisse par l'horloge. `_insertRecettes` rend s'il a inséré au moins une recette.
- Démarrage : `appStartupProvider` rend `true` au premier lancement (drapeau lu levé, puis baissé) ; `KadiApp` crée le routeur une fois avec `initialLocation` Recettes ou Liste. `welcomeProvider` (`lib/app/startup.dart`, Notifier de session) porte la ligne d'accueil ; Recettes l'éteint (`dismiss`) quand ses cartes deviennent vides, pour qu'elle ne revienne pas avec Annuler ou une nouvelle recette.
- Suppression : `RecettesRepository.deleteRecipe` (transaction, ne réécrit que `recipes`) rend nom + `UndoRow.before` ; la fiche attend ses écritures en cours, supprime, enregistre l'entrée Annuler et se ferme par `context.pop(RecipeDeletion)` ; Recettes l'attend (`_openFiche`) et montre `showUndoSnackBar` sous son messager. Le bouton apparaît pour une recette lue ou dès le premier enregistrement d'une fiche neuve.
- `pumpKadi` : par défaut, charge le contenu fourni et baisse le drapeau avant de monter l'app (ouverture sur la Liste) ; `firstLaunch: true` part d'une base vide ; `database:` relance sur une base existante.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Le drapeau se levait à toute insertion de recette exemple : une future version du fichier rouvrirait un téléphone utilisé sur Recettes avec l'accueil (contre R11) — corrigé : levé seulement au premier chargement du fichier de recettes (aucune version `recettes` stockée) ; test inversé.
  - `[low]` `[reject]` Retour pressé pendant la suppression : recette supprimée sans snackbar Annuler — fenêtre de quelques millisecondes, la recette reste en base (suppression logique).
  - `[low]` `[reject]` « Créer « … » » encore en vol pendant la suppression rend l'Annuler sans effet — séquence rare, aucune donnée fausse (AD-10).
  - `[low]` `[patch]` Commentaire « Annuler rend la recette telle que la fiche l'a laissée » inexact si le dernier enregistrement a échoué — reformulé : dernière version enregistrée.
  - `[low]` `[reject]` Une suppression en échec avance l'horloge et invalide un Annuler en attente — même schéma que les autres écritures du projet (horodatage avant l'UPDATE), aucune donnée fausse.
  - `[low]` `[patch]` `pumpKadi` ignorait `firstLaunch` avec `database:` — `assert` ajouté.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : au premier chargement des recettes exemples (installation neuve ou téléphone de l'epic 1), l'app s'ouvre une fois sur Recettes avec la ligne d'accueil, puis sur la Liste ; « Supprimer la recette » en bas de la fiche, sans confirmation, avec « Recette supprimée : … » · « Annuler » sur Recettes ; Recettes vide avec son message et le FAB +.
- Fichiers : `seed_loader.dart`, `settings_repository.dart`, `startup.dart`, `kadi_app.dart`, `app_router.dart`, `recettes_repository.dart` (`deleteRecipe`), `fiche_recette_screen.dart`, `recettes_screen.dart`, `strings_fr.dart`, `pump_app.dart` ; tests `seed_loader_test.dart`, `settings_repository_test.dart`, `supprimer_recette_test.dart` (nouveau), `fiche_recette_photo_test.dart`, `app_test.dart`.
- Revue : 3 correctifs (medium drapeau, 2 low), 0 report, 3 rejets motivés.
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 615/615.
- Risques : retour pressé pendant la suppression ou création d'article en vol : Annuler absent ou sans effet, rare.
