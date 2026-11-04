---
title: 'Paramètres : Écran allumé et groupement par rayon'
type: 'feature'
ticket: '1'
created: '2026-11-04'
status: 'built'
baseline_revision: 'a2eeeb430688ca91125021b71ecf6e0a3b56c2a2'
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
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Kadi n'a pas d'écran Paramètres : aucune icône ⚙, impossible de garder l'écran allumé au magasin ni de voir la Liste sans groupement par rayon, alors que les réglages `keepScreenOn` et `groupByRayon` existent déjà en base.

**Approach:** une icône ⚙ sur Liste et Recettes pousse l'écran Paramètres (nouvelle fonctionnalité `reglages`, UI seulement) avec deux switches écrits par le `SettingsRepository` ; la Liste suit `groupByRayon` ; un contrôleur de la couche `app` maintient l'écran allumé tant que l'onglet Liste est affiché, par un service enveloppant le paquet `wakelock_plus`.

## Boundaries & Constraints

**Always:**
- Microcopie dans `lib/core/strings/strings_fr.dart` : titre « Paramètres » (aussi libellé TalkBack de ⚙) ; « Garder l'écran allumé » · « Pendant que la liste est affichée » ; « Grouper par rayon » · « Sinon, la liste suit l'ordre d'ajout » ; erreur « Réglage impossible à enregistrer. ».
- Setters `setKeepScreenOn(bool)`, `setGroupByRayon(bool)`, `setRouteOrder(List<Rayon>)` dans `SettingsRepository`, horodatés par l'horloge (`_clock.stamp`, AD-7), sans effet si la valeur ne change pas ; `setRouteOrder` exige les 13 rayons, chacun une fois (sinon `ArgumentError`). Il n'a pas d'UI ici : les stories 2 à 4 l'utilisent.
- Groupement désactivé : les lignes non cochées en ordre `added_at` croissant, sans `RayonHeader` ; la case garde la couleur du rayon ; la Section Cochés ne change pas. Le basculement est immédiat, sans redémarrage.
- Écran allumé actif ⇔ réglage vrai ET emplacement du routeur = `/liste` (aucune page poussée au-dessus ; le Panneau +, une feuille ou la popup quantité ne comptent pas) ET app au premier plan (`AppLifecycleState.resumed`). Toute autre situation relâche le maintien. Désactivé par défaut.
- ⚙ : `IconButton` dans les `actions` de l'AppBar, cible ≥ 48 dp, couleur `on-surface`, jamais d'argile ; sur Recettes à droite de Nouvelle liste. Paramètres : route poussée plein écran (flèche retour, sans barre de navigation), Lignes de paramètre en `SwitchListTile` M3 (DESIGN `settings-row`). Taille de police système respectée sans troncature.
- `features/reglages` ne dépend que de `core` (et de `features/catalogue` plus tard) ; `liste` ne dépend jamais de `reglages`.

**Never:** lignes Parcours, Articles, Fréquents, Exporter, Importer (stories suivantes) ; nouvelle colonne ou migration (les colonnes existent) ; permission Android nouvelle ; appel direct à `WakelockPlus` hors du service.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Grouper off | 3 lignes ajoutées Lait (Crèmerie), Tomates (F&L), Pain (Boulangerie), dans cet ordre | Liste : Lait, Tomates, Pain, sans en-tête | — |
| Grouper on de nouveau | idem | En-têtes revenus, ordre du parcours | — |
| Écran allumé, onglet Liste | réglage vrai, `/liste`, resumed | service `enable` | — |
| Changement d'onglet | → Recettes | service `disable` | — |
| Page poussée | Paramètres ouvert depuis la Liste | `disable` ; au retour sur la Liste, `enable` | — |
| Panneau + ouvert | sur la Liste | reste `enable` | — |
| Arrière-plan | lifecycle paused / inactive | `disable` ; au retour resumed sur Liste, `enable` | — |
| Réglage faux | n'importe où | jamais `enable` | — |
| Écriture qui échoue | setter lève | le switch revient à la valeur en base | snackbar d'erreur |

</intent-contract>

## Code Map

