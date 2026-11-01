---
title: "Les tags Quantité et Rayon sous le Champ d'ajout"
type: 'feature'
ticket: '15'
created: '2026-11-01'
status: 'built'
baseline_revision: 'f808b7a90cc61e47918b88fe2e103d0e169ca322'
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
warnings: []
deferred:
  - summary: >-
      AD-1 n'admettait que le brouillon de la Revue comme état d'écran.
    evidence: |-
      Les tags du panneau sont un second brouillon, exigé par R28. AD-1 amendé dans le spine le 2026-11-01.
    location: >-
      _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md
    severity: low
---

<intent-contract>

## Intent

**Problem:** Pour préciser la quantité ou le rayon d'un article tapé à la main, il faut l'ajouter d'abord puis le rouvrir : une ligne libre part dans Divers et on la corrige ensuite.

**Approach:** Sous le Champ d'ajout, un Tag Quantité et un Tag Rayon à régler avant Entrée. Ils s'appliquent à l'ajout suivant, puis reviennent à zéro.

## Boundaries & Constraints

**Always:** brouillon tenu en état d'écran du panneau, jamais écrit avant l'ajout ; Tag Quantité : `QuantityTag` et `showQuantityPopup` de la story 14, libellé vide « Quantité », titre de la popup = texte tapé, sinon « Quantité », unité préchoisie = unité de l'article au nom exact, sinon pièce ; à la fermeture de la popup, le focus revient au Champ d'ajout. Tag Rayon : liste déroulante (`MenuAnchor`, au-dessus du tag, hauteur plafonnée, défilante) des 13 rayons dans l'ordre du parcours de `settings`, chaque entrée en pastille comme l'En-tête de rayon, clavier conservé. Contour : point du rayon + nom + flèche, rayon de l'article au nom exact tapé (catalogue, casse et accents ignorés par `normalizeName`), sinon Divers ; plein (fond de pastille du rayon) dès qu'un rayon est choisi, qui prime alors. Application : Entrée, « Ajouter « … » » et tap sur un résultat hors liste ; quantité en contribution `ajout`, jamais manuelle (AD-5) ; rayon sur la seule ligne, jamais sur l'article, hors catalogue compris (AD-15), et seulement s'il a été choisi. Article déjà dans la liste par Entrée : avec un tag réglé, quantité et rayon remplacent ceux de sa plus ancienne ligne non cochée par le chemin de l'édition (AD-5, fusion comprise), ligne montrée et surlignée ; sans tag, rien ne change, ligne montrée. En une transaction (AD-3). Remise à zéro des deux tags après tout ajout réussi et à la fermeture du panneau ; effacer le texte ne les remet pas à zéro ; un échec les garde, avec la saisie. Zone tactile 48 dp, visuel 32 dp. TalkBack : « Quantité, aucune », « Quantité, 500 g », « Rayon, Divers ». Textes dans `strings_fr.dart`, couleurs par le thème.

