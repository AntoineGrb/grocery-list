---
type: epic
title: "La liste de courses au magasin"
parent: initiative-grocery-list
covers: [R9, R10, R11, R12, R13, R15, R16, R17, R18, R19, R20, R23, R24, R25, R26, R27, R28]
sources: []
companions: []
after: []
refined: true
risk: high
---

# La liste de courses au magasin

## Description

Installée sur le téléphone d'Antoine, l'app tient une seule liste en cours, groupée par rayon dans l'ordre par défaut des 13 rayons. On la remplit à la main par le Panneau +, bas, la Liste restant visible au-dessus : Entrée ajoute le texte tapé, même hors catalogue, avec ses tags Quantité et Rayon facultatifs, un tap ajoute un résultat ou un fréquent, chaque ajout se voit aussitôt dans la Liste, et on la coche d'une main jusqu'à Terminer les courses. L'epic livre aussi le socle que les epics 2 et 3 réutilisent : le projet Flutter et un build release installable, les thèmes clair et sombre, le stockage local prêt pour la synchro, le modèle d'unités et la fusion dans la liste (avec la provenance de chaque quantité), la recherche d'article, le catalogue et les fréquents générés par IA.

## Outcome

Antoine remplace son app todo par la Liste pour ses courses : il ajoute un article en un tap depuis le Panneau + et coche tout d'une main au magasin. Le signal est le moment ★ des Flux 2 et 3 d'EXPERIENCE.md.

## Requirements

- R1 (parent R9) : la Liste montre une seule liste en cours, groupée sous des en-têtes de rayon dans l'ordre du parcours (par défaut, l'ordre des 13 rayons), sans compteur ; seuls les rayons non vides s'affichent.
- R2 (parent R10) : seul un tap sur la case coche un article ; l'article coché rejoint la section « Cochés (n) », repliée par défaut en bas de la liste ; décoché depuis cette section, il retourne dans son rayon ; un rayon entièrement coché disparaît.
- R3 (parent R11) : une quantité se saisit en pièces, g, kg, ml ou L, ou reste absente ; l'unité se choisit librement, celle de l'article est préchoisie, sinon la pièce ; kg et L ne sont que des saisies de g et de ml, sans conversion ; un même article dans la même unité s'additionne, dans deux unités il donne deux lignes ; la Liste affiche les quantités arrondies pour la lecture (1,5 kg, 20 cl).
- R4 (parent R12) : la liste ne se vide jamais seule ; quand tout est coché, « Terminer les courses » apparaît et vide la liste, et le Snackbar Annuler la restaure.
- R5 (parent R13) : glisser un article vers la gauche le supprime, avec Snackbar Annuler ; un appui long ouvre la Feuille d'édition, une feuille courte qui monte du bas de l'écran, pour changer la quantité (la ligne passe alors en mode manuel), l'unité, le rayon, ou supprimer l'article ; changer l'unité fusionne la ligne avec la ligne non cochée du même article dans cette unité, s'il y en a une.
- R6 (parent R15) : le FAB + de la Liste ouvre le Panneau +, un panneau bas qui laisse la Liste visible au-dessus de lui, sans voile : champ « Ajouter un article » focalisé, clavier ouvert, ses deux tags (R16), puis la section « Ajouts fréquents », titrée, avec un bouton « Gérer » à droite du titre (sans action dans cet epic) ; les fréquents y forment une liste plate dans l'ordre du parcours, sans en-tête ni libellé de rayon ; le panneau reste ouvert après un ajout.
- R7 (parent R16) : un tap sur un fréquent l'ajoute à la liste, son + devenant une coche, ou retire l'article de la liste s'il y est déjà, avec Annuler ; son état suit la Liste dans les deux sens.
- R8 (parent R17) : chaque frappe dans « Ajouter un article » filtre aussi tout le catalogue ; un tap sur un résultat l'ajoute avec les tags de R16, ou retire l'article s'il est déjà dans la liste, avec Annuler ; le Panneau + ne crée jamais d'article au catalogue.
- R9 (parent R18) : un catalogue unique d'environ 200 articles (nom, picto, rayon par défaut, unité par défaut) est fourni à l'installation et sert à la recherche ; un ajout à la liste ne le modifie jamais.
- R10 (parent R20) : environ 30 fréquents sont fournis, dans un ordre stable par rayon ; l'app n'en ajoute jamais d'elle-même.
- R11 (parent R23) : la Liste vide, le Panneau + sans fréquent et le Panneau + sans résultat affichent leur message et au plus une action, avec la microcopie de Voice and Tone.
- R12 (parent R24) : la Liste et le Panneau + sont utilisables avec TalkBack (libellés annoncés, actions « Supprimer » et « Modifier » à la place des gestes), avec la taille de police système et sans animation quand elles sont désactivées.
- R13 (parent R25) : Entrée dans « Ajouter un article » ajoute le texte saisi, qu'un résultat s'affiche ou non : l'article du catalogue qui porte exactement ce nom (casse et accents ignorés), sinon une ligne libre, qui n'entre pas au catalogue et dont le rayon n'est jamais mémorisé ; un article déjà dans la liste n'est ni ajouté une seconde fois ni retiré : sans tag, rien ne change ; avec des tags, leur quantité et leur rayon remplacent ceux de sa ligne ; après Entrée, le champ se vide et le clavier reste ouvert.
- R14 (parent R26) : dans le Panneau +, tout article déjà dans la liste (fréquent ou résultat) montre sa coche et un tag quantité, « Qté » en contour sans quantité, la quantité en plein sinon, qui ouvre la popup quantité au-dessus du panneau : quantité et unité, jamais le rayon ; la Feuille d'édition de R5 ne s'ouvre plus depuis le panneau.
- R15 (parent R27) : tout ajout depuis le Panneau + se voit aussitôt dans la Liste derrière lui : la ligne arrive animée et brièvement surlignée, juste au-dessus du panneau si elle serait masquée, la Liste défilant alors jusqu'à elle ; sinon rien ne défile ; sans animation quand elles sont désactivées.
- R16 (parent R28) : sous « Ajouter un article », un tag Quantité ouvre la popup quantité de R14 et un tag Rayon ouvre une liste déroulante des 13 rayons ; Rayon affiche le rayon de l'article au nom exact, sinon Divers ; un tag choisi passe de contour à plein ; le choix ne vaut que pour la ligne ajoutée suivante, par Entrée ou tap sur un résultat, jamais pour le catalogue ; les tags reviennent ensuite à zéro ; un tap sur un fréquent ne les utilise pas.

