import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';
import '../state/recettes_providers.dart';
import 'fiche_recette_rows.dart';

/// Fiche recette (R1) : écran poussé plein écran, flèche retour, sans Barre
/// de navigation. Ouverte vide par le FAB + de Recettes ([recipeId] nul : nom
/// focalisé, clavier ouvert), ou sur une recette par l'icône « modifier » de
/// sa carte.
///
/// Nom, Champ de recherche sur tout le catalogue (un tap sur un résultat
/// ajoute l'article comme ingrédient en dernière position ; sans article de
/// ce nom exact, « Créer « … » » le crée au catalogue), puis les Lignes
/// d'ingrédient. Après un ajout, la recherche se vide et le Champ quantité
/// du nouvel ingrédient prend le focus ; Entrée y rend le focus à la
/// recherche.
///
/// Enregistrement automatique : dès que la fiche a un nom et au moins un
/// ingrédient, chaque changement s'écrit, dans l'ordre, en une transaction.
/// Sinon rien n'est écrit : une nouvelle fiche incomplète ne crée rien, une
/// recette existante garde sa dernière version valide. Modifier une recette
/// ne change jamais la liste en cours ni la sélection (R7).
class FicheRecetteScreen extends ConsumerStatefulWidget {
  const FicheRecetteScreen({super.key, this.recipeId});

  /// Recette à modifier ; nulle pour une nouvelle recette.
  final String? recipeId;

  @override
  ConsumerState<FicheRecetteScreen> createState() => _FicheRecetteState();
}

class _FicheRecetteState extends ConsumerState<FicheRecetteScreen> {
  late final RecettesRepository _repository = ref.read(
    recettesRepositoryProvider,
  );

  /// Id de la recette, tiré à l'ouverture d'une fiche vide : les écritures
  /// successives de la fiche visent la même ligne.
  late final String _recipeId = widget.recipeId ?? _repository.newId();

  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Brouillon d'écran : les ingrédients dans l'ordre.
  final _ingredients = <IngredientDraft>[];

  /// La fiche est prête à être modifiée (recette lue, ou fiche vide).
  bool _loaded = false;

  /// La recette à modifier n'existe plus.
  bool _missing = false;

  /// Ingrédient dont le Choix d'unité est ouvert.
  String? _unitOpenFor;

  List<CatalogueArticle> _lastResults = const [];

  /// Une création « Créer « … » » est en cours : un second tap est ignoré.
  bool _creating = false;

