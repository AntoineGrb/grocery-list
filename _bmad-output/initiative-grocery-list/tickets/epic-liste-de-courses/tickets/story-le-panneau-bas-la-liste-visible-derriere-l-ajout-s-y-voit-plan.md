---
title: "Le Panneau + bas : la Liste visible derrière, l'ajout s'y voit"
type: 'feature'
ticket: '13'
created: '2026-11-01'
status: 'built'
baseline_revision: 'c68fb9bd9cf207ef69bf5d4a4aad05c364d2eae3'
route: 'full'
route_source: 'auto'
risk: 'high'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Le Panneau + couvre 90 % de l'écran : Antoine ne voit pas ce qu'il vient d'ajouter, et la Ligne saisie compense mal.

**Approach:** Panneau bas et sans voile, Liste vivante au-dessus ; toute ligne nouvelle y arrive animée et, si elle serait masquée, la Liste défile pour la poser juste au-dessus du panneau. La Ligne saisie disparaît.

## Boundaries & Constraints

**Always:** panneau d'environ deux tiers de la zone libre (hauteur écran − clavier − marge haute − Barre d'application) ; aucun voile, mais tap hors panneau, glissement et retour ferment toujours ; filet `outline` sur le haut et ombre ; poignée fine (20 dp environ) ; le panneau reste au-dessus du clavier, le clavier reste ouvert après Entrée ; le bas de la Liste réserve la hauteur du panneau tant qu'il est ouvert, pour que la dernière ligne reste atteignable ; message de liste vide centré dans la zone libre ; aucun défilement si la ligne est déjà entièrement visible entre le haut de la Liste et le haut du panneau ; animations coupées (`MediaQuery.disableAnimationsOf`) : ni fondu ni surlignage, saut direct ; TalkBack annonce un ajout, la Liste étant inaccessible sous le panneau ; textes dans `strings_fr.dart` ; couleurs par le thème (AD-12) ; coordination par un seul objet partagé (AD-19), sans donnée persistée (AD-1).

**Never:** pas de copie des lignes côté panneau ; pas de nouvelle dépendance ; pas de surlignage quand une ligne change de quantité ou de rayon ; ne pas toucher le crayon ni la Feuille d'édition empilée (story 14), ni les tags (story 15), ni la coche, le bouton Gérer et Cochés (story 16) ; pas de migration ; la Liste reste inerte sous le panneau (pas de cochage à travers).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ajout, ligne hors écran | Liste de 30 lignes, panneau ouvert, tap sur un fréquent dont le rayon est sous la zone libre | La Liste défile, le bas de la ligne se termine au haut du panneau, ligne surlignée | - |
| Ajout, ligne au-dessus | Liste défilée vers le bas, ajout d'une ligne d'un rayon au-dessus de la zone libre | La Liste remonte, ligne visible, En-tête de rayon visible si la place le permet | - |
| Ajout, ligne visible | Liste courte | Ligne animée, position de défilement inchangée | - |
| Liste vide | Premier ajout | Le message vide laisse place à la ligne, en haut de l'écran | - |
| Entrée, article présent | « lait » + Entrée, Lait déjà dans la liste hors écran | Rien d'ajouté ni retiré, la Liste montre sa ligne et la surligne ; annonce « Lait, dans la liste » | - |
| Entrée | « piles » + Entrée | Champ vidé, aucune Ligne saisie sous le champ, ligne dans la Liste ; annonce « Piles ajouté, Divers » | Échec d'écriture : snackbar existant, saisie gardée |
| Tap qui retire | Tap sur un fréquent déjà dans la liste | Ligne retirée, Annuler ; ni défilement ni surlignage ; Annuler la remet et la montre | - |
| Animations coupées | `disableAnimations` | Ligne sans fondu ni surlignage, `jumpTo` | - |
| Fermeture | Panneau fermé | La réserve du bas revient à `listBottomInset`, plus aucune ligne n'est animée à l'ajout | - |
| Clavier | Clavier ouvert puis fermé | Le panneau suit le clavier et sa hauteur se recalcule | - |

</intent-contract>

## Code Map

