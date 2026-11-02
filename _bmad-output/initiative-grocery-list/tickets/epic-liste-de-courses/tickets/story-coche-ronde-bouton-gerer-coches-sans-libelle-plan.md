---
title: 'Coche ronde, bouton Gérer, Cochés sans libellé'
type: 'feature'
ticket: '16'
created: '2026-11-01'
status: done
baseline_revision: 'c61719260431d1a52ae640f2b2089dd5d8ee6f8a'
route: 'oneshot'
route_source: 'auto'
risk: 'low'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Les retours mineurs de la 2e revue d'Antoine restent à faire : cases carrées, crayon du titre « Ajouts fréquents », et libellé « Afficher » ou « Replier » superflu dans la section Cochés.

**Approach:** Coche ronde de 24 dp dans la Liste (contour à faire, pleine faite), même coche pleine dans le Panneau + ; bouton texte « Gérer » sur le titre, lu « Gérer les ajouts fréquents », sans action jusqu'à l'epic 3 ; chevron seul dans Cochés, TalkBack gardant « replié » et « déplié ». Le Champ quantité perd sa bordure de focus en argile, interdite par C6.

</intent-contract>

## Implementation Notes

Oneshot : moins de 100 lignes, trois widgets connus, plus leurs tests.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 6 findings — high 0, medium 0, low 6, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` Appui sur une coche non cochée : halo en argile, contraire à C6 — vérifié dans le défaut M3 de `checkbox_defaults_m3.g.dart` ; `overlayColor` à l'accent du rayon.
  - `[low]` `[patch]` `Transform.scale` grossit aussi le contour (2,67 dp) et le halo (53 dp, déborde sur les lignes voisines) — `side` et `splashRadius` compensés.
  - `[low]` `[patch]` Commentaire « Crayon du titre » resté au-dessus de `gerer` — corrigé.
  - `[low]` `[patch]` Titres et commentaires de test qui décrivent encore le crayon — corrigés.
  - `[low]` `[patch]` Taille de 24 dp non testée — ajoutée pour la coche du panneau ; pour la Liste, `_checkScale` est une constante privée dérivée du token, et sa vérification relève de l'œil au test d'Antoine.
  - `[low]` `[patch]` Bordure de focus du Champ quantité non testée — test ajouté.

## Verification

**Commands:**
- `dart format --set-exit-if-changed lib test` -- expected: aucun changement
- `flutter analyze` -- expected: No issues found
- `flutter test` -- expected: tous les tests passent

## Auto Run Result

**Résumé :** coche ronde de 24 dp dans la Liste et le Panneau +, bouton « Gérer » sur le titre des fréquents, chevron seul dans Cochés, plus d'argile sur le focus du Champ quantité ni sur l'appui de la coche.

**Fichiers :** `item_row.dart`, `add_sheet_rows.dart`, `checked_section.dart`, `quantity_field.dart`, `strings_fr.dart`, tests.

**Revue :** 6 patches appliqués (low). Aucun rejet ni report.

**Suivi de revue recommandé :** non (0 high, 0 medium corrigé).

**Vérification :** `dart format`, `flutter analyze`, `flutter test` passent.

**Risques résiduels :** rendu de la coche à juger sur le téléphone.
