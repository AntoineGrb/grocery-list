import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';
import '../data/recipe_link.dart';
import '../data/recipe_photos.dart';
import '../state/recettes_providers.dart';
import 'fiche_recette_photo.dart';
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
/// Sous les ingrédients, la zone photo (galerie ou appareil photo, copiée
/// sous `photos/`, AD-18 ; remplacer, retirer) et le champ « Lien », avec
/// une icône qui l'ouvre dans le navigateur.
///
/// Enregistrement automatique : dès que la fiche a un nom et au moins un
/// ingrédient, chaque changement s'écrit, dans l'ordre, en une transaction.
/// Sinon rien n'est écrit : une nouvelle fiche incomplète ne crée rien, une
/// recette existante garde sa dernière version valide. Modifier une recette
/// ne change jamais la liste en cours ni la sélection (R7).
///
/// En bas, « Supprimer la recette », seulement pour une recette enregistrée :
/// un tap, sans confirmation (C9), la supprime logiquement et ferme la fiche
/// en rendant une [RecipeDeletion] à Recettes, qui montre le snackbar
/// Annuler. Un échec montre un snackbar et la fiche reste ouverte.
class FicheRecetteScreen extends ConsumerStatefulWidget {
  const FicheRecetteScreen({super.key, this.recipeId});

  /// Recette à modifier ; nulle pour une nouvelle recette.
  final String? recipeId;

  @override
  ConsumerState<FicheRecetteScreen> createState() => _FicheRecetteState();
}

/// Résultat d'une Fiche recette fermée par « Supprimer la recette » : le nom
/// de la recette supprimée et son entrée Annuler (AD-10).
class RecipeDeletion {
  const RecipeDeletion(this.name, this.entry);

  final String name;
  final UndoEntry entry;
}

class _FicheRecetteState extends ConsumerState<FicheRecetteScreen> {
  late final RecettesRepository _repository = ref.read(
    recettesRepositoryProvider,
  );

  /// Lu à l'ouverture : le ménage des photos se finit après la fermeture.
  late final RecipePhotos _photos;

  /// Id de la recette, tiré à l'ouverture d'une fiche vide : les écritures
  /// successives de la fiche visent la même ligne.
  late final String _recipeId = widget.recipeId ?? _repository.newId();

  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _linkController = TextEditingController();

  /// Photo du brouillon (nom de fichier dans `photos/`), nulle sans photo.
  String? _photo;

  /// Photo de la recette en base, telle que la dernière écriture l'a mise.
  String? _savedPhoto;

  /// Fichiers de photo connus de la fiche (celui lu, ceux choisis) : ceux
  /// que ni la base ni le brouillon ne portent plus sont supprimés après
  /// une écriture, et à la fermeture.
  final _photoFiles = <String>{};

  /// Un choix de photo est en cours : un second tap est ignoré.
  bool _picking = false;

  /// La fiche est fermée : le ménage des photos attend la fin des
  /// écritures.
  bool _closed = false;

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

  /// Écritures en cours, attendues avant une suppression.
  Future<void>? _flushing;

  /// La recette est en base : « Supprimer la recette » est montré.
  bool _saved = false;

