---
title: "La Revue : décocher ce qu'on a déjà et corriger une quantité"
type: 'feature'
ticket: '2'
created: '2026-11-02'
status: done
baseline_revision: '91b507b6695c56060f4bfcd020960e87a6d10ece'
route: 'full'
route_source: 'auto'
risk: 'high'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/epic-recettes-et-revue.md'
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-une-recette-exemple-selectionnee-et-validee-arrive-dans-la-l-plan.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** La Revue de la story 1 est en lecture seule : Antoine ne peut ni décocher ce qu'il a déjà ni corriger une quantité avant « Ajouter à la liste » (R5, Flux 1 étape 4).

**Approach:** Un brouillon d'écran dans la Revue (cases et quantités saisies, jamais persisté, AD-1) ; une fonction pure transforme Revue + brouillon en contributions à écrire (ligne décochée : aucune ; ligne corrigée : répartie au prorata entre les recettes, AD-4) ; l'action « Ajouter à la liste » écrit ces contributions.

## Boundaries & Constraints

**Always:**
- Ligne de Revue (DESIGN `review-row`, EXPERIENCE Ligne de Revue) : un tap sur la coche ronde (cible 48 dp) décoche ou recoche ; décochée, le nom passe en couleur `checked` sans barré et la ligne reste en place. Champ quantité (`QuantityField` de `lib/core/ui/quantity_field.dart`) à droite, valeur exacte dans l'unité de la ligne (texte de `quantityFieldText`), sans Choix d'unité ; une ligne sans quantité montre un champ vide dans l'unité par défaut de l'article, sinon pièce ; vide ou 0 = sans quantité.
- Prorata (AD-4) : la valeur corrigée V d'une ligne se répartit entre ses contributions au prorata de leurs quantités d'origine, arrondie vers le bas dans l'unité (g et ml : unité stockée ; pièce : pièce entière, soit 1000 millièmes), la dernière contribution absorbant le reste ; la somme écrite vaut exactement V. Sans quantité d'origine sur aucune contribution, poids égaux. Une contribution sans quantité d'origine reçoit sa part (0 = sans quantité).
- Correction vidée : toutes les contributions de la ligne s'écrivent sans quantité. Valeur saisie égale à l'origine : comme non corrigée.
- Tout décoché : « Ajouter à la liste » reste actif, n'écrit aucune contribution et valide quand même les sélections de la Revue (AD-16). Retour arrière : rien n'est écrit, sélection gardée.
- TalkBack : la ligne lue « Pâtes, 500 g, Épicerie salée » avec son état coché ou non et l'action tap ; le champ lu « Quantité de Pâtes, 500 g » (ou « aucune ») ; annonce « Pâtes, non coché » / « Pâtes, coché » au changement (chaînes existantes `cocheAnnonce`, `nonCocheAnnonce`, `quantiteDe`). Police système sans débordement.

**Never:**
- Persister le brouillon, changer l'unité d'une ligne en Revue, rendre une ligne de liste manuelle (`manual_at`) par une correction de Revue.
- Toucher à la désélection d'une recette validée (story 3) ou à Nouvelle liste (story 4).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Décochée | Pâtes décochées | Aucune contribution pour Pâtes ; rien d'autre ne change | — |
| Prorata pièces | Œufs 4 + 4 pièces corrigé à 6 | Contributions 3000 et 3000 ; ligne « Œufs 6 pièces » | — |
| Prorata reste | Œufs 4 + 4 corrigé à 7 | 3000 et 4000 (dernière absorbe) | — |
| Prorata grammes | Lardons 200 g + 300 g corrigé à 400 | 160 g et 240 g | — |
| Somme exacte | Toute correction V | Somme des contributions écrites = V | — |
| Vidée | Lardons 400 g, champ vidé | Deux contributions sans quantité | — |
| Sans quantité d'origine | Poivre sans quantité dans deux recettes, saisi 2 (unité par défaut de l'article, sinon pièce) | Poids égaux : 1 et 1 dans cette unité | — |
| Inchangée | Valeur retapée identique | Contributions d'origine | — |
| Tout décoché | Toutes les lignes décochées | Aucune contribution ; sélections validées ; « Valider » disparaît | — |
| Retour | Flèche retour après décoche | Rien d'écrit, « Valider (n) » toujours là | — |

</intent-contract>

## Code Map

