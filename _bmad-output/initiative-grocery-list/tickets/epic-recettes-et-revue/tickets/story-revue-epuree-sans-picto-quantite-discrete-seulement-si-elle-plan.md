---
title: 'Revue épurée : sans picto, quantité discrète seulement si elle existe'
type: 'feature'
ticket: '10'
created: '2026-11-03'
status: 'in-progress'
baseline_revision: 'BASELINE'
route: 'full'
route_source: 'auto'
risk: 'low'
review: ''
review_source: ''
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/epic-recettes-et-revue.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Au test de fin d'epic, Antoine trouve que la Revue montre une « puce » inutile à côté de la coche (le picto, en repli neutre tant que le pack n'est pas choisi) et que les quantités prennent trop de place : un champ bordé même sans quantité, trop large (Decision 2026-11-03 ; initiative C7 : pas de picto en Revue).

**Approach:** Retirer le picto de la Ligne de Revue ; ne montrer un Champ quantité que pour une ligne chiffrée, en version discrète : plus petit, coins arrondis, fond grisé sans bordure, comme le champ de la Popup quantité du Panneau +.

## Boundaries & Constraints

**Always:**
- Ligne de Revue : coche ronde, nom, et à droite, seulement si la ligne a une quantité, le Champ quantité en variante remplie (`QuantityField(filled: true)` : fond `surface-container`, coins `rounded.sm`, sans bordure), avec son suffixe d'unité, nettement plus étroit qu'aujourd'hui (≈ 96 dp, à ajuster pour « 500 g » et « 6 pièces » entiers à ×1).
- Ligne sans quantité : ni champ ni texte de quantité ; elle se décoche toujours.
- Décoche, correction (valeur exacte dans l'unité de la ligne), champ vidé = sans quantité, prorata, brouillon et bouton au-dessus du clavier : inchangés.
- TalkBack : ligne lue « Pâtes, 500 g, Épicerie salée » avec son état ; champ lu « Quantité de Pâtes, 500 g » ; une ligne sans quantité n'annonce aucun champ. Police système : à grande taille, le champ passe sous le nom comme aujourd'hui, sans débordement.

**Never:**
- Picto dans la Revue ; ajout d'une quantité à une ligne qui n'en a pas ; changement des règles d'écriture (`revueWrites`).

</intent-contract>

## Code Map

- `lib/features/recettes/ui/revue_row.dart` -- `Picto(...)` (ligne ~110) à retirer ; `_fieldWidth = 128` ; le champ (`QuantityField(controller, unit: inputUnit)`, ~130) devient rempli et n'est construit que si `line.quantity != null` ; disposition sous le nom au-delà de `_inlineFieldMaxTextScale` gardée.
- `lib/core/ui/quantity_field.dart` -- variante `filled` existante (utilisée par `lib/features/liste/ui/quantity_popup.dart`) : la réutiliser sans la changer.
- `lib/features/recettes/ui/revue_screen.dart` -- les contrôleurs des lignes sans quantité ne servent plus à la saisie : ne pas en dépendre pour l'écriture (ligne sans quantité = parts d'origine).
- Tests : `test/features/recettes/recettes_screen_test.dart` (Revue : pas de picto, Poivre sans champ, Lardons champ rempli plus étroit, correction Œufs 4 inchangée, police ×1,3 ×2 ×3, TalkBack).

## Tasks & Acceptance

**Execution:**
- [ ] `revue_row.dart`, `revue_screen.dart` -- sans picto, champ rempli seulement si chiffrée
- [ ] tests -- matrice ci-dessus

**Acceptance Criteria:**
- Given la Revue Carbonara + Quiche, then aucune ligne ne montre de picto, Poivre n'a pas de champ, et Lardons montre « 400 g » dans un petit champ arrondi à fond grisé.
- Given cette Revue, when Antoine remplace 6 par 4 aux Œufs et ajoute à la liste, then la Liste montre « Œufs 4 pièces ».

## Implementation Notes

## Plan Change Log

## Review Triage Log

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed
