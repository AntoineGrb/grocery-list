# Idée forgée : app de liste de courses (grocery-list)

**Statut** : durcie (2026-10-24). **But** : répondre au besoin personnel d'Antoine avec le moins de friction possible, pas battre Bring!, Paprika ou Jow.
**Cible** : Flutter, Android. V1 sur un téléphone, V2 partagée à deux dans le foyer, V3 Play Store hors périmètre.

## Décisions

- **Deux onglets.**
  - **Recettes** : on sélectionne les recettes de la semaine, on appuie sur **Valider**, puis on passe à la **Revue**.
  - **Liste** : liste triée par rayon, avec la coche ; c'est le seul endroit où l'on coche.
- **Revue** : tout est coché par défaut. On décoche ce qu'on a déjà, et on peut remplacer une quantité (6 œufs au lieu de 8). N'importe quel ingrédient peut être en stock, puisqu'on compose ses menus à partir de ce qu'on a.
- **Une seule liste en cours.** Une recette ajoutée après validation complète la liste, et seuls ses ingrédients passent en Revue. La liste se vide quand tout est coché ou via **Nouvelle liste**. Le planning par jour est optionnel (glisser-déposer).
- **Bouton + sur la Liste** : il ouvre un panneau avec un champ de recherche et d'ajout rapide (filtre tout le catalogue, crée un article inconnu) et la grille des fréquents (un tap pour ajouter ou retirer). Cocher dans la Liste retire la couleur dans la grille, et inversement.
- **Catalogue unique d'articles** : nom, picto, rayon par défaut, unité par défaut. Environ 200 articles fournis ; un article inconnu saisi rejoint le catalogue. Recettes et fréquents piochent dedans.
- **Fiche recette** : nom, ingrédients (recherche + tap), quantité facultative, lien facultatif, photo facultative avec visuel de repli. Rien d'autre. Objectif : moins d'une minute par recette, pour une vingtaine de recettes au départ.
- **Unités** : `g`, `ml`, `pièce`, ou sans quantité. Aucune conversion. L'unité par défaut de l'article est préremplie. Même unité, on additionne ; unités différentes, une ligne avec deux quantités, ou deux lignes si c'est plus simple. Cuillères et pincées restent sans quantité.
- **Rayons** : 12 rayons génériques fixes et un seul magasin. Le parcours se règle par glisser-déposer depuis les paramètres de la Liste. Le groupement est désactivable ; la liste suit alors l'ordre d'ajout.
- **Fréquents** : environ 30 articles courants hors recette préremplis. Grille rangée par rayon, ordre stable. On les gère depuis les paramètres, jamais automatiquement.
- **Pictos** : un pack d'icônes cohérent, pas d'emoji. Piste : un pack existant complété par des SVG générés par IA dans le même style, à valider sur un échantillon.
- **Données V1** : tout en local, sans compte. Export/import par fichier. UUID, date de modification et suppressions logiques dès la V1.
- **V2** : on rejoint le foyer par un code ou un QR code, sans e-mail ni mot de passe. Tout est partagé en temps réel, y compris pour cocher à deux dans le magasin. Il faudra quand même un backend de synchro.

## Rejeté

- Inscription obligatoire, contenu commercial, suggestions de recettes : ce sont les reproches faits à Bring! et Jow.
- Étapes de préparation, portions, temps, tags : « ce n'est pas une app de cuisine » ; c'est l'excès de champs de Paprika.
- Import d'URL de recettes : parsing fragile, ne correspond pas au catalogue.
- Inventaire de stock, simple drapeau « placard », tout charger puis balayer : remplacés par la Revue.
- Onglets Boissons et Divers séparés, onglet « Habituels », onglet « Définir la liste » avec une liste en lecture seule : trop lourds.
- Entrée automatique dans les fréquents, tri par fréquence : pollution de la grille, positions instables.
- Plusieurs magasins, conversion d'unités, emoji.

## Ouvert

- Retirer un fréquent par appui long en plus des paramètres : sinon, la grille risque de vieillir.
- Source exacte du pack d'icônes, et sa licence.
