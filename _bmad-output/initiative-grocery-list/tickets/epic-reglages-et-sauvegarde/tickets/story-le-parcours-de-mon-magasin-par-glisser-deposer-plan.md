---
title: 'Le parcours de mon magasin, par glisser-déposer'
type: 'feature'
ticket: '4'
created: '2026-11-04'
status: 'draft'
baseline_revision: ''
route: 'full'
route_source: 'auto'
risk: 'medium'
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
- [ ] `lib/core/router/app_router.dart`, `lib/app/kadi_app.dart`, `lib/core/strings/strings_fr.dart` -- route et textes.
- [ ] `lib/features/reglages/ui/parcours_screen.dart`, `lib/features/reglages/ui/parametres_screen.dart` -- écran et ligne.
- [ ] consommateurs de l'ordre -- réactivité vérifiée, corrigée au besoin.
- [ ] `test/features/reglages/parcours_screen_test.dart` -- chaque ligne de la matrice (glisser avec `tester.drag` sur la poignée ; actions par `tester.semantics`/`SemanticsAction.customAction`), TalkBack, police ×2, animations désactivées.
- [ ] test d'intégration widget (app montée) -- après un réordonnancement, la Liste, la Revue et le Panneau + suivent l'ordre.

**Acceptance Criteria:**
- Given la Liste avec Tomates (Fruits et légumes) et Pain (Boulangerie), when Antoine glisse Boulangerie en premier dans Parcours et revient, then Pain est au-dessus de Tomates, et la Revue et les Ajouts fréquents suivent le même ordre.

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Design Notes

- [ASSUMPTION] Aide de la ligne « L'ordre des rayons dans ton magasin » et message d'erreur (absents de Voice and Tone) ; Antoine les valide au test de fin d'epic.
- Le Choix de rayon de la Feuille d'édition (`lib/core/ui/rayon_picker.dart`) garde l'ordre fixe des 13 rayons : EXPERIENCE ne lui impose pas le parcours.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- `flutter test` -- expected: toute la suite passe, lancée une seule fois après les stories 3.1 à 3.4 (seul processus de test en cours).