## Constraints

- C1, C3, C4, C5, C6, C7, C8, C9, C10 de l'initiative s'appliquent tels quels ; C2 vaut pour cet epic sans permission demandée à l'utilisateur.
- L'architecture (AD-1 à AD-18) lie toutes les stories ; cet epic crée `core/` (base, tables, réglages, horloge, Annuler, thème, routeur, contenu fourni) et les fonctionnalités `catalogue` et `liste`.

## Done when

- Le build release est installé sur le téléphone d'Antoine et s'ouvre en thème clair comme en thème sombre, selon le réglage système.
- Les Flux 2 (au magasin à une main) et 3 (l'ajout éclair) d'EXPERIENCE.md passent de bout en bout, moment ★ observé.
- Le catalogue d'environ 200 articles et les ~30 fréquents générés sont présents, chacun avec un rayon et une unité.
- Chaque élément stocké porte un UUID, une date de modification et une suppression logique ; une ligne de liste garde la provenance de ses quantités.
- Les tests automatisés du socle, de la Liste et du Panneau + passent, et TalkBack lit la Liste et le Panneau +.

## Boundaries

- Parts des exigences partagées : R9 groupement par rayon (sa désactivation est à l'epic 3) ; R11 unités, arrondi et fusion dans la liste (la fusion en Revue est à l'epic 2) ; R12 vider la liste avec Annuler (la remise à zéro de la sélection est à l'epic 2) ; R18 catalogue fourni et création à la volée (Paramètres › Articles est à l'epic 3) ; R19 ordre par défaut (le glisser-déposer est à l'epic 3) ; R20 fréquents fournis (leur gestion est à l'epic 3) ; R23 états vides de la Liste et du Panneau + ; R24 sur ses surfaces.
- Hors epic : les recettes, la Revue, Nouvelle liste et le premier lancement (epic-recettes-et-revue) ; l'écran Paramètres, Écran allumé, la sauvegarde (epic-reglages-et-sauvegarde).
- Touch point: pack de pictos (externe, choix reporté) — consommé par le catalogue ; owner: cet epic.

## References

- parent — _bmad-output/initiative-grocery-list/initiative-grocery-list.md, section Requirements
- experience — _bmad-output/initiative-grocery-list/ux-grocery-list/EXPERIENCE.md, sections Liste, Panneau +, Flux 2 et 3
- design — _bmad-output/initiative-grocery-list/ux-grocery-list/DESIGN.md
- mockups — _bmad-output/initiative-grocery-list/ux-grocery-list/.working/key-liste.html, key-panneau-plus.html
- architecture — _bmad-output/initiative-grocery-list/architecture-grocery-list/architecture-grocery-list.md, AD-1 à AD-19 (cet epic pose core/, catalogue, liste et Terminer les courses)

## Notes

- Decision: 2026-11-01 — re-slice après la 2e revue : quatre stories ajoutées dans une seule voie (même code du Panneau +), la plus risquée d'abord : 13 Liste visible derrière le panneau (traceur du replan), 14 tag et popup quantité, 15 tags sous le champ, 16 retours mineurs.
- Decision: 2026-11-01 — pas de second « Refactor sweep » : les stories remplacent du code récent et nettoient ce qu'elles remplacent (Ligne saisie, crayon, feuille empilée) ; la story 9 reste le sweep de l'epic.
- Decision: 2026-11-01 — tout est livré en un lot, sans essai intermédiaire ; Antoine teste l'ensemble à la fin (demande d'Antoine).
- Decision: 2026-11-01 — 2e revue de l'app par Antoine après la story 12 : R6, R8, R13, R14 re-rendus depuis l'initiative, R15 et R16 ajoutés (R27, R28) ; l'epic rouvre pour de nouvelles stories, les stories 1 à 12 restent faites.
- Decision: 2026-10-30 — re-slice après la revue : trois stories ajoutées dans une seule voie (même code du Panneau +), la plus risquée d'abord : 10 Entrée et articles hors catalogue (traceur du replan : migration v2 jusqu'au Champ d'ajout), 11 Feuille d'édition avec unité et crayon, 12 Ajouts fréquents et en-têtes sans compteur.
- Decision: 2026-10-30 — pas de second « Refactor sweep » : les trois stories remplacent du code récent et nettoient ce qu'elles remplacent ; la story 9 reste le sweep de l'epic.
- Decision: 2026-10-30 — construction enchaînée sans arrêt ni relecture de plan (demande d'Antoine) ; il teste l'epic entier sur le téléphone à la fin.
- Decision: 2026-10-30 — revue de l'app par Antoine après la story 9 : l'ajout au Panneau + doit être le plus rapide possible. R1, R3, R5 à R9 sont re-rendus depuis l'initiative, R13 et R14 ajoutés (R25, R26) ; la création à la volée au catalogue et le dépliage de ligne après ajout (story 8) sont remplacés. L'epic rouvre pour de nouvelles stories ; les stories 1 à 9 restent faites.
- Decision: 2026-10-30 — l'architecture (AD-4, AD-17) et EXPERIENCE.md ne suivent plus ces exigences : bmad-architecture et bmad-ux les remettent à jour avant le nouveau découpage.
- Decision: 2026-10-26 — identifiant Android `fr.antoinegrb.kadi`, définitif dès la première installation.

- Decision: 2026-10-25 — les décisions partagées sont tranchées dans l'architecture (AD-1 à AD-18) ; cet epic pose le noyau : base, tables, réglages et parcours par défaut, contenu fourni, horloge, Annuler, thème, routeur.
- Decision: 2026-10-25 — story traceur : « Kadi installée : un article cherché apparaît dans la Liste » (socle, base v1, chargeur de contenu, Panneau + réduit à la recherche, Liste, release installée) ; la suivante est la moins sûre, les quantités et contributions.
- Decision: 2026-10-25 — la base v1 de la story 1 crée toutes les tables de l'epic ; une story suivante n'ajoute une migration que si elle change le schéma.
- Decision: 2026-10-25 — l'accessibilité (TalkBack, taille de police, animations) et la microcopie se construisent dans chaque story d'écran, sans story dédiée.
- Decision: 2026-10-25 — le choix du pack de pictos reste hors de l'epic : les stories utilisent le résolveur à repli neutre et les picto_key du contenu fourni.
- Decision: 2026-10-25 — une story « Refactor sweep » clôt l'epic ; pas de suite de bout en bout ici, elle est dans l'epic 3.
- Decision: 2026-10-26 — découpage en 9 stories approuvé ; construction en boucle automatique (bmad-build-auto) ; relecture du plan avant les stories 1 et 2 (les plus risquées), pause après les stories 1 et 3 (installation et relecture du contenu par Antoine).
- Decision: 2026-10-25 — l'app s'appelle « Kadi » (nom affiché sur le téléphone).
- Decision: 2026-10-25 — pas de générateur de code Riverpod ; Drift garde le sien.
- Decision: 2026-10-25 — le contenu fourni (~200 articles, ~30 fréquents) est une story à part, générée par IA et relue par Antoine.
- Decision: 2026-10-25 — étape faite par Antoine avant la première story : réparer le certificat SSL de git sur le poste, puis passer Flutter de 3.44.5 à 3.47.8.
