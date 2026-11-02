---
title: 'Créer un article et préciser quantité et rayon à l''ajout'
type: 'feature'
ticket: '8'
created: '2026-10-29'
status: done
baseline_revision: '661c8c79728a647c5ae1b980ac6609f109d18a78'
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

**Problem:** Le Panneau + ne permet ni d'ajouter un article absent du catalogue, ni de préciser la quantité ou le rayon au moment de l'ajout : « piles » est introuvable, et « Œufs 6 pièces » demande un appui long dans la Liste (R8, R9, R3).

**Approach:** Sans correspondance exacte (nom normalisé, AD-17), la recherche propose « Créer « … » », qui crée l'article par l'unique `createArticle` (Divers, sans unité) et l'ajoute, dans une transaction. Après un ajout depuis un fréquent, un résultat ou une création, la ligne du panneau affiche le Champ quantité (unité par défaut de l'article) et le Choix de rayon de la story 6, facultatifs ; le rayon choisi place la ligne, et devient celui de l'article quand il vient d'être créé.

## Boundaries & Constraints

**Always:** correspondance exacte = un article actif de même `normalizeName` que la saisie ; un nom normalisé reste unique parmi les articles actifs (« Lait » et « lait » ne créent jamais deux articles) ; `createArticle(nom, rayon = divers, unité = sans)` est la seule création, dans `CatalogueRepository` ; créer et ajouter se font dans une seule transaction (action de `lib/app/actions/`, AD-3) ; nom créé = saisie sans espaces de bord ni espaces doublés, première lettre en majuscule (« piles » → « Piles ») ; la quantité saisie après un ajout complète la contribution `ajout` de cet ajout (jamais `edition`, la ligne ne devient pas manuelle, AD-5), dans l'unité par défaut de l'article, vide ou 0 = sans quantité (AD-6) ; le Choix de rayon change `list_lines.rayon` de la ligne ajoutée ; pour un article créé dans ce panneau, il change aussi `articles.rayon` (même transaction) ; Champ quantité et Choix de rayon sont les composants partagés `QuantityField` et `RayonPicker` ; une seule ligne du panneau est dépliée à la fois (le dernier ajout) ; textes dans `strings_fr.dart` ; libellés TalkBack et taille de police système ; cibles ≥ 48 dp.

**Never:** pas de choix d'unité ni d'unité donnée à un article créé ; pas de fréquent ajouté par l'app ; pas de modification du rayon d'un article existant depuis le panneau ; pas d'Annuler sur la quantité ni sur le rayon ; pas de fusion entre lignes après une saisie ; pas de migration de schéma.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Créer | saisie « piles », aucun « piles » au catalogue | « Créer « piles » » proposé ; au tap : article « Piles » (Divers, sans unité, `normalized_name = piles`) et ligne sans quantité sous Divers, dans une transaction | snackbar `ajoutImpossible` |
| Correspondance exacte | saisie « LAIT » ou « lait » | résultat Lait, pas de « Créer » | — |
| Sans correspondance exacte | saisie « lai » | résultats (Lait…) puis, en dernier, « Créer « lai » » | — |
| Aucun résultat | saisie « zzz » | une seule ligne « Créer « zzz » » | — |
| Nom déjà pris | `createArticle(« Lait »)` alors que Lait est actif | aucun nouvel article ; l'article existant est rendu | — |
| Rayon d'un article créé | Piles créé, tap sur Entretien | ligne et article passent en Entretien | snackbar `modificationImpossible` |
| Rayon d'un article existant | Lait ajouté, tap sur Épicerie salée | seule la ligne change, l'article reste en Crèmerie | snackbar `modificationImpossible` |
| Quantité | Œufs (pièce) ajouté, saisie 6 | la contribution `ajout` passe à `6000` `piece`, la ligne à `unit = piece`, `manual_at` nul ; la Liste lit « 6 pièces » | snackbar `modificationImpossible` |
| Quantité vidée | Œufs 6 pièces, champ vidé | contribution et ligne sans quantité ni unité | — |
| Article sans unité | Piles (sans unité) ajouté | pas de Champ quantité, seulement le Choix de rayon | — |

</intent-contract>

## Code Map

