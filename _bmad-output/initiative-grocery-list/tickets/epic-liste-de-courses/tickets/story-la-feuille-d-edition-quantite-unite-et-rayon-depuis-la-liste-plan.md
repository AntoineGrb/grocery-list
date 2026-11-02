---
title: 'La Feuille d''édition : quantité, unité et rayon, depuis la Liste et le Panneau +'
type: 'feature'
ticket: '11'
created: '2026-10-30'
status: done
baseline_revision: '7b9b2ce05cd42a4c21e44d0a0461f60e7fa0def5'
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
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Après un ajout au Panneau +, la ligne se déplie avec quantité et rayon : l'optionnel encombre l'ajout. Et on ne peut pas choisir l'unité (on reste dans celle de l'article, sans kg ni L).

**Approach:** Une seule Feuille d'édition courte, qui monte du bas, ouverte par l'appui long de la Liste et par un crayon à côté de la coche de toute ligne du Panneau + déjà dans la liste ; elle gagne un Choix d'unité (pièce, g, kg, ml, L). Le dépliage disparaît du panneau.

## Boundaries & Constraints

**Always:** AD-5 (amendé : la feuille change aussi l'unité, mode manuel, fusion avec la ligne jumelle), AD-6 (kg et L seulement en saisie, stockés en g et ml par une seule fonction de `lib/core/units/`), AD-13 (feuille empilée sur le Panneau +, erreurs dans le messager du panneau), AD-10 (Supprimer depuis la feuille = Annuler) ; textes dans `strings_fr.dart` ; Material par `package:material_ui/material_ui.dart` ; cibles 48 dp ; TalkBack et taille de police système ; tests unitaires et de widgets.

**Never:** pas de changement de la section fréquents ni des en-têtes (story 12) ; pas d'argile sur la puce choisie ; aucune conversion entre pièces, poids et volumes ; pas de nouveau code d'unité en base.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Changer d'unité avec jumeau | Tomates 300 g et Tomates 2 pièces ; feuille de la ligne pièces → g, 200 | Une seule ligne non cochée « Tomates 500 g » (la ligne éditée, son `added_at`), manuelle ; le jumeau supprimé logiquement | Échec : snackbar `modificationImpossible`, rien écrit |
| Saisie en kg | Riz sans quantité ; kg, « 1,5 » | Ligne en g, quantité 1500, affichée « 1,5 kg » | — |
| Saisie en L | Lait ; L, « 2 » | 2000 ml, affiché « 2 l » | — |
| Unité préchoisie | ligne en g / ligne sans quantité, article en ml / article sans unité | g / ml / pièce | — |
| Vider la quantité | Tomates 300 g ; champ vidé | Ligne sans quantité ; fusion avec une ligne sans quantité du même article s'il y en a une | — |
| Rien changé | ouvrir puis fermer | Rien écrit | — |
| Crayon au Panneau + | Lait dans la liste (fréquent, résultat ou Ligne saisie) | Crayon visible à côté de la coche ; tap → feuille empilée, le panneau reste ouvert dessous ; hors liste : pas de crayon | — |
| Rayon depuis le panneau | crayon de Lait → Épicerie salée | La ligne change de groupe dans la Liste, l'article garde son rayon | idem |
| Supprimer depuis le panneau | crayon de Lait → Supprimer | Ligne retirée, snackbar Annuler dans le panneau ; Annuler la remet | `suppressionImpossible` |
| Article sur deux lignes | Tomates en g et en pièces, crayon au panneau | La feuille ouvre la plus ancienne ligne non cochée (`added_at`, puis `id`) | — |

</intent-contract>

## Code Map

- `lib/features/liste/ui/item_edit_sheet.dart` -- la Feuille d'édition actuelle (titre, `QuantityField` dans l'unité de la ligne, `RayonPicker`, Supprimer → `ItemEditResult.delete`, écriture au submit / à la fermeture via `setQuantity`). Y ajouter le Choix d'unité ; titre en `titleMedium` (DESIGN `item-edit-sheet`) ; hauteur au contenu (déjà `isScrollControlled` + `mainAxisSize.min`) ; le champ s'affiche toujours (plus de « absent sans unité »).
- `lib/features/liste/data/liste_repository.dart:457` `setQuantity(lineId, quantity, {unit})` -- lève aujourd'hui si `unit` ≠ unité de la ligne. Nouvelle règle AD-5 : valeur et unité saisies (unité stockée), vide = sans quantité ; contributions actives remplacées par une `edition`, `manual_at` fixé ; si une autre ligne active non cochée du même article a le même `unit_key`, ses contributions actives passent sur la ligne éditée (`line_id`) et elle est supprimée logiquement. Ajouter `Future<ListeItem?> firstUnchecked(String articleId)` (plus ancienne ligne non cochée) pour le crayon du panneau. `setAddedQuantity` (l. 197) devient inutile : le retirer avec ses tests.
- `lib/core/ui/quantity_field.dart` -- `quantityFieldText` / `quantityFromFieldText` et `digitsOnly` : ajouter l'unité de saisie (pièce, g, kg, ml, L) et la virgule décimale pour kg et L (au plus 3 décimales) ; la conversion saisie → (quantité, `Unit`) stockée vit dans `lib/core/units/` (une seule fonction, AD-6), le champ l'appelle. Suffixes : pièces, g, kg, ml, l (`strings_fr.dart` a `uniteKg`, `uniteL`).
- `lib/core/units/unit.dart` -- y mettre l'énumération des unités de saisie et la conversion (AD-6) ; `formatQuantity` inchangé.
- `lib/features/liste/ui/liste_screen.dart:60-75` -- `_edit` / `_remove` : modèle à reproduire au panneau pour Supprimer.
- `lib/features/liste/ui/add_sheet.dart` -- retirer `_deplie`, `_unfold`, `_fold`, `_commitQuantity`, `_selectRayon`, `_quantityController`, `withEditor` et l'usage d'`AddedLineEditor` ; ajouter `_edit(context, article)` : `firstUnchecked` puis `showItemEditSheet(context, item)` (context sous le messager du panneau), et Supprimer → `removeLine` + Annuler comme `_remove` (pendingUndo compris).
- `lib/features/liste/ui/add_sheet_rows.dart` -- `FrequentRow`, `SearchResultRow` : paramètre `onEdit` ; dans la liste, crayon (`Icons.edit_outlined`, `on-surface-variant`, cible 48 dp, tooltip et TalkBack « Modifier Lait ») à gauche de la coche ; le nœud de la ligne reste lu comme aujourd'hui, le crayon est un bouton à part. Retirer `AddedLineEditor`.
- `lib/app/actions/ajout_panneau.dart` -- `ArticleAjoute` et `PlacerLigneAjoutee` deviennent inutiles : les retirer avec leurs tests.
- `lib/core/strings/strings_fr.dart` -- `unite` (libellé « Unité »), `modifierNom(name) => 'Modifier $name'`, libellés des puces.
- Tests : `test/features/liste/liste_repository_test.dart`, `item_edit_sheet` / `liste_screen_test.dart`, `add_sheet_test.dart`, `test/core/quantity_field_test.dart`, `units_test.dart`, `test/app/ajout_panneau_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/units/unit.dart`, `lib/core/ui/quantity_field.dart` + tests -- unités de saisie, virgule pour kg et L, conversion unique -- AD-6, R3.
- [x] `lib/features/liste/data/liste_repository.dart` + tests -- `setQuantity` avec unité et fusion, `firstUnchecked`, retrait de `setAddedQuantity` -- AD-5, R5.
- [x] `lib/features/liste/ui/item_edit_sheet.dart` + tests -- Choix d'unité, titre, écriture unique au submit ou à la fermeture si quantité ou unité a changé -- R5.
- [x] `lib/features/liste/ui/add_sheet.dart`, `add_sheet_rows.dart`, `lib/app/actions/ajout_panneau.dart`, `strings_fr.dart` + tests -- crayon, feuille empilée, Supprimer avec Annuler, retrait du dépliage -- R14, AD-13.

