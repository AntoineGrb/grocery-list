---
title: 'Le tag quantité et sa popup, sur les lignes du Panneau +'
type: 'feature'
ticket: '14'
created: '2026-11-01'
status: 'built'
baseline_revision: 'eb9d77d54feb866a5b144b2a2cfc007cbed5715d'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Dans le Panneau +, le crayon ouvre une feuille empilée sur le panneau, qui fait « fenêtre sur fenêtre », et on ne voit pas sur la ligne qu'une quantité a été saisie.

**Approach:** À la place du crayon, un tag quantité sur la ligne (« Qté » en contour, la valeur en plein) qui ouvre une Popup quantité flottante au-dessus du panneau. Plus aucune feuille ne s'ouvre depuis le panneau ; le rayon y disparaît.

## Boundaries & Constraints

**Always:** tag présent seulement pour un article dans la liste, à gauche de la coche, sur fréquents et résultats ; il décrit et édite la plus ancienne ligne non cochée de l'article ; zone tactile 48 dp, visuel 32 dp, `{rounded.sm}`, `labelLarge` ; vide : contour `outline`, texte `onSurfaceVariant`, « Qté » ; plein : fond `onSurfaceVariant`, texte `surface`, valeur de `formatQuantity` ; le tag réutilisable sera repris par la story 15 ; popup = route légère du navigateur racine (AD-13), barrière transparente qui ferme, fondu et léger zoom depuis son bord bas, jamais une feuille ; posée juste au-dessus du panneau (bas de la carte = `ListePanel.top` − 8 dp), marges `margin`, recalée quand le clavier change le panneau ; carte `surfaceContainer`, `{rounded.lg}`, contour `outline`, ombre ; titre = nom de l'article en `titleMedium`, `QuantityField` focalisé, `UnitChoice` ; Entrée, tap hors carte et retour ferment en écrivant une seule fois si la valeur a changé ; vide = sans quantité ; unité préchoisie par `initialInputUnit` ; écriture par `ListeRepository.setQuantity` (AD-5, fusion comprise) ; erreur = snackbar `modificationImpossible` dans le messager du panneau ; le texte préchargé arrondi n'est pas réécrit sans saisie ; animations coupées : apparition immédiate ; TalkBack : « Quantité de Lait, 500 g » ou « Quantité de Lait, aucune » ; textes dans `strings_fr.dart`.

**Never:** pas de rayon dans la popup ; pas de « Supprimer » dans la popup : le retrait reste le tap sur la ligne ; ne pas modifier le comportement de la Feuille d'édition de la Liste (appui long) ; pas de surlignage de la ligne après une modif (décision d'Antoine : le contour/plein suffit) ; pas de tags sous le champ (story 15) ; pas de coche ronde ni bouton Gérer (story 16) ; pas de nouvelle dépendance ni migration.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Hors liste | Lait hors liste | Signe +, aucun tag | - |
| Dans la liste, sans quantité | Tap sur Lait | Coche + tag « Qté » en contour | - |
| Saisie | Tag, « 2 », Entrée | Popup fermée, tag « 2 pièces » ou selon `formatQuantity`, Liste à jour | Échec : snackbar dans le panneau, tag inchangé |
| Vider | Lait à 2, champ vidé, tap hors carte | Tag « Qté », Liste sans quantité | - |
| Sans changement | Tag ouvert puis fermé sans saisie | Aucune écriture | - |
| Unité | Tomates 500 g, puce kg, « 1,5 », retour | Tag « 1,5 kg », enregistré en g | - |
| Fusion | Tomates 300 g et 2 pièces, popup de la plus ancienne passée à l'autre unité | Une seule ligne fusionnée (AD-5) ; tag à jour | - |
| Deux lignes | Article à deux lignes | Le tag montre et édite la plus ancienne | - |
| Résultat | Résultat de recherche dans la liste | Même tag, même popup | - |
| Panneau | Popup fermée | Le panneau reste ouvert, la saisie du nom reprend le focus si elle l'avait | - |
| Coché dans la Liste | Article coché | Tag absent, + revenu | - |

</intent-contract>

## Code Map