  /// Brouillon à écrire après l'écriture en cours, et écriture en cours.
  RecipeDraft? _pendingSave;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final recipeId = widget.recipeId;
    if (recipeId == null) {
      _loaded = true;
    } else {
      unawaited(_load(recipeId));
    }
  }

  Future<void> _load(String recipeId) async {
    final sheet = await _repository.readSheet(recipeId);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (sheet == null) {
        _missing = true;
        return;
      }
      _nameController.text = sheet.name;
      _ingredients.addAll(sheet.ingredients.map(IngredientDraft.read));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  RecipeDraft _snapshot() => RecipeDraft(
    recipeId: _recipeId,
    name: _nameController.text,
    ingredients: [for (final ingredient in _ingredients) _draftOf(ingredient)],
  );

  static RecipeDraftIngredient _draftOf(IngredientDraft ingredient) {
    final value = ingredient.value;
    return RecipeDraftIngredient(
      id: ingredient.id,
      articleId: ingredient.articleId,
      quantity: value?.quantity,
      unit: value?.unit,
    );
  }

  /// Un changement de la fiche : son état est pris tout de suite, puis écrit
  /// après l'écriture en cours (une seule à la fois, la plus récente).
  void _changed() {
    if (!_loaded || _missing) return;
    _pendingSave = _snapshot();
    if (!_saving) unawaited(_flush());
  }

  Future<void> _flush() async {
    _saving = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    while (_pendingSave != null) {
      final draft = _pendingSave!;
      _pendingSave = null;
      try {
        await _repository.saveDraft(draft);
      } catch (_) {
        if (messenger != null) {
          showErrorSnackBar(messenger, StringsFr.enregistrementImpossible);
        }
      }
    }
    _saving = false;
  }

  /// Ajoute [article] comme ingrédient en dernière position, sauf s'il l'est
  /// déjà ; vide la recherche et donne le focus à son Champ quantité.
  void _addArticle(CatalogueArticle article) {
    if (_ingredients.any((i) => i.articleId == article.id)) return;
    final ingredient = IngredientDraft.added(_repository.newId(), article);
    setState(() {
      _ingredients.add(ingredient);
      _searchController.clear();
      _unitOpenFor = null;
    });
    _changed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus(ingredient.focusNode);
    });
  }

  /// Donne le focus au champ de [node] et le fait défiler à l'écran.
  void _focus(FocusNode node) {
    node.requestFocus();
    final context = node.context;
    if (context != null) unawaited(Scrollable.ensureVisible(context));
  }

  /// « Créer « … » » : l'article au catalogue, puis ajouté comme
  /// ingrédient. Un échec montre un snackbar et n'écrit rien.
  Future<void> _create(String text) async {
    if (_creating) return;
    _creating = true;
    final messenger = ScaffoldMessenger.of(context);
    final CatalogueArticle article;
    try {
      article = await ref.read(creerArticleProvider)(text);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.ajoutImpossible);
      return;
    } finally {
      _creating = false;
    }
    if (!mounted) return;
    _addArticle(article);
  }

  void _remove(IngredientDraft ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
      if (_unitOpenFor == ingredient.id) _unitOpenFor = null;
    });
    _changed();
    // Le champ quitte l'arbre à la frame suivante.
    WidgetsBinding.instance.addPostFrameCallback((_) => ingredient.dispose());
  }

  void _selectUnit(IngredientDraft ingredient, InputUnit unit) {
    setState(() {
      ingredient.selectUnit(unit);
      _unitOpenFor = null;
    });
    _changed();
  }

  /// Article du catalogue au nom exact de [text] (casse et accents ignorés),
  /// parmi [results].
  static bool _hasExact(List<CatalogueArticle> results, String text) {
    final normalized = normalizeName(text);
    return results.any((a) => normalizeName(a.name) == normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _searchController.text;
    final searching = query.trim().isNotEmpty;
    // Les derniers résultats restent tant que la saisie n'a pas les siens.
    final fresh = searching
        ? ref.watch(articleSearchProvider(query)).value
        : null;
    final results = searching
        ? fresh ?? _lastResults
        : const <CatalogueArticle>[];
    _lastResults = results;
    // « Créer « … » » attend les résultats de cette saisie.
    final showCreate = fresh != null && !_hasExact(fresh, query);
    final ingredientIds = {for (final i in _ingredients) i.articleId};

    final nameStyle = theme.textTheme.titleLarge;
    final body = !_loaded || _missing
        ? const SizedBox.shrink()
        // Toutes les lignes sont bâties : le champ visé par un saut de focus
        // existe toujours, même hors de l'écran.
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: KadiSpacing.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                  ),
                  child: Semantics(
                    label: StringsFr.nomDeLaRecette,
                    child: TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      autofocus: widget.recipeId == null,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      style: nameStyle?.copyWith(color: scheme.onSurface),
                      onChanged: (_) => _changed(),
                      onSubmitted: (_) => _focus(_searchFocus),
                      decoration: InputDecoration(
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        // Lu par le libellé du champ, une seule fois.
                        hint: ExcludeSemantics(
                          child: Text(
                            StringsFr.nomDeLaRecette,
                            style: nameStyle?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Champ de recherche (DESIGN `search-field`) : pilule du
                // thème, loupe, × d'effacement, curseur `on-surface`.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KadiSpacing.margin,
                    vertical: KadiSpacing.s2,
                  ),
                  child: Semantics(
                    label: StringsFr.ajouterUnIngredient,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      // Le clavier reste ouvert ; Entrée n'ajoute rien.
                      onEditingComplete: () {},
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hint: ExcludeSemantics(
                          child: Text(
                            StringsFr.ajouterUnIngredient,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        prefixIcon: const Icon(Icons.search),
                        constraints: const BoxConstraints(
                          minHeight: KadiSpacing.touchTarget,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: StringsFr.effacerLeTexte,
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(_searchController.clear),
                              ),
                      ),
                    ),
                  ),
                ),
                if (searching) ...[
                  for (final article in results)
                    IngredientResultRow(
                      key: ValueKey('result-${article.id}'),
                      article: article,
                      inRecipe: ingredientIds.contains(article.id),
                      onTap: () => _addArticle(article),
                    ),
                  if (showCreate)
                    CreateArticleRow(
                      key: const ValueKey(CreateArticleRow),
                      name: query.trim(),
                      onTap: () => _create(query),
                    ),
                  const Divider(height: KadiSpacing.s4),
                ],
                for (final ingredient in _ingredients)
                  IngredientRow(
                    key: ValueKey(ingredient.id),
                    ingredient: ingredient,
                    unitOpen: _unitOpenFor == ingredient.id,
                    onUnitTap: () => setState(
                      () => _unitOpenFor = _unitOpenFor == ingredient.id
                          ? null
                          : ingredient.id,
                    ),
                    onUnitSelected: (unit) => _selectUnit(ingredient, unit),
                    onChanged: _changed,
                    onSubmitted: () => _focus(_searchFocus),
                    onRemove: () => _remove(ingredient),
                  ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipeId == null
              ? StringsFr.nouvelleRecette
              : StringsFr.recette,
        ),
      ),
      body: body,
    );
  }
}