**Never:** aucun changement du rayon ou de l'unité d'un article, ni mémorisation pour un prochain ajout du même nom ; un tap sur un fréquent n'utilise ni ne remet à zéro les tags ; un tap sur un résultat déjà dans la liste le retire et laisse les tags intacts ; pas de surlignage hors du cas d'Entrée sur une ligne présente ; pas de migration ni de dépendance ; coche ronde, bouton Gérer et Cochés restent à la story 16.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Ligne libre avec tags | « piles », Entretien, 4 pièces, Entrée | « Piles 4 » sous Entretien, champ vidé, clavier ouvert, tags à zéro | Échec : snackbar, saisie et tags gardés |
| Pas de mémoire | Puis Piles retirée, « piles » + Entrée | Sous Divers, sans quantité ; tag de nouveau Divers | - |
| Article du catalogue | « lait » tapé | Tag Rayon en contour : Crèmerie ; Entrée : ligne sous Crèmerie, unité préchoisie de l'article | - |
| Nom partiel | « lai » | Tag Rayon : Divers (pas de nom exact) | - |
| Rayon choisi sur un article | « lait », Boissons, Entrée | Ligne sous Boissons ; l'article reste Crèmerie (ajout suivant de nouveau sous Crèmerie) | - |
| Présent, avec quantité | Lait présent à 1 pièce, « lait », 2, Entrée | Une seule ligne, quantité remplacée à 2, montrée et surlignée, tags à zéro | Échec : snackbar, saisie et tags gardés |
| Présent, avec rayon | Lait présent, « lait », Boissons, Entrée | Ligne déplacée sous Boissons, sans autre changement | - |
| Présent, sans tag | Lait présent, « lait », Entrée | Rien ne change, ligne montrée | - |
| Résultat | « lai », tag 2, tap sur Lait hors liste | Lait à 2, tags à zéro, le champ garde son texte | - |
| Résultat présent | « lai », tag 2, tap sur Lait présent | Lait retiré avec Annuler, tags intacts | - |
| Ajouter « … » | « xyz », Hygiène, tap sur la ligne | Comme Entrée | - |
| Fréquent | Tag 2 réglé, tap sur un fréquent | Fréquent ajouté sans quantité, tag toujours à 2 | - |
| Entrée vide | Tags réglés, champ vide, Entrée | Rien, tags intacts | - |
| Effacer | Tags réglés, × | Texte vidé, tags intacts | - |
| Fermeture | Tags réglés, panneau fermé puis rouvert | Tags à zéro, rien d'écrit | - |
| Quantité vidée | Tag à 4, popup vidée | Tag « Quantité » en contour | - |

</intent-contract>

## Code Map

- `lib/features/liste/ui/add_sheet.dart` -- `_AddSheetState` (`_addTyped`, `_add`, `_toggle`, `_editQuantity`, zone du champ dans `build`) ; `results` contient le résultat de nom exact.
- `lib/features/liste/ui/add_sheet_rows.dart` -- y mettre le Tag Rayon, ou un fichier voisin ; `PanelHandle` et rangées existantes.
- `lib/features/liste/ui/quantity_tag.dart`, `quantity_popup.dart`, `quantity_input.dart` -- story 14 : `QuantityTag` (`emptyLabel`), `showQuantityPopup` (`null` = inchangé, sinon `(value: …)`), `initialInputUnit`.
- `lib/app/actions/ajout_panneau.dart` -- `AjouterTexte.call(name)` en transaction : y ajouter quantité, unité et rayon ; `TexteAjoute` porte déjà `article`, `ajoute`, `lineId`.
- `lib/features/liste/data/liste_repository.dart` -- `addArticle(id, quantity:, unit:)`, `setQuantity`, `setRayon`, `firstUnchecked`. Ils ouvrent leur propre transaction, imbriquée sans souci dans celle de l'action.
- `lib/features/catalogue/data/normalize_name.dart` -- `normalizeName`.
- `lib/core/settings/settings_providers.dart` -- `settingsProvider`, `routeOrder` pour l'ordre du menu.
- `lib/core/ui/rayon_pastille.dart` -- pastille réutilisable ; `lib/core/theme/kadi_colors.dart` pour l'accent et le fond.
- `lib/features/liste/state/liste_panel.dart` -- `reveal(lineId)`.
- Tests : `test/app/ajout_panneau_test.dart`, `test/features/liste/add_sheet_test.dart`, `test/features/liste/add_panel_reveal_test.dart`, `test/features/liste/quantity_popup_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/app/actions/ajout_panneau.dart` -- paramètres facultatifs quantité, unité, rayon ; ajout ou remplacement selon la présence -- matrice.
- [x] `lib/features/liste/ui/rayon_tag.dart` -- Tag Rayon et son menu.
- [x] `lib/features/liste/ui/add_sheet.dart` -- brouillon, rangée de tags sous le champ, rayon affiché, application et remise à zéro, retour du focus ; un résultat ajouté avec tags passe par `addArticle` + `setRayon` dans une action en une transaction, pas par deux écritures séparées.
- [x] `lib/core/strings/strings_fr.dart` -- « Quantité, aucune », « Rayon, … ».
- [x] `test/*` -- couvrir chaque ligne de la matrice, dont le menu, l'absence d'écriture avant l'ajout et l'absence de mémoire.

