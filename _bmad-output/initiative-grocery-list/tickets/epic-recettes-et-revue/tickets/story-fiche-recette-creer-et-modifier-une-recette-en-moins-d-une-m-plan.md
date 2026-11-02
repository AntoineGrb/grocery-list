---
title: "Fiche recette : créer et modifier une recette en moins d'une minute"
type: 'feature'
ticket: '5'
created: '2026-11-02'
status: 'built'
baseline_revision: 'eb282da1502089220fdaf71c54e6d19cfd589089'
route: 'full'
route_source: 'auto'
risk: 'medium'
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

**Problem:** Antoine ne peut ni créer ni modifier une recette : seules les 4 recettes exemples existent (R1, R7, Flux 4).

**Approach:** Une Fiche recette en écran poussé, ouverte vide par le FAB + de Recettes ou sur une recette par l'icône « modifier » de sa carte : nom, Champ de recherche sur le catalogue (tap = ingrédient, « Créer « … » » sinon), Lignes d'ingrédient avec quantité et unité, enregistrement automatique dès un nom et un ingrédient.

## Boundaries & Constraints

**Always:**
- FAB + de Recettes (DESIGN `fab`, argile) lu « Nouvelle recette », empilé au-dessus du Bouton d'action « Valider » quand il est là ; il ouvre une Fiche recette vide, nom focalisé, clavier ouvert. Icône « modifier » discrète sur chaque Carte recette, cible ≥ 48 dp, lue « Modifier Chili con carne », qui ouvre la fiche sans changer la sélection ; un tap ailleurs sur la carte sélectionne toujours.
- Fiche recette : écran poussé plein écran (AD-13), flèche retour, sans Barre de navigation ; champ nom ; Champ de recherche (DESIGN `search-field` : pilule, loupe, × d'effacement, texte indicatif « Ajouter un ingrédient », curseur `on-surface`) qui filtre tout le catalogue à chaque frappe (`CatalogueRepository.watchSearch`) ; Lignes de résultat (Picto, nom, rayon) ; un tap ajoute l'article comme ingrédient en dernière position.
- Sans résultat au nom exact (casse et accents ignorés, `normalizeName`), une ligne « Créer « … » » crée l'article au catalogue par `CatalogueRepository.createArticle` (Divers, sans unité, AD-17 ; un nom porté par un article hors catalogue y entre, même id) et l'ajoute comme ingrédient, sans quitter la fiche.
- Après un ajout : le champ de recherche se vide et le Champ quantité du nouvel ingrédient prend le focus (clavier numérique) ; Entrée sur ce champ rend le focus à la recherche. Un article déjà ingrédient n'est pas ajouté de nouveau (son résultat montre une coche, un tap ne fait rien).
- Ligne d'ingrédient (DESIGN `ingredient-row`) : Picto, nom, Champ quantité (`QuantityField`) dans l'unité de l'ingrédient, sinon celle de l'article, sinon pièce ; un tap sur l'unité du champ ouvre le Choix d'unité (`UnitChoice` de `lib/features/liste/ui/quantity_input.dart`, pièce, g, kg, ml, L) sous la ligne ; icône de retrait (48 dp, lue « Retirer Haricots rouges »). Vide ou 0 = sans quantité ; kg et L s'enregistrent en g et ml (AD-6). L'ingrédient copie l'unité de l'article à son ajout (AD-15).
- Enregistrement automatique : dès que la fiche a un nom (non vide une fois nettoyé) et au moins un ingrédient, chaque changement s'écrit (nom, ajout, retrait, quantité, unité, ordre), par `RecettesRepository`, en une transaction, horloge et UUID (AD-7) ; ingrédients retirés supprimés logiquement. Une nouvelle fiche quittée sans nom ou sans ingrédient ne crée rien. Une recette existante privée de nom ou de tout ingrédient n'est pas écrite et garde sa dernière version valide.
- R7 : modifier une recette, validée ou non, ne change jamais la liste en cours ; une sélection active reste active.
- TalkBack : nom, recherche, résultats (« Haricots rouges, Épicerie salée »), « Créer « … » », ingrédients (« Haricots rouges, 500 g »), champ « Quantité de Haricots rouges, 500 g », « Retirer … ». Police système sans troncature. Microcopie dans `strings_fr.dart`.

**Never:**
- Photo, lien, suppression de recette (stories 6 et 7) ; ligne libre hors catalogue comme ingrédient ; création d'article ailleurs que par « Créer « … » ».
- Portions, étapes, temps, tags (initiative, Boundaries).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Flux 4 | FAB +, « Chili », « hari » → Haricots… ; 500 ; 4 autres dont un créé | Carte « Chili » sur Recettes, picto du premier ingrédient | — |
| Incomplète | Nouvelle fiche avec un nom sans ingrédient, retour | Aucune recette | — |
| Sans nom | Ingrédients sans nom, retour | Aucune recette | — |
| Nom vidé | Recette existante, nom effacé, retour | Ancien nom gardé | — |
| Dernier ingrédient retiré | Recette existante | Dernière version valide gardée | — |
| Créer | « Piment d'Espelette » inconnu | Article au catalogue (Divers, sans unité), ingrédient ajouté, trouvable ensuite par la recherche | Échec : snackbar d'erreur, rien d'écrit |
| Nom hors catalogue | « Piles » existe hors catalogue | Le même article entre au catalogue et devient ingrédient | — |
| Doublon | Tap sur un article déjà ingrédient | Rien ne change | — |
| kg | 1,5 kg saisi | Stocké 1500 g | — |
| Recette validée modifiée | Chili validé, quantité changée | Liste inchangée, carte toujours sélectionnée | — |

</intent-contract>

## Code Map

- `lib/features/recettes/data/recettes_repository.dart` -- lecture d'une recette pour la fiche (nom, ingrédients actifs par `position` avec article actif : nom, picto, rayon, unité de l'article) ; écriture de la fiche en une transaction (insertion ou mise à jour de `recipes`, ingrédients : insertion, mise à jour de position, quantité et unité, suppression logique des retirés) ; rien d'écrit si invalide.
- `lib/features/recettes/ui/` -- nouvel écran de fiche (et ses lignes) ; brouillon d'écran avec un id de recette tiré à l'ouverture d'une fiche vide, ids d'ingrédient stables.
- `lib/features/recettes/ui/recettes_screen.dart` -- FAB +, ouverture de la fiche par l'icône de carte.
- `lib/features/recettes/ui/recipe_card.dart` -- icône « modifier » (`edit_outlined`, `on-surface-variant`) en haut à droite du visuel, 48 dp, sémantique séparée de celle de la carte (la carte garde « …, sélectionnée » et son tap).
- `lib/app/kadi_app.dart`, `lib/core/router/app_router.dart` -- routes poussées de la fiche (nouvelle, et par id de recette).
- `lib/features/catalogue/data/catalogue_repository.dart`, `normalize_name.dart`, `lib/features/catalogue/state/catalogue_providers.dart` (`articleSearchProvider`) -- réutiliser ; `createArticle` à appeler dans une transaction.
- `lib/features/liste/ui/quantity_input.dart` (`UnitChoice`), `lib/core/ui/quantity_field.dart` (`QuantityField`, `quantityFieldText`, `quantityFromFieldText`, `quantityTextForUnit`), `lib/features/liste/ui/add_sheet_rows.dart` (style des lignes de résultat) -- réutiliser sans changer leur comportement.
- `lib/core/strings/strings_fr.dart` -- Nouvelle recette, Nom de la recette, Ajouter un ingrédient, Créer « … », Modifier …, Retirer …, échec d'enregistrement.
- Tests : repository (lecture, écriture, invalides, suppression logique), écran (Flux 4 complet, matrice, TalkBack, police ×2), carte (icône sans sélection).

