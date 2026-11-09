# Handoff : refonte des écrans Kadi (Recettes, Fiche recette, Revue, Liste, Panneau +)

Repo cible : `AntoineGrb/grocery-list` (Flutter, Material 3, Riverpod, go_router, drift).
Écrans validés : **2a, 2b, 3a, 3c, 3d, 2d, 2e, 2f, 2g, 2h**. Ils sont dans `Kadi - Propositions.dc.html`. Les sections 1 et 3b et la variante 2c ne sont que des pistes écartées : ne pas les implémenter.

---

## 1. À propos des fichiers

`Kadi - Propositions.dc.html` est une **maquette HTML de référence**. C'est un prototype qui montre le rendu et le comportement attendus : ce n'est pas du code à copier. Il s'ouvre dans un navigateur, à condition que `support.js` et `assets/fonts/Phosphor-Regular.ttf` soient à côté. Chaque écran a un badge (`2a`, `3c`…), et la plupart des interactions sont cliquables.

La tâche consiste à **recréer ces écrans en Flutter dans l'app existante**, avec ses conventions :
- les couleurs ne s'écrivent que dans `lib/core/theme/` (AD-12) ;
- tous les textes passent par `StringsFr` ;
- espacements via `KadiSpacing`, rayons via `KadiRadius` ;
- les widgets partagés vont dans `lib/core/ui/`, les écrans dans `lib/features/*/ui/`.

## 2. Fidélité

**Haute fidélité.** Les couleurs, tailles, rayons et textes sont définitifs. Les maquettes ne montrent que le **thème clair**. Pour le sombre, on dérive des tokens `KadiPalette.dark` existants, avec les mêmes rôles :
- `#2A211C` → `onSurface` ;
- `#FBF6F2` → `surface` ;
- `#F3ECE6` → `surfaceContainer` ;
- `#E8DFD8` → `surfaceContainerHigh`.

