---
title: 'Une recette exemple sélectionnée et validée arrive dans la Liste'
type: 'feature'
ticket: '1'
created: '2026-11-02'
status: done
baseline_revision: 'fbd1612a8bc408a72a0a1d1f1a3c4512b4ae608b'
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
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: ['oversized']
deferred:
  - summary: >-
      La Revue garde un instantané des articles ; si l'un est supprimé avant « Ajouter à la liste », l'ajout échoue à chaque essai.
    evidence: |-
      ListeRepository._contribute lève StateError sur un article absent ou supprimé ; la transaction de AjouterALaListe est alors annulée à chaque tap. Inatteignable tant qu'aucun écran ne supprime d'article (epic 3, import).
    location: >-
      lib/app/actions/ajouter_a_la_liste.dart
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Kadi n'a pas de recettes : l'onglet Recettes n'affiche qu'un message vide, et rien ne relie une recette à la liste en cours (epic 2, parcours traceur).

**Approach:** Migration v3 avec les trois tables de recettes, 4 recettes exemples fournies, Recettes en cartes sélectionnables, « Valider (n) », la Revue (lecture seule, tout coché) et l'action « Ajouter à la liste » qui écrit une contribution `week_selection` par ingrédient puis ouvre la Liste avec « Ta liste est prête. ».

## Boundaries & Constraints

**Always:**
- AD-1 à AD-19 : tables dans `lib/core/db/tables/` avec `SyncColumns` ; écriture par le seul propriétaire (`recettes` : `recipes`, `recipe_ingredients`, `week_selections` ; `liste` : lignes et contributions) ; action transverse dans `lib/app/actions/` en une transaction ; horloge pour tout `updated_at` ; lectures filtrées `deleted_at IS NULL`, parent supprimé = supprimé.
- Migration v3 non destructive, étape `from2To3` générée par `make-migrations`, dump `drift_schema_v3.json`, test de migration. Toutes les colonnes de l'epic dès v3 : `recipes` (name, link nullable, photo nullable = nom de fichier), `recipe_ingredients` (recipe_id, article_id, position, quantity et unit nulles ensemble), `week_selections` (recipe_id, validated_at nullable).
- Contenu fourni par le chargeur unique d'AD-8 : `assets/seed/recettes.json`, clé de version `recettes`, UUID définitifs (recettes et ingrédients), insertion des UUID absents seulement, `updated_at = 0`, une ligne supprimée compte comme présente.
- Toute microcopie dans `strings_fr.dart` ; Material par `material_ui` ; couleurs du thème seulement ; jamais d'argile hors Bouton d'action et FAB (C6).
- Accessibilité : carte annoncée « Chili, sélectionnée » / « Chili, non sélectionnée » ; En-tête de rayon titre ; Ligne de Revue « Lardons, 400 g, Viande et poisson, coché » ; police système sans troncature (cartes qui grandissent) ; cibles ≥ 48 dp.

**Never:**
- Décocher ou corriger une quantité en Revue (story 2), désélectionner une recette validée (story 3 : en story 1 un tap sur une carte validée ne fait rien), Nouvelle liste (story 4), Fiche recette, FAB + de Recettes et icône « modifier » (story 5), photo (story 6), ouverture sur Recettes et ligne d'accueil (story 7 : ne pas lever `first_launch`).
- `features/liste` qui importe `features/recettes` ; état d'écran persistant hors du brouillon de Revue.
- Une v4 du schéma plus tard dans l'epic : rien d'autre à ajouter aux tables.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Sélection | Tap sur une carte non sélectionnée | Nouvelle ligne `week_selections` active, carte cochée + bordure, « Valider (1) » | — |
| Désélection non validée | Tap sur une carte sélectionnée non validée | Sélection supprimée logiquement, plus de coche ; Valider disparaît à 0 | — |
| Carte validée | Tap sur une carte validée | Rien n'est écrit (story 3) | — |
| Fusion même unité | Carbonara (Lardons 200 g) + Quiche (Lardons 200 g) | Une Ligne de Revue « Lardons 400 g » | — |
| Deux unités | Même article en g dans l'une, en pièces dans l'autre | Deux Lignes de Revue | — |
| Sans quantité | Article sans quantité dans une recette, chiffré dans l'autre | Il rejoint la ligne chiffrée de l'article ; seul sans quantité : une ligne sans quantité | — |
| Ajouter à la liste | Revue de 2 recettes | Une contribution `week_selection` par ingrédient et par sélection (`week_selection_id`), fusionnée par AD-4 avec les lignes existantes ; `validated_at` posé sur ces sélections ; Liste ouverte, snackbar « Ta liste est prête. » ; « Valider » absent | Échec : rien n'est écrit, snackbar « Ajout impossible. Réessaie. », la Revue reste |
| Ligne cochée existante | « Lardons » déjà coché dans la liste | Nouvelle ligne non cochée (AD-4) | — |
| Seed | Fichier v1, recettes déjà présentes ou supprimées | Rien n'est réinséré ; ingrédient dont l'article n'existe pas sauté, recette sans ingrédient sautée | Fichier invalide : exception, écran d'erreur bloquant existant |
| Migration | Base v2 avec articles, lignes, contributions | Données intactes, 3 tables créées vides | — |

