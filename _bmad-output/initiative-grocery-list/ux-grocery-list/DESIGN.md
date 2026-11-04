---
title: DESIGN — grocery-list
name: grocery-list
description: "Liste de courses du foyer, Android (Flutter, Material 3). Palette « Argile sur fusain » : interface neutre, couleur portée par les 13 rayons, argile réservée au FAB +, à l'onglet actif, aux boutons d'action et à l'action des snackbars."
status: draft
updated: 2026-11-02
sources:
  - ../../forge-grocery-list/forge-grocery-list.md
  - ../../forge-grocery-list/.memlog.md
  - .memlog.md
colors:
  # Rôles Material 3 surchargés. Convention : `<token>` = thème clair, `<token>-dark` = thème sombre.
  # Le thème suit le réglage système Android. Valeurs reprises telles quelles de .working/color-themes-2.html (variation B).
  primary: '#9C4A2A'
  on-primary: '#FFFFFF'
  primary-container: '#F2D6C8'
  on-primary-container: '#3B1305'
  surface: '#FBF6F2'
  surface-container: '#F3ECE6'
  on-surface: '#2A211C'
  on-surface-variant: '#5C4E46'
  outline: '#8F7E74'
  checked: '#6F625A'
  error: '#B3261E'
  primary-dark: '#F0A585'
  on-primary-dark: '#4D1C08'
  primary-container-dark: '#6E3219'
  on-primary-container-dark: '#FFDBCC'
  surface-dark: '#1B1715'
  surface-container-dark: '#26201D'
  on-surface-dark: '#F0E5DD'
  on-surface-variant-dark: '#D0C2B8'
  outline-dark: '#9A8B81'
  checked-dark: '#A6988E'
  error-dark: '#FFB4AB'
  # 13 rayons. `rayon-<x>` = accent (point de la pastille, case à cocher, picto) ; `rayon-<x>-pastille` = fond de la pastille d'en-tête.
  rayon-fruits-legumes: '#4B9245'
  rayon-fruits-legumes-dark: '#93CE8D'
  rayon-fruits-legumes-pastille: '#DFE6D6'
  rayon-fruits-legumes-pastille-dark: '#384332'
  rayon-boulangerie: '#927245'
  rayon-boulangerie-dark: '#CEB38D'
  rayon-boulangerie-pastille: '#EAE1D6'
  rayon-boulangerie-pastille-dark: '#463C32'
  rayon-viande-poisson: '#924546'
  rayon-viande-poisson-dark: '#CE8D8E'
  rayon-viande-poisson-pastille: '#EADAD6'
  rayon-viande-poisson-pastille-dark: '#463332'
  rayon-cremerie: '#485A99'
  rayon-cremerie-dark: '#909FD0'
  rayon-cremerie-pastille: '#DEDDE4'
  rayon-cremerie-pastille-dark: '#373842'
  rayon-epicerie-salee: '#925F45'
  rayon-epicerie-salee-dark: '#CEA38D'
  rayon-epicerie-salee-pastille: '#EADED6'
  rayon-epicerie-salee-pastille-dark: '#463932'
  rayon-epicerie-sucree: '#924563'
  rayon-epicerie-sucree-dark: '#CE8DA6'
  rayon-epicerie-sucree-pastille: '#EADADB'
  rayon-epicerie-sucree-pastille-dark: '#463338'
  rayon-surgeles: '#45928E'
  rayon-surgeles-dark: '#8DCECB'
  rayon-surgeles-pastille: '#DEE6E2'
  rayon-surgeles-pastille-dark: '#364341'
  rayon-plats-prepares: '#84783E'
  rayon-plats-prepares-dark: '#CBC086'
  rayon-plats-prepares-pastille: '#E8E2D5'
  rayon-plats-prepares-pastille-dark: '#454030'
  rayon-boissons: '#83499C'
  rayon-boissons-dark: '#BD92D0'
  rayon-boissons-pastille: '#E8DAE4'
  rayon-boissons-pastille-dark: '#423542'
  rayon-hygiene: '#459272'
  rayon-hygiene-dark: '#8DCEB3'
  rayon-hygiene-pastille: '#DEE6DE'
  rayon-hygiene-pastille-dark: '#36433B'
  rayon-entretien: '#544BA0'
  rayon-entretien-dark: '#9B94D1'
  rayon-entretien-pastille: '#E0DBE5'
  rayon-entretien-pastille-dark: '#3A3542'
  rayon-bebe-animaux: '#99488F'
  rayon-bebe-animaux-dark: '#D090C8'
  rayon-bebe-animaux-pastille: '#EBDAE2'
  rayon-bebe-animaux-pastille-dark: '#463440'
  rayon-divers: '#706B66'
  rayon-divers-dark: '#B2ADA9'
  rayon-divers-pastille: '#E5E0DC'
  rayon-divers-pastille-dark: '#3F3B39'