## Tasks & Acceptance

**Execution:**
- [x] `recettes_repository.dart` + tests -- lecture et écriture de la fiche, règles de validité
- [x] fiche recette (écran, lignes), routes, `strings_fr.dart` -- R1
- [x] `recettes_screen.dart`, `recipe_card.dart` -- FAB + et icône « modifier »
- [x] tests d'écran -- matrice, Flux 4, R7, TalkBack, police

**Acceptance Criteria:**
- Given Recettes, when Antoine touche le FAB +, tape « Chili », cherche « hari » et touche Haricots rouges, saisit 500, ajoute quatre autres ingrédients dont un créé, puis revient, then la carte « Chili » apparaît avec le picto des haricots rouges.
- Given une fiche neuve avec un nom mais sans ingrédient, when il revient, then aucune carte n'est créée.
- Given Chili con carne validé, when il ouvre sa fiche par l'icône « modifier » et change une quantité, then la Liste est inchangée et la carte reste sélectionnée.
- Given TalkBack, when il parcourt la fiche, then nom, recherche, résultats, ingrédients, quantités et « Retirer » sont annoncés.

## Implementation Notes

- Implémenté par un sous-agent sur la base eb282da. Fichiers : `recettes_repository.dart` (`readSheet`, `saveDraft`, `newId`, `cleanRecipeName`), `recettes_providers.dart` (`creerArticleProvider` : `createArticle` dans une transaction), `fiche_recette_screen.dart` et `fiche_recette_rows.dart` (Ligne d'ingrédient, Ligne de résultat, « Créer « … » »), routes `/recette` et `/recette/:id`, `recipe_card.dart` (icône « modifier »), `recettes_screen.dart` (FAB +), `strings_fr.dart`.
- Écarts et choix : `QuantityField` reçoit un `onUnitTap` facultatif (suffixe d'unité tappable, ≥ 48 dp, lu « Unité, g », avec une flèche) ; sans lui, rien ne change (Revue, Popup). Dans la fiche, le Champ de recherche est sous le nom, ses résultats juste dessous, les Lignes d'ingrédient ensuite. Entrée dans la recherche n'ajoute rien (aucune création hors « Créer « … » »). Une quantité lue de la base est réécrite telle quelle tant que son champ et son unité n'ont pas changé (le texte des pièces est arrondi). Le Choix d'unité se ferme après un choix ; une unité choisie sans quantité n'est pas gardée en base (quantité et unité nulles ensemble, AD-6). Écritures sérialisées : une à la fois, la plus récente ensuite. Retirer les ingrédients un à un écrit chaque version valide : la dernière (un seul ingrédient) reste. Le FAB de Recettes n'a pas de Hero (celui de la Liste vit dans la même coque) ; la grille garde 96 dp en bas pour lui.
- [ASSUMPTION] Le Champ de recherche suit DESIGN (`surface` sur fond `surface`) : la pilule ne se détache pas du fond, seuls la loupe et le texte indicatif la signalent ; à valider par Antoine au test de fin d'epic.
- Vérification : `flutter analyze` sans problème ; `flutter test` tout vert (Flux 4, matrice, R7, TalkBack, police ×1,3/×2/×3, échecs de création et d'enregistrement).

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 4 findings — high 0, medium 1, low 3, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` Corps en `ListView` paresseux : clavier ouvert et recette longue, le Champ quantité du nouvel ingrédient (ou la recherche) n'est pas construit, le focus ne suit pas — corrigé : `SingleChildScrollView` + `Column`, focus puis `Scrollable.ensureVisible` ; test clavier ouvert avec 11 ingrédients, vérifié en échec sur l'ancien code.
  - `[low]` `[patch]` `saveDraft` supprimait les ingrédients cachés par un article supprimé que `readSheet` ne montre pas — corrigé : même filtre que `readSheet` ; test de non-modification.
  - `[low]` `[reject]` Suffixe d'unité cliquable : peu de place pour les chiffres en pièces à ×1,3 — les quantités en pièces sont courtes (1 à 2 chiffres), les grammes gardent environ 6 chiffres ; à juger au test de fin d'epic.
  - `[low]` `[reject]` Lecture de la fiche en échec : écran vide sans message — base locale, même traitement que la Revue et Recettes ; la route ne s'ouvre que depuis une carte existante.

## Design Notes

- Rapidité (Flux 4, moins d'une minute pour 5 ingrédients) : recherche → tap → quantité focalisée → Entrée → recherche, sans autre geste. [ASSUMPTION] à valider par Antoine au test de fin d'epic.
- L'id d'une nouvelle recette est tiré à l'ouverture : les écritures successives d'une même fiche visent la même ligne.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : FAB + « Nouvelle recette » et icône « modifier » sur chaque carte ouvrent la Fiche recette : nom, recherche sur le catalogue, « Créer « … » » au catalogue, Lignes d'ingrédient avec quantité et unité (tap sur l'unité), retrait ; enregistrement automatique dès un nom et un ingrédient ; après un ajout, le focus passe à la quantité puis revient à la recherche par Entrée.
- Fichiers : `recettes_repository.dart` (`readSheet`, `saveDraft`, `newId`), `recettes_providers.dart`, `fiche_recette_screen.dart` et `fiche_recette_rows.dart` (nouveaux), `recipe_card.dart`, `recettes_screen.dart`, `app_router.dart`, `kadi_app.dart`, `strings_fr.dart`, `quantity_field.dart` (`onUnitTap` facultatif) ; tests `fiche_recette_repository_test.dart`, `fiche_recette_screen_test.dart`.
- Revue : 2 correctifs (medium focus, low ingrédients cachés), 0 report, 2 rejets motivés.
- Revue de suivi recommandée : non (un seul medium corrigé et prouvé par test).
- Vérification : `flutter analyze` sans problème ; `flutter test` 565/565.
- Risques : le champ de recherche (fond `surface` sur `surface`) se distingue peu ; chaque frappe écrit en base, non mesuré sur le téléphone ; rapidité du Flux 4 à juger au test de fin d'epic.
