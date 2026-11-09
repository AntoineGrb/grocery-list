import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/confirm_dialog.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_sheet.dart';
import 'package:kadi/core/ui/rayon_menu.dart';
import 'package:kadi/core/ui/recipe_monogram.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../data/recettes_repository.dart';
import '../data/recipe_link.dart';
import '../data/recipe_photos.dart';
import '../state/recettes_providers.dart';
import 'fiche_recette_rows.dart';
import 'ingredient_sheet.dart';
import 'recipe_photo_image.dart';

/// Durée du défilement qui montre un ingrédient ajouté.
const _revealDuration = Duration(milliseconds: 200);

/// Fiche recette (R1) : écran poussé plein écran, flèche retour, sans Barre
/// de navigation. Ouverte vide par le FAB + de Recettes ([recipeId] nul : nom
/// focalisé, clavier ouvert), ou sur une recette par l'icône « modifier » de
/// sa carte.
///
/// Nom, Lignes d'ingrédient, puis le bouton « Ajouter un ingrédient », qui
/// ouvre la popup d'ajout ([showIngredientSheet]) au-dessus de la fiche :
/// chaque article ajouté y entre en dernière position et la fiche défile
/// pour montrer sa ligne au-dessus de la popup. La quantité est facultative :
/// aucun Champ quantité ne prend le focus après un ajout.
///
/// Sous les ingrédients, la zone photo (galerie ou appareil photo, copiée
/// sous `photos/`, AD-18 ; remplacer, retirer) et le champ « Lien », avec
/// une icône qui l'ouvre dans le navigateur.
///
/// La fiche garde son brouillon en mémoire et n'écrit rien avant
/// « Enregistrer » (R1) : ce Bouton d'action, en bas, au-dessus du clavier,
/// grisé tant que la fiche n'a pas de nom ou pas d'ingrédient, écrit nom,
/// ingrédients, photo et lien en une transaction, puis ferme la fiche. Un
/// échec montre un snackbar ; la fiche reste ouverte, rien n'est écrit.
/// Seuls les articles créés par la popup entrent au catalogue tout de suite.
/// Modifier une recette ne change jamais la liste en cours ni la sélection
/// (R7).
///
/// Le retour (flèche ou Android) sur une fiche modifiée depuis son ouverture
/// demande « Quitter sans enregistrer ? » : « Quitter » ferme sans rien
/// écrire, « Garder », le retour ou un tap hors du dialogue restent sur la
/// fiche. Non modifiée, elle se ferme sans question.
///
/// Sous le lien, « Supprimer la recette », seulement pour une recette en
/// base : un tap, sans confirmation (C9), la supprime logiquement et ferme
/// la fiche en rendant une [RecipeDeletion] à Recettes, qui montre le
/// snackbar Annuler. Un échec montre un snackbar et la fiche reste ouverte.
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

  /// Id de la recette, tiré à l'ouverture d'une fiche vide.
  late final String _recipeId = widget.recipeId ?? _repository.newId();

  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _linkController = TextEditingController();
  final _scroll = ScrollController();

  /// Zone défilante de la fiche, pour la mesurer.
  final _viewportKey = GlobalKey();

  /// La popup d'ajout est ouverte : un second tap sur le bouton est ignoré.
  bool _sheetOpen = false;

  /// Haut de la popup d'ajout ouverte, en coordonnées globales.
  double? _sheetTop;

  /// Photo du brouillon (nom de fichier dans `photos/`), nulle sans photo.
  String? _photo;

  /// Photo de la recette en base : celle lue, puis celle enregistrée.
  String? _savedPhoto;

  /// Fichiers de photo connus de la fiche (celui lu, ceux choisis) : ceux
  /// que ni la base ni le brouillon ne portent plus sont supprimés dès
  /// qu'ils sont abandonnés, et à la fermeture.
  final _photoFiles = <String>{};

  /// Un choix de photo est en cours : un second tap est ignoré.
  bool _picking = false;

  /// La fiche est fermée : seule la photo en base est gardée ; le ménage
  /// attend la fin d'un enregistrement en cours.
  bool _closed = false;

  /// Brouillon d'écran : les ingrédients dans l'ordre.
  final _ingredients = <IngredientDraft>[];

  /// La fiche est prête à être modifiée (recette lue, ou fiche vide).
  bool _loaded = false;

  /// La recette à modifier n'existe plus.
  bool _missing = false;

  /// Menu des rayons de chaque ingrédient (3d), par id.
  final _menus = <String, MenuController>{};

  /// Le Module quantité est ouvert : un second tap est ignoré.
  bool _quantityOpen = false;

  /// État du brouillon à l'ouverture : la fiche est modifiée quand le sien
  /// en diffère ([_signature]).
  List<Object?> _initial = const [];

  /// « Enregistrer » écrit : un second tap, le retour et la suppression
  /// attendent.
  bool _saving = false;

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
      _initial = _signature();
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
      _initial = _signature();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _linkController.dispose();
    _scroll.dispose();
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

  /// Ce que l'écran montre du brouillon : nom, lien, photo, ingrédients dans
  /// l'ordre avec leur quantité.
  List<Object?> _signature() => [
    _nameController.text,
    _linkController.text,
    _photo,
    for (final ingredient in _ingredients) ...[
      ingredient.id,
      ingredient.value,
      ingredient.rayon,
    ],
  ];

  /// La fiche a changé depuis son ouverture, ou une photo est en cours de
  /// choix : quitter demande confirmation.
  bool get _modified =>
      _picking || (_loaded && !_missing && !listEquals(_signature(), _initial));

  /// « Enregistrer » est actif : un nom une fois nettoyé, un ingrédient,
  /// aucun choix de photo en cours.
  bool get _canSave =>
      _loaded &&
      !_missing &&
      !_picking &&
      cleanRecipeName(_nameController.text).isNotEmpty &&
      _ingredients.isNotEmpty;

  /// « Enregistrer » : le brouillon entier écrit en une transaction, puis la
  /// fiche se ferme. Un échec montre un snackbar ; la fiche reste ouverte et
  /// rien n'est écrit. Pendant l'écriture, la fiche est inerte : plus de
  /// saisie, d'ajout ni d'action sur la photo.
  Future<void> _save() async {
    if (_saving || _deleting || !_canSave) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final draft = _snapshot();
    final db = ref.read(databaseProvider);
    final catalogue = ref.read(catalogueRepositoryProvider);
    final rayons = {
      for (final i in _ingredients)
        if (i.rayon != i.originalRayon) i.articleId: i.rayon,
    };
    var saved = false;
    try {
      // Le rayon changé par le picto (3d) va au catalogue, dans la même
      // transaction que la recette. Recette supprimée entre-temps : rien
      // n'est écrit.
      saved = await db.transaction(() async {
        for (final MapEntry(:key, :value) in rayons.entries) {
          await catalogue.setRayon(key, value);
        }
        if (!await _repository.saveDraft(draft)) throw const _NotSaved();
        return true;
      });
    } catch (_) {}
    if (saved) _savedPhoto = draft.photo;
    if (_closed) {
      await _cleanPhotos();
      return;
    }
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      showErrorSnackBar(messenger, StringsFr.enregistrementImpossible);
      return;
    }
    // L'ancienne photo, remplacée ou retirée, n'est plus portée.
    unawaited(_cleanPhotos());
    context.pop();
  }

  /// Retour (flèche ou Android) : une fiche modifiée demande confirmation ;
  /// « Quitter » la ferme sans rien écrire. Pendant un enregistrement, rien.
  Future<void> _onBack() async {
    if (_saving || _deleting) return;
    if (_modified) {
      final quit = await showConfirmDialog(
        context,
        title: StringsFr.quitterSansEnregistrerTitre,
        message: StringsFr.quitterSansEnregistrerTexte,
        keepLabel: StringsFr.garder,
        confirmLabel: StringsFr.quitter,
      );
      if (!quit || !mounted || _saving || _deleting) return;
    }
    context.pop();
  }

  /// Supprime les fichiers de photo que plus rien ne porte : ni la base,
  /// ni (fiche ouverte) le brouillon. Fiche ouverte, une photo choisie puis
  /// remplacée ou retirée ; après un enregistrement, l'ancienne photo ; à la
  /// fermeture, une photo choisie et jamais enregistrée.
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
  ///
  /// Tant que le choix est en cours, « Enregistrer » est grisé et le retour
  /// demande confirmation.
  Future<void> _pickPhoto(PhotoSource source) async {
    if (_picking || _saving) return;
    setState(() => _picking = true);
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
      if (mounted) setState(() {});
    }
    if (_closed || !mounted) {
      await _photos.delete(name);
      return;
    }
    _photoFiles.add(name);
    setState(() => _photo = name);
    // La photo choisie avant, jamais enregistrée, est abandonnée.
    unawaited(_cleanPhotos());
  }

  void _removePhoto() {
    if (_saving) return;
    setState(() => _photo = null);
    unawaited(_cleanPhotos());
  }

  /// « Supprimer la recette » : la recette en base est supprimée logiquement
  /// et la fiche se ferme en rendant son nom et son entrée Annuler ; le
  /// brouillon non enregistré est perdu. Un échec montre un snackbar ; la
  /// fiche reste ouverte.
  Future<void> _delete() async {
    if (_deleting || _saving) return;
    _deleting = true;
    final messenger = ScaffoldMessenger.of(context);
    final undo = ref.read(undoProvider);
    final DeletedRecipe? deleted;
    try {
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

  /// Le bouton « Ajouter un ingrédient » : ouvre la popup d'ajout au-dessus
  /// de la fiche. Le champ qui avait le focus le rend : à la fermeture, aucun
  /// champ de la fiche ne le reprend.
  Future<void> _openSheet() async {
    if (_sheetOpen || _saving) return;
    _sheetOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    await showIngredientSheet(
      context,
      inRecipe: (articleId) =>
          _ingredients.any((i) => i.articleId == articleId),
      onAdd: _addArticle,
      onCreate: _create,
      onTop: _onSheetTop,
      ficheMessenger: ScaffoldMessenger.maybeOf(context),
    );
    _sheetOpen = false;
    if (mounted) setState(() => _sheetTop = null);
  }

  /// La popup d'ajout a changé de hauteur : la fiche garde de quoi défiler
  /// sous elle.
  void _onSheetTop(double top) {
    if (!mounted || !_sheetOpen || top == _sheetTop) return;
    setState(() => _sheetTop = top);
  }

  /// Ajoute [article] comme ingrédient en dernière position, sauf s'il l'est
  /// déjà (rend alors `false`) ; sa ligne est montrée au-dessus de la popup.
  /// Aucun Champ quantité ne prend le focus : la quantité est facultative.
  bool _addArticle(CatalogueArticle article) {
    if (_ingredients.any((i) => i.articleId == article.id)) return false;
    final ingredient = IngredientDraft.added(_repository.newId(), article);
    setState(() => _ingredients.add(ingredient));
    // La popup change de hauteur dans la même frame et la publie après
    // elle : la ligne est montrée une frame plus tard, sous sa géométrie à
    // jour.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _reveal(ingredient))
        ..scheduleFrame();
    });
    return true;
  }

  /// Fait défiler la fiche jusqu'à montrer la ligne de [ingredient], juste
  /// au-dessus de la popup si elle la masquait ; rien si elle est visible.
  void _reveal(IngredientDraft ingredient) {
    if (!mounted || !_scroll.hasClients) return;
    final row = ingredient.rowKey.currentContext?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (row is! RenderBox || viewport is! RenderBox) return;

    final rowTop = row.localToGlobal(Offset.zero).dy;
    final rowBottom = rowTop + row.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    final limit = math.min(viewportBottom, _sheetTop ?? viewportBottom);

    final double delta;
    if (rowBottom > limit) {
      delta = rowBottom - limit;
    } else if (rowTop < viewportTop) {
      delta = rowTop - viewportTop;
    } else {
      return;
    }
    final position = _scroll.position;
    final offset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(offset);
    } else {
      unawaited(
        _scroll.animateTo(
          offset,
          duration: _revealDuration,
          curve: Curves.easeOut,
        ),
      );
    }
  }

  /// Entrée ou « Créer « … » » dans la popup : l'article actif de ce nom,
  /// sinon créé au catalogue (Divers, sans unité, AD-17), puis ajouté comme
  /// ingrédient. Rend l'article ajouté, nul s'il l'était déjà ; un échec
  /// lève une erreur et n'écrit rien.
  Future<CatalogueArticle?> _create(String text) async {
    final article = await ref.read(creerArticleProvider)(text);
    if (!mounted) return null;
    return _addArticle(article) ? article : null;
  }

  /// Glissé vers la gauche : l'ingrédient quitte le brouillon, avec un
  /// snackbar Annuler qui le remet à sa place.
  void _remove(IngredientDraft ingredient) {
    if (_saving) return;
    final index = _ingredients.indexOf(ingredient);
    if (index < 0) return;
    setState(() {
      _ingredients.removeAt(index);
      _menus.remove(ingredient.id);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(StringsFr.ingredientRetire(ingredient.name)),
          action: SnackBarAction(
            label: StringsFr.annuler,
            onPressed: () {
              if (!mounted || _saving) return;
              setState(
                () => _ingredients.insert(
                  math.min(index, _ingredients.length),
                  ingredient,
                ),
              );
            },
          ),
        ),
      );
  }

  /// Tag quantité (3c) : le Module quantité, puis la quantité du brouillon.
  Future<void> _editQuantity(IngredientDraft ingredient) async {
    if (_saving || _quantityOpen) return;
    _quantityOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    final QuantityEdit? edit;
    try {
      edit = await showQuantitySheet(
        context,
        title: ingredient.name,
        leading: Picto(pictoKey: ingredient.pictoKey, rayon: ingredient.rayon),
        quantity: ingredient.value?.quantity,
        unit: ingredient.value?.unit,
        initialUnit: ingredient.inputUnit,
      );
    } finally {
      _quantityOpen = false;
    }
    if (edit == null || !mounted) return;
    final value = edit.value;
    setState(() => ingredient.value = value);
  }

  /// Disque picto (3d) : ouvre ou ferme le menu des rayons sous la ligne.
  void _toggleRayonMenu(IngredientDraft ingredient) {
    if (_saving) return;
    final menu = _menus[ingredient.id];
    if (menu == null) return;
    menu.isOpen ? menu.close() : menu.open();
  }

  void _selectRayon(IngredientDraft ingredient, Rayon rayon) {
    if (_saving) return;
    setState(() => ingredient.rayon = rayon);
  }

  /// Pastille appareil photo du monogramme : Galerie, Appareil photo et,
  /// avec une photo, « Retirer la photo ».
  Future<void> _photoActions() async {
    if (_saving || _picking) return;
    final hasPhoto = _photo != null;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        Widget option(Object value, IconData icon, String label) => ListTile(
          minTileHeight: KadiSpacing.rowMinHeight,
          leading: Icon(icon, color: scheme.onSurfaceVariant),
          title: Text(label),
          onTap: () => Navigator.of(context).pop(value),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                PhotoSource.galerie,
                Icons.photo_library_outlined,
                StringsFr.galerie,
              ),
              option(
                PhotoSource.appareilPhoto,
                Icons.photo_camera_outlined,
                StringsFr.appareilPhoto,
              ),
              if (hasPhoto)
                option(
                  _RemovePhoto.value,
                  Icons.delete_outline,
                  StringsFr.retirerLaPhoto,
                ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case final PhotoSource source:
        await _pickPhoto(source);
      case _RemovePhoto.value:
        _removePhoto();
    }
  }

  /// « Ajouter un lien » ou le domaine du lien : un petit dialogue d'adresse.
  Future<void> _editLink() async {
    if (_saving) return;
    final controller = TextEditingController(text: _linkController.text);
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsFr.lien),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: StringsFr.adresseDuLien),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(StringsFr.annuler),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(StringsFr.ok),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (link == null || !mounted) return;
    setState(() => _linkController.text = link.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    // Sous la feuille d'ajout ouverte, la fiche garde de quoi faire défiler
    // sa dernière ligne au-dessus d'elle.
    final sheetTop = _sheetTop;
    final covered = sheetTop == null
        ? 0.0
        : math.max(0.0, media.size.height - media.viewInsets.bottom - sheetTop);
    final photo = _photo;
    final photosDir = photo == null
        ? null
        : ref.watch(photosDirectoryProvider).value;
    final route = ref.watch(settingsProvider).value?.routeOrder ?? Rayon.values;
    final name = _nameController.text;
    // Monogramme : rayon du premier ingrédient ; neutre sans nom.
    final monogramRayon = cleanRecipeName(name).isEmpty || _ingredients.isEmpty
        ? null
        : _ingredients.first.rayon;
    final linkUri = recipeLinkUri(_linkController.text);
    final menuWidth = media.size.width - 12 - 48;

    final monogram = RecipeMonogram(
      name: name,
      rayon: monogramRayon,
      size: MonogramSize.large,
      photo: photo == null || photosDir == null
          ? null
          : RecipePhotoImage(
              file: RecipePhotos.fileIn(photosDir, photo),
              height: MonogramSize.large.dimension,
              fallback: RecipeMonogram(
                name: name,
                rayon: monogramRayon,
                size: MonogramSize.large,
              ),
            ),
      onPhotoTap: _photoActions,
      photoSemanticLabel: photo == null
          ? StringsFr.ajouterUnePhoto
          : StringsFr.remplacerLaPhoto,
    );

    final linkStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    );
    final link = linkUri == null
        ? TextButton.icon(
            onPressed: _editLink,
            icon: Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
            label: Text(StringsFr.ajouterUnLien, style: linkStyle),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, KadiSpacing.touchTarget),
              alignment: AlignmentDirectional.centerStart,
            ),
          )
        : Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: _editLink,
                  icon: Icon(
                    Icons.link,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  label: Text(
                    linkUri.host.isEmpty ? _linkController.text : linkUri.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: linkStyle,
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, KadiSpacing.touchTarget),
                  ),
                ),
              ),
              IconButton(
                tooltip: StringsFr.ouvrirLeLien,
                onPressed: _openLink,
                icon: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        KadiSpacing.s1,
        KadiSpacing.margin,
        KadiSpacing.s1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          monogram,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: StringsFr.nomDeLaRecette,
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    autofocus: widget.recipeId == null,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    maxLines: null,
                    style: KadiText.recipeName.copyWith(
                      color: scheme.onSurface,
                    ),
                    // « Enregistrer » et le monogramme suivent le nom.
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.only(top: 8),
                      hint: ExcludeSemantics(
                        child: Text(
                          StringsFr.nomDeLaRecette,
                          style: KadiText.recipeName.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                link,
              ],
            ),
          ),
        ],
      ),
    );

    final section = Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        26 - KadiSpacing.s2,
        KadiSpacing.margin,
        KadiSpacing.s1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              StringsFr.ingredients,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          Text(
            '${_ingredients.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final addField = Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        14,
        KadiSpacing.margin,
        0,
      ),
      child: Semantics(
        container: true,
        button: true,
        label: StringsFr.ajouterUnIngredient,
        excludeSemantics: true,
        onTap: _openSheet,
        child: Material(
          color: scheme.surfaceContainer,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _openSheet,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: KadiSpacing.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KadiSpacing.margin,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 22, color: scheme.onSurface),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        StringsFr.ajouterUnIngredientEllipse,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final body = !_loaded || _missing
        ? const SizedBox.shrink()
        // Toutes les lignes sont bâties : la ligne ajoutée se mesure et se
        // montre, même hors de l'écran.
        : SingleChildScrollView(
            key: _viewportKey,
            controller: _scroll,
            padding: EdgeInsets.only(bottom: KadiSpacing.s6 + covered),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                section,
                for (final ingredient in _ingredients)
                  RayonMenuAnchor(
                    key: ingredient.rowKey,
                    controller: _menus.putIfAbsent(
                      ingredient.id,
                      MenuController.new,
                    ),
                    route: route,
                    current: ingredient.rayon,
                    onSelected: (rayon) => _selectRayon(ingredient, rayon),
                    width: menuWidth,
                    // Sous la ligne, à 12 dp de la gauche de l'écran.
                    alignmentOffset: const Offset(12, 0),
                    child: IngredientRow(
                      ingredient: ingredient,
                      onPictoTap: () => _toggleRayonMenu(ingredient),
                      onQuantityTap: () => _editQuantity(ingredient),
                      onRemove: () => _remove(ingredient),
                    ),
                  ),
                addField,
              ],
            ),
          );

    // Le retour passe par [_onBack] : confirmation si la fiche est modifiée.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (_saved)
              PopupMenuButton<_FicheAction>(
                tooltip: StringsFr.plusDOptions,
                padding: const EdgeInsets.all(KadiSpacing.s3),
                icon: Icon(Icons.more_vert, color: scheme.onSurface),
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _FicheAction.supprimer,
                    child: Text(StringsFr.supprimerLaRecette),
                  ),
                ],
              ),
            const SizedBox(width: KadiSpacing.s2),
          ],
        ),
        // Pendant l'écriture, la fiche est inerte au toucher ; les actions
        // TalkBack sont ignorées par leurs gestionnaires.
        body: AbsorbPointer(absorbing: _saving, child: body),
        // « Enregistrer » : clavier ouvert, il reste visible juste au-dessus ;
        // grisé sans nom ou sans ingrédient.
        bottomNavigationBar: !_loaded || _missing
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KadiSpacing.margin,
                      KadiSpacing.s2,
                      KadiSpacing.margin,
                      KadiSpacing.margin,
                    ),
                    child: FilledButton(
                      onPressed: _canSave && !_saving ? _save : null,
                      child: const Text(StringsFr.enregistrer),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Actions du menu ⋮ de la Fiche recette.
enum _FicheAction { supprimer }

/// Choix « Retirer la photo » de la pastille appareil photo.
enum _RemovePhoto { value }

/// La recette a été supprimée pendant l'enregistrement : la transaction est
/// annulée.
class _NotSaved implements Exception {
  const _NotSaved();
}
