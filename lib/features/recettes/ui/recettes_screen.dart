import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/deselectionner_une_recette.dart';
import 'package:kadi/app/actions/nouvelle_liste.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';
import '../data/recipe_photos.dart';
import '../state/recettes_providers.dart';
import 'recipe_card.dart';

/// Recettes : cartes sur 2 colonnes (R2) ; un tap sélectionne ou
/// désélectionne une recette pour la semaine (R3) ; Bouton d'action
/// « Valider (n) » tant que n recettes sélectionnées ne sont pas validées,
/// qui ouvre la Revue ; Action Nouvelle liste dans la Barre d'application
/// (R8). Sans recette, son message d'état vide. FAB + : nouvelle recette ;
/// icône « modifier » d'une carte : sa Fiche recette (R1).
class RecettesScreen extends ConsumerWidget {
  const RecettesScreen({super.key});

  /// Sélectionne ou désélectionne [card]. Une carte validée passe par
  /// l'action transverse qui retire ses ingrédients de la liste (R6, AD-3),
  /// avec le snackbar Annuler (AD-10).
  ///
  /// [context] est celui du `Builder` de Recettes, sous son messager.
  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    RecipeCardItem card,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (card.validated) {
      final UndoEntry? entry;
      try {
        entry = await ref
            .read(deselectionnerUneRecetteProvider)
            .call(card.recipeId);
      } catch (_) {
        showErrorSnackBar(messenger, StringsFr.modificationImpossible);
        return;
      }
      if (entry == null || !context.mounted) return;
      showUndoSnackBar(context, StringsFr.ingredientsRetires(card.name), entry);
      return;
    }
    final repository = ref.read(recettesRepositoryProvider);
    try {
      if (card.selected) {
        await repository.deselect(card.recipeId);
      } else {
        await repository.select(card.recipeId);
      }
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.modificationImpossible);
    }
  }

  /// Action Nouvelle liste (R8) : Dialogue de confirmation, puis, confirmée,
  /// l'action transverse qui efface la liste et la sélection (AD-3), sans
  /// Annuler (C9). « Garder », le retour et un tap hors du dialogue
  /// n'écrivent rien.
  ///
  /// [context] est celui du `Builder` de Recettes, sous son messager.
  Future<void> _nouvelleListe(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _NouvelleListeDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(nouvelleListeProvider).call();
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.nouvelleListeImpossible);
      return;
    }
    // Un Annuler encore affiché ne rendrait plus rien (emplacement vidé).
    messenger.hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(recipeCardsProvider).value;
    final toValidate = ref.watch(toValidateCountProvider);
    // Le dossier des photos n'est lu que si une carte en a une.
    final photosDir = (cards ?? const []).any((c) => c.photo != null)
        ? ref.watch(photosDirectoryProvider).value
        : null;

    // Messager propre à Recettes : ses snackbars s'affichent dans son
    // Scaffold, au-dessus du Bouton d'action, pas dans la coque. Le Builder
    // donne un contexte sous ce messager, qui reste monté quand le Bouton
    // d'action disparaît.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(StringsFr.tabRecettes),
            actions: [
              // Action Nouvelle liste : texte `on-surface`, jamais d'argile.
              // Police système agrandie : au plus la moitié de la largeur,
              // entière sur une ligne, réduite seulement si elle n'y tient
              // pas (le titre de l'AppBar plafonne déjà sa police).
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width / 2,
                ),
                child: TextButton(
                  onPressed: () => _nouvelleListe(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    textStyle: Theme.of(context).textTheme.labelLarge,
                    minimumSize: const Size(
                      KadiSpacing.touchTarget,
                      KadiSpacing.touchTarget,
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(StringsFr.nouvelleListe),
                  ),
                ),
              ),
              const SizedBox(width: KadiSpacing.s2),
            ],
          ),
          body: switch (cards) {
            null => const SizedBox.shrink(),
            [] => const EmptyState(message: StringsFr.recettesVide),
            final cards => ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                KadiSpacing.margin,
                KadiSpacing.s2,
                KadiSpacing.margin,
                // La dernière rangée défile au-dessus du FAB +.
                KadiSpacing.listBottomInset,
              ),
              itemCount: (cards.length + 1) ~/ 2,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: KadiSpacing.gutter),
              // Rangées de deux cartes à hauteur égale : la plus haute
              // (police système) donne la hauteur de la rangée.
              itemBuilder: (_, row) {
                final left = cards[row * 2];
                final right = row * 2 + 1 < cards.length
                    ? cards[row * 2 + 1]
                    : null;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _card(context, ref, left, photosDir)),
                      const SizedBox(width: KadiSpacing.gutter),
                      Expanded(
                        child: right == null
                            ? const SizedBox.shrink()
                            : _card(context, ref, right, photosDir),
                      ),
                    ],
                  ),
                );
              },
            ),
          },
          bottomNavigationBar: toValidate > 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                  ),
                  child: FilledButton(
                    onPressed: () => context.push(AppRoutes.revue),
                    child: Text(StringsFr.validerN(toValidate)),
                  ),
                )
              : null,
          // FAB + (DESIGN `fab`, argile) : ouvre une Fiche recette vide ;
          // empilé au-dessus du Bouton d'action quand il est là. Sans Hero :
          // le FAB de la Liste vit dans la même coque.
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => context.push(AppRoutes.nouvelleRecette),
            child: const Icon(
              Icons.add,
              semanticLabel: StringsFr.nouvelleRecette,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    RecipeCardItem card,
    Directory? photosDir,
  ) => RecipeCard(
    key: ValueKey(card.recipeId),
    card: card,
    photo: card.photo == null || photosDir == null
        ? null
        : RecipePhotos.fileIn(photosDir, card.photo!),
    onTap: () => _toggle(context, ref, card),
    onEdit: () => context.push(AppRoutes.recette(card.recipeId)),
  );
}

/// Dialogue de confirmation de Nouvelle liste (DESIGN `confirm-dialog`) :
/// rend `true` sur « Effacer et recommencer », `false` sur « Garder » ; le
/// retour et un tap hors du dialogue rendent `null`, comme « Garder ».
class _NouvelleListeDialog extends StatelessWidget {
  const _NouvelleListeDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const target = Size(KadiSpacing.touchTarget, KadiSpacing.touchTarget);
    return AlertDialog(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KadiRadius.xl)),
      ),
      title: const Text(StringsFr.nouvelleListeTitre),
      titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
        color: scheme.onSurface,
      ),
      content: const Text(StringsFr.nouvelleListeTexte),
      contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            minimumSize: target,
          ),
          child: const Text(StringsFr.garder),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: scheme.error,
            minimumSize: target,
          ),
          child: const Text(StringsFr.effacerEtRecommencer),
        ),
      ],
    );
  }
}
