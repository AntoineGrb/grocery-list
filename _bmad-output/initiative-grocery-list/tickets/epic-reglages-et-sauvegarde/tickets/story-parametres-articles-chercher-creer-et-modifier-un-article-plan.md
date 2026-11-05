---
title: 'Paramètres › Articles : chercher, créer et modifier un article'
type: 'feature'
ticket: '6'
created: '2026-11-05'
status: 'built'
baseline_revision: '91728c2cafe51a5e34bc3d7442085e7009e8830a'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'quick'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md'
warnings: ['oversized']
deferred:
  - {summary: 'Panneau + en grande police : les tags passent sur deux rangées, le budget de hauteur n en compte qu une, un résultat unique peut disparaître (choix rejeté à la story des tags, à revoir)', severity: low}
---

<intent-contract>

## Intent

**Problem:** les articles créés par la Fiche recette arrivent au catalogue en Divers et sans unité, et rien ne permet de corriger le rayon, l'unité ou le nom d'un article, ni d'en créer un hors recette.

**Approach:** une ligne « Articles » des Paramètres pousse Paramètres › Articles : un Champ de recherche sur les articles du catalogue, un tap ouvre la Fiche article (feuille modale : nom, rayon par défaut, unité par défaut ; son Picto est affiché sans être modifiable, le choix du picto vient avec la story 5), enregistrée par le repository `catalogue`.

## Boundaries & Constraints

