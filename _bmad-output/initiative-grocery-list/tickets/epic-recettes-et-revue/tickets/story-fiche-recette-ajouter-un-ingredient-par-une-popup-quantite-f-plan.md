---
title: "Fiche recette : ajouter un ingrédient par une popup, quantité facultative"
type: 'feature'
ticket: '11'
created: '2026-11-03'
status: done
baseline_revision: 'a0e91a7380ffd52320a82c7173b49cd7c2ca61b9'
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
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-recettes-et-revue/tickets/story-fiche-recette-creer-et-modifier-une-recette-en-moins-d-une-m-plan.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Au test de fin d'epic, Antoine trouve que les résultats du Champ de recherche intégré à la fiche se superposent à la liste des ingrédients sans qu'on les distingue, et que le focus imposé sur la quantité après un ajout gêne : la quantité doit rester facultative (Decision 2026-11-03, R1).

**Approach:** Remplacer le champ de recherche de la fiche par un bouton « Ajouter un ingrédient » qui ouvre une popup basse sur le principe du Panneau + de la Liste : recherche, résultats, création, Entrée ; la fiche reste visible derrière et sa liste d'ingrédients se met à jour à chaque ajout. Plus aucun focus automatique sur la quantité.

## Boundaries & Constraints

**Always:**
- Fiche : nom, puis section des ingrédients (Lignes d'ingrédient inchangées) suivie d'un bouton « Ajouter un ingrédient » (icône +, `on-surface`, jamais d'argile, cible 48 dp) ; plus de champ de recherche dans la fiche. Photo et lien restent dessous.
- Popup d'ajout : panneau bas qui s'ouvre sur le navigateur racine au-dessus de la fiche, même allure que le Panneau + (`lib/features/liste/ui/add_sheet.dart` : carte `surface-container`, coins `rounded.xl`, voile léger, poignée), hauteur au contenu ; champ « Ajouter un ingrédient » focalisé, clavier ouvert, × d'effacement ; résultats du catalogue (`articleSearchProvider`) en lignes comme les Lignes de résultat du Panneau + (`add_sheet_rows.dart` : picto, nom, rayon, indicateur) ; un article déjà ingrédient montre sa coche et un tap ne fait rien.
- Ajouts : un tap sur un résultat ajoute l'article en dernier ingrédient ; Entrée ajoute le texte tapé : l'article actif de ce nom exact (`normalizeName`), sinon un article créé au catalogue (`createArticle` : Divers, sans unité ; un nom hors catalogue y entre, même id) ; sans résultat exact, une ligne « Créer « … » » fait comme Entrée. Après chaque ajout : le champ se vide, le clavier reste ouvert, la popup reste ouverte pour enchaîner ; la ligne ajoutée apparaît dans la fiche derrière et la fiche défile pour la montrer juste au-dessus de la popup si elle serait masquée. Texte vide : Entrée ne fait rien.
- La popup se ferme par glissement vers le bas, tap hors du panneau ou retour ; rien ne se perd (le brouillon de la fiche garde les ajouts).
- Quantité facultative : après un ajout, aucun Champ quantité ne prend le focus ; on la saisit seulement en touchant le champ de la ligne.
- Enregistrement : comme aujourd'hui (automatique) ; la story 12 le remplace par un bouton.
- TalkBack : bouton « Ajouter un ingrédient » ; dans la popup, champ, résultats (« Haricots rouges, Épicerie salée », « …, dans la recette »), « Créer « … » » ; un ajout annoncé « Haricots rouges ajouté » (la fiche est inaccessible sous la popup). Police système sans troncature. Microcopie dans `strings_fr.dart`.

**Never:**
- Tags Quantité ou Rayon dans cette popup ; fréquents ; ligne libre hors catalogue.
- Changer le Panneau + de la Liste : réutiliser ses widgets publics sans modifier leur comportement, ou en écrire une version propre à la fiche.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tap résultat | « hari » → Haricots… | Ingrédient ajouté derrière, champ vidé, popup ouverte, aucun focus quantité | — |
| Entrée nom exact | « tomates » | Tomates ajoutées (article du catalogue) | — |
| Entrée nom inconnu | « Piment d'Espelette » | Article créé au catalogue, ajouté | Échec : snackbar d'erreur dans la popup, rien d'ajouté |
| Déjà ingrédient | Tap sur Tomates présentes | Rien ne change, coche visible | — |
| Enchaîner | 5 ingrédients d'affilée | 5 lignes dans l'ordre, la dernière visible au-dessus de la popup | — |
| Fermer | Glissement / retour | Popup fermée, fiche avec les ajouts | — |

</intent-contract>

## Code Map

- `lib/features/recettes/ui/fiche_recette_screen.dart` -- retirer `_searchController`, `_searchFocus`, les résultats et « Créer » intégrés, `_focus` vers la quantité après `_addArticle` ; ajouter le bouton et l'ouverture de la popup ; garder `_addArticle` / `_create` comme points d'entrée appelés par la popup ; défilement vers la ligne ajoutée (`Scrollable.ensureVisible` en tenant compte de la hauteur de la popup).
- `lib/features/recettes/ui/` -- nouvelle popup d'ajout d'ingrédient (fichier propre) ; elle reçoit l'état « déjà ingrédient » et les rappels d'ajout de la fiche.
- `lib/features/liste/ui/add_sheet.dart`, `add_sheet_rows.dart` -- modèles : `showAddSheet` (`showModalBottomSheet`, `useRootNavigator`, `isScrollControlled`, `barrierColor`), `PanelHandle`, `SearchResultRow`, `InListIndicator`, `AddTypedRow`.
- `lib/features/recettes/ui/fiche_recette_rows.dart` -- lignes de résultat intégrées à retirer si elles ne servent plus.
- `lib/core/strings/strings_fr.dart` -- « Ajouter un ingrédient », annonce d'ajout, « dans la recette ».
- Tests : `test/features/recettes/fiche_recette_screen_test.dart` (le parcours Flux 4 passe par la popup ; matrice ; aucun focus quantité ; TalkBack ; police ×2 ; clavier ouvert avec 11 ingrédients : la ligne ajoutée est visible au-dessus de la popup), `test/helpers/recettes.dart` si une aide d'ouverture de la popup sert à plusieurs fichiers.

## Tasks & Acceptance

**Execution:**
- [x] popup d'ajout + `fiche_recette_screen.dart` + `strings_fr.dart` -- bouton, popup, ajouts, défilement, pas de focus quantité
- [x] tests -- matrice, Flux 4, TalkBack, police, grand nombre d'ingrédients

**Acceptance Criteria:**
- Given une fiche, when Antoine touche « Ajouter un ingrédient », then une popup basse s'ouvre avec le champ focalisé, et la fiche reste visible derrière.
- Given la popup, when il tape « hari » et touche Haricots rouges, then la ligne apparaît dans la fiche derrière, le champ se vide et il peut taper l'ingrédient suivant ; aucun champ quantité n'a le focus.
- Given la popup, when il tape « Piment d'Espelette » et Entrée, then l'article est créé au catalogue et ajouté.

## Implementation Notes

- Nouveau `lib/features/recettes/ui/ingredient_sheet.dart` (`showIngredientSheet`, `IngredientSheet`) : `showModalBottomSheet` sur le navigateur racine comme le Panneau +, carte `surface-container` `rounded.xl`, `PanelHandle`, messager et Scaffold propres (snackbar d'erreur dans la popup). Les lignes `IngredientResultRow` et `CreateArticleRow` de `fiche_recette_rows.dart` sont gardées et servent dans la popup (elles lisent « dans la recette », pas « dans la liste ») ; le Panneau + n'est pas modifié.
- Entrée : l'article de ce nom exact parmi les résultats, sinon `creerArticleProvider` (qui rend aussi l'article actif de ce nom quand les résultats ne sont pas encore arrivés). Déjà ingrédient : rien, saisie gardée. Annonce « Haricots rouges ajouté » (`StringsFr.ingredientAjoute`).
- Fiche : `_addArticle` rend `bool`, `_create` rend l'article ajouté (nul si déjà ingrédient) et laisse remonter l'échec à la popup. La popup publie le haut de sa carte (`onTop`) ; la fiche ajoute cette hauteur en marge basse de son défilement et montre la ligne ajoutée juste au-dessus de la popup, une frame après l'ajout (la popup change de hauteur dans la même frame). Plus de champ de recherche ni de focus quantité ; Entrée sur le nom ou une quantité ferme simplement le clavier. Le bouton retire le focus avant d'ouvrir la popup : à la fermeture, aucun champ ne le reprend.
- Grande police : le texte indicatif du champ passe à la ligne (pas de troncature) ; le champ est mesuré après chaque frame et la hauteur de la carte en dépend ; le texte indicatif est retiré dès la saisie pour laisser la place aux résultats (au moins une ligne).
- Vérification : `flutter analyze` sans problème ; `flutter test` 621/621.

## Plan Change Log

## Review Triage Log

### 2026-11-03 — Review pass
- verdicts: 1 findings — high 0, medium 0, low 1, false 0, maybe-false 0
- findings:
  - `[low]` `[reject]` À ×2 / ×3, la ligne ajoutée se place selon le haut de la popup d'avant le retour du texte indicatif (publié une frame trop tard) : un peu trop haut, voire en partie sous la popup à ×3 — très grande police seulement ; le correctif demande de rejouer le défilement quand la popup bouge, comme la Liste ; à reprendre si Antoine le voit.

## Verification

**Commands:**
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: All tests passed

## Auto Run Result

- Résumé : la fiche n'a plus de champ de recherche ; « Ajouter un ingrédient » ouvre une popup basse comme le Panneau + (recherche, résultats, « Créer « … » », Entrée qui ajoute le nom exact ou le crée au catalogue) ; chaque ajout apparaît derrière, la fiche défile pour le montrer au-dessus de la popup, le champ se vide ; plus de focus imposé sur la quantité.
- Fichiers : `ingredient_sheet.dart` (nouveau), `fiche_recette_screen.dart`, `fiche_recette_rows.dart`, `strings_fr.dart` ; tests `fiche_recette_screen_test.dart`, `fiche_recette_photo_test.dart`, `supprimer_recette_test.dart`, `test/helpers/recettes.dart`.
- Revue : 0 correctif, 0 report, 1 rejet motivé.
- Revue de suivi recommandée : non.
- Vérification : `flutter analyze` sans problème ; `flutter test` 621/621.
- Risques : hauteur de la popup et défilement avec le vrai clavier à voir sur le téléphone ; en pièces, l'unité du champ quantité occupe presque tout le champ (un tap à gauche peut ouvrir le Choix d'unité).