- `lib/features/catalogue/data/catalogue_repository.dart` -- `CatalogueRepository(this._db)` (sans horloge aujourd'hui), `CatalogueArticle`, `_toModel`, `watchSearch(query)` (contient, `normalizeName`, préfixe d'abord), `watchFrequents()` : ajouter `createArticle(name)` et `setArticleRayon(articleId, rayon)` ; injecter `Clock` (`clockProvider`) pour `updated_at`.
- `lib/features/catalogue/data/normalize_name.dart` -- `normalizeName` (seule normalisation, AD-17). `lib/core/db/tables/articles.dart` -- `name`, `normalizedName`, `rayon`, `unit` (nullable), `pictoKey` (kebab-case, AD-18).
- `lib/features/catalogue/state/catalogue_providers.dart` -- `catalogueRepositoryProvider`, `articleSearchProvider`, `frequentsProvider`.
- `lib/features/liste/data/liste_repository.dart` -- `addArticle(articleId, {quantity, unit})` (rend `void`) et `_contribute` : faire rendre l'id de la contribution `ajout` ; ajouter `setAddedQuantity(contributionId, int? quantity)` ; `setRayon(lineId, rayon)` existe (story 6).
- `lib/features/liste/ui/add_sheet.dart` -- `showAddSheet` + `PanelUndo`, `AddSheet` (`_toggle`, `_add`, `_remove`, `_pending`, messager propre au panneau), `FrequentRow`, `SearchResultRow`, `InListIndicator` : y ajouter la ligne « Créer », la ligne dépliée après ajout et l'appel aux actions.
- `lib/core/ui/quantity_field.dart` -- `QuantityField(controller, unit, focusNode, onChanged, onSubmitted)`, `quantityFieldText`, `quantityFromFieldText` (pièces entières ×1000). `lib/core/ui/rayon_picker.dart` -- `RayonPicker(selected, onSelected)`.
- `lib/features/liste/ui/item_edit_sheet.dart` -- modèle d'écriture d'une quantité à la validation et à la fermeture, une seule fois.
- `lib/app/actions/terminer_les_courses.dart` -- modèle d'action transverse en une transaction et de provider.
- `lib/core/pictos/picto.dart` -- `Picto` (repli neutre pour toute clé).
- Tests : `test/features/catalogue/catalogue_test.dart`, `test/features/liste/liste_repository_test.dart`, `test/features/liste/add_sheet_test.dart` (panneau, vue 800×3000), `test/app/terminer_les_courses_test.dart` (modèle d'action), `test/helpers/test_db.dart` (`SeedIds.oeufs` en pièce, `lait`).

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/strings/strings_fr.dart` -- `creer(saisie)` « Créer « piles » » (guillemets français, espaces insécables) -- Voice and Tone.
- [x] `lib/features/catalogue/data/catalogue_repository.dart` -- `createArticle(String name) → CatalogueArticle` (à appeler dans une transaction ; rend l'article actif de même nom normalisé s'il existe), `setArticleRayon(articleId, Rayon)`, `hasExactMatch` ou équivalent pour la recherche -- AD-17.
- [x] `lib/features/catalogue/state/catalogue_providers.dart` -- passer `clockProvider` au repository -- AD-7.
- [x] `lib/features/liste/data/liste_repository.dart` -- `addArticle` rend l'id de la contribution ; `setAddedQuantity(contributionId, int? quantity)` (Design Notes) -- AD-4, AD-6.
- [x] `lib/app/actions/ajout_panneau.dart` -- `CreerEtAjouter(name)` (crée puis ajoute, une transaction) et `PlacerLigneAjoutee(lineId, articleId, rayon, {articleCree})` (ligne, plus article si créé, une transaction), avec providers -- AD-3.
- [x] `lib/features/liste/ui/add_sheet.dart` -- ligne « Créer « … » » (signe + neutre, dernière ligne des résultats, seule sans résultat), ligne dépliée après un ajout (Champ quantité si l'article a une unité, Choix de rayon), écriture de la quantité -- R3, R8, R11, R12.
- [x] `test/features/catalogue/catalogue_test.dart` -- lignes Correspondance exacte, Nom déjà pris, création (nom, normalisé, Divers, sans unité, clé de picto) -- AD-17.
- [x] `test/features/liste/liste_repository_test.dart` -- lignes Quantité, Quantité vidée -- AD-4.
- [x] `test/app/ajout_panneau_test.dart` -- lignes Créer, Rayon d'un article créé, Rayon d'un article existant -- AD-3.
- [x] `test/features/liste/add_sheet_test.dart` -- tests de widget des critères ci-dessous et des lignes Sans correspondance exacte, Aucun résultat, Article sans unité -- vérification du ticket.

**Acceptance Criteria:**
- Given le Panneau + ouvert, when Antoine tape « piles », then une seule ligne « Créer « piles » » s'affiche ; when il la touche puis touche Entretien dans le Choix de rayon, then la Liste montre Piles sous Entretien et le catalogue contient Piles en Entretien.
- Given Lait au catalogue, when il tape « lait » puis « LAIT », then aucune ligne « Créer » n'apparaît ; toucher le résultat ajoute Lait et ne crée aucun article.
- Given le Panneau + ouvert, when il touche Œufs dans les fréquents, then sa ligne se déplie avec le Champ quantité (suffixe pièces, vide) et le Choix de rayon (Crèmerie entouré) ; when il saisit 6 et valide, then la Liste montre « Œufs » avec « 6 pièces ».
- Given une ligne dépliée, when il ajoute un autre article, then la première se replie et sa quantité saisie est écrite ; when il ferme le panneau, then la quantité en cours est écrite.
- Given TalkBack, then « Créer « piles » » est annoncé comme bouton, le Champ quantité est annoncé « Quantité » et les pastilles du Choix de rayon par leur nom lu.

## Implementation Notes

- `addArticle` rend `({lineId, contributionId})` (typedef `AddedContribution`) et non l'id seul : le Choix de rayon a besoin de la ligne, et la lire après coup coûterait une requête.
- `CatalogueRepository.findByName(name)` (article actif de même nom normalisé) sert `createArticle` et `CreerEtAjouter`, qui en déduit `articleCree` : un nom déjà pris n'est jamais traité comme créé, donc son rayon d'article ne change pas.
- Correspondance exacte : `CatalogueRepository.hasExactMatch(hits, query)` sur les résultats de `watchSearch` ; « Créer » n'est proposé que sur les résultats de la saisie courante (jamais sur les derniers résultats gardés pendant la frappe).
- Les écritures de `setRayon` et `addArticle` ouvrent leur propre transaction ; appelées dans celle d'une action, drift en fait une transaction imbriquée (savepoint) : un échec annule tout (testé).
- Le contenu fourni contient déjà « Piles » (Divers, pièce) : les tests du scénario Créer suppriment cet article d'abord pour poser « aucun « piles » au catalogue ». Sur le téléphone, « piles » trouve donc l'article fourni, sans « Créer ».
- Revue : tout retrait replie la ligne dépliée et attend l'écriture de sa quantité avant `removeArticle` (sinon l'écriture à la fermeture vidait l'Annuler du retrait) ; le panneau garde les ids créés, pour qu'un article créé puis retiré et rajouté reste `articleCree` ; `createArticle(name, {rayon = divers, unit})` (AD-17).
- Erreur d'une écriture faite à la fermeture du panneau : snackbar sous le messager de la Liste (`listMessenger`).

## Plan Change Log

## Review Triage Log

### 2026-10-29 — Review pass
- verdicts: 5 findings — high 0, medium 0, low 4, false 0, maybe-false 0 (1 rejetée sur le plan, sans verdict de code)
- findings:
  - `[low]` `[patch]` Une quantité saisie sans validation, puis le retrait d'un autre article, puis la fermeture : l'écriture de la quantité à la fermeture rend sans effet (ou supprime) l'Annuler remontré sur la Liste — corrigé : `_remove` replie et écrit la quantité en attente avant `removeArticle` ; test ajouté.
  - `[low]` `[patch]` Un article créé dans le panneau, retiré puis rajouté, ne déplaçait plus son rayon de catalogue — corrigé : ensemble `_created` des articles créés dans le panneau, `articleCree` en découle ; test ajouté.
  - `[low]` `[reject]` « Créer » et un tap sur un résultat peuvent tourner en parallèle et laisser déplié l'ajout fini en dernier — demande deux taps pendant une écriture locale de quelques millisecondes ; la garde ajouterait un verrou commun aux deux chemins.
  - `[low]` `[patch]` `createArticle(name)` plus étroit qu'AD-17 (`createArticle(nom, rayon = divers, unité = sans)`) — paramètres nommés facultatifs `rayon` et `unit` ajoutés ; test ajouté.
  - `[false]` `[reject]` Le critère 1 (« piles ») ne se voit pas sur le téléphone, le contenu fourni ayant déjà Piles — vrai pour l'exemple du ticket, mais le code suit la règle ; la correction serait d'éditer le plan. Pour le test d'Antoine : « Bougies », absent du catalogue fourni.

## Design Notes

`setAddedQuantity(contributionId, int? quantity)` : dans une transaction, la contribution active `ajout` et sa ligne active ; 0 → sans quantité ; unité = unité par défaut de l'article (pièces ×1000 déjà appliqué par `quantityFromFieldText`) ; met à jour la contribution (`quantity`, `unit`, `updated_at`) et la ligne (`unit`, `updated_at`) ; quantité non nulle sans unité d'article → `ArgumentError`. Le tap qui ajoute ne passe que par un article hors liste : la ligne est neuve et cette contribution y est seule. Si la ligne porte d'autres contributions actives (cas non atteignable depuis le panneau), lever `StateError` sans rien écrire. Valeur inchangée → rien.

Ligne dépliée : l'état du panneau garde `{articleId, lineId, contributionId, articleCree}` du dernier ajout ; la ligne de cet article (fréquent, résultat ou article créé, affiché comme résultat) montre, sous elle, `QuantityField` (unité par défaut de l'article ; absent sans unité) et `RayonPicker` (rayon actuel de la ligne). La quantité s'écrit à la validation du clavier, au repli (autre ajout, retrait de cet article) et à la fermeture du panneau, une seule fois et seulement si la saisie a changé. Retirer l'article (nouveau tap) replie la ligne.

Créer : le nom proposé est la saisie telle que tapée (`Créer « piles »`) ; l'article créé prend le nom nettoyé avec majuscule initiale, `rayon = divers`, `unit` nulle, `picto_key` = nom normalisé réduit à `[a-z0-9]` (`article` si vide), id UUID v4. Après création, la saisie reste et le résultat Piles apparaît, déplié.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous les tests passent, dont les 196 existants avant la story

## Auto Run Result

Status: built

- **Résumé :** sans correspondance exacte (nom normalisé, AD-17), la recherche du Panneau + finit par « Créer « … » » (seule ligne sans résultat), qui crée l'article (majuscule initiale, Divers, sans unité) et l'ajoute en une transaction. Après tout ajout (fréquent, résultat, création), la ligne se déplie : Champ quantité dans l'unité par défaut de l'article (absent sans unité), qui complète la contribution `ajout` sans rendre la ligne manuelle, et Choix de rayon, qui place la ligne et, pour un article créé dans le panneau, devient son rayon de catalogue.
- **Fichiers :**
  - `lib/features/catalogue/data/catalogue_repository.dart`, `state/catalogue_providers.dart` — `createArticle(nom, {rayon, unit})`, `setArticleRayon`, `hasExactMatch`, `findByName`, horloge injectée.
  - `lib/features/liste/data/liste_repository.dart` — `addArticle` rend `(lineId, contributionId)`, `setAddedQuantity`.
  - `lib/app/actions/ajout_panneau.dart` — `CreerEtAjouter`, `PlacerLigneAjoutee`.
  - `lib/features/liste/ui/add_sheet.dart` — ligne « Créer », ligne dépliée, écritures et snackbars.
  - `lib/core/strings/strings_fr.dart` — `creer(saisie)`.
  - Tests : `test/features/catalogue/catalogue_test.dart`, `test/features/liste/liste_repository_test.dart`, `test/app/ajout_panneau_test.dart` (nouveau), `test/features/liste/add_sheet_test.dart`.
- **Revue :** 3 corrections appliquées (low), 0 reporté, 2 rejetés (taps parallèles en quelques millisecondes ; exemple « piles » du ticket déjà au catalogue) — raisons dans le Review Triage Log.
- **Revue de suivi recommandée :** non — aucune correction high ni medium.
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 236/236 après corrections.
- **Risques résiduels :** l'exemple « piles » du ticket est déjà au catalogue fourni (tester avec « Bougies ») ; un article créé n'a pas d'unité, donc pas de Champ quantité [ASSUMPTION à valider par Antoine] ; clavier et repli de la ligne non vérifiés sur téléphone.