typography:
  # Roboto, échelle typographique Material 3 par défaut (valeurs M3 de référence). 1px = 1 dp logique Flutter.
  headline-small:
    fontFamily: Roboto
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 32px
  title-large:
    fontFamily: Roboto
    fontSize: 22px
    fontWeight: '400'
    lineHeight: 28px
  title-medium:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.15px
  title-small:
    fontFamily: Roboto
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  body-large:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-medium:
    fontFamily: Roboto
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-large:
    fontFamily: Roboto
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-medium:
    fontFamily: Roboto
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  # Échelle de formes Material 3.
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 28px
  full: 9999px
spacing:
  # Grille M3 de 4 dp.
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
  margin: 16px
  gutter: 12px
  touch-target: 48px
  row-min-height: 48px
  list-bottom-inset: 96px
components:
  top-app-bar:
    background: '{colors.surface}'
    foreground: '{colors.on-surface}'
    title: '{typography.title-large}'
    elevation: '0'
  navigation-bar:
    background: '{colors.surface-container}'
    indicator: '{colors.primary-container}'
    indicator-radius: '{rounded.full}'
    icon-active: '{colors.on-primary-container}'
    label-active: '{colors.on-surface}'
    label-inactive: '{colors.on-surface-variant}'
    label: '{typography.label-medium}'
  fab:
    background: '{colors.primary}'
    foreground: '{colors.on-primary}'
    radius: '{rounded.lg}'
    size: 56px
  action-button:
    background: '{colors.primary}'
    foreground: '{colors.on-primary}'
    label: '{typography.label-large}'
    height: '{spacing.touch-target}'
    radius: '{rounded.full}'
  recipe-card:
    background: '{colors.surface-container}'
    radius: '{rounded.md}'
    title: '{typography.title-medium}'
    title-color: '{colors.on-surface}'
    gutter: '{spacing.gutter}'
    selected-border: '{colors.on-surface}'
    selected-border-width: 2px
    selected-mark: '{colors.on-surface}'
    selected-mark-size: 26px
    fallback-background: '{colors.surface}'
    fallback-picto-size: 44px
  rayon-header:
    background: 'fond de pastille du rayon : colors.rayon-<rayon>-pastille'
    dot: 'accent du rayon : colors.rayon-<rayon>'
    dot-size: 10px
    label: '{typography.title-small}'
    label-color: '{colors.on-surface}'
    radius: '{rounded.full}'
  item-row:
    min-height: '{spacing.row-min-height}'
    padding-x: '{spacing.margin}'
    label: '{typography.body-large}'
    label-color: '{colors.on-surface}'
    quantity: '{typography.body-medium}'
    quantity-color: '{colors.on-surface-variant}'
    round-check: 'accent du rayon : colors.rayon-<rayon>'
    round-check-size: 24px
    checkmark: '{colors.surface}'
    arrival-highlight: 'fond de pastille du rayon : colors.rayon-<rayon>-pastille, en fondu'
  checked-section:
    divider: '{colors.outline}'
    header: '{typography.label-large}'
    header-color: '{colors.on-surface-variant}'
    item-color: '{colors.checked}'
    item-decoration: line-through
  add-sheet:
    background: '{colors.surface-container}'
    radius: '{rounded.xl}'
    inset: 8px
    border: none
    elevation: '0'
    barrier: 'voile scrim : noir 20 % en clair, 32 % en sombre'
    field: '{typography.title-large}'
    field-height: 56px
  submit-button:
    background: '{colors.primary}'
    foreground: '{colors.on-primary}'
    radius: '{rounded.md}'
    size: 40px
    touch-target: '{spacing.touch-target}'
  add-tag:
    label: '{typography.label-large}'
    height: 32px
    touch-target: '{spacing.touch-target}'
    radius: '{rounded.sm}'
    empty-background: 'surface-container-high : #E8DFD8 clair, #342C28 sombre'
    empty-label: '{colors.on-surface-variant}'
    filled-background: '{colors.on-surface-variant}'
    filled-label: '{colors.surface}'
    rayon-filled-background: 'fond de pastille du rayon : colors.rayon-<rayon>-pastille'
    rayon-filled-label: '{colors.on-surface}'
  quantity-popup:
    background: 'surface-container-high'
    radius: '{rounded.lg}'
    border: none
    max-width: 340px
    field-background: '{colors.surface-container}'
    unit-selected-background: '{colors.surface-container}'
  search-field:
    background: '{colors.surface}'
    foreground: '{colors.on-surface}'
    cursor: '{colors.on-surface}'
    placeholder: '{colors.on-surface-variant}'
    radius: '{rounded.full}'
    height: '{spacing.touch-target}'
  frequents-title:
    label: '{typography.title-small}'
    label-color: '{colors.on-surface-variant}'
    action: '{typography.label-large}'
    action-color: '{colors.on-surface-variant}'
  frequent-row:
    min-height: '{spacing.row-min-height}'
    label: '{typography.body-large}'
    picto: 'accent du rayon : colors.rayon-<rayon>'
    state-on: 'accent du rayon : colors.rayon-<rayon>'
    state-off: '{colors.on-surface-variant}'
  search-result-row:
    min-height: '{spacing.row-min-height}'
    label: '{typography.body-large}'
  quantity-field:
    text: '{typography.body-large}'
    unit-color: '{colors.on-surface-variant}'
    border: '{colors.outline}'
    radius: '{rounded.xs}'
    height: '{spacing.touch-target}'
  review-row:
    min-height: '{spacing.row-min-height}'
    label: '{typography.body-large}'
    checkbox: 'accent du rayon : colors.rayon-<rayon>'
    unchecked-label-color: '{colors.checked}'
  item-edit-sheet:
    background: '{colors.surface-container}'
    radius: '{rounded.xl}'
    title: '{typography.title-medium}'
    unit-chip-selected: '{colors.on-surface}'
    destructive: '{colors.error}'
  undo-snackbar:
    note: '[ASSUMPTION] rôles inverses M3 : inverse-surface = on-surface, inverse-on-surface = surface, inverse-primary = primary du thème opposé'
    background: '{colors.on-surface}'
    foreground: '{colors.surface}'
    action-color: 'light: {colors.primary-dark} ; dark: {colors.primary}'
    action-label: '{typography.label-large}'
  confirm-dialog:
    background: '{colors.surface-container}'
    radius: '{rounded.xl}'
    title: '{typography.headline-small}'
    body: '{typography.body-medium}'
    destructive: '{colors.error}'
  rayon-picker:
    item: 'pastille du rayon, comme rayon-header'
    selected-border: '{colors.on-surface}'
    min-height: '{spacing.touch-target}'
  ingredient-row:
    min-height: '{spacing.row-min-height}'
    label: '{typography.body-large}'
  settings-row:
    min-height: '{spacing.row-min-height}'
    label: '{typography.body-large}'
    supporting: '{typography.body-medium}'
    supporting-color: '{colors.on-surface-variant}'
  route-row:
    min-height: '{spacing.row-min-height}'
    handle-color: '{colors.on-surface-variant}'
  article-sheet:
    background: '{colors.surface-container}'
    radius: '{rounded.xl}'
  picto:
    size: 24px
    color: 'accent du rayon : colors.rayon-<rayon>'
  empty-state:
    text: '{typography.body-large}'
    color: '{colors.on-surface-variant}'
  action-nouvelle-liste:
    label: '{typography.label-large}'
    color: '{colors.on-surface}'