- `lib/core/settings/settings_repository.dart` -- ajouter les trois setters sur le modèle de `setFirstLaunch` (lecture de la ligne, `_clock.stamp(r.updatedAt)`), `encodeRouteOrder` existe déjà.
- `lib/core/settings/settings_providers.dart` -- `settingsProvider` (stream) : source des switches et de la Liste.
- `lib/core/router/app_router.dart` -- `AppRoutes` : ajouter `parametres = '/parametres'` ; `createAppRouter` reçoit les routes poussées de l'appelant (`core` ne connaît aucune fonctionnalité) ; accepter aussi des `observers`/rien de plus si inutile.
- `lib/app/kadi_app.dart` -- `_routerFor` : ajouter la `GoRoute` Paramètres dans `pushed` ; monter ici le contrôleur d'écran allumé (il lit le routeur, `settingsProvider` et le cycle de vie). Écouter `router.routerDelegate` (Listenable) et lire `routerDelegate.currentConfiguration.uri.path`.
- `lib/core/screen/screen_awake.dart` (nouveau) -- interface `ScreenAwake { Future<void> enable(); Future<void> disable(); }`, implémentation `wakelock_plus`, `screenAwakeProvider` surchargeable en test.
- `lib/app/keep_screen_on.dart` (nouveau) -- logique pure testable : (réglage, chemin, cycle de vie) → enable/disable, sans appel répété si l'état ne change pas.
- `lib/features/reglages/ui/parametres_screen.dart` (nouveau) -- écran Paramètres, deux `SwitchListTile`, erreurs par `showErrorSnackBar` (`lib/core/ui/error_snackbar.dart`).
- `lib/features/liste/state/liste_providers.dart` -- `listeGroupsProvider` : groupement off → un seul `RayonGroup` sans rayon (rendre `rayon` nullable, ou un champ `grouped`) avec toutes les lignes dans l'ordre reçu ; `watchUnchecked` livre déjà l'ordre d'ajout (vérifier `_watch`, l. ~673 de `liste_repository.dart`, sinon trier par `addedAt`). Vérifier que le provider réagit à un changement de réglage (`ref.watch(settingsProvider.future)`), sinon le faire réagir.
- `lib/features/liste/ui/liste_screen.dart` -- AppBar : ajouter ⚙ ; `build` l. ~311 : pas de `RayonHeader` quand le groupe n'a pas de rayon ; `_onGroups` (l. ~122) : prendre le rayon de chaque ligne (`item.rayon`), pas celui du groupe, pour garder le suivi AD-19.
- `lib/features/recettes/ui/recettes_screen.dart` -- AppBar l. ~137 : ⚙ après l'action Nouvelle liste (avant le `SizedBox` final).
- `pubspec.yaml` -- ajouter `wakelock_plus` en version épinglée exacte (comme les autres dépendances), compatible Dart 3.13 ; `flutter pub get`.
- `test/helpers/pump_app.dart` -- `pumpKadi` : surcharger `screenAwakeProvider` par un double par défaut, pour qu'aucun test n'appelle la plateforme.
- `test/architecture/imports_test.dart` -- étendre la règle : `features/liste` n'importe pas `features/reglages`.

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- ajouter `wakelock_plus` épinglé, `flutter pub get` -- touch point de l'epic.
- [x] `lib/core/settings/settings_repository.dart` -- trois setters -- seul écrivain de `settings` (AD-2).
- [x] `lib/core/screen/screen_awake.dart` -- service + provider -- isoler le paquet.
- [x] `lib/app/keep_screen_on.dart` + `lib/app/kadi_app.dart` -- contrôleur et branchement ; route Paramètres -- AD-13.
- [x] `lib/core/router/app_router.dart`, `lib/core/strings/strings_fr.dart` -- route et microcopie.
- [x] `lib/features/reglages/ui/parametres_screen.dart` -- écran.
- [x] `lib/features/liste/state/liste_providers.dart`, `lib/features/liste/ui/liste_screen.dart`, `lib/features/recettes/ui/recettes_screen.dart` -- groupement off et ⚙.
- [x] `test/core/settings_repository_test.dart` -- setters : valeur écrite, `updated_at` croissant, rien si valeur égale, `setRouteOrder` refuse 12 rayons ou un doublon.
- [x] `test/app/keep_screen_on_test.dart` -- chaque ligne Écran allumé de la matrice, au niveau de l'app montée (`pumpKadi` + double qui compte les appels), y compris Panneau + ouvert et cycle de vie (`tester.binding.handleAppLifecycleStateChanged`).
- [x] `test/features/reglages/parametres_screen_test.dart` -- ⚙ depuis Liste et Recettes ouvre Paramètres ; switches reflètent et écrivent la base ; réglages gardés après relance (`pumpKadi(database: db)`) ; échec d'écriture → snackbar et switch inchangé ; libellés TalkBack (⚙ « Paramètres », switches lus avec leur état) ; police ×2 sans débordement.
- [x] `test/features/liste/` (nouveau fichier ou existant) -- lignes Grouper de la matrice ; avec Panneau + ouvert et groupement off, une ligne ajoutée est toujours montrée et surlignée.

