import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/deselectionner_une_recette.dart';
import 'package:kadi/app/actions/nouvelle_liste.dart';
import 'package:kadi/app/startup.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/confirm_dialog.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/tab_app_bar.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_models.dart';
import '../data/recettes_repository.dart';
import '../data/recipe_photos.dart';
import '../state/recettes_providers.dart';
import 'fiche_recette_screen.dart';
import 'recipe_row.dart';

/// Recettes (README redesign 2a) : recherche, filtres « Toutes » et « Cette
/// semaine », une ligne par recette avec son monogramme. Le bouton de la
/// ligne sélectionne ou désélectionne la recette pour la semaine (R3) ; un
/// tap sur la ligne ouvre sa Fiche recette (R1). Bouton d'action
/// « Valider (n) » tant que n recettes sélectionnées ne sont pas validées,
/// qui ouvre la Revue. + de la Barre d'application : nouvelle recette ; menu
/// ⋮ : Nouvelle liste (R8) et Paramètres. Une fiche fermée par « Supprimer
/// la recette » donne ici le snackbar Annuler.
///
/// Au premier lancement, la ligne d'accueil au-dessus des recettes (R22), le
/// temps de la session et tant qu'il y a des recettes.
class RecettesScreen extends ConsumerStatefulWidget {
  const RecettesScreen({super.key});

  @override
  ConsumerState<RecettesScreen> createState() => _RecettesScreenState();
}

class _RecettesScreenState extends ConsumerState<RecettesScreen> {
  /// Recherche par nom, casse et accents ignorés (état d'écran).
  final _search = TextEditingController();

  /// Filtre « Cette semaine » : recettes sélectionnées ou validées.
  bool _thisWeek = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Ouvre la Fiche recette [location] ; fermée par « Supprimer la recette »,
  /// montre « Recette supprimée : … » · « Annuler » (AD-10).
  ///
  /// [context] est celui du `Builder` de Recettes, sous son messager.
  Future<void> _openFiche(BuildContext context, String location) async {
    final deletion = await context.push<RecipeDeletion>(location);
    if (deletion == null || !context.mounted) return;
    showUndoSnackBar(
      context,
      StringsFr.recetteSupprimee(deletion.name),
      deletion.entry,
    );
  }

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
    final confirmed = await showConfirmDialog(
      context,
      title: StringsFr.nouvelleListeTitre,
      message: StringsFr.nouvelleListeTexte,
      keepLabel: StringsFr.garder,
      confirmLabel: StringsFr.effacerEtRecommencer,
    );
    if (!confirmed || !context.mounted) return;
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
  Widget build(BuildContext context) {
    final cards = ref.watch(recipeCardsProvider).value;
    final toValidate = ref.watch(toValidateCountProvider);
    // Plus aucune recette : la ligne d'accueil ne revient pas de la session.
    ref.listen(recipeCardsProvider, (_, next) {
      if (next.value?.isEmpty ?? false) {
        ref.read(welcomeProvider.notifier).dismiss();
      }
    });
    final welcome = ref.watch(welcomeProvider);
    // Le dossier des photos n'est lu que si une recette en a une.
    final photosDir = (cards ?? const []).any((c) => c.photo != null)
        ? ref.watch(photosDirectoryProvider).value
        : null;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Messager propre à Recettes : ses snackbars s'affichent dans son
    // Scaffold, au-dessus du Bouton d'action, pas dans la coque. Le Builder
    // donne un contexte sous ce messager, qui reste monté quand le Bouton
    // d'action disparaît.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: TabAppBar(
            title: StringsFr.tabRecettes,
            actions: [
              IconButton(
                onPressed: () => _openFiche(context, AppRoutes.nouvelleRecette),
                tooltip: StringsFr.nouvelleRecette,
                color: onSurface,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: switch (cards) {
            null => const SizedBox.shrink(),
            [] => const EmptyState(message: StringsFr.recettesVide),
            final cards => _list(context, cards, welcome, photosDir),
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
        ),
      ),
    );
  }

  /// Recherche, filtres et lignes de [cards] (README redesign 2a).
  ///
  /// [context] est celui du `Builder` de Recettes, sous son messager : il
  /// reste monté quand une ligne disparaît (suppression, filtre).
  Widget _list(
    BuildContext context,
    List<RecipeCardItem> cards,
    bool welcome,
    Directory? photosDir,
  ) {
    final query = normalizeName(_search.text);
    final thisWeek = cards.where((c) => c.selected).toList();
    final shown = [
      for (final card in _thisWeek ? thisWeek : cards)
        if (query.isEmpty || normalizeName(card.name).contains(query)) card,
    ];
    final empty = shown.isNotEmpty
        ? null
        : query.isNotEmpty
        ? StringsFr.aucuneRecetteTrouvee
        : StringsFr.pasDeRecetteCetteSemaine;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchField(
                  controller: _search,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: KadiSpacing.s1),
                Wrap(
                  spacing: KadiSpacing.s2,
                  children: [
                    _FilterChip(
                      label: StringsFr.toutesN(cards.length),
                      selected: !_thisWeek,
                      onTap: () => setState(() => _thisWeek = false),
                    ),
                    _FilterChip(
                      label: StringsFr.cetteSemaineN(thisWeek.length),
                      selected: _thisWeek,
                      onTap: () => setState(() => _thisWeek = true),
                    ),
                  ],
                ),
                if (welcome) ...[
                  const SizedBox(height: KadiSpacing.s2),
                  const _WelcomeLine(),
                  const SizedBox(height: KadiSpacing.s2),
                ],
              ],
            ),
          ),
        ),
        if (empty != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(message: empty),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: KadiSpacing.s2),
            sliver: SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (_, index) {
                final card = shown[index];
                return RecipeRow(
                  key: ValueKey(card.recipeId),
                  card: card,
                  photo: card.photo == null || photosDir == null
                      ? null
                      : RecipePhotos.fileIn(photosDir, card.photo!),
                  onOpen: () =>
                      _openFiche(context, AppRoutes.recette(card.recipeId)),
                  onToggle: () => _toggle(context, ref, card),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Actions du menu ⋮ de Recettes.

/// Champ « Chercher une recette » : pilule de 44 dp `surface-container`.
/// Filtre par nom, casse et accents ignorés.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodyLarge?.copyWith(fontSize: 15);
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: textStyle?.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: StringsFr.chercherUneRecette,
        hintStyle: textStyle?.copyWith(color: scheme.onSurfaceVariant),
        fillColor: scheme.surfaceContainer,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        prefixIcon: Icon(
          Icons.search,
          size: 22,
          color: scheme.onSurfaceVariant,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: StringsFr.effacerLeTexte,
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
    );
  }
}

/// Puce de filtre de Recettes : 32 dp, rayon 8, contour encre ; choisie à
/// l'encre, texte `surface` (C6). Cible de 48 dp.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KadiSpacing.s2),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? scheme.onSurface : Colors.transparent,
              border: Border.all(color: scheme.onSurface),
              borderRadius: BorderRadius.circular(KadiRadius.sm),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? scheme.surface : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne d'accueil du premier lancement : une phrase, non interactive, lue
/// par TalkBack ; elle passe à la ligne avec la police système.
class _WelcomeLine extends StatelessWidget {
  const _WelcomeLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      StringsFr.recettesAccueil,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