- `lib/features/liste/ui/add_sheet_rows.dart` -- `_PanelRow` et son crayon (`onEdit`), `FrequentRow`, `SearchResultRow` : remplacer le crayon par le tag.
- `lib/features/liste/ui/add_sheet.dart` -- `_edit`, `_editing`, `showItemEditSheet`, `item_edit_sheet.dart` : tout le chemin de feuille empilée disparaît du panneau ; `inListProvider` reste pour l'état.
- `lib/features/liste/state/liste_providers.dart` -- ajouter un provider dérivé de `watchUnchecked` : article → sa plus ancienne ligne non cochée. Le flux est trié par `added_at` puis `id` (vérifier dans `_items` de `liste_repository.dart`).
- `lib/features/liste/ui/item_edit_sheet.dart` -- réutiliser `initialInputUnit`, `UnitChoice`, et la logique `_commitQuantity`, `_selectUnit` ; déplacer ce qui est partagé dans un fichier commun plutôt que dupliquer. Retirer les mentions du Panneau + et d'AD-13 dans ses commentaires.
- `lib/core/ui/quantity_field.dart` -- `QuantityField`, `quantityFieldText`, `quantityFromFieldText`, `quantityTextForUnit`.
- `lib/core/units/unit.dart` -- `formatQuantity`, `StoredQuantity`.
- `lib/features/liste/data/liste_repository.dart` -- `setQuantity(lineId, quantity, unit:)`.
- `lib/features/liste/state/liste_panel.dart` -- `ListePanel.top`, pour poser la carte.
- `lib/core/strings/strings_fr.dart` -- « Qté », « Quantité de … », retirer ce qui ne sert plus (`modifierNom` si plus d'appelant).
- Tests : `test/features/liste/add_sheet_test.dart` (crayon, feuille empilée), `test/features/liste/add_panel_reveal_test.dart` (aides pour un écran de téléphone), `test/features/liste/liste_screen_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/features/liste/ui/quantity_tag.dart` -- `QuantityTag` -- visuel commun aux lignes (et à la story 15).
- [x] `lib/features/liste/ui/quantity_popup.dart` -- `showQuantityPopup(context, {title, quantity, unit, initialUnit})` rendant un résultat qui distingue « inchangé » d'une valeur (ou vide) -- l'appelant écrit ; la story 15 s'en servira pour un brouillon.
- [x] `lib/features/liste/ui/add_sheet_rows.dart`, `lib/features/liste/ui/add_sheet.dart` -- tag à la place du crayon ; ouvrir la popup, écrire par `setQuantity` ; retirer `_edit` et la feuille empilée ; mettre à jour les commentaires.
- [x] `lib/features/liste/state/liste_providers.dart` -- provider article → ligne.
- [x] `lib/features/liste/ui/item_edit_sheet.dart` -- code partagé sorti, commentaires à jour.
- [x] `lib/core/strings/strings_fr.dart` -- textes.
- [x] `test/features/liste/*` -- couvrir chaque ligne de la matrice ; remplacer les tests de crayon et de feuille empilée.

**Acceptance Criteria:**
- Given un article dans la liste au Panneau +, when on touche son tag, then une carte s'affiche au-dessus du haut du panneau, sans Choix de rayon ni Supprimer, et aucun `BottomSheet` supplémentaire n'est ouvert.
- Given le panneau ouvert, when on cherche un crayon, then aucun `Icons.edit_outlined` n'apparaît sur les lignes.
- Given la Liste, when on fait un appui long sur une ligne, then la Feuille d'édition s'ouvre comme avant.
- Given l'application complète, when `flutter test` tourne, then tous les tests passent.

## Implementation Notes

- Code partagé avec la Feuille d'édition dans `lib/features/liste/ui/quantity_input.dart` (`QuantityInput`, `UnitChoice`, `initialInputUnit`, `storedQuantityOf`). Entrée dans la Feuille compte toujours comme une saisie ; dans la popup, non, pour ne pas réécrire un texte préchargé arrondi.
- Résultat de la popup : `null` = inchangé, sinon `(value: …)`, `value` nulle = sans quantité. La route le rend par `currentResult`, quel que soit le mode de fermeture.
- Ajout hors liste de tâches : au-delà d'une police ×1,2, le rayon d'une ligne de résultat passe sous le nom, car la ligne débordait ; à toute taille, le tag prend sa seule largeur jusqu'à `KadiSpacing.tagMaxWidth`, puis s'abrège.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Au-dessus de ×1,2, le nom et le tag se partagent la place en deux, la coche se décale — vérifié dans `_PanelRow` (`Expanded` + `Flexible`) ; corrigé : tag borné par `KadiSpacing.tagMaxWidth` à toutes les tailles, test ajouté.
  - `[low]` `[reject]` Jusqu'à ×1,2, une ligne de résultat peut écraser le nom ou déborder avec un rayon long, une très longue quantité et un écran étroit — limité à 360 ou 320 dp avec « 999 pièces », alors que le téléphone d'Antoine fait 412 dp ; la borne du tag réduit le cas, et aller plus loin ajouterait une mesure de largeur.

## Design Notes

Le crayon du titre « Ajouts fréquents » reste jusqu'à la story 16.

Clavier : la popup prend le focus (clavier numérique) ; à sa fermeture, Flutter rend le focus à la route du panneau. Si le clavier était fermé, le panneau remonte à l'ouverture : la carte doit suivre `ListePanel` et rester sous la marge haute. Une `ScrollView` interne garde la carte utilisable en très grande police.

[ASSUMPTION] Le titre reprend le nom de l'article, car la carte est loin de la ligne touchée.

## Verification

**Commands:**
- `dart format --set-exit-if-changed lib test` -- expected: aucun changement
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: tous les tests passent

## Auto Run Result

**Résumé :** tag quantité sur les lignes du Panneau + dans la liste (« Qté » en contour, la valeur en plein) ; Popup quantité flottante au-dessus du panneau, qui suit le clavier ; crayon et feuille empilée retirés du panneau.

**Fichiers :** `quantity_tag.dart`, `quantity_popup.dart`, `quantity_input.dart` (nouveaux), `add_sheet.dart`, `add_sheet_rows.dart`, `item_edit_sheet.dart`, `liste_providers.dart`, `strings_fr.dart`, `kadi_tokens.dart`, `quantity_field.dart`, commentaires de `liste_repository.dart` et `rayon_picker.dart`, tests.

**Revue :** 1 patch appliqué (low), 1 rejeté (low, voir triage). Aucun report.

**Suivi de revue recommandé :** non (0 high, 0 medium corrigé).

**Vérification :** `dart format`, `flutter analyze`, `flutter test` passent.

**Risques résiduels :** bascule entre clavier texte et clavier numérique non vue sur téléphone ; bordure de focus du Champ quantité en argile, à passer en neutre en story 16 (C6).