</intent-contract>

## Code Map

- `lib/core/db/app_database.dart` -- `schemaVersion` 2 → 3, `from2To3` (`m.createTable` × 3), tables à déclarer et exporter. Puis `dart run build_runner build --delete-conflicting-outputs` et `dart run drift_dev make-migrations` (build.yaml : `drift_schemas/`, `test/drift/`) régénèrent `app_database.g.dart`, `app_database.steps.dart`, `drift_schemas/app_database/drift_schema_v3.json`, `test/drift/app_database/generated/schema_v3.dart`.
- `lib/core/db/tables/` -- nouveaux `recipes.dart`, `recipe_ingredients.dart`, `week_selections.dart` sur le modèle de `list_lines.dart` (références `.references(...)`, entiers pour les dates, jamais `dateTime()`).
- `test/drift/app_database/migration_test.dart` -- modèle des tests v1 → v2 (`testWithDataIntegrity`) ; ajouter v3 conforme au dump, v2 → v3 et v1 → v3, avec lignes de liste conservées.
- `lib/core/db/seed/seed_loader.dart` -- ajouter `recettesFile = 'recettes'`, `recettesPath`, parse (UUID en double, recette sans nom → `FormatException` ; `unit` lu par `Unit.fromCode`, quantité et unité nulles ensemble), insertion après articles et fréquents ; aucune écriture de `first_launch`.
- `assets/seed/recettes.json` -- nouveau, `seed_version` 1 : Pâtes carbonara (Pâtes 500 g, Lardons 200 g, Œufs 3 pièces, Parmesan 60 g, Poivre sans quantité), Chili con carne (Viande hachée 500 g, Oignons 2, Tomates concassées 400 g, Poivrons 1, Riz 300 g), Quiche lorraine (Pâte feuilletée 1, Lardons 200 g, Œufs 3, Crème fraîche 200 ml, Emmental râpé 100 g), Ratatouille (Courgettes 400 g, Aubergines 2, Poivrons 2, Tomates 500 g, Oignons 1, Huile d'olive et Herbes de Provence sans quantité). Ids d'article pris dans `articles.json` par nom ; unité = unité de l'article ; quantités stockées (g, ml, millièmes de pièce : 3 pièces = 3000).
- `test/helpers/test_db.dart` -- `seedAssetPaths` + recettes ; ids figés des recettes utiles aux tests.
- `lib/features/liste/data/liste_repository.dart` -- `_contribute` prend `weekSelectionId` ; nouvelle méthode publique d'ajout de contribution de recette, à appeler dans la transaction de l'action (pas sa propre transaction). Ne rien changer d'autre.
- `lib/features/liste/state/` -- un avis de la Liste (ex. `listeNoticeProvider`) que `ListeScreen` écoute pour montrer un snackbar simple puis vider ; c'est `recettes` qui le lève (liste ne dépend pas de recettes).
- `lib/features/liste/ui/liste_screen.dart` -- écoute l'avis ; son `ScaffoldMessenger` propre affiche le snackbar.
- `lib/features/recettes/data/recettes_repository.dart` -- nouveau : cartes observées (id, nom, picto_key et rayon actuel de l'article du premier ingrédient par `position`, sinon repli Divers ; sélectionnée ; validée), triées par `normalizeName` du nom ; `select`, `deselect` (non validée seulement) ; lecture des ingrédients des sélections actives non validées ; marquage `validated_at` (dans la transaction de l'action).
- `lib/features/recettes/state/recettes_providers.dart` -- repository, flux des cartes, nombre à valider.
- `lib/features/recettes/` -- construction pure de la Revue : ingrédients → groupes par rayon actuel dans l'ordre du parcours (`settings.routeOrder`, réutiliser `groupByRayon` de `liste_providers.dart`), lignes par (article, unité), chaque ligne gardant ses contributions (sélection, quantité, unité).
- `lib/app/actions/ajouter_a_la_liste.dart` -- nouveau, modèle `terminer_les_courses.dart` : une transaction, contributions puis `validated_at` de toutes les sélections de la Revue.
- `lib/features/recettes/ui/recettes_screen.dart` -- grille 2 colonnes (rangées de deux cartes à hauteur égale, pas de ratio fixe : police système), Bouton d'action « Valider (n) » en `bottomNavigationBar` comme « Terminer les courses » de `liste_screen.dart` ; message d'état vide gardé sans recette.
- `lib/features/recettes/ui/` -- `recipe_card.dart` (DESIGN `recipe-card` : `surface-container`, `rounded.md`, visuel de repli Picto 44 dp sur `surface`, nom `title-medium` ; sélectionnée : bordure 2 dp `on-surface` et pastille 26 dp `on-surface` avec coche `surface` en haut à gauche) ; `revue_screen.dart` (titre « Revue », consigne « Décoche ce que tu as déjà. », `RayonHeader` de `features/liste/ui/rayon_header.dart`, Ligne de Revue : coche ronde cochée à l'accent du rayon comme `item_row.dart`, Picto 24 dp, nom, quantité exacte via `quantityFieldText` + suffixe d'unité ; Bouton d'action « Ajouter à la liste »).
- `lib/core/router/app_router.dart` -- `core` ne connaît pas les écrans : accepter des routes poussées fournies par `kadi_app.dart` (Revue hors de la coque, sans Barre de navigation, flèche retour). Après l'ajout : `go` vers la Liste, ce qui retire la Revue.
- `lib/core/pictos/picto.dart` -- `Picto(size: 44)` pour le repli de carte.
- `lib/core/strings/strings_fr.dart` -- Valider (n), Revue, consigne, Ajouter à la liste, Ta liste est prête., sélectionnée / non sélectionnée, coché.
- `test/helpers/pump_app.dart` -- l'app s'ouvre sur la Liste : les tests touchent l'onglet Recettes.

## Tasks & Acceptance

**Execution:**
- [ ] `lib/core/db/tables/*.dart`, `app_database.dart` + génération -- trois tables, v3 -- AD-2, AD-14
- [ ] `test/drift/app_database/migration_test.dart` -- v3 conforme, v2 → v3 et v1 → v3 avec données de liste intactes -- note de risque du ticket
- [ ] `assets/seed/recettes.json`, `seed_loader.dart`, `test_db.dart` -- recettes exemples -- AD-8
- [ ] `test/core/seed_loader_test.dart`, `test/core/seed_content_test.dart` -- insertion, idempotence, supprimée = présente, article absent sauté ; contenu : 4 recettes, articles existants, unité = unité de l'article
- [ ] `liste_repository.dart` + test -- contribution de recette avec `week_selection_id`
- [ ] `recettes_repository.dart`, construction de la Revue, providers + tests unitaires -- matrice (sélection, fusion, deux unités, sans quantité)
- [ ] `ajouter_a_la_liste.dart` + test -- contributions, `validated_at`, ligne cochée existante, échec sans écriture
- [ ] `app_router.dart`, `kadi_app.dart` -- route Revue poussée
- [ ] `recettes_screen.dart`, `recipe_card.dart`, `revue_screen.dart`, avis de la Liste, `strings_fr.dart` + tests de widgets -- parcours de bout en bout, TalkBack, grande police

**Acceptance Criteria:**
- Given l'app sur une base neuve, when Antoine touche l'onglet Recettes, then il voit les 4 recettes exemples en cartes sur 2 colonnes, chacune avec son nom et le picto de son premier ingrédient.
- Given Pâtes carbonara et Quiche lorraine sélectionnées, when il touche « Valider (2) », then la Revue montre leurs ingrédients groupés par rayon dans l'ordre du parcours, tous cochés, avec « Lardons 400 g » et « Œufs 6 pièces » sur une ligne chacun.
- Given cette Revue, when il touche « Ajouter à la liste », then la Liste s'affiche triée par rayon avec « Ta liste est prête. », et de retour sur Recettes les deux cartes restent sélectionnées sans bouton « Valider ».
- Given les deux recettes validées, when il sélectionne Ratatouille et valide, then la Revue ne montre que les ingrédients de la Ratatouille.
- Given TalkBack, when il parcourt Recettes et la Revue, then chaque carte est lue avec son état de sélection et chaque Ligne de Revue avec nom, quantité, rayon et « coché ».

## Implementation Notes

- Implémenté par un sous-agent sur la base fbd1612. Écarts au plan : `rayon_header.dart` laisse le nom de rayon passer à la ligne (débordement en très grande police, Revue et Liste) ; la Ligne de Revue est dans `revue_row.dart` ; « ordre des recettes » = ordre des cartes (nom normalisé) ; une nouvelle version du fichier de recettes ne complète jamais une recette existante ; « 1 pièce » au singulier. Un échec de sélection réutilise « Modification impossible. Réessaie. ».

## Plan Change Log

## Review Triage Log

### 2026-11-02 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 4, false 1, maybe-false 1
- findings:
  - `[false]` `[reject]` Quantité de Revue hors de `formatQuantity` (AD-6) — EXPERIENCE (Ligne de Revue) veut la valeur exacte dans l'unité de la ligne, l'arrondi de lecture ne valant que dans la Liste ; le texte vient de `quantityFieldText`, celui du Champ quantité que la story 2 rend éditable ; une fraction de pièce n'est pas saisissable (pièces sans décimale).
  - `[low]` `[reject]` Écran vide si la lecture de la Revue ou des cartes échoue — erreur d'une base locale improbable, même traitement que la Liste existante (`_ => SizedBox.shrink()`), le correctif ajoute des états d'erreur.
  - `[low]` `[reject]` Deux taps rapides sur une carte : le second est perdu — la carte reste dans l'état du premier tap, sans écriture fausse ; le garde-fou ajouterait un état en attente par carte.
  - `[low]` `[reject]` Case de Revue tappable sans effet — la décoche arrive avec la story 2, construite juste après.
  - `[low]` `[reject]` Pas de chaîne « coché » — `Semantics(checked: true)` donne l'état lu par TalkBack, comme la Ligne d'article de l'epic 1 validée par Antoine.
  - `[maybe-false]` `[defer]` Instantané de Revue avec un article supprimé : l'ajout échoue toujours — inatteignable aujourd'hui ; se tranche quand un écran supprime des articles (epic 3) ou à l'import.

## Design Notes

- Sélection (AD-16) : « sélectionnée » = une ligne `week_selections` active de la recette ; « validée » = son `validated_at` non nul. `select` n'insère rien s'il en existe déjà une. Une recette supprimée n'a pas de carte.
- Fusion en Revue, alignée sur AD-4 pour que la Revue montre ce que la Liste deviendra : par article, une ligne par unité stockée ; un ingrédient sans quantité rejoint la première ligne de l'article (ordre des recettes puis `position`), sinon une ligne sans quantité. Dans un rayon, ordre de première apparition. L'action n'additionne rien elle-même : elle écrit chaque contribution source et laisse `ListeRepository` fusionner (AD-4).
- La Revue lit les sélections à valider à son ouverture et garde cet instantané (brouillon d'écran, AD-1) ; « Ajouter à la liste » valide exactement ces sélections.
- Le tri des cartes par nom normalisé est une hypothèse : [ASSUMPTION] à valider par Antoine au test de fin d'epic.
- Un tap sur une carte validée ne fait rien jusqu'à la story 3, enchaînée juste après.

## Verification

**Commands:**
- `dart run build_runner build --delete-conflicting-outputs` puis `dart run drift_dev make-migrations` -- expected: v3 générée, relancé ensuite sans changement
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed, migrations v1 → v3 et v2 → v3 comprises

## Auto Run Result

- Résumé : migration v3 (recettes, ingrédients, sélections), 4 recettes exemples fournies, Recettes en cartes sélectionnables avec « Valider (n) », Revue en lecture seule groupée par rayon, action « Ajouter à la liste » (contributions `week_selection`, `validated_at`) et avis « Ta liste est prête. » sur la Liste.
- Fichiers : tables `recipes.dart`, `recipe_ingredients.dart`, `week_selections.dart` et `app_database.dart` (v3, générés) ; `seed_loader.dart` + `assets/seed/recettes.json` ; `liste_repository.dart` (contribution de recette), `liste_notice.dart`, `liste_screen.dart`, `rayon_header.dart` ; `features/recettes/` (repository, `revue.dart`, providers, `recettes_screen.dart`, `recipe_card.dart`, `revue_row.dart`, `revue_screen.dart`) ; `ajouter_a_la_liste.dart` ; `app_router.dart`, `kadi_app.dart`, `strings_fr.dart`, `kadi_tokens.dart` ; tests de migration, chargeur, contenu, repository, Revue, action et écrans.
- Revue : 0 correctif, 1 report (instantané et article supprimé), 5 rejets motivés au journal.
- Revue de suivi recommandée : non (aucun correctif).
- Vérification : `flutter analyze` sans problème ; `make-migrations` sans changement ; `flutter test` 461/461.
- Risques : un double tap rapide sur « Valider » peut ouvrir la Revue deux fois ; à voir au test de fin d'epic.