1 px de la maquette = 1 dp. Le cadre téléphone fait 360 × 760 dp (barre d'état de 28 dp, simulée).

---

## 3. Tokens

### 3.1 Couleurs : toutes existent déjà dans `kadi_tokens.dart`
| Rôle maquette | Hex (clair) | Token |
|---|---|---|
| Fond d'écran | `#FBF6F2` | `surface` |
| Cartes, feuilles, champs remplis | `#F3ECE6` | `surfaceContainer` |
| Tags neutres, piste du segmenté, filets | `#E8DFD8` | `surfaceContainerHigh` |
| Encre (texte, sélection, puces actives) | `#2A211C` | `onSurface` |
| Texte secondaire | `#5C4E46` | `onSurfaceVariant` |
| Contours, pointillés | `#8F7E74` | `outline` |
| Texte coché / « J'ai ! » | `#6F625A` | `checked` |
| Argile (bouton d'action, envoi, FAB) | `#9C4A2A` | `primary` |
| Indicateur de l'onglet actif | `#F2D6C8` | `primaryContainer` |
| Voile sous les feuilles | `rgba(0,0,0,.25)` / `.20` | `scrim` (en clair, monter l'alpha à ~0x40) |

Les **13 couleurs de rayon** (`rayonAccents` / `rayonPastilles`) sont reprises telles quelles. Elles pilotent désormais aussi :
- le monogramme des recettes ;
- le fond rond des pictos ;
- les tags de quantité ;
- les pastilles des fréquents.

> **Règle C6 maintenue** : l'argile ne sert jamais à indiquer un état. Toute sélection se fait à l'**encre** (`onSurface`) : bouton « Ajoutée », filtres actifs, unité choisie, valeur rapide choisie, ⚡ Fréquents actif.

### 3.2 Typographie
- **Corps de texte : Roboto**, la police système Android, comme aujourd'hui.
- **Nouveau : Bricolage Grotesque** (Google Fonts, OFL), en titre display uniquement. L'ajouter en asset (`pubspec.yaml`, poids 600 et 700) et exposer un style dans `kadi_theme.dart`, par exemple `KadiText.display`.

| Usage | Police | Taille / interligne | Graisse |
|---|---|---|---|
| Titre d'écran (« Recettes », « Liste ») | Bricolage | 26 / 32 | 600 |
| Titre de Revue « Qu'as-tu déjà ? » | Bricolage | 26 / 30 | 600 |
| Nom de recette dans la fiche | Bricolage | 24 / 28 | 600 |
| Monogramme 56 dp / 72 dp | Bricolage | 22 / 26 | 700, letter-spacing −0,5 |
| Grand nombre du module quantité | Bricolage | 44 / 1 | 600 |
| Nom de ligne (recette, article, ingrédient) | Roboto | 16 / 22 | 400 (recette : 500) |
| Méta (« 5 ingrédients », rayon, recette d'origine) | Roboto | 12–13 / 16–18 | 400 |
| Tags, puces, boutons | Roboto | 13–14 | 500 |
| Libellé de section (« Ingrédients ») | Roboto | 14 | 500 |
| Surtitre (« SUGGESTIONS », « TES INGRÉDIENTS ») | Roboto | 12, letter-spacing 0,4 | 500 |

### 3.3 Rayons de coin
- 8 : tags quantité ;
- 10 : tags du Panneau +, valeurs rapides ;
- 12 : bouton d'envoi, lignes de résultat au survol ;
- 14 : monogramme 56 ;
- 16 : FAB ;
- 18 : monogramme 72, cartes rayon de la Revue ;
- 20 : menu rayon ;
- 28 : haut des feuilles ;
- full : boutons d'action, champs, pastilles, puces.

### 3.4 Ombres
- Feuille du bas : `0 -4 16 rgba(0,0,0,.12)`.
- Menu rayon : `0 8 24 rgba(0,0,0,.2)`.
- Pastille appareil photo : `0 1 3 rgba(0,0,0,.2)`.
- FAB : inchangé (élévation 6).

### 3.5 Pictos
- **Articles** : Phosphor Regular, inchangé (`Picto`, `phosphor_table.dart`).
- **Interface** : Material Symbols Outlined (`Icons.*_outlined`), notamment `search`, `add`, `check`, `close`, `more_vert`, `arrow_back`, `photo_camera`, `link`, `home`, `bolt`, `arrow_upward`, `arrow_drop_down`, `remove`.
- **Balance** : l'icône Material `scale`. Elle n'existe pas dans `Icons` : utiliser `Symbols.scale` (package `material_symbols_icons`) ou, à défaut, l'icône Phosphor `scales`.

---

## 4. Composants partagés à créer (`lib/core/ui/`)

### 4.1 `RecipeMonogram`
- Carré arrondi en deux tailles : 56 (rayon 14, texte 22) et 72 (rayon 18, texte 26).
- **Fond** = accent du rayon de l'**ingrédient principal**, c'est-à-dire le premier ingrédient de la recette. **Texte** = pastille de ce même rayon.
- **Initiales** :
  - nom de plusieurs mots : 1re lettre du 1er mot en majuscule, puis 1re lettre du 2e mot significatif en minuscule (on ignore de, du, des, la, le, au, aux, à, et, con) : « Chili con carne » → `Cc`, « Pâtes carbonara » → `Pc`, « Quiche lorraine » → `Ql` ;
  - nom d'un seul mot : les 2 premières lettres (« Ratatouille » → `Ra`).
- Si la recette a une photo, elle remplace le monogramme, recadrée avec le même rayon.
- Variante « fiche » (72) : une pastille ronde de 26 dp en bas à droite, décalée de −4/−4, fond `surface`, icône `photo_camera` 16. Elle ouvre le choix Galerie / Appareil photo (`showPhotoSourceSheet` existant).

### 4.2 `QuantityTag` (variante 2b validée)
- **Avec quantité** : hauteur 30 (28 dans la Revue), rayon 8, fond = **pastille du rayon**, texte `formatQuantity()` en Roboto 13/500 encre, padding horizontal 10.
- **Sans quantité** : carré de 30 × 30 (28 dans la Revue), rayon 8, bordure **1,5 dp pointillée** couleur **accent du rayon**, icône **balance** 17 couleur accent. Flutter n'a pas de bordure pointillée native : utiliser `dotted_border` ou un `CustomPainter`.
- Tap → `QuantitySheet`.

### 4.3 `QuantitySheet` : un seul module partout
Il est utilisé par la fiche (3c), la Revue (2d) et le Panneau + (2h). Il **remplace** `quantity_popup.dart` et le `QuantityField` texte de la fiche et de la Revue.

`showModalBottomSheet`, fond `surfaceContainer`, rayon 28 en haut, padding 10 / 20 / 20, poignée 32 × 4 (`onSurfaceVariant` à 60 %). De haut en bas :
1. **En-tête** : picto Phosphor 24 (accent du rayon) + nom de l'article en Roboto 16/500. Dans la Revue, une puce de rayon de 10 dp remplace le picto, et « quantité à acheter » s'affiche à droite en 12 `onSurfaceVariant`.
2. **Ligne nombre** (marge 16 au-dessus, 14 en dessous) : bouton `−` rond de 40 (fond `surface`, icône `remove` 22), puis au centre le grand nombre (Bricolage 44/600, virgule décimale) suivi de l'unité en Roboto 16/500 `onSurfaceVariant` (« pièce » ou « pièces » selon la quantité), puis le bouton `+` rond de 40.
   - Pas : g et ml = 50 ; pièce = 1 ; kg et L = 0,5. Minimum 0.
3. **Choix d'unité segmenté** : piste en pilule `surfaceContainerHigh`, padding 3, gap 2 ; 5 segments égaux de 30 de haut : `pièce`, `g`, `kg`, `ml`, `L`. Le segment actif a un fond encre et un texte `surface`. **Changer d'unité remet le nombre à 0.**
4. **Valeurs rapides** (marge 10 au-dessus) : 4 boutons égaux de 36 de haut, rayon 10, fond `surface`, actif à l'encre.
   - g : 100 / 250 / 500 / 750 g
   - kg : 0,5 / 1 / 1,5 / 2 kg
   - pièce : 1 pièce / 2 / 3 / 6 pièces
   - ml : 100 / 200 / 250 / 500 ml
   - L : 0,5 / 1 / 1,5 / 2 L
5. **Bouton « OK »** (marge 16 au-dessus) : `FilledButton` argile de 48.
   - Si le nombre est supérieur à 0, la quantité est écrite (conversion via `storedQuantity`).
   - Si le nombre vaut 0, la quantité est **effacée** (« sans quantité »).
   - Il n'y a **pas** de bouton « Sans quantité ».
- Tap sur le voile ou retour = fermer sans rien écrire.
- Tap sur le grand nombre (amélioration recommandée, non maquettée) : ouvrir le clavier numérique pour une saisie libre.

### 4.4 `RayonMenu`
Il reprend le menu actuel du Panneau +, utilisé dans 2f et 3d.
- Carte `surfaceContainer`, rayon 20, padding vertical 6, ombre `0 8 24 rgba(0,0,0,.2)`, hauteur max 300 avec défilement.
- Lignes de 44 : puce 10 accent, puis nom en Roboto 16, puis ✓ 20 sur le rayon courant. Fond `surfaceContainerHigh` au survol ou à l'appui.
- Les 13 rayons dans l'ordre du **parcours** (`settings.route_order`).
- Dans 3d, la carte s'ouvre juste **sous la ligne** touchée, à 12 dp à gauche et 48 dp à droite. Tap à l'extérieur = fermer.

### 4.5 `PictoDisc`
Disque de 34 (28 dans les suggestions inline), fond = pastille du rayon, picto Phosphor 20 (17) couleur accent. C'est le nouveau rendu du picto dans la fiche et dans les résultats de recherche.

---

## 5. Écrans

Structure commune des onglets :
- AppBar de 56 dp sans titre M3 standard : titre display à gauche (padding 16), actions en `IconButton` de 48.
- NavigationBar inchangée (80 dp, `surfaceContainer`, indicateur `primaryContainer` de 64 × 32).
- Bouton d'action : `FilledButton` argile, hauteur 48, rayon full, padding 16 / 8 (16 en bas sur les écrans poussés).

### 2a · Recettes (`recettes_screen.dart`, remplace `recipe_card.dart`)
- **AppBar** : « Recettes » (display 26), puis `IconButton(add)`, qui ouvre la Fiche recette vide et **remplace le FAB**, puis `IconButton(more_vert)`, un menu qui contient « Nouvelle liste » (même dialogue qu'aujourd'hui) et « Paramètres ».
- **Recherche** : champ en pilule de 44, fond `surfaceContainer`, icône `search` 22, indication « Chercher une recette », padding 16. Il filtre par nom (insensible aux accents) — non maquetté en dynamique.
- **Filtres** (gap 8, marge haute 10) : deux puces de 32, rayon 8, bordure 1 encre. Active = fond encre, texte `surface` ; inactive = fond transparent.
  - « Toutes · N » ;
  - « Cette semaine · n » : recettes sélectionnées ou validées.
- **Liste** : une ligne par recette, padding 8 / 16, gap 14.
  - `RecipeMonogram` 56 ;
  - nom en Roboto 16/22 500, avec en dessous « N ingrédients » en 13/18 `onSurfaceVariant` ;
  - à droite, le **bouton de sélection** : pilule de 40, padding 0 12 0 8, gap 4, Roboto 13/500, icône 18.
- **États du bouton de sélection** :
  - non sélectionnée : bordure 1 `outline`, fond transparent, icône `add`, « Ajouter » ;
  - sélectionnée ou validée : fond et bordure encre, texte `surface`, icône `check`, « Ajoutée ». Transition du fond en 200 ms.
- **Interactions** :
  - tap sur la ligne → Fiche recette (remplace l'icône crayon) ;
  - tap sur le bouton → sélectionne ou désélectionne (logique `_toggle` existante, snackbar Annuler pour une recette validée).
- **Bas d'écran** : bouton d'action « Valider (n) » (texte de la maquette : « Valider 2 recettes »), visible tant que `toValidate > 0`. Sinon il est caché. La maquette affiche « Choisis tes recettes » à titre indicatif.
- La ligne d'accueil du premier lancement est conservée au-dessus de la liste.

### 2b · Fiche recette (`fiche_recette_screen.dart`, `fiche_recette_rows.dart`)
- **AppBar** : `arrow_back` (même logique « Quitter sans enregistrer ? »), espace, `more_vert` (menu : « Supprimer la recette »). Le titre « Recette » / « Nouvelle recette » disparaît au profit de l'en-tête.
- **En-tête** (padding 4 / 16, gap 14) :
  - `RecipeMonogram` 72 avec sa pastille photo. Tant que le nom est vide, afficher un monogramme neutre (fond `surfaceContainerHigh`).
  - Colonne : **nom éditable** en Bricolage 24/28 600 (`TextField` sans décoration, indication « Nom de la recette »), puis le lien « Ajouter un lien » (icône `link` 16 + Roboto 13/500 `onSurfaceVariant`, marge haute 4). Un tap ouvre un petit dialogue ou champ URL. Une fois le lien rempli, afficher le domaine et une icône `open_in_new`.
- **Section** (marge haute 26, basse 4) : « Ingrédients » à gauche (14/500), le nombre à droite (13 `onSurfaceVariant`).
- **Ligne d'ingrédient** : hauteur 54, gap 12, filet bas 1 `surfaceContainerHigh`.
  - `PictoDisc` 34 : un tap ouvre le **RayonMenu** (3d) ;
  - nom en Roboto 16 ;
  - `QuantityTag` : un tap ouvre le **QuantitySheet** (3c) ;
  - suppression : **balayer vers la gauche** (`Dismissible`, fond `error`, icône `delete_outline`, comme dans la Liste) avec un snackbar Annuler. La croix disparaît.
- **Champ d'ajout** (marge haute 14) : pilule de 48, fond `surfaceContainer`, icône `add` 22, indication « Ajouter un ingrédient… » en 15 `onSurfaceVariant`. Un tap ouvre **3a**.
- **Bas** : « Enregistrer », grisé tant qu'il manque le nom ou un ingrédient (règle actuelle).
- Les ingrédients ajoutés sont **sans quantité** par défaut.

### 3a · Ajout d'ingrédient (remplace `ingredient_sheet.dart`)
- La feuille modale s'ouvre **par-dessus la fiche**, avec un voile à .25.
  - Bord haut à 92 dp du haut de l'écran : environ 88 % de la hauteur. Utiliser `DraggableScrollableSheet` ou `isScrollControlled: true`.
  - Fond `surfaceContainer`, rayon 28 en haut.
- **Contenu**, de haut en bas :
  1. **Poignée** (marge 10 / 6).
  2. **En-tête** de 44 : « Ajouter un ingrédient » (16/500), et `close` 22 à droite.
  3. **Champ de recherche** : pilule de 50, fond `surface`, **bordure 2 encre** (focus), icône `search` 22, texte 17, indication « Chercher ou créer… ». Autofocus, clavier ouvert. Marges 4 / 16 / 8.
  4. **Surtitre** : « TES INGRÉDIENTS » si la saisie est vide (les 5 premiers du catalogue, ou les plus utilisés), « SUGGESTIONS » sinon. Padding 8 / 12 / 4.
  5. **Résultats** : au plus 6, filtrés à chaque frappe sur le catalogue, en `contains` insensible à la casse et aux accents.
     - Ligne de 54, rayon 12, padding 12, gap 12 : `PictoDisc` 34, puis le nom (16/20) et en dessous le rayon (12/16 `onSurfaceVariant`), puis à droite une icône 22.
     - Article hors de la recette : icône `add` à l'encre.
     - Article déjà dans la recette : icône `check` à l'accent du rayon, et le texte du dessous devient « Déjà dans la recette ». Le tap ne fait rien.
  6. **Aucun résultat** : la ligne « Aucun ingrédient enregistré à ce nom. » (13 `onSurfaceVariant`).
  7. **Ligne de création**, toujours en dernier dès qu'**aucun article ne porte exactement ce nom** :
     - cercle de 34 en pointillés `outline` avec `add` ;
     - « Ajouter « saisie » » en 16/500 ;
     - en dessous : « Nouvel ingrédient · rayon modifiable ensuite ».
     - L'action crée l'article (Divers, sans unité, via `creerArticleProvider`) et l'ajoute. Le rayon se change ensuite dans la fiche (3d).
  8. **Clavier système**, sous la liste.
- **Après un ajout** : la saisie se vide, la **feuille reste ouverte** pour enchaîner, et l'ingrédient apparaît dans la fiche, derrière le voile. Entrée valide la première suggestion, sinon crée l'article.

### 3c · Fiche, tap sur la quantité
C'est `QuantitySheet` (§4.3), ouvert sur l'ingrédient touché, avec en-tête picto + nom. OK met le tag à jour.

### 3d · Fiche, tap sur le picto
C'est `RayonMenu` (§4.4), ancré sous la ligne. Choisir un rayon change le rayon de l'**ingrédient de la recette** et met à jour la couleur du disque et du tag. **Décision à prendre côté code** : soit c'est le rayon de l'article au catalogue (recommandé, comme la Feuille d'édition de la Liste), soit c'est un réglage propre à l'ingrédient. Le modèle actuel stocke le rayon sur `articles`, donc la mise à jour se fait au catalogue.

### 2d · Revue (`revue_screen.dart`, `revue_row.dart`)
- **AppBar** : `arrow_back` seul.
- **En-tête** (padding 0 / 16 / 12) :
  - « Qu'as-tu déjà ? » en Bricolage 26/30 ;
  - consigne (14/20 `onSurfaceVariant`, marge 4) : « Touche un article si tu l'as déjà, ou sa quantité si tu en as une partie. »
- **Cartes par rayon** : padding latéral 12, gap 10.
  - Carte `surfaceContainer`, rayon 18, padding vertical 6.
  - En-tête de carte (padding 6 / 14) : puce 10 accent, nom du rayon (14/500), et à droite « gardés / total » (12 `onSurfaceVariant`).
- **Ligne** : hauteur 42, padding 0 10 0 14, gap 10.
  - **Gardé** (état par défaut) : rond de 22 plein à l'accent avec `check` 16 `surface`, nom en 15 encre, puis à droite le `QuantityTag` en 28 de haut.
  - **« J'ai ! »** : icône `home` 20 `outline`, nom en 15 `checked` **barré**, puis à droite le texte « J'ai ! » en 12 `checked`. Pas de tag dans cet état.
- **Interactions** :
  - tap sur la ligne → bascule gardé / « J'ai ! » ;
  - tap sur le tag → `QuantitySheet` : on corrige la quantité à acheter quand on en a déjà une partie. Le tag est une zone de tap séparée, qui ne bascule pas la ligne.
- **Bas** : bouton d'action de 52 « Ajouter N article(s) à la liste », où N = lignes gardées. Mêmes règles de brouillon qu'aujourd'hui (AD-1, AD-16).

### 2e · Liste (`liste_screen.dart`, `item_row.dart`, `checked_section.dart`)
- **AppBar** : « Liste » (display 26), puis `settings`.
- **Progression** (padding 0 / 16 / 6) :
  - texte « X sur N dans le panier » en 13/500 ;
  - barre de 6 dp, rayon 3, piste `surfaceContainerHigh`, remplissage encre animé en 300 ms. **Aucun libellé de recette.**
  - X = articles cochés, N = total.
- **Groupes de rayon** :
  - En-tête : `RayonPastille` existante (padding 14 / 16 / 2), et à droite le nombre d'articles **restants** (12 `onSurfaceVariant`).
  - **Un rayon dont tous les articles sont cochés disparaît** (comportement actuel de `groupByRayon` sur les lignes non cochées).
- **Ligne d'article** : la `ItemRow` actuelle, plus une **ligne d'origine** sous le nom quand l'article vient d'une recette : noms des recettes séparés par « · », en Roboto 12/16 `onSurfaceVariant`. Les données sont à dériver de `list_contributions` → `recipes`.
- **Cocher** envoie l'article dans la **Section Cochés** (existante) :
  - filet de 1 `surfaceContainerHigh` à 16 dp des bords ;
  - en-tête de 48 « Cochés (n) » avec chevron, repliée par défaut ;
  - une fois dépliée, lignes barrées avec rond plein à l'accent ; un tap décoche.
- Le FAB + reste et ouvre le Panneau + (2f).

### 2f · Panneau + au repos (`add_sheet.dart`, `add_sheet_rows.dart`)
Panneau en bas, au-dessus de la Liste voilée à .20. Fond `surfaceContainer`, rayon 28 en haut, padding 10 / 16 / 14, poignée.
- **Ligne de saisie** de 44, padding gauche 8 : texte 22 (indication « Ajouter un article » en `onSurfaceVariant`), puis à droite le **bouton d'envoi** de 40 × 40, rayon 12, icône `arrow_upward` 24.
  - Grisé (`surfaceContainerHigh` / `outline`) quand le champ est vide ;
  - argile / blanc quand il est rempli.
  - Il passe sur cette ligne (et non plus sur la ligne des tags) pour libérer de la place.
- **Ligne de tags** (marge haute 12, gap 6), toutes en 36 de haut, rayon 10, Roboto 14/500, sans retour à la ligne :
  1. **« Quantité »** : fond `surfaceContainerHigh`, padding 10, pas de pointillés. Une fois rempli : fond encre, texte `surface`, valeur `formatQuantity` (« 2 pièces »). Tap → `QuantitySheet` (2h).
  2. **Rayon** : fond = pastille du rayon, puce 10 accent, nom, `arrow_drop_down` 20, padding 0 2 0 10. Tap → `RayonMenu` au-dessus du panneau (marge 0 40 8 16).
  3. **« ⚡ Fréquents »** : icône `bolt` 18 + « Fréquents », padding 0 10 0 6. Inactif : fond `surfaceContainerHigh` ; actif : fond encre, texte `surface`.
- Le **clavier** est ouvert par défaut. **Rien d'autre n'apparaît** : la liste des fréquents n'est plus affichée par défaut.

### 2g · Panneau +, fréquents ouverts
- Tap sur ⚡ Fréquents → le clavier se **ferme** et le panneau affiche, sous les tags :
  - un titre (marge 20 / 4 / 10) : « Ajouts fréquents » (14/500) à gauche, « Gérer » (14/500 `onSurfaceVariant`) à droite, qui pousse `AppRoutes.frequents` ;
  - les **fréquents en pastilles** (wrap, gap 8, padding bas 16).
- **Pastille de fréquent** : hauteur 36, rayon full, padding 0 10, gap 6.
  - Picto Phosphor 18 à l'accent du rayon, nom en 14/500, puis une icône 16 à 70 % : `add`.
  - Article déjà dans la liste : fond encre, texte et picto `surface`, icône `check`.
  - Article hors de la liste : fond `surface`.
- Tap = ajoute l'article avec sa quantité et son rayon par défaut (logique actuelle des fréquents). Re-tap sur une pastille ✓ : sans effet, ou bien ouvre la ligne dans la liste, au choix de l'implémentation.
- Retaper dans le champ ou re-toucher ⚡ → retour à l'état 2f (clavier).

### 2h · Panneau +, module quantité
C'est `QuantitySheet` (§4.3), ouvert depuis le tag « Quantité », avec en en-tête le texte saisi (« Lessive ») et le picto du rayon choisi. Il **remplace** `quantity_popup.dart`. OK met le tag à jour (« 2 pièces », fond encre), puis l'envoi crée la ligne.

---

## 6. État (Riverpod) — ce qui change
- `RecettesScreen` : filtre `Toutes / Cette semaine` et requête de recherche (état local d'écran). Le provider `recipeCardsProvider` doit exposer `ingredientCount` et le rayon de l'ingrédient principal (`mainRayon`) pour le monogramme.
- `QuantitySheet` : état local `{num, unit}` initialisé depuis la quantité stockée (`quantityFieldText` / `InputUnit.of`). Le résultat est renvoyé par `Navigator.pop` sous forme de `StoredQuantity?`, `null` pour effacer.
- Fiche recette : `IngredientDraft` n'a plus de `TextEditingController` ; il porte `StoredQuantity? value`. Le rayon modifié (3d) s'écrit au catalogue à l'enregistrement, ou tout de suite, comme pour la Liste.
- Ajout d'ingrédient (3a) : requête de saisie locale ; résultats via la recherche du catalogue existante (`catalogue_repository`).
- Revue : `_unchecked` reste ; `_controllers` est remplacé par `Map<String, StoredQuantity?> corrections`.
- Liste : un provider `listeProgressProvider` (cochés / total) et l'origine par ligne (`List<String> recipeNames`) ajoutée à `ListeItem`.
- Panneau + : `mode` ∈ `{keyboard, frequents}` et les tags existants (`ajout_panneau.dart`).

## 7. Nouveaux textes `StringsFr`
```dart
static const chercherUneRecette = 'Chercher une recette';
static String toutesN(int n) => 'Toutes · $n';
static String cetteSemaineN(int n) => 'Cette semaine · $n';
static const ajouter = 'Ajouter';
static const ajoutee = 'Ajoutée';
static String nIngredients(int n) => n == 1 ? '1 ingrédient' : '$n ingrédients';
static const ajouterUnLien = 'Ajouter un lien';
static const ingredients = 'Ingrédients';
static const ajouterUnIngredientEllipse = 'Ajouter un ingrédient…';
static const chercherOuCreer = 'Chercher ou créer…';
static const tesIngredients = 'TES INGRÉDIENTS';
static const suggestions = 'SUGGESTIONS';
static const dejaDansLaRecette = 'Déjà dans la recette';
static const aucunIngredient = 'Aucun ingrédient enregistré à ce nom.';
static String ajouterSaisie(String s) => 'Ajouter « $s »'; // = ajouterNom existant
static const nouvelIngredientDetail = 'Nouvel ingrédient · rayon modifiable ensuite';
static const ok = 'OK';
static const quantiteAAcheter = 'quantité à acheter';
static const quAsTuDeja = 'Qu’as-tu déjà ?';
static const revueConsigne = 'Touche un article si tu l’as déjà, ou sa quantité si tu en as une partie.'; // remplace
static const jAi = 'J’ai !';
static String ajouterNArticles(int n) => n == 1 ? 'Ajouter 1 article à la liste' : 'Ajouter $n articles à la liste';
static String dansLePanier(int x, int n) => '$x sur $n dans le panier';
static const frequents = 'Fréquents';
```
Lectures TalkBack à ajouter :
- tag balance : « Ajouter une quantité à X » ;
- disque picto : « Rayon de X, Fruits et légumes. Modifier » ;
- bouton de sélection : « Ajouter X à la semaine » / « Retirer X de la semaine ».

## 8. Assets
- `assets/fonts/Phosphor-Regular.ttf` : déjà dans le repo.
- **Bricolage Grotesque** (Google Fonts, OFL 1.1) : à ajouter, poids 600 et 700.
- Material Symbols pour `scale` (balance) : package `material_symbols_icons`, ou bien `scales` de Phosphor.
- Aucune image : les photos de recettes restent celles de l'utilisateur.

## 9. Fichiers de ce dossier
- `Kadi - Propositions.dc.html` : toutes les maquettes. Écrans validés : sections **2** (2a, 2b, 2d, 2e, 2f, 2g, 2h) et **3** (3a, 3c, 3d).
- `Kadi - Actuel.dc.html` : recréation de l'état actuel, pour comparer.
- `support.js` : runtime nécessaire pour ouvrir les `.dc.html` dans un navigateur.
- `assets/fonts/Phosphor-Regular.ttf` : pictos utilisés par les maquettes.

## 10. Correspondance écran → fichiers Flutter
| Écran | Fichiers à modifier / créer |
|---|---|
| 2a | `recettes/ui/recettes_screen.dart`, nouveau `recettes/ui/recipe_row.dart` (supprime `recipe_card.dart`), `core/ui/recipe_monogram.dart` |
| 2b, 3c, 3d | `recettes/ui/fiche_recette_screen.dart`, `fiche_recette_rows.dart`, `fiche_recette_photo.dart`, `core/ui/quantity_tag.dart`, `core/ui/quantity_sheet.dart`, `core/ui/rayon_menu.dart`, `core/ui/picto_disc.dart` |
| 3a | `recettes/ui/ingredient_sheet.dart` (refonte) |
| 2d | `recettes/ui/revue_screen.dart`, `revue_row.dart` |
| 2e | `liste/ui/liste_screen.dart`, `item_row.dart`, `checked_section.dart`, `liste/state/liste_providers.dart`, `liste/data/liste_repository.dart` (origine) |
| 2f, 2g, 2h | `liste/ui/add_sheet.dart`, `add_sheet_rows.dart`, `quantity_tag.dart`, `rayon_tag.dart` ; `quantity_popup.dart` est supprimé, remplacé par `QuantitySheet` |
| Thème | `core/theme/kadi_theme.dart` (style display), `pubspec.yaml` (police) |
| Textes | `core/strings/strings_fr.dart` |

Penser à mettre à jour `DESIGN.md` et `EXPERIENCE.md` (`_bmad-output/initiative-grocery-list/ux-grocery-list/`) ainsi que les tests de widgets concernés : `recettes_screen_test`, `fiche_recette_screen_test`, `revue_test`, `liste_screen_test`, `add_sheet_test`, `quantity_popup_test`.