  /// Une suppression est en cours : un second tap est ignoré.
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _photos = ref.read(recipePhotosProvider);
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
      _saved = true;
      _nameController.text = sheet.name;
      _linkController.text = sheet.link ?? '';
      _photo = _savedPhoto = sheet.photo;
      if (sheet.photo != null) _photoFiles.add(sheet.photo!);
      _ingredients.addAll(sheet.ingredients.map(IngredientDraft.read));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _linkController.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    _closed = true;
    if (!_saving) unawaited(_cleanPhotos());
    super.dispose();
  }

  RecipeDraft _snapshot() => RecipeDraft(
    recipeId: _recipeId,
    name: _nameController.text,
    ingredients: [for (final ingredient in _ingredients) _draftOf(ingredient)],
    link: _linkController.text,
    photo: _photo,
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
    if (!_saving) _flushing = _flush();
  }

  Future<void> _flush() async {
    _saving = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    while (_pendingSave != null) {
      final draft = _pendingSave!;
      _pendingSave = null;
      try {
        if (await _repository.saveDraft(draft)) {
          _savedPhoto = draft.photo;
          if (!_saved && mounted) setState(() => _saved = true);
        }
      } catch (_) {
        if (messenger != null) {
          showErrorSnackBar(messenger, StringsFr.enregistrementImpossible);
        }
      }
    }
    _saving = false;
    await _cleanPhotos();
  }

  /// Supprime les fichiers de photo que plus rien ne porte : ni la base,
  /// ni (fiche ouverte) le brouillon. Après une écriture, l'ancienne photo
  /// d'un remplacement ou d'un retrait ; à la fermeture, une photo choisie
  /// sur une fiche jamais devenue valide.
  Future<void> _cleanPhotos() async {
    final keep = {_savedPhoto, if (!_closed) _photo};
    final orphans = [
      for (final name in _photoFiles)
        if (!keep.contains(name)) name,
    ];
    _photoFiles.removeAll(orphans);
    for (final name in orphans) {
      await _photos.delete(name);
    }
  }

  /// Prend une photo à [source] : copiée sous `photos/`, elle remplace celle
  /// du brouillon. Choix annulé : rien ne change ; échec : snackbar, rien
  /// d'écrit.
  Future<void> _pickPhoto(PhotoSource source) async {
    if (_picking) return;
    _picking = true;
    final messenger = ScaffoldMessenger.of(context);
    final pick = ref.read(photoPickerProvider);
    final String name;
    try {
      final path = await pick(source);
      if (path == null) return;
      name = await _photos.importPhoto(path);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.photoImpossible);
      return;
    } finally {
      _picking = false;
    }
    if (_closed || !mounted) {
      await _photos.delete(name);
      return;
    }
    _photoFiles.add(name);
    setState(() => _photo = name);
    _changed();
  }

  void _removePhoto() {
    setState(() => _photo = null);
    _changed();
  }

  /// « Supprimer la recette » : les écritures en cours finies, la recette est
  /// supprimée logiquement et la fiche se ferme en rendant son nom et son
  /// entrée Annuler. Un échec montre un snackbar ; la fiche reste ouverte.
  Future<void> _delete() async {
    if (_deleting) return;
    _deleting = true;
    final messenger = ScaffoldMessenger.of(context);
    final undo = ref.read(undoProvider);
    final DeletedRecipe? deleted;
    try {
      // Les écritures en cours finies : Annuler rend la dernière version
      // enregistrée de la recette.
      await _flushing;
      deleted = await _repository.deleteRecipe(_recipeId);
    } catch (_) {
      _deleting = false;
      showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
      return;
    }
    if (!mounted) return;
    context.pop(
      deleted == null
          ? null
          : RecipeDeletion(deleted.name, undo.record([deleted.undoRow])),
    );
  }

  /// Ouvre le lien dans le navigateur, `https://` ajouté sans schéma ; un
  /// échec montre « Impossible d'ouvrir le lien. ».
  Future<void> _openLink() async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = recipeLinkUri(_linkController.text);
    var opened = false;
    if (uri != null) {
      try {
        opened = await ref.read(openLinkProvider)(uri);
      } catch (_) {}
    }
    if (!opened) showErrorSnackBar(messenger, StringsFr.lienImpossible);
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
    final photo = _photo;
    final photosDir = photo == null
        ? null
        : ref.watch(photosDirectoryProvider).value;
    final hasLink = _linkController.text.trim().isNotEmpty;

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
                      onChanged: (_) {
                        // L'aperçu de la photo est lu avec le nom.
                        if (_photo != null) setState(() {});
                        _changed();
                      },
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KadiSpacing.margin,
                    KadiSpacing.s4,
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                  ),
                  child: RecipePhotoZone(
                    recipeName: cleanRecipeName(_nameController.text),
                    hasPhoto: photo != null,
                    file: photo == null || photosDir == null
                        ? null
                        : RecipePhotos.fileIn(photosDir, photo),
                    onPick: _pickPhoto,
                    onRemove: _removePhoto,
                  ),
                ),
                // Champ « Lien » : facultatif, clavier URL ; l'icône
                // d'ouverture n'est là que s'il n'est pas vide.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KadiSpacing.margin,
                    vertical: KadiSpacing.s2,
                  ),
                  child: Semantics(
                    label: StringsFr.lien,
                    child: TextField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) {
                        setState(() {});
                        _changed();
                      },
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hint: ExcludeSemantics(
                          child: Text(
                            StringsFr.lien,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        prefixIcon: const Icon(Icons.link),
                        constraints: const BoxConstraints(
                          minHeight: KadiSpacing.touchTarget,
                        ),
                        suffixIcon: hasLink
                            ? IconButton(
                                tooltip: StringsFr.ouvrirLeLien,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(
                                    KadiSpacing.touchTarget,
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new),
                                onPressed: _openLink,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_saved)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KadiSpacing.margin,
                      KadiSpacing.s4,
                      KadiSpacing.margin,
                      0,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text(StringsFr.supprimerLaRecette),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          minimumSize: const Size(
                            KadiSpacing.touchTarget,
                            KadiSpacing.touchTarget,
                          ),
                        ),
                      ),
                    ),
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