**Acceptance Criteria:**
- Given la Liste avec trois articles de rayons différents, when Antoine touche ⚙ puis désactive « Grouper par rayon » et revient, then la Liste montre les articles dans l'ordre d'ajout, sans en-tête, et les en-têtes reviennent quand il le réactive.
- Given « Garder l'écran allumé » activé, when l'onglet Liste est affiché, then le maintien de l'écran est demandé, et il est relâché sur Recettes, sur Paramètres et en arrière-plan.
- Given deux réglages modifiés, when l'app redémarre sur la même base, then les deux switches gardent leur valeur.

## Implementation Notes

- **Consigne du coordinateur (Antoine) : `flutter test` n'a PAS été lancé pour cette story** ; les tests sont écrits, à lancer après les stories suivantes. Vérifié par `flutter analyze` (aucun problème) et le grep des accents (aucun résultat).
- `wakelock_plus: 1.8.2` épinglé (dernière version, Dart >= 3.12, Flutter >= 3.44). Il tire `package_info_plus 10.2.2`, `win32`, `dbus`, `xml`... Manifestes Android de `wakelock_plus` et `package_info_plus` vides : aucune permission (C2) ; le plugin pose `FLAG_KEEP_SCREEN_ON`.
- Setters : `setKeepScreenOn`, `setGroupByRayon`, `setRouteOrder` passent par un `_write` privé commun (lecture de la ligne, rien si absente ou inchangée, `_clock.stamp(r.updatedAt)`). `setRouteOrder` lève `ArgumentError` de façon synchrone avant toute lecture.
- **Écart au Code Map** : le chemin du routeur se lit par `routerDelegate.currentConfiguration.lastOrNull?.matchedLocation`, pas `currentConfiguration.uri.path`. Dans go_router 18, `RouteMatchList.uri` ignore les `ImperativeRouteMatch` (routes poussées par `push`) : avec Paramètres ouvert, `uri.path` vaut toujours `/liste`. `matchedLocation` de la dernière feuille vaut `/parametres`. Le délégué notifie au `push`, au `pop` et au changement d'onglet.
- Contrôleur : `lib/app/keep_screen_on.dart` = fonction pure `shouldKeepScreenOn` + `KeepScreenOnController` (dédoublonne, part de « non maintenu », `release()` au démontage, erreurs de plateforme ignorées). `_KadiAppState` est `WidgetsBindingObserver`, écoute `settingsProvider` par `ref.listenManual` et le `routerDelegate` (ajouté à la création du routeur, retiré au `dispose`). Cycle de vie `null` (pas encore reçu, cas des tests) compté comme premier plan.
- ⚙ : widget partagé `lib/core/ui/settings_action.dart` (`SettingsAction`, `IconButton` + `tooltip` « Paramètres » qui donne le libellé TalkBack, `color: onSurface`, `Icons.settings_outlined`) ; `core/ui` ne connaît que `core/router`. Sur la Liste, il est suivi d'un `SizedBox(width: s2)`, comme sur Recettes.
- Paramètres : `ParametresScreen` (ConsumerWidget, sans état) ; les switches lisent `settingsProvider`, donc un échec d'écriture laisse le switch à la valeur en base, sans retour arrière à coder. Snackbar par le messager racine, comme Revue et Fiche recette.
- Groupement : `RayonGroup.rayon` devient `Rayon?` ; `ungrouped(items)` donne un seul groupe sans rayon dans l'ordre reçu (`watchUnchecked` trie déjà par `added_at`, `id`). `listeGroupsProvider` suit `settingsProvider.selectAsync((s) => (s.groupByRayon, s.routeOrder))` : le provider se reconstruit à chaque émission des réglages (la liste `routeOrder` est neuve à chaque décodage, donc le record n'est jamais égal), comme l'ancien `ref.watch(settingsProvider.future)`. C'est sans risque et rare (écritures de réglages seulement). `_onGroups` prend `item.rayon`.
- Microcopie : apostrophes typographiques (’) dans « Garder l’écran allumé », « Sinon, la liste suit l’ordre d’ajout », comme les autres chaînes de `strings_fr.dart`.
- Tests écrits (non lancés) : `test/core/settings_repository_test.dart` (groupe setters), `test/app/keep_screen_on_test.dart` (logique pure + app montée : Liste, onglets, Paramètres poussé et retour, Panneau + ouvert, inactive/hidden/paused/resumed, réglage faux, bascule depuis Paramètres, relance), `test/features/reglages/parametres_screen_test.dart`, `test/features/liste/liste_grouping_test.dart`, règles d'import (`liste` -> pas `reglages` ; `reglages` -> seulement `core`/`catalogue`). `pumpKadi` reçoit `screenAwake:` (par défaut un `FakeScreenAwake` neuf, `test/helpers/fake_screen_awake.dart`).
- Risques à surveiller au premier `flutter test` : (1) test Recettes « police ×2 sur 360 dp » : la Barre d'application porte maintenant ⚙ en plus de Nouvelle liste ; (2) libellé fusionné des `SwitchListTile` attendu en « titre
sous-titre » dans le test TalkBack ; (3) le cycle de vie du binding est remis à `resumed` en tearDown dans `keep_screen_on_test.dart`.
- Fichiers touchés : `pubspec.yaml`, `pubspec.lock`, `lib/core/settings/settings_repository.dart`, `lib/core/screen/screen_awake.dart` (nouveau), `lib/core/router/app_router.dart`, `lib/core/strings/strings_fr.dart`, `lib/core/ui/settings_action.dart` (nouveau), `lib/app/keep_screen_on.dart` (nouveau), `lib/app/kadi_app.dart`, `lib/features/reglages/ui/parametres_screen.dart` (nouveau), `lib/features/liste/state/liste_providers.dart`, `lib/features/liste/ui/liste_screen.dart`, `lib/features/recettes/ui/recettes_screen.dart`, `test/helpers/pump_app.dart`, `test/helpers/fake_screen_awake.dart` (nouveau), `test/architecture/imports_test.dart`, `test/core/settings_repository_test.dart`, `test/app/keep_screen_on_test.dart` (nouveau), `test/features/reglages/parametres_screen_test.dart` (nouveau), `test/features/liste/liste_grouping_test.dart` (nouveau).