**Acceptance Criteria:**
- Given le panneau ouvert, when on regarde sous le champ, then deux tags sont visibles et le titre des fréquents vient après.
- Given le clavier ouvert, when on ouvre le Tag Rayon et choisit un rayon, then le Champ d'ajout garde le focus.
- Given une ligne ajoutée avec un rayon choisi, when on lit l'article au catalogue, then son rayon n'a pas changé.
- Given l'application complète, when `flutter test` tourne, then tous les tests passent.

## Implementation Notes

- Une action `AjouterArticle` rejoint `AjouterTexte` dans `ajout_panneau.dart` pour le tap sur un résultat ; le fréquent y passe aussi, sans tags.
- `AddTag` (cible 48 dp, puce 32 dp) est extrait de `QuantityTag` dans `quantity_tag.dart`, partagé avec `RayonTag`.
- Hors Code Map : `liste_screen.dart` remontre la dernière ligne montrée quand son rayon change, car la demande de montrer peut précéder l'émission du flux (AD-19).
- Hors Code Map : `RayonPastille` passe son nom en `Flexible`, sinon les entrées du menu débordent à partir de la police ×2.
- `_panelMinHeight` compte la rangée de tags, à la place de l'écart de 8 dp sous le champ.
- Un tap hors du menu le ferme seulement (`consumeOutsideTap`) : ni ajout, ni panneau fermé.
- Une Entrée ou un tap sur un résultat est ignoré pendant une écriture du panneau en cours, pour que les tags ne soient pas consommés deux fois.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` `ref.watch(settingsProvider)` dans la closure du `Builder`, hors du `build` de l'élément : abonnement refermé à chaque reconstruction — déplacé en tête de `build`.
  - `[low]` `[reject]` Budget de hauteur du panneau compté sur une rangée de tags alors qu'ils passent sur deux en grande police — à ×2 ou ×3 sur un écran de 640 dp seulement ; le corriger ajouterait une mesure, pour un cas loin de l'usage d'Antoine.
  - `[low]` `[patch]` Entrée qui remplace une ligne présente annoncée comme si rien n'avait changé — annonce distincte « Lait modifié », test ajouté.
  - `[low]` `[defer]` AD-1 n'admet que le brouillon de la Revue comme état d'écran — le code suit le plan ; AD-1 amendé dans le spine à la clôture de cette story, hors de son diff.
  - `[low]` `[patch]` Titre de test qui promet une vérification d'unité jamais faite — renommé ; l'unité reste couverte par le test `tomates`.

## Design Notes

[ASSUMPTION] Avec des tags, le remplacement passe par `setQuantity`, qui rend la ligne manuelle : c'est une édition explicite (AD-5). Un tag rayon seul ne touche pas la quantité.

[ASSUMPTION] L'absence de Annuler après un remplacement est acceptée : la quantité se corrige par le tag de la ligne.

## Verification

**Commands:**
- `dart format --set-exit-if-changed lib test` -- expected: aucun changement
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: tous les tests passent

## Auto Run Result

**Résumé :** Tag Quantité et Tag Rayon sous le Champ d'ajout, appliqués à l'ajout suivant par Entrée, « Ajouter « … » » ou tap sur un résultat, puis remis à zéro ; Entrée sur une ligne présente remplace sa quantité et son rayon si un tag est réglé ; rayon jamais écrit sur l'article.

**Fichiers :** `rayon_tag.dart` (nouveau), `quantity_tag.dart` (`AddTag` commun), `add_sheet.dart`, `ajout_panneau.dart` (`AjouterTexte`, `AjouterArticle`), `liste_screen.dart` (revérifie la ligne montrée si son rayon change), `rayon_pastille.dart`, `strings_fr.dart`, tests.

**Revue :** 3 patches appliqués (low), 1 rejeté, 1 reporté (AD-1, amendé dans le spine).

**Suivi de revue recommandé :** non (0 high, 0 medium corrigé).

**Vérification :** `dart format`, `flutter analyze`, `flutter test` passent.

**Risques résiduels :** clavier conservé, retour du focus et position du menu vus seulement en test de widgets ; retour Android avec le menu ouvert ferme tout le panneau, sans rien écrire ; `RayonHeader` déborde à ×3 sur 360 dp (antérieur à cette story).