- `lib/features/liste/ui/add_sheet.dart` -- `showAddSheet` (hauteur 0.9 à remplacer, `showDragHandle`), `_AddSheetState` (`_saisie`, `_addTyped`, `_add`, bloc « saisie » du build à retirer). Le `Scaffold` interne ne doit plus se redimensionner : la hauteur exclut déjà le clavier.
- `lib/features/liste/ui/liste_screen.dart` -- `ListeScreen` (`ConsumerWidget`, à passer en `ConsumerStatefulWidget`), `ListView` des groupes.
- `lib/features/liste/ui/checked_section.dart` -- `AutomaticKeepAliveClientMixin` devenu inutile sans `ListView`.
- `lib/features/liste/ui/item_row.dart` -- ne pas modifier sa logique ; envelopper depuis `liste_screen.dart`.
- `lib/features/liste/ui/add_sheet_rows.dart` -- commentaire « Sert aussi à la Ligne saisie » à retirer.
- `lib/features/liste/state/liste_providers.dart` -- ajouter le provider de l'objet partagé, au style de ce fichier (`Provider`, pas de générateur).
- `lib/app/actions/ajout_panneau.dart` -- `TexteAjoute` doit porter `lineId`. `addArticle` rend déjà la ligne ; `ListeRepository.firstUnchecked` donne celle d'un article présent.
- `lib/core/theme/kadi_theme.dart:104` -- `bottomSheetTheme` : y ajouter `shadowColor` (sinon l'élévation M3 ne se voit pas).
- `lib/core/theme/kadi_tokens.dart` -- `KadiSpacing`, ajouter les constantes du panneau si besoin ; `KadiColors.of(context).rayon(r)` donne `accent` et la pastille.
- `lib/core/strings/strings_fr.dart` -- annonces.
- `lib/features/liste/ui/item_row.dart:112` -- modèle d'annonce `SemanticsService.sendAnnouncement(view, texte, TextDirection.ltr)`.
- Tests : `test/features/liste/add_sheet_test.dart`, `test/features/liste/liste_screen_test.dart`, `test/app/ajout_panneau_test.dart`, aides `test/helpers/pump_app.dart`, `test/helpers/test_db.dart`. Convention : `closeStreamsSynchronously: true`, Material importé par `package:material_ui/material_ui.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/features/liste/state/liste_panel.dart` (+ provider dans `liste_providers.dart`) -- créer `ListePanel extends ChangeNotifier` : `open(top, height)`/mise à jour, `close()`, `double? top`, `double? height`, `bool isOpen`, `reveal(lineId)` et sa consommation -- AD-19.
- [x] `lib/features/liste/ui/add_sheet.dart` -- `addPanelHeight(MediaQueryData)` pure et testable ; `barrierColor` transparent ; forme avec filet `outline` ; `elevation` ; sans `showDragHandle`, poignée dessinée dans le panneau, exclue de la sémantique ; `Padding(bottom: viewInsets)` + `SizedBox(height)` ; publication de `top = size.height - viewInsets.bottom - hauteur` au `ListePanel` en post-frame à chaque changement, `close()` quand la route est finie ; retirer la Ligne saisie ; annonces après un ajout ; appeler `reveal` sur Entrée quand `ajoute` est faux -- R15, R27.
- [x] `lib/app/actions/ajout_panneau.dart` -- `lineId` dans `TexteAjoute` -- pour montrer une ligne présente.
- [x] `lib/features/liste/ui/liste_screen.dart` -- état, `ScrollController`, `SingleChildScrollView` + `Column` (toutes les lignes bâties, on peut donc atteindre une ligne hors écran), `GlobalKey` par ligne non cochée (table élaguée quand une ligne disparaît) ; `ref.listen(listeGroupsProvider)` : si le panneau est ouvert, toute ligne absente du résultat précédent est marquée « arrivante » et la dernière devient la cible ; post-frame, calcul du défilement ; réserve du bas et centrage du message vide -- voir Design Notes.
- [x] `lib/features/liste/ui/row_highlight.dart` -- `RowHighlight` : fondu, léger glissement vertical et fond de pastille du rayon qui s'efface sur environ 1,2 s ; rejouable pour une ligne présente (surlignage seul, via un compteur reçu en paramètre) ; aucun effet si animations coupées.
- [x] `lib/features/liste/ui/checked_section.dart` -- retirer le mixin et `super.build`.
- [x] `lib/core/theme/kadi_theme.dart`, `lib/core/strings/strings_fr.dart` -- ombre, `ajouteAnnonce(name, rayon)` « Lait ajouté, Crèmerie », annonce « Lait, dans la liste ».
- [x] `test/features/liste/*`, `test/app/ajout_panneau_test.dart` -- couvrir chaque ligne de la matrice, géométrie comprise, avec un écran de téléphone (`tester.view.physicalSize` 412×914 dp, `tester.view.viewInsets` pour le clavier) ; remplacer les tests de Ligne saisie.

**Acceptance Criteria:**
- Given la Liste et le panneau ouvert sur un écran 412×914 avec un clavier de 300 dp, when on regarde l'écran, then le haut du panneau est sous la Barre d'application avec au moins 150 dp de Liste visible, et la barrière n'a aucune couleur.
- Given le panneau ouvert, when on touche hors du panneau, then il se ferme et la Liste retrouve sa réserve normale.
- Given une ligne ajoutée, when elle devient visible, then elle n'est jamais cachée par le panneau, à une ligne de distance du calcul près.
- Given l'application complète, when `flutter test` tourne, then tous les tests passent.

## Implementation Notes

- La feuille modale retire la marge haute de son `MediaQuery` : `addPanelHeight` la reçoit lue sur la `View`.
- Pendant sa descente, le panneau se reconstruit quand le clavier se ferme : la publication vérifie `route.isActive`, sinon le panneau se rouvrirait dans `ListePanel` après `close()`.
- Filet sur le seul bord haut : `_TopOutlineBorder`, sous-classe de `RoundedRectangleBorder` qui ne peint que le haut.
- `ListeRepository.isInList` retiré, plus aucun appelant depuis que `AjouterTexte` passe par `firstUnchecked`.
- Avec la marge de `touchTarget` (48 dp) et un En-tête de 52 dp, les 4 dp vides du haut de l'En-tête passent sous la Barre d'application ; sa pastille reste entièrement visible.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Une ligne montrée se retrouve masquée quand le panneau remonte (clavier rouvert : haut de 342 à 242 sur 412×914) — vérifié dans `_onPanelChanged` ; corrigé : `_lastShown` revérifiée à chaque changement de géométrie, test ajouté.
  - `[low]` `[reject]` Annuler dans le panneau remet une ligne sans annonce TalkBack — réel mais même comportement qu'avant cette story, Antoine n'utilise pas TalkBack au quotidien, et la correction ajoute un paramètre au snackbar partagé.

## Design Notes

**Calcul du défilement** (coordonnées globales, ligne et viewport mesurés par leur `RenderBox`) : `limite = min(bas du viewport, top du panneau)`. Si `bas ligne > limite`, `delta = bas ligne − limite`. Si `haut ligne < haut du viewport`, `delta = haut ligne − haut du viewport − KadiSpacing.touchTarget` (la marge laisse voir l'En-tête de rayon, clampé à 0). Sinon rien. `target = (pixels + delta).clamp(min, max)`, `animateTo` 250 ms ou `jumpTo` si animations coupées.

**Pourquoi pas d'animation de hauteur :** la ligne prend sa hauteur tout de suite. Sinon `maxScrollExtent` grandit pendant que `animateTo` vise la dernière ligne, et le défilement s'arrête en butée sur Android (physique clampée).

**Pourquoi détecter sur le flux :** l'écriture et l'émission du flux Drift n'ont pas d'ordre garanti ; comparer les lignes de deux émissions supprime la course (AD-19). Seule Entrée sur une ligne présente passe par `reveal`.

**Réserve du bas :** réserver toute la hauteur du panneau plutôt que le recouvrement exact : plus simple, et le surplus est invisible.

[ASSUMPTION] Annuler une suppression dans le panneau fait réapparaître la ligne : elle est traitée comme une arrivée, ce qui la montre.

## Verification

**Commands:**
- `dart format --set-exit-if-changed lib test` -- expected: aucun changement
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: tous les tests passent

## Auto Run Result

**Résumé :** Panneau + bas sans voile, Liste visible et vivante au-dessus ; toute ligne nouvelle arrive en fondu avec surlignage, la Liste défile si elle serait masquée ; Ligne saisie retirée ; annonces TalkBack.

**Fichiers :** `liste_panel.dart` (objet partagé AD-19), `row_highlight.dart` (arrivée), `liste_screen.dart` (état, défilement, réserve), `add_sheet.dart` (géométrie, sans Ligne saisie), `ajout_panneau.dart` (`lineId`), `liste_repository.dart` (`isInList` sans appelant retiré), `checked_section.dart`, `add_sheet_rows.dart`, `kadi_theme.dart`, `kadi_tokens.dart`, `strings_fr.dart`, tests.

**Revue :** 1 patch appliqué (medium), 1 rejeté (low, voir triage). Aucun report.

**Suivi de revue recommandé :** non (0 high, 1 medium corrigé).

**Vérification :** `dart format`, `flutter analyze`, `flutter test` passent.

**Risques résiduels :** pas encore vu sur téléphone : hauteur du panneau et force de l'ombre à régler au test d'Antoine ; pendant l'animation du clavier, `animateTo` repart à chaque frame si la ligne est masquée.