**Acceptance Criteria:**
- Given Lait dans la liste, when Antoine touche Lait dans le Panneau +, then le + devient une coche et un crayon apparaît, sans rien déplier.
- Given le crayon de Lait, when il change la quantité et ferme la feuille, then le Panneau + est toujours ouvert et la Liste montre la nouvelle quantité.
- Given une ligne en pièces, when TalkBack parcourt la feuille, then il lit le titre, « Quantité », chaque puce d'unité avec son état choisi, les rayons, « Supprimer » ; le crayon du panneau est lu « Modifier Lait ».

## Implementation Notes

- AD-6 : `InputUnit` (pièce, g, kg, ml, L) et l'unique `storedQuantity(text, unit)` dans `lib/core/units/unit.dart` ; `quantityFromFieldText` rend désormais `({quantity, unit})?` stocké. Le Champ quantité prend un `InputUnit` ; kg et L acceptent la virgule (le point devient virgule), 6 chiffres puis au plus 3 décimales.
- `setQuantity(lineId, quantity, {unit})` : `unit` est l'unité stockée ; une quantité chiffrée sans unité lève. Fusion seulement si la ligne éditée est non cochée (AD-4 : l'unicité ne vaut que pour les lignes non cochées) ; tous les jumeaux trouvés sont fusionnés.
- Feuille : écriture si le champ a été saisi (comme avant) ou la puce changée, et si le résultat diffère de la ligne — un retour au même texte après saisie réécrit donc la valeur (cas 1 ½ pièce → 2, test existant gardé). Passer à une puce sans décimales coupe la partie après la virgule (« 1,5 » kg → « 1 » g).
- Panneau + : `_closing` et la `PopScope` de fermeture disparaissent avec le dépliage ; `_showMessage` retombe sur le messager de la Liste si le panneau n'est plus monté. Crayon : `IconButton` à part dans un nœud `Semantics(container)` de la ligne, lu par son tooltip « Modifier Lait ».
- Choix d'unité : `UnitChoice` (dans `item_edit_sheet.dart`), `ChoiceChip` à fond transparent, contour `on-surface` + coche si choisie, `outline` sinon.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 2 findings — high 0, medium 1, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` En kg ou L, une saisie qui commence par la virgule (« ,5 », ou « .5 » devenu « ,5 ») était acceptée par le champ mais lue `null` par `storedQuantity` : la ligne passait sans quantité, sans message — `storedQuantity` lit maintenant « ,5 » comme « 0,5 » (une virgule seule reste « sans quantité ») ; trois cas ajoutés à `units_test.dart`. Appliqué par l'orchestrateur.
  - `[low]` `[reject]` Branche kg/L de `quantityFieldText` : seconde conversion de lecture hors de `lib/core/units/`, jamais atteinte en production (la feuille s'ouvre toujours en g, ml ou pièce) — aucun utilisateur ne la rencontre ; la retirer demande de remanier le `switch` exhaustif et ses tests, plus qu'une correction directe.

## Design Notes

Changer de puce garde le nombre tapé tel quel : la puce dit seulement dans quelle unité il est lu (pas de conversion 300 g → 0,3 kg) [ASSUMPTION]. Une ligne en g s'ouvre en g même au-delà de 1000 (DESIGN : kg seulement si choisi). Rien n'est écrit si ni le texte ni la puce n'ont changé. Une quantité vide écrit « sans quantité » quelle que soit la puce.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous verts

## Auto Run Result

Status: built

- **Visible sur le téléphone :** au Panneau +, un tap ajoute (le + devient coche) sans rien déplier ; un crayon à côté de la coche ouvre la Feuille d'édition par-dessus le panneau (fréquents, résultats, Ligne saisie). La feuille (aussi par appui long dans la Liste) a Quantité, Unité (pièce · g · kg · ml · L), Rayon, Supprimer ; « 1,5 » en kg donne « 1,5 kg » ; changer d'unité fusionne avec la ligne du même article dans cette unité.
- **Fichiers :** `lib/core/units/unit.dart` (`InputUnit`, `storedQuantity`) ; `lib/core/ui/quantity_field.dart`, `rayon_picker.dart` ; `liste_repository.dart` (`setQuantity` avec unité et fusion, `firstUnchecked`, retrait de `setAddedQuantity`) ; `item_edit_sheet.dart` (Choix d'unité) ; `add_sheet.dart`, `add_sheet_rows.dart` (crayon, retrait du dépliage) ; `ajout_panneau.dart` (retrait d'`ArticleAjoute`, `PlacerLigneAjoutee`) ; `strings_fr.dart` ; tests.
- **Revue :** 1 correction (medium), 0 reporté, 1 rejeté (low) — voir Review Triage Log. Hors revue, l'orchestrateur a aussi mis le clavier à virgule pour toutes les unités : Android ne changeait pas de clavier quand la puce passait à kg ou L pendant la saisie.
- **Revue de suivi recommandée :** non (un seul medium corrigé, aucun high).
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 297/297.
- **Risques résiduels :** feuille plus haute (Supprimer peut demander un défilement sur petit écran) ; une erreur pendant que la feuille est ouverte s'affiche dans le panneau, sous la feuille ; rien vérifié sur téléphone.