**Always:**
- Route poussée `/parametres/articles` (`AppRoutes`, `GoRoute` dans `lib/app/kadi_app.dart`), titre « Articles », flèche retour. Ligne « Articles » · « Ton catalogue d'articles » (chevron) juste sous « Parcours ».
- Champ de recherche (DESIGN `search-field` : loupe à gauche, × dès qu'il y a du texte, texte indicatif « Chercher un article », curseur `on-surface`) ; champ vide : tout le catalogue par ordre alphabétique (nom normalisé) ; avec texte : `watchSearch` (articles `in_catalogue` seulement, AD-17). Les articles hors catalogue n'apparaissent jamais.
- Ligne de résultat : Picto, nom, nom du rayon en `body-medium` `on-surface-variant` ; cible ≥ 48 dp ; lue « Tomates, Fruits et légumes ». Texte saisi sans article de ce nom normalisé exact au catalogue : une ligne « Créer « … » » en tête, qui ouvre la Fiche article préremplie du nom nettoyé (`CatalogueRepository.cleanName`).
- Fiche article : feuille modale M3 (DESIGN `article-sheet`, navigateur racine, AD-13), titre = nom de l'article ou « Nouvel article » ; champ Nom ; Picto de l'article affiché (non interactif ; repli neutre pour une création) ; « Rayon par défaut » par le Choix de rayon (`lib/core/ui/rayon_picker.dart`) ; « Unité par défaut » par puces de choix pièce · g · ml · sans (jamais kg ni L : AD-6), puce choisie en contour `on-surface` avec coche, jamais d'argile ; bouton « Enregistrer », actif dès que le nom n'est pas vide et qu'un champ a changé (création : nom non vide suffit). Fermer la feuille sans enregistrer n'écrit rien, sans confirmation.
- Écritures par le repository `catalogue`, en une transaction : nouvelle méthode de mise à jour (nom nettoyé et `normalized_name`, rayon, unité ; `picto_key` inchangée) ; création par `createArticle` puis les valeurs de la fiche (un nom porté par un article hors catalogue le fait entrer au catalogue, même id, avec les valeurs de la fiche). Nom dont le nom normalisé est porté par un autre article actif (au catalogue ou non) : refusé, message « Un article porte déjà ce nom. » sous le champ, rien d'écrit. Échec d'écriture : snackbar « Article impossible à enregistrer. ».
- Changer le rayon d'un article qui a un fréquent actif passe ce fréquent en dernier (`position` = max des positions actives + 1), dans la même transaction et par une seule méthode du repository `catalogue`, que la story 7 réutilisera (AD-17).
- Une modification vaut pour les ajouts suivants : lignes de liste et ingrédients existants inchangés (AD-15).
- TalkBack sur la recherche, les lignes et la fiche ; police système ×2 sans débordement (le nom passe à la ligne).

**Never:** choix ou modification du picto (story 5) ; suppression d'article ; affichage des articles hors catalogue ; kg ou L comme unité par défaut ; réécriture de lignes de liste ou d'ingrédients existants.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Recherche | « tom » | Tomates (et autres « tom… ») avec leur rayon | — |
| Modifier | Tomates → Épicerie salée, g, puis ajout Tomates par le Panneau + | nouvelle ligne en Épicerie salée ; la ligne Tomates déjà présente reste en Fruits et légumes ; ajouter Tomates comme ingrédient préchoisit g | — |
| Créer | « Piment » sans résultat exact → Créer → Enregistrer | article du catalogue « Piment », trouvé ensuite par le Panneau + et la Fiche recette | — |
| Hors catalogue | « Piles » tapé dans le Panneau + puis créé ici | même id, entre au catalogue avec les valeurs de la fiche | — |
| Nom pris | Lait renommé « tomates » | refusé, rien d'écrit | « Un article porte déjà ce nom. » |
| Fréquent | Lait (fréquent) passé en Boissons | rayon changé, fréquent en dernier | — |
| Fermer | fiche modifiée puis fermée | rien d'écrit | — |
| Échec | écriture qui lève | rien d'écrit | snackbar d'erreur |

</intent-contract>

## Code Map

- `lib/features/catalogue/data/catalogue_repository.dart` -- `createArticle` (création, entrée au catalogue d'un hors-catalogue), `_activeRowNamed`, `cleanName`, `normalizeName`, `setArticleRayon` (aujourd'hui sans appelant : à remplacer ou réutiliser par la méthode unique de mise à jour), `watchSearch` (l. ~298 : vide pour une requête vide ; ajouter un flux du catalogue entier), `watchFrequents` et la table `frequents.position`.
- `lib/features/catalogue/state/catalogue_providers.dart` -- providers de recherche (l. ~21).
- `lib/features/recettes/ui/ingredient_sheet.dart` -- exemple existant de recherche avec « Créer « … » » (logique d'exactitude par nom normalisé) ; s'en inspirer, ne pas le modifier.
- `lib/features/liste/ui/add_sheet_rows.dart` -- dessin des lignes à Picto ; `lib/core/pictos/picto.dart` -- `Picto`.
- `lib/core/ui/rayon_picker.dart`, `lib/core/units/unit.dart` -- Choix de rayon, unités (`Unit.g`, `Unit.ml`, `Unit.piece`, null = sans).
- `lib/features/reglages/ui/parametres_screen.dart` -- lignes de navigation existantes (Parcours) : y ajouter « Articles ».
- `lib/core/router/app_router.dart`, `lib/app/kadi_app.dart`, `lib/core/strings/strings_fr.dart` -- route et microcopie.
- Nouveaux : `lib/features/reglages/ui/articles_screen.dart`, `lib/features/reglages/ui/article_sheet.dart` (`reglages` peut dépendre de `catalogue`, pas de `liste` ni `recettes`).

## Tasks & Acceptance

**Execution:**
- [x] `lib/features/catalogue/data/catalogue_repository.dart`, `catalogue_providers.dart` -- mise à jour d'article, refus de nom pris, fréquent en dernier, flux du catalogue entier.
- [x] route, chaînes, ligne « Articles ».
- [x] `lib/features/reglages/ui/articles_screen.dart`, `article_sheet.dart` -- écran et fiche.
- [x] `test/features/catalogue/` -- tests du repository : chaque ligne de la matrice côté données.
- [x] `test/features/reglages/articles_screen_test.dart` -- chaque ligne de la matrice côté écran (app montée par `pumpKadi` pour Modifier et Créer, vérifiés jusque dans la Liste et la Fiche recette), TalkBack, police ×2.

**Acceptance Criteria:**
- Given Tomates en Fruits et légumes déjà dans la liste, when Antoine passe Tomates en Épicerie salée dans Articles puis l'ajoute de nouveau, then la nouvelle ligne est en Épicerie salée et l'ancienne n'a pas bougé.

## Implementation Notes

**Fichiers touchés.** `lib/features/catalogue/data/catalogue_repository.dart` (`ArticleNameTakenException`, `updateArticle`, `createCatalogueArticle`, `watchCatalogue`, `_update`, `_moveFrequentLast` ; `setArticleRayon` retiré), `lib/features/catalogue/state/catalogue_providers.dart` (`catalogueArticlesProvider`), `lib/core/router/app_router.dart` (`AppRoutes.articles`), `lib/app/kadi_app.dart` (`GoRoute`), `lib/core/strings/strings_fr.dart` (microcopie Articles), `lib/features/reglages/ui/parametres_screen.dart` (ligne « Articles » sous « Parcours »), nouveaux `lib/features/reglages/ui/articles_screen.dart` et `article_sheet.dart`, `test/features/catalogue/catalogue_test.dart` (nouveau groupe + test de `setArticleRayon` réécrit sur `updateArticle`), nouveau `test/features/reglages/articles_screen_test.dart`.

**Décisions.**
- Méthode unique de mise à jour : `updateArticle(id, name:, rayon:, unit:)` (valeurs complètes, transaction propre). Elle remplace `setArticleRayon` (sans appelant) : la story 7 l'appelle avec le nom et l'unité actuels et le nouveau rayon ; le passage du fréquent en dernier est dans la même transaction (`position` = max des positions actives + 1, même si le fréquent était déjà dernier). Aucune valeur changée : rien n'est écrit. Article absent ou supprimé : `StateError`.
- Création : `createCatalogueArticle(name, rayon:, unit:)`, une transaction : refus si un article **du catalogue** porte le nom ; sinon `createArticle`, puis `_update` avec les valeurs de la fiche (un hors-catalogue entre au catalogue, même id, et prend nom, rayon, unité de la fiche). Le refus vaut, à la modification, pour tout autre article actif, au catalogue ou non. Le hors-catalogue entré au catalogue garde sa `picto_key` de repli (`article`), conformément à « picto_key inchangée » ; le choix du picto vient avec la story 5.
- Fiche article : feuille modale du navigateur racine, poignée, hauteur au contenu (défilante en grande police). Puces d'unité propres à `reglages` (`DefaultUnitChoice`, pièce · g · ml · sans) : `UnitChoice` vit dans `liste`, que `reglages` ne peut pas importer. De même `ArticleLine` et `CreateArticleLine` sont propres à l'écran (`CreateArticleRow` vit dans `recettes`). Le Picto de la fiche suit le rayon choisi ; création : clé `article` (repli neutre).
- Échec d'écriture : la fiche reste ouverte, saisie gardée, snackbar « Article impossible à enregistrer. » dans un `ScaffoldMessenger` + `Scaffold` transparents posés sur la fiche (`Positioned.fill` sous `IgnorePointer`) : un snackbar du messager de l'écran serait caché sous la feuille. Nom pris : `errorText` sous le champ, plus une annonce TalkBack ; effacé à la frappe suivante.
- Ligne de résultat : nom puis rayon en dessous (`body-medium` `on-surface-variant`), ce qui évite tout débordement à ×2 ; la ligne « Créer « … » » montre le nom nettoyé (`cleanName`).
- « Enregistrer » compare le nom **nettoyé** au nom de l'article : « tomates » sur Tomates ne compte pas comme un changement.

**Surprises.**
- Une contribution sans quantité rejoint la ligne non cochée existante de l'article (AD-4) et un tap sur un article déjà dans la liste le retire : pour que « l'ajouter de nouveau » crée une nouvelle ligne (critère d'acceptation), les tests cochent d'abord la ligne Tomates existante.
- Tomates est déjà en g dans le contenu fourni : les tests passent Tomates en **ml** (et non g comme dans la matrice) pour que le préchoix de l'unité dans la Fiche recette prouve bien la modification.
- `test/features/catalogue/catalogue_test.dart` : le test « Échec » simule l'échec par un trigger SQLite qui lève sur `UPDATE frequents` (dernière étape) et vérifie que l'article n'a pas changé (transaction annulée).
- `dart format --set-exit-if-changed` signale deux fichiers non formatés hors de cette story (`lib/features/recettes/data/recettes_repository.dart`, `test/core/backup_import_test.dart`), laissés tels quels.

**Vérification.** `flutter analyze` : aucun problème. `grep -rn "Ã\|â€" lib test` : aucun résultat. Tests écrits, non lancés (lancés une fois après 3.6 à 3.8).

## Plan Change Log

## Review Triage Log

- 2026-11-05 — revue unique du lot 3.6 à 3.8 (tests et revue à la fin du lot, demande d'Antoine). Première passe : 788 tests passent, 2 échouent : glisser vers le bas du Parcours cassé par le drapeau `_dropping` du sweep (Flutter appelle onReorderItem avant onReorderEnd quand le dépôt précède l'animation) — corrigé dans le produit, deux tests ajoutés ; « Créer « Piment » » : test trop étroit en police de test (tags sur deux rangées), écran du test élargi, assertion inchangée. Revue de code : high 0, medium 0, low 3, reportés (deferred). Suite complète : 792 tests passent.

## Design Notes

- [ASSUMPTION] Champ vide = tout le catalogue par ordre alphabétique, pour parcourir ; aide « Ton catalogue d'articles », « Nouvel article », « Un article porte déjà ce nom. », fermeture sans confirmation : Antoine les valide au test de fin d'epic.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- Tests : écrits, lancés une seule fois à la fin des stories 3.6 à 3.8 (demande d'Antoine).
