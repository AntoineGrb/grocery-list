import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/sheet_handle.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'fiche_recette_rows.dart';

/// Résultats montrés au plus (README redesign 3a).
const _maxResults = 6;

/// Suggestions sans saisie : les premiers fréquents.
const _maxSuggestions = 5;

/// Part de l'écran couverte par la feuille : son bord haut à ~92 dp.
const _sheetShare = 0.88;

/// Annonce TalkBack.
Future<void> _announce(FlutterView view, String message) =>
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);

/// Ouvre la feuille d'ajout d'ingrédient (README redesign 3a) par-dessus la
/// Fiche recette, voilée ; elle se ferme par ✕, glissement, voile ou
/// retour.
///
/// [inRecipe] dit si un article est déjà ingrédient ; [onAdd] ajoute un
/// article en dernier ingrédient et rend `false` s'il l'est déjà ;
/// [onCreate] crée au catalogue l'article du texte tapé (ou prend l'article
/// actif de ce nom), l'ajoute et le rend, nul s'il était déjà ingrédient ;
/// il lève une erreur en cas d'échec. [onTop] reçoit le haut de la feuille.
/// [ficheMessenger] montre une erreur arrivée après la fermeture.
Future<void> showIngredientSheet(
  BuildContext context, {
  required bool Function(String articleId) inRecipe,
  required bool Function(CatalogueArticle article) onAdd,
  required Future<CatalogueArticle?> Function(String text) onCreate,
  required ValueChanged<double> onTop,
  ScaffoldMessengerState? ficheMessenger,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  barrierColor: Theme.of(context).colorScheme.scrim,
  isScrollControlled: true,
  builder: (_) => IngredientSheet(
    inRecipe: inRecipe,
    onAdd: onAdd,
    onCreate: onCreate,
    onTop: onTop,
    ficheMessenger: ficheMessenger,
  ),
);

/// Feuille d'ajout d'ingrédient (README redesign 3a) : en-tête et ✕, champ
/// « Chercher ou créer… » focalisé, puis « TES INGRÉDIENTS » (sans saisie)
/// ou « SUGGESTIONS » : au plus 6 articles du catalogue, ✓ pour ceux déjà
/// dans la recette, et « Ajouter « … » » en dernier quand aucun ne porte
/// exactement ce nom. Après un ajout, la saisie se vide et la feuille reste
/// ouverte. Entrée prend la première suggestion, sinon crée l'article.
class IngredientSheet extends ConsumerStatefulWidget {
  const IngredientSheet({
    super.key,
    required this.inRecipe,
    required this.onAdd,
    required this.onCreate,
    required this.onTop,
    this.ficheMessenger,
  });

  final bool Function(String articleId) inRecipe;
  final bool Function(CatalogueArticle article) onAdd;
  final Future<CatalogueArticle?> Function(String text) onCreate;
  final ValueChanged<double> onTop;
  final ScaffoldMessengerState? ficheMessenger;

  @override
  ConsumerState<IngredientSheet> createState() => _IngredientSheetState();
}

class _IngredientSheetState extends ConsumerState<IngredientSheet> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  List<CatalogueArticle> _lastResults = const [];

  /// Un ajout par Entrée ou « Ajouter « … » » est en cours.
  bool _submitting = false;

  /// Messager propre à la feuille : ses snackbars restent au-dessus du voile.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  static CatalogueArticle? _exactIn(
    List<CatalogueArticle> results,
    String text,
  ) {
    final normalized = normalizeName(text);
    return results
        .where((article) => normalizeName(article.name) == normalized)
        .firstOrNull;
  }

  void _showError(String message) {
    final sheet = _messengerKey.currentState;
    final messenger = sheet != null && sheet.mounted
        ? sheet
        : widget.ficheMessenger;
    if (messenger == null || !messenger.mounted) return;
    showErrorSnackBar(messenger, message);
  }

  /// Tap sur un résultat : l'ajoute, sauf s'il est déjà ingrédient.
  void _add(CatalogueArticle article) {
    if (!widget.onAdd(article)) return;
    setState(_controller.clear);
    _fieldFocus.requestFocus();
    unawaited(
      _announce(View.of(context), StringsFr.ingredientAjoute(article.name)),
    );
  }

  /// Entrée : l'article au nom exact, sinon la première suggestion hors de
  /// la recette, sinon l'article créé au catalogue.
  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _submitting) return;
    final exact = _exactIn(_lastResults, text);
    if (exact != null) {
      _add(exact);
      return;
    }
    final first = _lastResults.where((a) => !widget.inRecipe(a.id)).firstOrNull;
    if (first != null) {
      _add(first);
      return;
    }
    await _create();
  }

  /// « Ajouter « … » » : l'article créé au catalogue (Divers, sans unité),
  /// puis ajouté. Un échec garde la saisie.
  Future<void> _create() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _submitting) return;
    _submitting = true;
    final view = View.of(context);
    final CatalogueArticle? article;
    try {
      article = await widget.onCreate(text);
    } catch (_) {
      _showError(StringsFr.ajoutImpossible);
      return;
    } finally {
      _submitting = false;
    }
    if (article == null) return;
    if (mounted) {
      setState(() {
        if (_controller.text == text) _controller.clear();
      });
    }
    await _announce(view, StringsFr.ingredientAjoute(article.name));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _controller.text;
    final searching = query.trim().isNotEmpty;

    final fresh = searching
        ? ref.watch(articleSearchProvider(query)).value
        : null;
    final List<CatalogueArticle> results;
    if (searching) {
      results = (fresh ?? _lastResults).take(_maxResults).toList();
      _lastResults = fresh ?? _lastResults;
    } else {
      final frequents = ref.watch(frequentsProvider).value ?? const [];
      results = frequents.take(_maxSuggestions).toList();
      _lastResults = const [];
    }
    final showCreate =
        searching && fresh != null && _exactIn(fresh, query) == null;
    final empty = searching && fresh != null && fresh.isEmpty;

    final height = media.size.height * _sheetShare;
    final top = media.size.height - height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTop(top);
    });

    final overline = Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.s3,
        KadiSpacing.s2,
        KadiSpacing.s3,
        KadiSpacing.s1,
      ),
      child: Text(
        searching ? StringsFr.suggestions : StringsFr.tesIngredients,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    final field = Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.onSurface, width: 2),
        borderRadius: BorderRadius.circular(KadiRadius.full),
      ),
      padding: const EdgeInsetsDirectional.only(start: KadiSpacing.s4),
      child: Row(
        children: [
          Icon(Icons.search, size: 22, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: StringsFr.ajouterUnIngredient,
              child: TextField(
                controller: _controller,
                focusNode: _fieldFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  color: scheme.onSurface,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                // Le clavier reste ouvert après Entrée.
                onEditingComplete: () {},
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hint: ExcludeSemantics(
                    child: Text(
                      StringsFr.chercherOuCreer,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 17,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              tooltip: StringsFr.effacerLeTexte,
              icon: const Icon(Icons.close),
              onPressed: () => setState(_controller.clear),
            )
          else
            const SizedBox(width: KadiSpacing.s4),
        ],
      ),
    );

    return SizedBox(
      height: height,
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 6),
                child: SheetHandle(),
              ),
              SizedBox(
                height: KadiSpacing.touchTarget,
                child: Row(
                  children: [
                    const SizedBox(width: KadiSpacing.margin),
                    Expanded(
                      child: Text(
                        StringsFr.ajouterUnIngredient,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: StringsFr.fermer,
                      icon: Icon(
                        Icons.close,
                        size: 22,
                        color: scheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: KadiSpacing.s1),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KadiSpacing.margin,
                  KadiSpacing.s1,
                  KadiSpacing.margin,
                  KadiSpacing.s2,
                ),
                child: field,
              ),
              Expanded(
                // Au plus 6 résultats et la ligne de création : tout est
                // bâti, la liste défile seulement.
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    KadiSpacing.s3,
                    0,
                    KadiSpacing.s3,
                    KadiSpacing.s4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (results.isNotEmpty || searching) overline,
                      for (final article in results)
                        IngredientResultRow(
                          key: ValueKey(article.id),
                          article: article,
                          inRecipe: widget.inRecipe(article.id),
                          onTap: () => _add(article),
                        ),
                      if (empty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KadiSpacing.s3,
                            vertical: KadiSpacing.s2,
                          ),
                          child: Text(
                            StringsFr.aucunIngredient,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (showCreate)
                        CreateArticleRow(
                          key: const ValueKey(CreateArticleRow),
                          name: query.trim(),
                          onTap: _create,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
