import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';
import '../state/recettes_providers.dart';
import 'recipe_card.dart';

/// Recettes : cartes sur 2 colonnes (R2) ; un tap sélectionne ou
/// désélectionne une recette pour la semaine (R3) ; Bouton d'action
/// « Valider (n) » tant que n recettes sélectionnées ne sont pas validées,
/// qui ouvre la Revue. Sans recette, son message d'état vide.
class RecettesScreen extends ConsumerWidget {
  const RecettesScreen({super.key});

  /// Une carte validée ne change pas encore : sa désélection (qui retire
  /// ses ingrédients de la liste) vient avec la story 3.
  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    RecipeCardItem card,
  ) async {
    if (card.validated) return;
    final messenger = ScaffoldMessenger.of(context);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(recipeCardsProvider).value;
    final toValidate = ref.watch(toValidateCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.tabRecettes)),
      body: switch (cards) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(message: StringsFr.recettesVide),
        final cards => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            KadiSpacing.margin,
            KadiSpacing.s2,
            KadiSpacing.margin,
            KadiSpacing.s4,
          ),
          itemCount: (cards.length + 1) ~/ 2,
          separatorBuilder: (_, _) =>
              const SizedBox(height: KadiSpacing.gutter),
          // Rangées de deux cartes à hauteur égale : la plus haute (police
          // système) donne la hauteur de la rangée.
          itemBuilder: (context, row) {
            final left = cards[row * 2];
            final right = row * 2 + 1 < cards.length
                ? cards[row * 2 + 1]
                : null;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _card(context, ref, left)),
                  const SizedBox(width: KadiSpacing.gutter),
                  Expanded(
                    child: right == null
                        ? const SizedBox.shrink()
                        : _card(context, ref, right),
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
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, RecipeCardItem card) =>
      RecipeCard(
        key: ValueKey(card.recipeId),
        card: card,
        onTap: () => _toggle(context, ref, card),
      );
}