---

## Brand & Style

grocery-list est une app de courses pour un foyer, pas une app de cuisine ni une vitrine commerciale. Le registre est **chaleureux** (on parle de nourriture et de repas de la semaine), **épuré** et **facile** : peu de menus, peu d'options, l'impression que tout va de soi. Le contre-modèle est explicite : pas une usine à gaz.

La posture visuelle vient du choix « Crème & fusain » (thème 4 de `.working/color-themes-1.html`, historique) réchauffé par la variation B « Argile sur fusain » de `.working/color-themes-2.html` : papier à peine rosé, encre fusain, et la couleur réservée à ce qui a du sens au magasin, les rayons. L'interface elle-même reste neutre ; une seule note d'argile signale l'action d'ajout et l'onglet où l'on se trouve.

Base système : **Material 3 (Flutter)** pour le POC, composants standard. Ce DESIGN.md ne décrit que le delta par rapport à M3 : rôles de couleur surchargés, 13 couleurs de rayon, quelques composants propres (pastille de rayon, section Cochés, panneau +). Tout ce qui n'est pas listé hérite de M3.

Références visuelles : `.working/color-themes-2.html` (variation B, écran Liste clair/sombre, section Cochés, comparatif d'en-têtes) illustre la palette et la composition retenues. Le spine prime en cas de conflit avec une maquette.

## Colors

La règle : **la structure est neutre, la couleur appartient aux rayons, l'argile est rare.** Clair et sombre sont conçus ensemble ; le thème suit le réglage système. Chaque token clair a son pendant `-dark`.

- **Surface (`#FBF6F2` / `#1B1715`)** : fond de tous les écrans, à peine rosé en clair. **Surface container (`#F3ECE6` / `#26201D`)** : barre de navigation, cartes recette, feuilles et dialogues.
- **Encre (`on-surface` `#2A211C` / `#F0E5DD`)** pour le texte principal ; **`on-surface-variant` (`#5C4E46` / `#D0C2B8`)** pour les quantités, compteurs, libellés secondaires ; **`outline` (`#8F7E74` / `#9A8B81`)** pour les séparateurs porteurs de sens (au-dessus de Cochés) et les bordures de champ.
- **Coché (`checked` `#6F625A` / `#A6988E`)** : texte barré des articles cochés et des ingrédients décochés en Revue. Plus discret que l'encre, toujours lisible (≥ 5,5:1).
- **Argile (`primary` `#9C4A2A` / `#F0A585`)** : **uniquement** le fond du FAB +, le fond des Boutons d'action (Valider, Ajouter à la liste, Terminer les courses) et l'action du Snackbar Annuler. Sa teinte claire **`primary-container` (`#F2D6C8` / `#6E3219`)** : **uniquement** l'indicateur de l'onglet actif. Jamais sur un lien, une sélection, un état ou une surface. Conséquence : le `surfaceTint` M3 est neutralisé (transparent) pour qu'aucune surface élevée ne se teinte d'argile.
- **Erreur (`#B3261E` / `#FFB4AB`)** : actions destructrices (Supprimer dans la Feuille d'édition d'article, Effacer dans le Dialogue de confirmation) et messages d'erreur d'import.
- **Rayons** : 13 accents mats issus de Terre cuite, chacun avec un fond de pastille. L'accent colore le point de la pastille, la coche ronde et le picto ; le fond de pastille sert à l'En-tête de rayon, au Tag Rayon choisi et au surlignage d'arrivée d'une ligne. La couleur est l'**identité** du rayon : elle est stable, ne change jamais de sens et n'est jamais utilisée hors rayon.

| Rayon | Token | Accent clair / sombre | Pastille clair / sombre |
|---|---|---|---|
| Fruits & légumes | `rayon-fruits-legumes` | `#4B9245` / `#93CE8D` | `#DFE6D6` / `#384332` |
| Boulangerie | `rayon-boulangerie` | `#927245` / `#CEB38D` | `#EAE1D6` / `#463C32` |
| Viande/Poisson | `rayon-viande-poisson` | `#924546` / `#CE8D8E` | `#EADAD6` / `#463332` |
| Crèmerie | `rayon-cremerie` | `#485A99` / `#909FD0` | `#DEDDE4` / `#373842` |
| Épicerie salée | `rayon-epicerie-salee` | `#925F45` / `#CEA38D` | `#EADED6` / `#463932` |
| Épicerie sucrée | `rayon-epicerie-sucree` | `#924563` / `#CE8DA6` | `#EADADB` / `#463338` |
| Surgelés | `rayon-surgeles` | `#45928E` / `#8DCECB` | `#DEE6E2` / `#364341` |
| Plats préparés | `rayon-plats-prepares` | `#84783E` / `#CBC086` | `#E8E2D5` / `#454030` |
| Boissons | `rayon-boissons` | `#83499C` / `#BD92D0` | `#E8DAE4` / `#423542` |
| Hygiène | `rayon-hygiene` | `#459272` / `#8DCEB3` | `#DEE6DE` / `#36433B` |
| Entretien | `rayon-entretien` | `#544BA0` / `#9B94D1` | `#E0DBE5` / `#3A3542` |
| Bébé/Animaux | `rayon-bebe-animaux` | `#99488F` / `#D090C8` | `#EBDAE2` / `#463440` |
| Divers | `rayon-divers` | `#706B66` / `#B2ADA9` | `#E5E0DC` / `#3F3B39` |

**Contrastes (mesurés, clair / sombre ; cibles WCAG : 4,5:1 texte, 3:1 éléments graphiques)**

| Paire | Rôle | Mesure | Cible |
|---|---|---|---|
| `on-surface` / `surface` | Texte principal | 14,7 / 14,4 | 4,5 |
| `on-surface-variant` / `surface` | Quantités, compteurs ; texte d'un tag plein | 7,4 / 10,2 | 4,5 |
| `checked` / `surface` | Texte coché | 5,5 / 6,4 | 4,5 |
| `on-primary` / `primary` | Signe + du FAB, libellé du Bouton d'action | 6,1 / 7,0 | 4,5 |
| `primary-dark` / `on-surface` ; `primary` / `on-surface-dark` | Action du Snackbar Annuler (clair / sombre) | 7,8 / 4,9 | 4,5 |
| `surface` / `on-surface` | Texte du Snackbar Annuler | 14,7 / 14,4 | 4,5 |
| `primary` / `surface` | FAB contre le fond | 5,7 / 8,8 | 3 |
| `on-primary-container` / `primary-container` | Icône de l'onglet actif | 11,9 / 7,6 | 3 |
| `on-surface-variant` / `surface-container` | Libellés de navigation | 6,8 / 9,3 | 4,5 |
| `error` / `surface` | Texte d'erreur | 6,1 / 10,5 | 4,5 |
| `outline` / `surface` | Séparateur, bordure de champ | 3,6 / 5,4 | 3 |
| `rayon-*` / `surface` (minimum des 13) | Coche ronde, picto | 3,4 / 6,4 | 3 |
| `on-surface` / `rayon-*-pastille` (minimum) | Nom du rayon dans la pastille | 11,6 / 8,3 | 4,5 |
| `rayon-*` / `rayon-*-pastille` (minimum) | Point de la pastille | 2,9 / 4,3 | décoratif |
| `primary-container` / `surface-container` | Forme de l'indicateur d'onglet | 1,2 / 1,6 | non porteur |

Le point de pastille et la forme de l'indicateur d'onglet ne portent pas l'information seuls : le nom du rayon est toujours écrit dans la pastille, et l'onglet actif se lit aussi par son libellé en `on-surface` et son icône contrastée.

Les rôles M3 non listés (secondary, tertiary, outline-variant, inverse-*, surface-container-low/high/highest, on-error) sont dérivés par Flutter de `ColorScheme.fromSeed` avec `{colors.primary}` comme graine, puis écrasés par les valeurs ci-dessus [ASSUMPTION] ; leurs contrastes sont vérifiés au build. Les rôles inverses du Snackbar sont fixés dans `components.undo-snackbar` [ASSUMPTION].

## Typography

**Roboto**, échelle typographique **M3 par défaut**, sans fonte d'accent. La taille de police système est respectée à tous les niveaux.

| Token | Usage |
|---|---|
| `{typography.title-large}` | Titre de la Barre d'application (Recettes, Liste, Revue, Paramètres, Articles) |
| `{typography.headline-small}` | Titre du Dialogue de confirmation |
| `{typography.title-medium}` | Nom sur la Carte recette ; titre des feuilles |
| `{typography.title-small}` | Nom du rayon dans l'En-tête de rayon |
| `{typography.body-large}` | Nom d'article dans toutes les lignes ; Message d'état vide ; saisie |
| `{typography.body-medium}` | Quantités, texte secondaire, corps de dialogue |
| `{typography.label-large}` | Libellés de boutons, en-tête « Cochés (n) », tags du Panneau +, action du Snackbar Annuler |
| `{typography.label-medium}` | Libellés de la Barre de navigation |

Pas de capitales décoratives (l'en-tête « Carré + capitales » a été écarté au profit de la pastille). La maquette rend le nom de rayon en gras 700 ; le poids normatif est celui de M3 (500).

## Layout & Spacing

Grille M3 de 4 dp : `{spacing.1}` à `{spacing.6}` (4 → 32). Marge latérale `{spacing.margin}` (16 dp, fenêtre compacte M3) ; la maquette utilise 18 px, non normatif [ASSUMPTION : espacements normalisés sur la grille M3].

- **Liste, Revue, Panneau +, Paramètres** : une colonne pleine largeur, lignes d'au moins `{spacing.row-min-height}`. Les groupes de rayon s'enchaînent sans carte ; l'En-tête de rayon ouvre chaque groupe.
- **Recettes** : grille de Cartes recette en **2 colonnes**, gouttière `{spacing.gutter}` [ASSUMPTION]. C'est la seule grille de l'app.
- **Zone du pouce** : FAB + en bas à droite au-dessus de la Barre de navigation (position M3 standard) ; Bouton d'action pleine largeur en bas d'écran, au-dessus de la Barre de navigation, le FAB + remontant alors au-dessus de lui. La Barre d'application ne porte que le titre, l'icône ⚙ et, sur Recettes, l'Action Nouvelle liste.
- **Revue** : écran poussé plein écran, flèche retour, sans Barre de navigation ; le Bouton d'action « Ajouter à la liste » est en bas d'écran.
- Le bas de la Liste réserve `{spacing.list-bottom-inset}` pour que le FAB ne masque jamais la dernière ligne, et la hauteur du Panneau + tant qu'il est ouvert.
- **Panneau +** : carte flottante à 8 dp des bords et du clavier, hauteur au contenu : clavier ouvert, seul le titre « Ajouts fréquents » dépasse sous les tags ; clavier fermé, environ quatre fréquents et demi ; pendant la saisie, jusqu'à trois résultats. Jamais plus des deux tiers de la zone libre. Poignée fine. Ses pop-ups (Popup quantité, liste des rayons) se posent juste au-dessus de la carte, calés sur sa marge gauche (24 dp), larges de 340 dp au plus.

## Elevation & Depth

Élévation M3 tonale, réduite au minimum. Les écrans sont à plat sur `{colors.surface}` ; la Barre de navigation se détache par le ton `{colors.surface-container}`, pas par une ombre. La Barre d'application reste à plat, même au défilement (pas de teinte d'élévation, `surfaceTint` neutralisé).

Ombres réservées aux éléments qui flottent réellement : le FAB (niveau 3 M3), les feuilles modales et le Dialogue de confirmation (valeurs M3). Le Panneau + et ses pop-ups n'ont ni ombre ni contour : un voile léger assombrit la Liste, et leurs fonds plus clairs suffisent à les détacher. Aucune carte de groupe, aucune ombre de hiérarchie.

## Shapes

Échelle M3 : `{rounded.xs}` pour les champs (Champ quantité), `{rounded.md}` pour les Cartes recette, `{rounded.lg}` pour le FAB, `{rounded.xl}` pour le haut des feuilles et les dialogues, `{rounded.full}` pour la pastille de rayon, le Champ de recherche, l'indicateur d'onglet et le Bouton d'action. Les photos de recette suivent exactement le rayon de leur carte. La coche est ronde : contour à faire, pleine faite.

La forme arrondie de la pastille est la signature de l'app : un rayon = un petit galet coloré avec son nom.

## Components

Composants M3 standard hérités sans changement hors des lignes ci-dessous (TextField, Switch, ListTile, ModalBottomSheet, AlertDialog, Snackbar). Référence de composition : `.working/color-themes-2.html`, variation B.

| Composant | Spécification visuelle |
|---|---|
| **Barre d'application** (`top-app-bar`) | M3 small top app bar sur `{colors.surface}`, jamais colorée. Titre en `{typography.title-large}`, icône ⚙ (Paramètres) à droite sur Liste et Recettes. |
| **Barre de navigation** (`navigation-bar`) | M3 NavigationBar, deux destinations : Recettes, Liste. Fond `{colors.surface-container}`. Onglet actif : indicateur pilule `{colors.primary-container}`, icône `{colors.on-primary-container}`, libellé `{colors.on-surface}` ; inactif : `{colors.on-surface-variant}`. Icônes au trait. |
| **FAB +** (`fab`) | M3 FAB 56 dp, `{rounded.lg}`, fond `{colors.primary}`, signe + `{colors.on-primary}`, ombre niveau 3. Seul élément plein en argile. |
| **Bouton d'action** (`action-button`) | Valider, Ajouter à la liste (Revue), Terminer les courses. Bouton plein pleine largeur `{colors.primary}`, texte `{colors.on-primary}`, `{rounded.full}`, hauteur `{spacing.touch-target}`, marges `{spacing.margin}`. État désactivé : M3. |
| **Carte recette** (`recipe-card`) | Carte M3 remplie `{colors.surface-container}`, `{rounded.md}` [ASSUMPTION]. Photo en haut, ou visuel de repli : Picto de l'ingrédient principal, 44 dp, teinté de son rayon, sur `{colors.surface}` ; nom en `{typography.title-medium}`. Petite icône discrète « modifier » (cible `{spacing.touch-target}`). Sélectionnée : bordure 2 dp `{colors.on-surface}` et pastille ronde 26 dp `{colors.on-surface}` portant une coche `{colors.surface}`, en haut à gauche ; jamais d'argile. |
| **En-tête de rayon** (`rayon-header`) | Pastille arrondie `{rounded.full}` sur fond `rayon-<rayon>-pastille` : point de 10 dp en accent du rayon + nom en `{typography.title-small}` `{colors.on-surface}`. Sans compteur. Utilisé dans la Liste et la Revue. |
| **Ligne d'article** (`item-row`) | Hauteur ≥ `{spacing.row-min-height}`, marge `{spacing.margin}`. Sans Picto. Coche ronde de 24 dp (case M3 de forme circulaire, cible `{spacing.touch-target}`) dont le contour et le remplissage prennent l'accent du rayon, coche en `{colors.surface}`. Nom en `{typography.body-large}`, quantité arrondie pour la lecture (« 1,5 kg », « 20 cl ») en `{typography.body-medium}` `{colors.on-surface-variant}`. Pas de fond, pas de carte, sauf le surlignage d'arrivée : fond de pastille du rayon qui s'efface en fondu. |
| **Section Cochés** (`checked-section`) | Filet `{colors.outline}` au-dessus. En-tête 48 dp : chevron, « Cochés (n) » en `{typography.label-large}` `{colors.on-surface-variant}`. Lignes cochées : coche ronde pleine en accent du rayon, nom et quantité barrés en `{colors.checked}`. |
| **Panneau +** (`add-sheet`) | Carte flottante sur un voile léger, fond `{colors.surface-container}`, coins `{rounded.xl}`, sans bordure ni ombre. Champ d'ajout sans fond ni icône, texte en `{typography.title-large}` ; dessous les deux tags et, au bout de la rangée, le bouton Valider (`submit-button`, flèche vers le haut, argile, grisé champ vide) ; puis le titre « Ajouts fréquents » et les fréquents en liste plate, sans En-tête de rayon. |
| **Tags du panneau** (`add-tag`) | Puce de 32 dp, `{rounded.sm}`, cible `{spacing.touch-target}`, en `{typography.label-large}`, sans bordure. Vide : fond `surface-container-high`, plus clair que la carte en sombre, texte `{colors.on-surface-variant}`. Plein : fond `{colors.on-surface-variant}`, texte `{colors.surface}`, jamais d'argile. Tag Rayon : point de 10 dp en accent du rayon + nom + flèche ; choisi : fond de pastille du rayon, texte `{colors.on-surface}`. Sa liste déroulante : fond `surface-container-high`, `{rounded.lg}`, sans bordure ni barre de défilement visible, une ligne par rayon (point + nom), coche sur le rayon montré. |
| **Popup quantité** (`quantity-popup`) | Carte compacte `surface-container-high`, `{rounded.lg}`, sans bordure ni ombre, juste au-dessus du panneau sur sa marge gauche. Sans titre visible (le nom est lu par TalkBack). Champ quantité à fond `{colors.surface-container}` sans bordure et, à côté, le bouton Valider (coche, argile) ; dessous le Choix d'unité resserré, sans contour, l'unité choisie sur fond `{colors.surface-container}`. Apparaît en fondu et léger zoom depuis son coin bas gauche. |
| **Champ de recherche** (`search-field`) | Barre M3, `{rounded.full}`, hauteur `{spacing.touch-target}`, fond `{colors.surface}`, texte indicatif `{colors.on-surface-variant}`, icône × d'effacement à droite. Curseur en `{colors.on-surface}`, jamais en argile (le défaut M3 serait `primary`). Champ d'ajout du Panneau + : icône + à gauche, « Ajouter un article » ; Fiche recette et Paramètres › Articles : icône loupe. |
| **Titre des fréquents** (`frequents-title`) | « Ajouts fréquents » en `{typography.title-small}` `{colors.on-surface-variant}`, marge `{spacing.margin}` ; bouton texte « Gérer » à droite, `{typography.label-large}` `{colors.on-surface-variant}`, cible `{spacing.touch-target}`. |
| **Ligne de fréquent** (`frequent-row`) | Liste plate : Picto + nom en `{typography.body-large}` + indicateur d'état à droite, sans libellé de rayon. Hors liste : signe + en `{colors.on-surface-variant}` ; dans la liste : coche ronde pleine en accent du rayon, et à sa gauche le tag quantité (`add-tag`). Rien ne s'insère sous la ligne. |
| **Ligne de résultat** (`search-result-row`) | Exactement comme la Ligne de fréquent, sans libellé de rayon. Sans résultat, une seule ligne « Ajouter « … » » avec un signe + neutre. |
| **Champ quantité** (`quantity-field`) | Petit champ M3, `{rounded.xs}`, bordure `{colors.outline}`, hauteur `{spacing.touch-target}`. Unité en suffixe `{colors.on-surface-variant}` ; vide = sans quantité. |
| **Ligne de Revue** (`review-row`) | Comme la Ligne d'article, avec le Champ quantité à droite. Case cochée par défaut (accent du rayon). Décochée : nom en `{colors.checked}`, sans barré (l'article reste en place). |
| **Feuille d'édition d'article** (`item-edit-sheet`) | Feuille modale M3 courte, hauteur au contenu, `{colors.surface-container}`, haut `{rounded.xl}`, poignée. Nom en `{typography.title-medium}`, puis Champ quantité, Choix d'unité (puces de choix M3 pièce · g · kg · ml · L, la puce choisie en contour `{colors.on-surface}` et coche, jamais en argile), Choix de rayon, « Supprimer » en `{colors.error}`. |
| **Choix de rayon** (`rayon-picker`) | Les 13 pastilles de rayon (comme l'En-tête de rayon), cible ≥ `{spacing.touch-target}` ; le rayon actuel est entouré d'une bordure `{colors.on-surface}`. Utilisé dans la Feuille d'édition d'article. |
| **Snackbar Annuler** (`undo-snackbar`) | Snackbar M3, fond `{colors.on-surface}`, texte `{colors.surface}`, une ligne + action « Annuler » en `{typography.label-large}`, en argile du thème opposé (`primary-dark` en clair, `primary` en sombre) [ASSUMPTION]. Au-dessus du FAB. |
| **Dialogue de confirmation** (`confirm-dialog`) | AlertDialog M3, `{colors.surface-container}`, `{rounded.xl}`, titre `{typography.headline-small}`. Action destructrice en `{colors.error}`, action de repli en `{colors.on-surface}`. |
| **Ligne d'ingrédient** (`ingredient-row`) | Fiche recette : Picto + nom + Champ quantité, icône de retrait à droite. |
| **Ligne de paramètre** (`settings-row`) | ListTile M3 : libellé `{typography.body-large}`, texte d'aide `{typography.body-medium}` `{colors.on-surface-variant}`, Switch M3 ou chevron à droite. |
| **Ligne de parcours** (`route-row`) | Pastille du rayon (comme l'En-tête de rayon) + poignée de glisser à droite en `{colors.on-surface-variant}`. Ligne soulevée pendant le glisser (élévation M3 de glisser). |
| **Fiche article** (`article-sheet`) | Paramètres › Articles : feuille modale M3, `{colors.surface-container}`, haut `{rounded.xl}` [ASSUMPTION]. Nom, Picto choisi dans une grille du pack avec Champ de recherche [ASSUMPTION], rayon par défaut (Choix de rayon), unité par défaut (g, ml, pièce, sans). |
| **Picto** (`picto`) | Icône au trait, 24 dp, teintée de l'accent du rayon de l'article. Un pack cohérent ; source et licence ouvertes. Jamais d'emoji. Présent dans le Panneau +, la Revue, la Fiche recette et la Fiche article ; absent de la Ligne d'article de la Liste. |
| **Message d'état vide** (`empty-state`) | Texte centré `{typography.body-large}` `{colors.on-surface-variant}`, une action au plus. |
| **Action Nouvelle liste** (`action-nouvelle-liste`) | Action textuelle dans la Barre d'application de Recettes, à gauche de ⚙, `{typography.label-large}` `{colors.on-surface}`, jamais en argile. |

## Do's and Don'ts

| Do | Don't |
|---|---|
| Laisser la couleur aux rayons : pastille, coche ronde, picto | Barre d'application colorée (thème 2 rejeté) |
| Fonds neutres, groupes de rayon sans fond | Surcoloration : cartes de groupe teintées (thème 5 rejeté) |
| Argile sur le FAB +, l'indicateur d'onglet actif, les Boutons d'action et l'action du Snackbar Annuler, nulle part ailleurs | Argile sur liens, sélection, états ou surfaces ; teinte `surfaceTint` sur les surfaces |
| Pictos au trait d'un pack cohérent, teintés du rayon | Emoji (« ça ne fait pas sérieux ») |
| Lignes simples pour la Liste, la Revue et les fréquents | Tuiles ou grilles (type Bring!) ; seule exception : les Cartes recette en 2 colonnes |
| Composants M3 standard, peu d'éléments par écran | Usine à gaz : menus, options, badges, compteurs décoratifs |
| Nom du rayon toujours écrit à côté de sa couleur | Couleur seule pour identifier un rayon |
| Concevoir clair et sombre ensemble | Un thème « de seconde zone » |

## Questions ouvertes

- Source exacte du pack de pictos et sa licence (ouvert depuis le forge) ; faisabilité du complément en SVG générés dans le même style. Antoine attend des propositions.
