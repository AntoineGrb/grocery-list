import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_providers.dart';

/// Ouvre le Panneau + sur la Liste.
Future<void> showAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // La barrière couvre toute l'app, Barre de navigation comprise.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        const FractionallySizedBox(heightFactor: 0.9, child: AddSheet()),
  );
}

/// Panneau + : Champ de recherche focalisé et lignes de résultat. Reste
/// ouvert après un ajout pour enchaîner.
class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({super.key});

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _controller = TextEditingController();
  List<CatalogueArticle> _lastResults = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(listeRepositoryProvider).addArticle(article.id);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text(StringsFr.ajoutImpossible)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    // Garder les derniers résultats tant que la nouvelle saisie n'a pas
    // encore reçu sa première valeur, pour éviter un clignotement à chaque
    // lettre.
    final results = query.trim().isEmpty
        ? const <CatalogueArticle>[]
        : ref.watch(articleSearchProvider(query)).value ?? _lastResults;
    _lastResults = results;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KadiSpacing.margin),
            child: SizedBox(
              height: KadiSpacing.touchTarget,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: StringsFr.rechercherUnArticle,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: StringsFr.effacerLaRecherche,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_controller.clear),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KadiSpacing.s2),
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: results.length,
              itemBuilder: (context, i) => SearchResultRow(
                article: results[i],
                onTap: () => _add(results[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de résultat : Picto, nom et rayon. Annoncée « Lait, Crèmerie ».
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.article,
    required this.onTap,
  });

  final CatalogueArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '${article.name}, ${article.rayon.spokenLabel}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KadiSpacing.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KadiSpacing.margin,
              vertical: KadiSpacing.s2,
            ),
            child: Row(
              children: [
                Picto(pictoKey: article.pictoKey, rayon: article.rayon),
                const SizedBox(width: KadiSpacing.s4),
                Expanded(
                  child: Text(
                    article.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: KadiSpacing.s3),
                Text(
                  article.rayon.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