- `lib/features/recettes/state/revue.dart` -- `RevueLine` (articleId, unit, contributions avec `selectionId`, quantity, unit) : ajouter une clé stable de ligne (article + `unitKey`), l'unité par défaut de l'article (unité du champ d'une ligne sans quantité) ; nouvelle fonction pure qui rend les contributions à écrire depuis la Revue et le brouillon (lignes décochées, quantités corrigées en quantité stockée), avec le prorata ci-dessus.
- `lib/features/recettes/data/recettes_repository.dart` -- `RevueSource` / `pendingSelections` : porter l'unité par défaut de l'article (`articles.unit`).
- `lib/app/actions/ajouter_a_la_liste.dart` -- `call` prend la Revue et le brouillon (ou la liste de contributions) ; garde une transaction, `markValidated` de toutes les sélections, même sans contribution.
- `lib/features/recettes/ui/revue_row.dart` -- la coche devient active (rappel de la Ligne d'article `lib/features/liste/ui/item_row.dart` : coche ronde 24 dp, accent du rayon, jamais d'argile) ; nom en `KadiColors.of(context).checked` décoché ; `QuantityField` à la place du texte (`revueQuantityText` ne sert plus que si utile, sinon le supprimer) ; sémantique séparée pour la ligne et le champ.
- `lib/features/recettes/ui/revue_screen.dart` -- état du brouillon (cases, textes saisis par clé de ligne), contrôleurs gardés tant que l'écran vit, passés à l'action.
- `lib/core/ui/quantity_field.dart` -- `quantityFieldText`, `quantityFromFieldText`, `InputUnit.of` : réutiliser, ne pas modifier.
- `test/features/recettes/revue_test.dart`, `test/app/ajouter_a_la_liste_test.dart`, `test/features/recettes/recettes_screen_test.dart` -- étendre.

## Tasks & Acceptance

**Execution:**
- [x] `revue.dart`, `recettes_repository.dart` -- clé de ligne, unité de l'article, contributions à écrire avec prorata -- AD-4
- [x] `test/features/recettes/revue_test.dart` -- chaque ligne de la matrice sur la fonction pure, dont somme exacte sur plusieurs cas (contrôle de risque du ticket)
- [x] `ajouter_a_la_liste.dart` + test -- écrit les contributions du brouillon ; Pâtes décochées absentes ; Œufs 6 = 3 + 3 ; tout décoché valide sans écrire
- [x] `revue_row.dart`, `revue_screen.dart` -- coche active, champ quantité, brouillon
- [x] `recettes_screen_test.dart` -- parcours écran : décocher Pâtes, Œufs 8 → 6, Ajouter : Liste sans Pâtes avec « Œufs 6 pièces » ; retour arrière ; TalkBack et police ×2

**Acceptance Criteria:**
- Given la Revue Carbonara + Quiche, when Antoine décoche Pâtes, then le nom de Pâtes passe en couleur cochée sans barré et reste à sa place.
- Given la même Revue, when il remplace 6 par 4 dans le champ des Œufs et touche « Ajouter à la liste », then la Liste montre « Œufs 4 pièces » et pas de Pâtes.
- Given toutes les lignes décochées, when il touche « Ajouter à la liste », then la Liste ne change pas et « Valider » a disparu de Recettes.
- Given TalkBack, when il parcourt une Ligne de Revue, then il entend nom, quantité, rayon et l'état coché, puis le champ « Quantité de … ».

## Implementation Notes

- Implémenté par un sous-agent sur la base 91b507b. Fonction pure `revueWrites(Revue, RevueDraft)` et `prorata` dans `revue.dart` ; `RevueDraft` = clés décochées + corrections en quantité stockée (null = vidé) ; l'action prend `draft:` en paramètre nommé (défaut vide).
- Écarts : les recettes exemples donnent Œufs 3 + 3 = 6 (pas 8) ; les tests d'écran et d'action corrigent donc Œufs 6 → 4 (critère d'acceptation) au lieu de 8 → 6. L'écran ne compte une correction que si le texte du champ diffère du texte d'origine (une ligne de 5,5 pièces affichée « 6 » et laissée telle quelle garde 5500).
- Champ quantité de 128 dp à droite ; au-delà d'une police ×1,3, il passe sous le nom (aligné sur le Picto), sans débordement. La quantité lue dans la ligne et le champ suit la saisie en cours.

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 1 findings — high 0, medium 1, low 0, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Le clavier ouvert masque « Ajouter à la liste » pendant la saisie d'une quantité (bouton dans `bottomNavigationBar`) — corrigé : la barre du bas prend en marge la hauteur du clavier (`MediaQuery.viewInsetsOf`), deux tests de widget (clavier ouvert, clavier fermé).

## Design Notes

- Exemple de prorata (pièces, granularité 1000) : origines [4000, 4000], V = 7000 → parts brutes 3500, 3500 → arrondi bas à la pièce 3000 pour la première, la dernière prend 7000 − 3000 = 4000.
- Le brouillon se garde par clé de ligne ; il meurt avec l'écran (retour = rien).

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : en Revue, la coche ronde décoche ou recoche une ligne (nom en couleur cochée, sans barré) ; un Champ quantité corrige la valeur dans l'unité de la ligne ; « Ajouter à la liste » n'écrit que les lignes cochées, une correction étant répartie au prorata des recettes (pièce entière pour les pièces, la dernière absorbant le reste) ; tout décoché valide sans rien ajouter.
- Fichiers : `revue.dart` (clé de ligne, unité du champ, `RevueDraft`, `revueWrites`, `prorata`) ; `recettes_repository.dart` (unité de l'article) ; `ajouter_a_la_liste.dart` (brouillon) ; `revue_row.dart` (coche active, champ, TalkBack) ; `revue_screen.dart` (brouillon, bouton au-dessus du clavier) ; tests `revue_test.dart`, `ajouter_a_la_liste_test.dart`, `recettes_screen_test.dart`.
- Revue : 1 correctif (medium, clavier), 0 report, 0 rejet.
- Revue de suivi recommandée : non (un seul correctif medium, vérifié par test).
- Vérification : `flutter analyze` sans problème ; `flutter test` 497/497.
- Risques : une quantité de pièces non entière laissée telle quelle garde sa valeur exacte ; inatteignable avec les saisies actuelles.
