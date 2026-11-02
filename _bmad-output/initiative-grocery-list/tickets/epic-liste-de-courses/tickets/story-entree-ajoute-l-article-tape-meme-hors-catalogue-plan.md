---
title: 'Entrée ajoute l''article tapé, même hors catalogue'
type: 'feature'
ticket: '10'
created: '2026-10-30'
status: done
baseline_revision: '904eadf448bdde560a1baadd64d6b011c371e7e9'
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
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Au Panneau +, ajouter un article qu'on écrit demande de trouver un résultat ou de toucher « Créer « … » », qui grossit le catalogue de doublons d'orthographe. Antoine veut taper un mot, appuyer sur Entrée, et que ce soit dans la liste.

**Approach:** Un article porte `in_catalogue` (migration v2). Entrée passe par une seule `resolveTypedArticle` : l'article actif de ce nom normalisé, sinon un article hors catalogue (Divers, sans unité), invisible de la recherche. Le champ devient « Ajouter un article » ; l'article ajouté s'affiche sous le champ (Ligne saisie).

## Boundaries & Constraints

**Always:** AD-1 à AD-18 du spine (AD-4, AD-8, AD-14, AD-17 amendés le 2026-10-30) ; Material par `package:material_ui/material_ui.dart` ; textes dans `strings_fr.dart` ; écriture par le repository propriétaire, actions transverses dans `lib/app/actions/` en une transaction ; TalkBack et taille de police système ; tests unitaires, de widgets et de migration.

**Never:** pas de Feuille d'édition ni de crayon (story 11) ; pas de changement de la section fréquents ni des en-têtes (story 12) ; le dépliage quantité/rayon après un tap sur un résultat ou un fréquent reste tel quel (story 11 le remplace) ; Entrée ne retire jamais, n'ajoute jamais deux fois ; aucune création au catalogue depuis le Panneau +.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Texte inconnu | « piles » + Entrée | Article hors catalogue « Piles » (Divers, sans unité) créé et ajouté ; champ vidé, clavier ouvert ; Ligne saisie « Piles » + coche sous le champ | Échec : snackbar `ajoutImpossible`, rien écrit, saisie gardée |
| Nom du catalogue | « LAIT » + Entrée | Le Lait du catalogue ajouté sous Crèmerie, aucun article créé | idem |
| Déjà dans la liste | « piles » + Entrée, Piles non coché dans la liste | Rien écrit ; champ vidé ; Ligne saisie « Piles » | — |
| Texte libre réutilisé | « piles » hors catalogue existe, plus dans la liste | Même article réutilisé (pas de second « Piles ») | — |
| Recherche | « pil » | Piles hors catalogue jamais dans les résultats | — |
| Sans résultat | « zzz » tapé, aucun résultat | Une seule ligne « Ajouter « zzz » » ; tap = comme Entrée | — |
| Vide | « » ou espaces + Entrée | Rien | — |
| Ligne saisie, tap | Piles dans la liste | Retiré + snackbar Annuler ; la ligne disparaît ; Annuler la fait revenir | Échec : `suppressionImpossible` |
| Seed | article fourni nommé comme un article hors catalogue | Article fourni inséré ; lignes de l'article hors catalogue reportées sur lui ; article hors catalogue supprimé logiquement | transaction du chargeur |
| Catalogue | `createArticle('piles')` alors que Piles est hors catalogue | Piles passe `in_catalogue = vrai`, même id | — |

</intent-contract>

## Code Map

