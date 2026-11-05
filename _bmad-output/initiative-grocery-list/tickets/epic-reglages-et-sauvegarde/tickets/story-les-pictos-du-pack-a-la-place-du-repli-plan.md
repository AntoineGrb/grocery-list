---
title: 'Les pictos du pack à la place du repli'
type: 'feature'
ticket: '5'
created: '2026-11-05'
status: 'built'
baseline_revision: '4afc5a65b63dea21d1ed806347bb20492c02fdee'
route: 'full'
route_source: 'auto'
risk: 'medium'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-grocery-list/tickets/epic-reglages-et-sauvegarde/pictos-phosphor.json'
warnings: []
deferred:
  - {summary: 'Grille de pictos : TalkBack lit le nom anglais de l icône', severity: low}
  - {summary: 'Recherche de la grille par nom d article limitée aux clés de la correspondance', severity: low}
---

<intent-contract>

## Intent

**Problem:** tous les pictos de Kadi sont un rond neutre (`PictoResolver.assetFor` rend toujours `null`) ; Antoine a choisi le pack Phosphor et sa correspondance le 2026-11-05.

**Approach:** le résolveur unique de `lib/core/pictos/` (AD-18) traduit chaque `picto_key` en picto Phosphor selon `pictos-phosphor.json` (dossier de l'epic), avec un repli par rayon à la place du rond neutre ; la Fiche article gagne le choix du picto dans une grille avec recherche.

## Boundaries & Constraints

**Always:**
- Correspondance = `pictos-phosphor.json` exactement : `articles` (`picto_key` → nom d'icône Phosphor regular, ou `null` = repli), `rayons` (code de rayon → icône de repli). Elle est recopiée dans le code (table Dart générée ou asset JSON chargé une fois), jamais devinée.
- Rendu : paquet `phosphor_flutter` (MIT, police d'icônes, version épinglée exacte) si toutes les icônes de la correspondance et des replis y existent en style regular ; sinon les SVG regular de `@phosphor-icons/core` 2.1.1 en assets avec `flutter_svg` épinglé. Licence MIT du pack jointe (fichier `LICENSE` à côté des assets, ou mention dans `README.md`). Aucun réseau à l'exécution (C2).
- Teinte = accent du rayon (`KadiColors.of(context).rayon(r).accent`), 24 dp par défaut, 44 dp pour le repli de la Carte recette (taille déjà passée par `recipe_card.dart`). `Picto` reste non interactif et exclu de la sémantique.
- Repli : clé inconnue, `null`, `article`, ou article hors catalogue → picto de repli du rayon passé à `Picto`. Plus aucun rond neutre.
- Partout où `Picto` est déjà utilisé (Panneau +, Fiche recette, Carte recette, Paramètres › Articles et Fréquents) ; toujours absent de la Liste et de la Revue (C7).
- Fiche article (`lib/features/reglages/ui/article_sheet.dart`) : le Picto affiché devient un bouton (cible 48 dp, lu « Changer le picto ») qui ouvre une grille de pictos avec un Champ de recherche (texte indicatif « Chercher un picto », recherche sur le nom anglais de l'icône et sur les noms d'articles qui l'utilisent) ; choisir un picto l'affiche dans la fiche, et « Enregistrer » l'écrit dans `picto_key` par le repository `catalogue` (`updateArticle` gagne un paramètre `pictoKey` ; une `picto_key` choisie est le nom de l'icône, résolu tel quel). La grille propose au moins toutes les icônes de la correspondance et des replis, plus les icônes alimentation, cuisine, maison et hygiène du pack ; picto choisi marqué (contour `on-surface`, jamais d'argile). Fermer la grille sans choisir ne change rien.
- Une `picto_key` stockée qui n'est ni une clé de la correspondance ni un nom d'icône connu → repli du rayon.
- TalkBack et police ×2 sans débordement sur la grille.

**Never:** emoji ; picto dans la Liste ou la Revue ; mélange de packs ; migration de schéma (la colonne `picto_key` existe) ; modification de `assets/seed/articles.json`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Clé connue | `camembert` | icône `cheese`, accent Crèmerie | — |
| Clé à repli | `oignons` (null) | repli Fruits et légumes `leaf` | — |
| Corrections d'Antoine | `lait`, `jus-d-orange`, `lardons` | `jar`, `pint-glass`, repli `hamburger` | — |
| Article créé | « Kombucha » (`picto_key` dérivée inconnue), rayon Boissons | repli Boissons | — |
| Hors catalogue | ligne libre `article`, Divers | repli Divers | — |
| Choix dans la fiche | Tomates → icône `orange` → Enregistrer | Panneau + montre `orange` pour Tomates | — |
| Grille fermée | sans choix | rien d'écrit | — |
| Clé inconnue stockée | `zzz` | repli du rayon | — |

</intent-contract>

## Code Map

- `lib/core/pictos/picto.dart` -- `PictoResolver` (stub, toujours `null`) et `Picto` (taille, teinte, `ExcludeSemantics`) : seul endroit qui change pour le rendu.
- `_bmad-output/initiative-grocery-list/tickets/epic-reglages-et-sauvegarde/pictos-phosphor.json` -- la correspondance.
- `assets/seed/articles.json` -- les 208 `picto_key`.
- `lib/features/catalogue/data/catalogue_repository.dart` -- `updateArticle`, `_insert` (clé dérivée du nom pour un article créé).
- `lib/features/reglages/ui/article_sheet.dart`, `lib/features/reglages/ui/article_lines.dart` -- Fiche article, lignes à Picto.
- `lib/features/liste/ui/add_sheet_rows.dart`, `lib/features/recettes/ui/fiche_recette_rows.dart`, `lib/features/recettes/ui/recipe_card.dart` -- appelants de `Picto`, à garder tels quels sauf besoin.
- `pubspec.yaml` -- dépendance, assets.

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- paquet ou assets, licence.
- [x] `lib/core/pictos/` -- correspondance, résolveur, replis par rayon, liste des pictos de la grille.
- [x] `catalogue_repository.dart` -- `pictoKey` dans `updateArticle`.
- [x] `article_sheet.dart` (+ nouveau widget de grille dans `lib/features/reglages/ui/`) -- choix du picto ; chaînes dans `strings_fr.dart`.
- [x] tests : chaque ligne de la matrice ; un test qui vérifie que chaque valeur de `pictos-phosphor.json` et chaque `picto_key` de `articles.json` résolvent vers un picto existant ; grille (recherche, choix, fermeture), TalkBack, police ×2.

**Acceptance Criteria:**
- Given le Panneau + ouvert, when Antoine regarde les Ajouts fréquents, then chaque ligne montre un picto Phosphor teinté de son rayon, jamais un rond neutre.

## Implementation Notes

**Décisions**
- ~~Rendu par le paquet `phosphor_flutter` 2.1.0~~ abandonné (voir Surprises) : la police regular de Phosphor est livrée par l'app. `assets/fonts/Phosphor-Regular.ttf` = `src/regular/Phosphor.ttf` de `@phosphor-icons/web` 2.1.1 (jsdelivr), avec son `LICENSE` MIT dans `assets/fonts/LICENSE`. Déclarée dans `pubspec.yaml` `fonts:`, famille `PhosphorRegular`. Pas de SVG ni `flutter_svg`, aucun réseau à l'exécution.
- Les icônes sont des constantes `IconData(0x…, fontFamily: phosphorFontFamily)`, générées à partir de `src/regular/style.css` du même paquet (1530 entrées, dont les 95 retenues ; les points de code sont les mêmes que ceux de `phosphor_flutter` 2.1.0). Elles restent `const` : l'élagage des icônes de la police en release fonctionne.
- Licence : `assets/fonts/LICENSE` à côté de la police, plus une mention dans `README.md` (section « Licences »).
- Correspondance recopiée en table Dart générée depuis `pictos-phosphor.json` (`lib/core/pictos/phosphor_table.dart` : `phosphorFontFamily`, `pictoRayonFallbacks`, `pictoArticleIcons`, `phosphorIcons`). Un test compare la table au JSON clé par clé.
- Ordre de résolution (`PictoResolver.iconNameFor(pictoKey, rayon)`) : clé de la correspondance (icône, ou repli du rayon si `null`) → sinon nom d'icône de la grille (picto choisi) → sinon repli du rayon. Seule collision clé/nom d'icône dans tout le pack : `pizza`, qui donne `pizza` dans les deux cas.
- Grille : 95 icônes = toutes celles de la correspondance et des replis, plus celles du catalogue Phosphor 2.1.1 dont les tags touchent alimentation, cuisine, boissons, maison, salle de bain, ménage, linge, bébé, animaux (filtrées sur les tags de `@phosphor-icons/core` 2.1.1), plus quelques ajouts maison/hygiène (house, couch, bed, armchair, drop, pill, bandaids, first-aid…). Ordre alphabétique.
- Recherche de la grille : nom anglais de l'icône, et `picto_key` des articles de la correspondance qui l'utilisent (les clés sont les noms d'articles en kebab-case : « Pommes de terre » → `pommes-de-terre`). Comparaison sur `normalizeName` réduit à `[a-z0-9]` (accents, casse, espaces, apostrophes ignorés). Pas de lecture de la base : les articles au repli (valeur `null`) ne sont pas trouvés par leur nom.
- `updateArticle` et `createCatalogueArticle` gagnent un paramètre optionnel `String? pictoKey` (`null` = ne change pas) : l'appel de Paramètres › Fréquents est inchangé. Un picto seul changé suffit à écrire (et à activer « Enregistrer »).
- En création, le picto peut aussi être choisi ; sans choix, la clé dérivée du nom reste celle de `_insert`.
- `ArticleSheetTitle` gagne `onPictoTap` : avec, le Picto est un `IconButton` (48 dp, tooltip « Changer le picto », clé `picto-button`) ; sans (Choix de rayon d'un fréquent), il reste non interactif.
- Grille : feuille modale du navigateur racine au-dessus de la Fiche article, 75 % de la hauteur, `CatalogueSearchField` réutilisé (« Chercher un picto »), `GridView` à cellules ≥ 48 dp ; chaque picto est un bouton lu par son nom anglais (tirets en espaces), état choisi, contour `on-surface` 2 dp sur le choisi. Texte « Aucun picto ne correspond. » quand la recherche ne trouve rien (chaîne ajoutée, hors plan).

**Fichiers touchés**
- `pubspec.yaml` (bloc `fonts:`), `README.md`, `assets/fonts/Phosphor-Regular.ttf` et `assets/fonts/LICENSE` (nouveaux)
- `lib/core/pictos/picto.dart`, `lib/core/pictos/phosphor_table.dart` (nouveau)
- `lib/core/strings/strings_fr.dart` (`changerLePicto`, `chercherUnPicto`, `aucunPicto`)
- `lib/features/catalogue/data/catalogue_repository.dart`
- `lib/features/reglages/ui/article_sheet.dart`, `article_lines.dart`, `picto_grid_sheet.dart` (nouveau)
- Tests : `test/core/picto_test.dart` (nouveau : matrice, table = JSON, 208 `picto_key` du seed, recherche, widget Picto 24/44 dp) ; `test/features/catalogue/catalogue_test.dart` (pictoKey écrit/inchangé, Kombucha) ; `test/features/reglages/articles_screen_test.dart` (bouton du picto, choix Tomates → orange → Panneau +, recherche + fermeture sans choix, TalkBack, police ×2 ; signatures du faux catalogue) ; `test/features/reglages/frequents_screen_test.dart` (signature) ; `test/features/liste/add_sheet_test.dart` (critère d'acceptation : 31 fréquents en picto Phosphor teinté).

**Surprises**
- `phosphor_flutter` 2.1.0 ne compile pas avec Flutter 3.47.8 : `PhosphorIconData extends IconData`, alors qu'`IconData` est maintenant une classe `final`. `flutter analyze` ne le voit pas (l'erreur est dans le paquet), mais tous les fichiers de test qui importent l'app échouent au chargement. Le paquet est retiré et la police vendue avec l'app (voir Décisions).
- Pour la sémantique des pictos de la grille : `Semantics(excludeSemantics: true)` retire aussi l'action tap de l'`InkWell`. Le `Semantics` du `PictoChoice` porte donc lui-même `onTap`.
- Test de la grille : `containsAll` sur une liste qui contient des doublons échoue (chaque attendu doit trouver un élément distinct) ; on compare les ensembles.
- Lancé : `flutter test test/core/picto_test.dart test/features/reglages/articles_screen_test.dart test/features/liste/add_sheet_test.dart` → 57 tests réussis ; `flutter test test/features/catalogue/catalogue_test.dart test/features/reglages/frequents_screen_test.dart test/architecture/imports_test.dart` → 94 tests réussis.
- Le test qui vérifiait « Picto hors de tout bouton » dans la Fiche article a été remplacé (le Picto y est maintenant un bouton).

## Plan Change Log

## Review Triage Log

- 2026-11-05 — pas de revue de code séparée (Antoine veut aller vite) ; suite complète lancée : un test de la Carte recette cherchait le picto par un SizedBox de 44 dp, désormais doublé par l'Icon : finder ciblé sur `Picto`. Suite complète : tout passe.

## Verification

**Commands:**
- `flutter analyze` -- expected: aucun problème.
- `dart format --set-exit-if-changed lib test` -- expected: aucun fichier à reformater.
- `grep -rn "Ã\|â€" lib test` -- expected: aucun résultat.
- `flutter test` -- expected: toute la suite passe (lancée par l'orchestrateur).