## Plan Change Log

## Review Triage Log

- 2026-11-04 — revue unique du lot 3.1 à 3.4 (demande d'Antoine : tests et revue à la fin du lot). Première passe de tests : 725 passent, 6 échouent, tous des défauts de test (article « Piles » déjà fourni, lignes hors écran en police ×2, libellé ⚙ porté par le tooltip, tap sous l'AppBar) ; tests corrigés sans affaiblir d'assertion. Revue de code : high 0, medium 0, low 6. Patchés : photo de recette validée comme simple nom de fichier, entrée `photos/.` refusée, ingrédient en double dans une recette après report d'article supprimé (tests ajoutés). Reportés (deferred) : positions de fréquents égales, gel bref à l'import, drapeau de glisser du Parcours. Suite complète : 734 tests passent.

## Design Notes

- Le contrôleur vit dans `lib/app/` : il relie le routeur (`core`), les réglages (`core`) et le cycle de vie ; ni `liste` ni `reglages` n'en dépendent. Chemin du routeur plutôt que `ModalRoute.isCurrent` : le Panneau + est une feuille du navigateur racine qui rendrait la coque « non courante » alors que la Liste reste affichée.
- [ASSUMPTION] Sous-titre de « Grouper par rayon » : « Sinon, la liste suit l'ordre d'ajout » (absent de Voice and Tone) ; Antoine le valide au test de fin d'epic.
- Le maintien d'écran Android (`FLAG_KEEP_SCREEN_ON`) ne demande aucune permission (C2) ; vérifier le manifeste après `pub get`.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `flutter test` -- expected: tout passe (lancer seul, jamais deux suites en parallèle).
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat (accents intacts).