- `lib/core/db/tables/articles.dart` -- ajouter `BoolColumn get inCatalogue => boolean().withDefault(const Constant(true))()` (commentaire AD-17).
- `lib/core/db/app_database.dart:34` -- `schemaVersion` 1 → 2 ; `onUpgrade` pas à pas (`stepByStep` généré par `make-migrations`) : `from1To2` = `addColumn(articles, articles.inCatalogue)`. Puis `dart run build_runner build --delete-conflicting-outputs` et `dart run drift_dev make-migrations` (build.yaml : `schema_dir: drift_schemas/`, `test_dir: test/drift/`) → `drift_schemas/app_database/drift_schema_v2.json`, `test/drift/app_database/generated/schema_v2.dart`.
- `test/drift/app_database/migration_test.dart` -- ajouter le test v1 → v2 (données conservées, `in_catalogue` vrai pour l'existant).
- `lib/features/catalogue/data/catalogue_repository.dart` -- `watchSearch` : filtre `inCatalogue` ; nouvelle `resolveTypedArticle(String name)` (dans une transaction ; `findByName` puis insert `inCatalogue: false`, Divers, sans unité, nom par `cleanName`, `picto_key` comme `createArticle`) ; `createArticle` : si `findByName` trouve un article hors catalogue, le passer `in_catalogue = vrai` (`updated_at` par l'horloge) et le rendre ; `hasExactMatch` devient inutile : le retirer et ses tests.
- `lib/core/db/seed/seed_loader.dart:76` `_insertArticles` -- aujourd'hui saute un article fourni dont le nom est pris ; si le nom est pris par un article actif hors catalogue : insérer le fourni, reporter `list_lines.article_id` de l'ancien vers le fourni, supprimer logiquement l'ancien (horloge). Le seed ne doit pas importer `features/` (règle d'imports) : écrire directement sur les tables dans `core/db/seed`, comme il le fait déjà.
- `lib/app/actions/ajout_panneau.dart` -- remplacer `CreerEtAjouter` par `AjouterTexte` : transaction { `resolveTypedArticle` ; s'il a une ligne active non cochée → ne rien écrire ; sinon `ListeRepository.addArticle` } ; rend `(CatalogueArticle article, bool ajoute)`. `ArticleAjoute.articleCree` et le paramètre `articleCree` de `PlacerLigneAjoutee` disparaissent (le rayon ne change que la ligne).
- `lib/features/liste/data/liste_repository.dart` -- `addArticle`, `watchInListArticleIds` réutilisés tels quels ; ajouter si besoin une lecture « a une ligne active non cochée » pour l'action.
- `lib/features/liste/ui/add_sheet.dart` -- champ : `hintText: StringsFr.ajouterUnArticle`, `prefixIcon: Icon(Icons.add)`, `textInputAction: TextInputAction.done`, `onSubmitted` → `_addTyped`, `onEditingComplete: () {}` pour garder le clavier ; `_saisie` (dernier article d'Entrée) affiché sous le champ par `FrequentRow` (tap = `_toggle`) tant qu'il est dans `inListProvider` ; « Ajouter « … » » quand la saisie a reçu ses résultats et qu'ils sont vides ; retirer `_create`, `_created`, `_creating` (garder une garde anti double Entrée).
- `lib/features/liste/ui/add_sheet_rows.dart` -- `CreateArticleRow` devient `AddTypedRow` (même dessin, libellé `StringsFr.ajouterNom(name)`).
- `lib/core/strings/strings_fr.dart` -- `rechercherUnArticle` → `ajouterUnArticle = 'Ajouter un article'` (existe peut-être déjà pour le FAB : réutiliser) ; `creer` → `ajouterNom(s) => 'Ajouter « $s »'`.
- Tests touchés : `test/app/ajout_panneau_test.dart`, `test/app/app_test.dart:49`, `test/features/catalogue/catalogue_test.dart`, `test/features/liste/add_sheet_test.dart` (`_create`, `creer`), `test/core/seed_loader_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/db/tables/articles.dart`, `lib/core/db/app_database.dart`, `drift_schemas/`, `test/drift/` -- colonne, v2, migration et son test -- AD-14.
- [x] `lib/features/catalogue/data/catalogue_repository.dart` + tests -- recherche filtrée, `resolveTypedArticle`, promotion par `createArticle`, retrait de `hasExactMatch` -- AD-17.
- [x] `lib/core/db/seed/seed_loader.dart` + test -- réconciliation avec un article hors catalogue -- AD-8.
- [x] `lib/app/actions/ajout_panneau.dart` + test -- `AjouterTexte`, sans `articleCree` -- R25, AD-3.
- [x] `lib/features/liste/ui/add_sheet.dart`, `add_sheet_rows.dart`, `lib/core/strings/strings_fr.dart` + tests de widgets -- Champ d'ajout, Entrée, Ligne saisie, « Ajouter « … » » -- R25, R17, R23.

**Acceptance Criteria:**
- Given le Panneau + ouvert, when Antoine tape « piles » puis Entrée, then Piles apparaît sous Divers dans la Liste, le champ est vide, le clavier ouvert et « Piles » s'affiche sous le champ avec sa coche ; une recherche « pil » ne le montre pas.
- Given Piles déjà dans la liste, when « piles » + Entrée, then la liste ne change pas.
- Given le Panneau +, when TalkBack lit le champ et la Ligne saisie, then il annonce « Ajouter un article » et « Piles, dans la liste ».
- Given une base v1 avec des articles et une liste, when l'app migre en v2, then tout est conservé et ces articles restent dans la recherche.

## Implementation Notes

- `PlacerLigneAjoutee` perd aussi `articleId` et sa dépendance au catalogue : `call(lineId, rayon)` ne change que la ligne.
- `ListeRepository.isInList(articleId)` ajouté pour `AjouterTexte` ; `AjouterTexte` rend le record `({CatalogueArticle article, bool ajoute})`.
- `SeedLoader` reçoit l'horloge (`clock:`) pour la réconciliation ; toutes les lignes de l'article hors catalogue (cochées et supprimées comprises) sont reportées sur l'article fourni.
- `createArticle` sur un nom hors catalogue : seuls `in_catalogue` et `updated_at` changent ; rayon et unité de l'article restent.
- Champ d'ajout lu par TalkBack : le texte indicatif sort en `label` « Ajouter un article » du nœud champ de texte.

## Plan Change Log

## Review Triage Log

### 2026-10-30 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` Un article hors catalogue reçoit une `picto_key` tirée du texte (« piles ») : un futur pack de pictos lui donnerait un vrai picto, contre EXPERIENCE (repli neutre pour une ligne libre) — corrigé dans `_insert` : hors catalogue, `picto_key` = `article` (repli) ; test ajusté. Appliqué par l'orchestrateur (correction d'une ligne).
  - `[low]` `[patch]` Le × du Champ d'ajout reste lu « Effacer la recherche » — renommé `effacerLeTexte` = « Effacer le texte » (code, test) ; commentaire « Champ de recherche » corrigé dans `add_sheet.dart`.
  - `[false]` `[reject]` La réconciliation du seed ne reporte que `list_lines` — aucune autre table ne référence aujourd'hui un article hors catalogue (pas de fréquent possible, `recipe_ingredients` n'existe pas) ; rien ne se perd. L'epic 2 ajoutera sa table à `_replace`.

## Design Notes

L'article hors catalogue évite deux identités de ligne (AD-17) : toute la fusion d'AD-4, `inListProvider`, Annuler et l'export marchent sans changement. La Ligne saisie réutilise `FrequentRow` : même dessin, même règle de tap, picto de repli pour un article hors catalogue. [ASSUMPTION] la Ligne saisie disparaît dès que son article n'est plus dans la liste (retrait, coche dans la Liste) et revient si Annuler le remet.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème
- `flutter test` -- expected: tous verts, dont le test de migration v1 → v2
- `dart run drift_dev make-migrations` -- expected: rien à régénérer après le commit

## Auto Run Result

Status: built

- **Visible sur le téléphone :** au Panneau +, le champ « Ajouter un article » ; Entrée ajoute le texte tapé (Piles sous Divers, sans entrer au catalogue ; « lait » ajoute le Lait du catalogue) ; champ vidé, clavier ouvert, « Piles » + coche sous le champ ; sans résultat, une ligne « Ajouter « … » » ; plus de « Créer « … » ».
- **Fichiers :** `lib/core/db/tables/articles.dart`, `app_database.dart`, `app_database.steps.dart` (v2) ; `drift_schemas/…v2.json`, `test/drift/…` ; `catalogue_repository.dart` (recherche filtrée, `resolveTypedArticle`, promotion) ; `seed_loader.dart` (+ `startup.dart`, `test_db.dart`) ; `ajout_panneau.dart` (`AjouterTexte`) ; `liste_repository.dart` (`isInList`) ; `add_sheet.dart`, `add_sheet_rows.dart`, `strings_fr.dart` ; tests.
- **Revue :** 2 corrections (low), 0 reporté, 1 rejeté (faux) — voir Review Triage Log.
- **Revue de suivi recommandée :** non (aucun high, aucun medium corrigé).
- **Vérification :** `flutter analyze` sans problème ; `flutter test` 253/253, dont la migration v1 → v2 ; `make-migrations` sans changement.
- **Risques résiduels :** clavier gardé ouvert après Entrée vérifié en test de widget seulement ; à voir au test de fin d'epic.
