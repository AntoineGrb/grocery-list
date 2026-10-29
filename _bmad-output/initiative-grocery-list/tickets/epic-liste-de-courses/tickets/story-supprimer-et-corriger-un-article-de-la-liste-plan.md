---
title: 'Supprimer et corriger un article de la liste'
type: 'feature'
ticket: '6'
created: '2026-10-29'
status: 'built'
baseline_revision: '3d26937590f97c801353caf42b497975687fe8e7'
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
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Une ligne de la Liste ne peut être ni retirée ni corrigée : Antoine ne peut pas enlever un article ajouté par erreur, ajuster une quantité ni déplacer un article mal rangé (R5).

**Approach:** Glisser une Ligne d'article vers la gauche la supprime avec le Snackbar Annuler de la story 5 ; un appui long ouvre la Feuille d'édition d'article (Champ quantité, Choix de rayon, Supprimer). Corriger la quantité suit AD-5 (contribution `edition`, `manual_at`), changer le rayon modifie la seule ligne (AD-15). TalkBack offre « Supprimer » et « Modifier ».

## Boundaries & Constraints

**Always:** seul `ListeRepository` écrit `list_lines` et `list_contributions` ; chaque écriture dans une transaction, horodatée par `Clock.stamp(ancien)` ; supprimer = suppression logique de la ligne et de ses contributions actives, enregistrée dans `Undo` (état d'avant de chaque ligne touchée) et annoncée par `showUndoSnackBar` « Retiré de la liste : Riz » ; corriger la quantité = dans une transaction, supprimer logiquement les contributions actives, insérer une contribution `edition` de la valeur saisie et fixer `manual_at` (AD-5) ; la feuille saisit dans l'unité de la ligne, jamais une autre ; une quantité vide ou 0 vaut « sans quantité » (contribution, ligne et unité nulles, AD-6) ; une valeur inchangée n'écrit rien ; changer le rayon ne change que `list_lines.rayon` et `updated_at`, jamais l'article ; les deux gestes valent pour les lignes cochées comme non cochées ; Champ quantité et Choix de rayon sont des composants réutilisables (story 8, epic 2) ; textes dans `strings_fr.dart` ; Material par `package:material_ui/material_ui.dart` ; cibles ≥ 48 dp.

**Never:** pas d'Annuler sur la correction de quantité ni sur le changement de rayon (seule la suppression est annulable) ; pas de modification de l'article (unité ou rayon par défaut) ; pas de choix d'unité dans la feuille ; pas de saisie de fractions de pièce ; pas de fusion de lignes après une correction ; pas de migration de schéma (`manual_at` existe) ; pas de Champ quantité dans le Panneau + (story 8).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Supprimer | Riz 1500 g, deux contributions | ligne et contributions supprimées logiquement ; une `UndoRow.before` par ligne touchée ; absente des deux flux | — |
| Annuler la suppression | juste après | Riz revient à sa place, 1,5 kg, cochée ou non comme avant | — |
| Corriger | Tomates 500 g (2 contributions `ajout`), saisie 300 | anciennes contributions supprimées logiquement, une contribution `edition` 300 g, `manual_at` fixé ; la Liste lit 300 g | — |
| Ligne sans quantité | Lardons sans quantité (article en g), saisie 300 | la ligne prend `unit = g`, contribution `edition` 300 g, `manual_at` fixé | — |
| Vider | Tomates 500 g, saisie vide ou 0 | contribution `edition` sans quantité, ligne `unit` nulle, `manual_at` fixé ; la Liste n'affiche plus de quantité | — |
| Pièces | Lait 2 pièces, saisie 3 | contribution `edition` `3000` `piece` | — |
| Inchangée | saisie égale à la quantité affichée | rien n'est écrit, `manual_at` reste nul | — |
| Rayon | Lardons (viande-poisson) → plats-prepares | `list_lines.rayon = plats-prepares`, `updated_at` neuf ; article inchangé ; la ligne passe sous Plats préparés | — |
| Ligne absente | id inconnu ou supprimé | rien n'est écrit, suppression rend une liste vide (pas de snackbar) | — |
| Entrée invalide | quantité négative | rien n'est écrit | `ArgumentError` |

</intent-contract>

## Code Map

- `lib/features/liste/data/liste_repository.dart` -- `ListeItem` (`lineId`, `articleId`, `name`, `rayon`, `unit`, `quantity`, `checked`), `_toItem(line, article, quantity)` (y ajouter `articleUnit` : unité par défaut de l'article), `ContributionSource.edition`, `_activeLine`, `clearList()` (modèle : suppression logique + `UndoRow.before`). Ajouter `removeLine`, `setQuantity`, `setRayon`.
- `lib/core/undo/undo.dart` -- `UndoRow.before(table, row)`, `Undo.record(rows)`, `undoProvider`. `lib/core/undo/undo_snackbar.dart` -- `showUndoSnackBar(context, message, entry)` : le `context` doit être sous le `ScaffoldMessenger` de la Liste.
- `lib/features/liste/ui/liste_screen.dart` -- `ScaffoldMessenger` propre à la Liste et `Builder` dont le contexte sert à `_terminer` et aux snackbars : la suppression (geste et feuille) passe par ce contexte.
- `lib/features/liste/ui/item_row.dart` -- `ConsumerStatefulWidget`, `Semantics(label, checked, onTap, excludeSemantics)` sur la ligne, `_pending` de la coche : y ajouter le glisser, l'appui long et `customSemanticsActions`.
- `lib/features/liste/ui/checked_section.dart` -- rend aussi des `ItemRow` (lignes cochées).
- `lib/features/liste/ui/rayon_header.dart` -- pastille de rayon (point + nom, `KadiColors.of(context).rayon(r)`) : le Choix de rayon reprend ce rendu.
- `lib/core/units/unit.dart` -- `Unit` (`g`, `ml`, `piece`), `formatQuantity`. `lib/core/rayons/rayon.dart` -- `Rayon.values` (ordre des 13), `label`, `spokenLabel`.
- `lib/core/ui/` -- `empty_state.dart` ; y créer `quantity_field.dart` et `rayon_picker.dart` (partagés par liste, recettes et réglages ; `core` n'importe aucune fonctionnalité).
- `lib/core/theme/kadi_theme.dart` -- `bottomSheetTheme` déjà conforme (`surfaceContainer`, haut `KadiRadius.xl`) ; `inputDecorationTheme` global sans bordure (le Champ quantité veut une bordure `outline`, `KadiRadius.xs` : la donner localement).
- Tests : `test/features/liste/liste_repository_test.dart`, `test/features/liste/liste_screen_test.dart` (`_pumpApp`, `_row`, `_tapBox`), `test/helpers/test_db.dart` (`SeedIds.riz`, `lardons` en g, `lait` en pièce, `tomates`).

## Tasks & Acceptance

**Execution:**
- [ ] `lib/core/strings/strings_fr.dart` -- `retireDeLaListe(name)` « Retiré de la liste : Riz », `supprimer` « Supprimer », `modifier` « Modifier », `quantite` « Quantité », `rayon` « Rayon », `suppressionImpossible` « Suppression impossible. Réessaie. », `modificationImpossible` « Modification impossible. Réessaie. », suffixe d'unité du champ (`g`, `ml`, `pièces`) -- Textes.
- [ ] `lib/features/liste/data/liste_repository.dart` -- `ListeItem.articleUnit` ; `removeLine(lineId) → List<UndoRow>`, `setQuantity(lineId, int? quantity)` (unité = celle de la ligne, sinon celle de l'article ; sans unité ni l'une ni l'autre → `ArgumentError` pour une quantité non nulle), `setRayon(lineId, Rayon)` -- AD-4, AD-5, AD-15.
- [ ] `lib/core/ui/quantity_field.dart` -- Champ quantité : `TextField` numérique entier (chiffres seulement), hauteur 48 dp, bordure `outline`, `KadiRadius.xs`, suffixe d'unité `onSurfaceVariant`, vide = sans quantité ; valeur en unité de saisie (g, ml, pièces entières) -- DESIGN `quantity-field`.
- [ ] `lib/core/ui/rayon_picker.dart` -- Choix de rayon : les 13 pastilles dans l'ordre de `Rayon.values`, en `Wrap`, cible ≥ 48 dp, rayon actuel entouré d'une bordure `onSurface` ; `Semantics(button, selected, label: spokenLabel)` -- DESIGN `rayon-picker`.
- [ ] `lib/features/liste/ui/item_edit_sheet.dart` -- Feuille d'édition d'article (feuille modale M3) : nom de l'article en titre, Champ quantité prérempli, Choix de rayon, « Supprimer » en `colorScheme.error` -- Design Notes.
- [ ] `lib/features/liste/ui/item_row.dart` -- `Dismissible` vers la gauche (fond `colorScheme.error`, icône corbeille), appui long → feuille, actions TalkBack « Supprimer » et « Modifier » -- R5, R12.
- [ ] `lib/features/liste/ui/liste_screen.dart` -- brancher la suppression : `removeLine` puis `undo.record` et `showUndoSnackBar` sur le contexte du `Builder` de la Liste ; snackbar d'erreur en cas d'échec -- AD-10.
- [ ] `test/features/liste/liste_repository_test.dart` -- un test par ligne de la matrice I/O, dont l'Annuler par `Undo` -- AD-5.
- [ ] `test/core/quantity_field_test.dart`, `test/core/rayon_picker_test.dart` -- saisie, préremplissage, sélection et sémantique -- composants partagés.
- [ ] `test/features/liste/liste_screen_test.dart` -- tests de widget des critères ci-dessous -- vérification du ticket.

**Acceptance Criteria:**
- Given Riz dans la liste, when Antoine glisse sa ligne vers la gauche, then Riz disparaît et un snackbar montre « Retiré de la liste : Riz » avec « Annuler » ; when il touche « Annuler », then Riz revient sous Épicerie salée avec sa quantité.
- Given Lardons dans la liste, when Antoine fait un appui long sur la ligne, then la Feuille d'édition s'ouvre avec le Champ quantité (suffixe g), le Choix de rayon (Viande/Poisson entouré) et « Supprimer ».
- Given cette feuille, when il saisit 300, choisit Plats préparés et ferme la feuille, then la Liste montre Lardons « 300 g » sous Plats préparés et plus sous Viande/Poisson.
- Given la feuille, when il touche « Supprimer », then la feuille se ferme, la ligne disparaît et le snackbar « Retiré de la liste : Lardons » propose Annuler.
- Given TalkBack, when il ouvre les actions d'une ligne, then « Supprimer » retire la ligne (snackbar Annuler) et « Modifier » ouvre la Feuille d'édition.
- Given une ligne cochée dans la Section Cochés dépliée, then le glisser et l'appui long y marchent aussi.

## Implementation Notes

## Plan Change Log

## Review Triage Log

### 2026-10-29 — Review pass
- verdicts: 6 findings — high 0, medium 1, low 5, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` La feuille fixe son unité à l'ouverture mais `setQuantity` la redéduit à chaque appel : vider puis ressaisir dans la même feuille écrit dans l'unité de l'article (500 `piece` au lieu de 500 ml) — corrigé : `setQuantity(..., {Unit? unit})` reçoit l'unité du champ, refuse une unité différente de celle de la ligne, la feuille passe toujours la sienne ; tests ajoutés.
  - `[low]` `[patch]` Pièces fractionnaires : `_written` partait du préremplissage arrondi, une correction égale à l'arrondi était ignorée — corrigé : comparaison avec la quantité stockée, écriture seulement après une saisie ou une validation (`QuantityField.onChanged`) ; test ajouté.
  - `[low]` `[reject]` Vider deux lignes du même article (g et ml) donne deux lignes sans unité, contre l'unicité d'AD-4 — réel mais rare (un article dans deux unités, les deux vidées) et la correction demande une fusion de lignes, que le plan exclut ; résidu noté ci-dessous.
  - `[low]` `[patch]` Le `Dismissible` gardait ses animations quand elles sont coupées — `movementDuration` et `resizeDuration` à zéro si `disableAnimationsOf`.
  - `[low]` `[reject]` Le snackbar « Modification impossible » s'écoule probablement caché derrière la feuille — un échec d'écriture SQLite locale est improbable et l'afficher dans la feuille ajoute un second canal d'erreur.
  - `[low]` `[reject]` Annuler la suppression de la dernière ligne cochée la rend dans une section Cochés repliée — la section disparaît quand elle est vide et revient « repliée par défaut » (DESIGN) ; la ligne est bien restaurée, un tap la montre.

## Design Notes

Feuille : `showModalBottomSheet` (`isScrollControlled`, `useSafeArea`, marge du clavier) ; elle rend un résultat au lieu d'écrire la suppression elle-même : « Supprimer » ferme la feuille par `Navigator.pop(context, ItemEditResult.delete)` et c'est la Liste qui supprime et montre le snackbar, sous son propre `ScaffoldMessenger` (la feuille vit dans le navigateur racine). Le rayon s'écrit au tap (la feuille reste ouverte, la sélection suit). La quantité s'écrit à la validation du clavier et à la fermeture de la feuille si la valeur a changé, une seule fois ; jamais après « Supprimer ». Un échec d'écriture montre `modificationImpossible`.

Saisie : g et ml en entiers ; pièces en nombre entier, stocké ×1000. Préremplissage : la quantité de la ligne dans l'unité de saisie (pièces arrondies à l'entier), vide sans quantité. Unité du champ : celle de la ligne, sinon l'unité par défaut de l'article **[ASSUMPTION]** (une ligne sans quantité n'a pas d'unité ; AD-5 interdit seulement de changer une unité existante) ; ni l'une ni l'autre → pas de Champ quantité dans la feuille.

Glisser : `Dismissible(direction: endToStart, key: ValueKey(lineId))`. Piège : un `Dismissible` rejeté doit quitter l'arbre tout de suite, avant que le flux Drift ne réémette ; faire la suppression dans `confirmDismiss` et masquer la ligne localement jusqu'à la nouvelle émission (ou équivalent), sans assertion « A dismissed Dismissible widget is still part of the tree ».

TalkBack : `customSemanticsActions` sur le `Semantics` de la ligne, `CustomSemanticsAction(label: StringsFr.supprimer)` et `modifier` ; le libellé de ligne reste inchangé.

Limite connue : corriger une ligne sans unité peut lui donner l'unité d'une autre ligne non cochée du même article (cas possible seulement après un décochage sans jumeau) ; on garde les deux lignes, pas de fusion.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent, dont les 140 existants avant la story

## Auto Run Result

Status: built

- **Résumé :** glisser une Ligne d'article vers la gauche la supprime (ligne et contributions supprimées logiquement) avec le snackbar « Retiré de la liste : Riz » · « Annuler ». L'appui long ouvre la Feuille d'édition : Champ quantité dans l'unité de la ligne (sinon celle de l'article), Choix de rayon des 13 pastilles, « Supprimer ». Corriger la quantité suit AD-5 (contribution `edition`, `manual_at`) ; changer le rayon ne touche que la ligne (AD-15). TalkBack propose « Supprimer » et « Modifier ». Lignes cochées comprises.
- **Fichiers :**
  - `lib/features/liste/data/liste_repository.dart` — `ListeItem.articleUnit`, `removeLine`, `setQuantity`, `setRayon`.
  - `lib/core/ui/quantity_field.dart`, `lib/core/ui/rayon_picker.dart`, `lib/core/ui/rayon_pastille.dart` — composants partagés (Champ quantité, Choix de rayon, pastille reprise de l'En-tête).
  - `lib/features/liste/ui/item_edit_sheet.dart` — Feuille d'édition d'article.
  - `lib/features/liste/ui/item_row.dart`, `checked_section.dart`, `liste_screen.dart`, `rayon_header.dart` — glisser, appui long, actions TalkBack, suppression et snackbars.
  - `lib/core/strings/strings_fr.dart` — textes.
  - Tests : `test/features/liste/liste_repository_test.dart`, `test/features/liste/liste_screen_test.dart`, `test/core/quantity_field_test.dart`, `test/core/rayon_picker_test.dart`.
- **Revue :** 3 corrections appliquées (1 medium, 2 low), 0 reporté, 3 rejetés (deux lignes sans unité après deux vidages, snackbar d'erreur derrière la feuille, section Cochés repliée après Annuler) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — une seule correction medium, aucune high.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 173/173 après corrections.
- **Risques résiduels :** unité de saisie d'une ligne sans quantité = unité de l'article et pièces entières [ASSUMPTION à valider par Antoine] ; deux lignes du même article peuvent finir dans la même unité (ou sans unité) après corrections, sans fusion ; fermeture de la feuille par le geste retour et par glissement non testée ; message d'erreur peu visible derrière la feuille ; la suite de tests est passée de ~30 s à ~1 min 15.
