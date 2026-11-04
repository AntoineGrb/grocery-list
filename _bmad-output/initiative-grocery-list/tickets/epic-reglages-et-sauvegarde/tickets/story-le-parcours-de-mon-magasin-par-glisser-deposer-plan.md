---
title: 'Le parcours de mon magasin, par glisser-déposer'
type: 'feature'
ticket: '4'
created: '2026-11-04'
status: 'built'
baseline_revision: '831926a10738e348f26b9114f36ad498c502ea34'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred:
  - {summary: 'Parcours : _dragFrom pas remis à zéro si un glisser est annulé sans onReorderEnd ; un Monter/Descendre TalkBack suivant suivrait l index brut', location: 'lib/features/reglages/ui/parcours_screen.dart:38', severity: low}
---

<intent-contract>

## Intent

**Problem:** les 13 rayons suivent l'ordre par défaut ; Antoine ne peut pas les ranger dans l'ordre de son magasin, alors que la Liste, la Revue et le Panneau + lisent déjà `settings.route_order`.

**Approach:** une ligne « Parcours » des Paramètres pousse Paramètres › Parcours, une liste réordonnable des 13 rayons (glisser-déposer, plus les actions TalkBack « Monter » et « Descendre ») qui écrit l'ordre par `SettingsRepository.setRouteOrder` (story 1).

## Boundaries & Constraints

**Always:**
- Route poussée `/parametres/parcours` (constante dans `AppRoutes`, `GoRoute` ajoutée par `lib/app/kadi_app.dart`), titre « Parcours », flèche retour. Ligne « Parcours » · « L'ordre des rayons dans ton magasin » (chevron) en tête des lignes de navigation, sous les deux switches et au-dessus d'Exporter.
- Ligne de parcours (DESIGN `route-row`) : `RayonPastille` (`lib/core/ui/rayon_pastille.dart`, comme l'En-tête de rayon) + poignée de glisser à droite en `on-surface-variant`, poignée et ligne ≥ 48 dp ; ligne soulevée (élévation M3) pendant le glisser. `ReorderableListView` avec poignée explicite (`ReorderableDragStartListener`), pas d'appui long n'importe où (C10 : seul glisser-déposer de l'app).
- Chaque déposer écrit les 13 rayons dans le nouvel ordre (`setRouteOrder`) ; l'écran lit l'ordre dans `settingsProvider` (aucune copie locale persistante au-delà du geste en cours). Échec d'écriture : l'ordre revient, snackbar « Parcours impossible à enregistrer. ».
- Actions sémantiques par ligne : « Monter » (absente sur la première), « Descendre » (absente sur la dernière) ; chacune échange avec le voisin, écrit, puis annonce « Boulangerie, position 2 sur 13 ». La ligne est lue « Fruits et légumes, position 1 sur 13 ».
- La Liste, la Revue, les Ajouts fréquents du Panneau + et la liste déroulante du Tag Rayon suivent le nouvel ordre sans redémarrage : vérifier que chacun réagit au flux de réglages (`lib/features/liste/state/liste_providers.dart` l. ~37 et ~120, `lib/features/recettes/state/recettes_providers.dart` l. ~98, `lib/features/liste/ui/add_sheet.dart` l. ~456) et corriger celui qui ne lit l'ordre qu'une fois.
- Animations désactivées : déplacement sans animation. Police système ×2 : le nom du rayon passe à la ligne, rien ne déborde.

**Never:** réinitialisation de l'ordre par défaut ; ajout, retrait ou renommage de rayon (AD-11) ; réordonnancement des fréquents ou des articles.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Glisser | Boulangerie glissé en premier | `route_order` commence par `boulangerie` ; Liste, Revue et fréquents du panneau mettent Boulangerie en tête | — |
| Descendre | action sur Fruits et légumes (1er) | échangé avec le 2e, annonce « Fruits et légumes, position 2 sur 13 » | — |
| Extrémités | première ligne ; dernière ligne | pas de « Monter » ; pas de « Descendre » | — |
| Relance | ordre modifié puis redémarrage | même ordre | — |
| Échec | `setRouteOrder` lève | ordre affiché revenu à celui de la base | snackbar d'erreur |

</intent-contract>

## Code Map

- `lib/core/settings/settings_repository.dart` -- `setRouteOrder` (story 1), `decodeRouteOrder` garantit toujours 13 rayons.
- `lib/core/router/app_router.dart`, `lib/app/kadi_app.dart` -- route poussée.
- `lib/features/reglages/ui/parametres_screen.dart` -- ligne Parcours (stories 1 à 3 y ont mis switches, Exporter, Importer).
- `lib/features/reglages/ui/parcours_screen.dart` (nouveau) -- l'écran.
- `lib/core/ui/rayon_pastille.dart`, `lib/features/liste/ui/rayon_header.dart` -- dessin de la pastille et du nom.
- `lib/core/strings/strings_fr.dart` -- microcopie.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/router/app_router.dart`, `lib/app/kadi_app.dart`, `lib/core/strings/strings_fr.dart` -- route et textes.
- [x] `lib/features/reglages/ui/parcours_screen.dart`, `lib/features/reglages/ui/parametres_screen.dart` -- écran et ligne.
- [x] consommateurs de l'ordre -- réactivité vérifiée, corrigée au besoin.
- [x] `test/features/reglages/parcours_screen_test.dart` -- chaque ligne de la matrice (glisser avec `tester.drag` sur la poignée ; actions par `tester.semantics`/`SemanticsAction.customAction`), TalkBack, police ×2, animations désactivées.
- [x] test d'intégration widget (app montée) -- après un réordonnancement, la Liste, la Revue et le Panneau + suivent l'ordre.

**Acceptance Criteria:**
- Given la Liste avec Tomates (Fruits et légumes) et Pain (Boulangerie), when Antoine glisse Boulangerie en premier dans Parcours et revient, then Pain est au-dessus de Tomates, et la Revue et les Ajouts fréquents suivent le même ordre.

## Implementation Notes

**Fichiers touchés**
- `lib/core/router/app_router.dart` : `AppRoutes.parcours = '/parametres/parcours'`.
- `lib/app/kadi_app.dart` : `GoRoute` poussée vers `ParcoursScreen`.
- `lib/core/strings/strings_fr.dart` : `parcours`, `parcoursDetail` (« L’ordre des rayons dans ton magasin », apostrophe typographique comme le reste du fichier), `parcoursImpossible`, `monter`, `descendre`, `positionSur(rayon, position, total)` (libellé de ligne et annonce).
- `lib/features/reglages/ui/parametres_screen.dart` : `_NavigationRow` (ListTile, aide en `on-surface-variant`, chevron) « Parcours » entre les switches et Exporter, `context.push(AppRoutes.parcours)`.
- `lib/features/reglages/ui/parcours_screen.dart` (nouveau) : `ParcoursScreen` et `RouteRow` (publique pour les tests).
- `test/features/reglages/parcours_screen_test.dart` (nouveau), `test/app/parcours_magasin_test.dart` (nouveau, intégration app montée).
- `test/features/reglages/parametres_export_test.dart` : le test police ×2 fait `ensureVisible` avant de vérifier Exporter (la ligne Parcours, insérée au-dessus, peut la pousser sous le pli à 360 × 800), comme le faisait déjà le test d'import.

**Décisions**
- Ordre affiché = `settingsProvider` ; `_pending` ne garde le nouvel ordre que le temps de l'écriture : effacé quand le flux renvoie le même ordre (`ref.listen`), quand l'écriture réussit sans flux (ordre déjà en base), ou sur échec (snackbar « Parcours impossible à enregistrer. »). Aucune copie persistante.
- `ReorderableListView.builder(buildDefaultDragHandles: false)` + `ReorderableDragStartListener` sur une poignée 48 × 48 (`Icons.drag_handle`, `on-surface-variant`) : pas d'appui long sur la ligne. `onReorderItem` (le `onReorder` est déprécié dans `material_ui` 1.8). Ligne soulevée par un `proxyDecorator` : `Material` élévation 6 (valeur M3 de `ReorderableListView`), couleur `surface` ; animations coupées, élévation donnée d'un coup.
- **Surprise TalkBack** : `SliverReorderableList` enveloppe chaque ligne d'un `Semantics(container: true)` portant ses propres actions (« Déplacer au début / vers le haut / vers le bas / à la fin »), impossible à retirer. Ajouter nos propres actions sur la ligne aurait créé un second nœud (actions incompatibles) : un nœud sans libellé avec 4 actions, puis le nôtre. Solution : la ligne ne porte que son libellé (fusionné dans le nœud du framework) et un `Localizations.override` (délégué `WidgetsLocalizations` qui relaie tout sauf les 4 libellés verticaux) renomme « au début » et « vers le haut » en « Monter », « vers le bas » et « à la fin » en « Descendre ». Même libellé = même clé dans la table d'actions du framework : chaque ligne n'a que « Monter » (absente en tête) et « Descendre » (absente en fin). « Descendre » appelle en fait « à la fin » ; l'écran distingue un glisser d'une action TalkBack (`_dragFrom`, posé par `onReorderStart`, levé par `onReorderItem` ou par `onReorderEnd` quand la ligne est déposée à sa place) et traite toute action TalkBack comme un cran vers le voisin dans le sens demandé, puis annonce « Boulangerie, position 2 sur 13 » après l'écriture réussie.
- Consommateurs de l'ordre vérifiés, aucun à corriger : `listeGroupsProvider` (`selectAsync` sur `(groupByRayon, routeOrder)`, la liste change d'identité à chaque émission), `frequentsInRouteProvider` (`ref.watch(settingsProvider.future)` : dans riverpod 3.4.3, `ElementWithFuture.onData` notifie les auditeurs de `.future` à chaque donnée), Tag Rayon de `add_sheet.dart` (`ref.watch(settingsProvider)`), `revueLoaderProvider` (lit l'ordre à chaque ouverture de la Revue, instantané voulu par AD-16).
- Tests de glisser : un geste par petits pas (`startGesture` + `moveBy`) plutôt qu'un seul `tester.drag` : `SliverReorderableList` ne recalcule l'index d'insertion qu'à chaque mise à jour, un saut unique de 1,5 ligne laisse la ligne à sa place.

**Risques / reste**
- `flutter test` non lancé ici (consigne) : `flutter analyze` propre, grep mojibake vide. Les tests de glisser dépendent de l'algorithme d'insertion de `SliverReorderableList` (pas de 0,25 ligne, seuil de 18 px franchi au 2e pas).
- Un glisser annulé par le système (pointeur annulé, sans `onReorderEnd`) laisserait `_dragFrom` posé : l'action TalkBack suivante serait prise pour un glisser (« Descendre » enverrait alors la ligne en fin). Cas improbable ; remis à zéro au glisser suivant.
- Le renommage des actions dépend du comportement de `_wrapWithSemantics` (table indexée par libellé) de Flutter 3.47.8 ; le test TalkBack échouera si une version future change ce mécanisme.

## Plan Change Log

## Review Triage Log

- 2026-11-04 — revue unique du lot 3.1 à 3.4 (demande d'Antoine : tests et revue à la fin du lot). Première passe de tests : 725 passent, 6 échouent, tous des défauts de test (article « Piles » déjà fourni, lignes hors écran en police ×2, libellé ⚙ porté par le tooltip, tap sous l'AppBar) ; tests corrigés sans affaiblir d'assertion. Revue de code : high 0, medium 0, low 6. Patchés : photo de recette validée comme simple nom de fichier, entrée `photos/.` refusée, ingrédient en double dans une recette après report d'article supprimé (tests ajoutés). Reportés (deferred) : positions de fréquents égales, gel bref à l'import, drapeau de glisser du Parcours. Suite complète : 734 tests passent.

## Design Notes

- [ASSUMPTION] Aide de la ligne « L'ordre des rayons dans ton magasin » et message d'erreur (absents de Voice and Tone) ; Antoine les valide au test de fin d'epic.
- Le Choix de rayon de la Feuille d'édition (`lib/core/ui/rayon_picker.dart`) garde l'ordre fixe des 13 rayons : EXPERIENCE ne lui impose pas le parcours.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- `flutter test` -- expected: toute la suite passe, lancée une seule fois après les stories 3.1 à 3.4 (seul processus de test en cours).
