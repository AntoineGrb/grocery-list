import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/app/actions/ajout_panneau.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_sheet.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_panel.dart';
import '../state/liste_providers.dart';
import 'add_sheet_rows.dart';
import 'quantity_input.dart';
import 'quantity_tag.dart';
import 'rayon_tag.dart';

/// Dernier Annuler montré dans le Panneau +, repris par la Liste quand le
/// panneau se ferme avant la fin de son snackbar (AD-10).
class PanelUndo {
  UndoEntry? entry;
  String message = '';
}

/// Haut du panneau toujours visible, hors tags : poignée et Champ d'ajout.
const _panelFieldHeight =
    KadiSpacing.panelHandleHeight + KadiSpacing.addFieldHeight;

/// Fréquents visibles clavier fermé : la moitié de la dernière ligne dit
/// qu'ils défilent. Les tests qui touchent tous les fréquents l'augmentent.
@visibleForTesting
double addPanelFrequentRows = 4.5;

/// Résultats visibles pendant la saisie.
const _maxResultRows = 3;

/// Part maximale de la zone libre prise par le panneau : la Liste reste
/// toujours visible au-dessus.
const _panelMaxShare = 2 / 3;

/// Écart entre la carte du panneau et les bords de l'écran ou le clavier.
const _panelInset = 0.0;

/// Hauteur de la carte du Panneau + pour [rows] lignes de contenu sous les
/// tags (titre compris), bornée aux deux tiers de la zone libre (écran −
/// clavier − marge haute − Barre d'application) de [media], dont
/// `padding.top` doit porter la marge haute de l'écran.
///
/// [tagsHeight] est la hauteur mesurée de la rangée des tags : une rangée
/// d'une cible tactile, deux quand le Tag Rayon passe à la ligne en grande
/// police ou sur un nom de rayon long.
double addPanelHeight(
  MediaQueryData media, {
  required double rows,
  double tagsHeight = KadiSpacing.touchTarget,
}) {
  final free =
      media.size.height -
      media.viewInsets.bottom -
      media.padding.top -
      kToolbarHeight;
  final chrome = _panelFieldHeight + tagsHeight;
  final row = media.textScaler.scale(KadiSpacing.rowMinHeight);
  final wanted = chrome + rows * row;
  return math.max(math.min(wanted, free * _panelMaxShare), chrome);
}

/// Annonce TalkBack : la Liste est inaccessible sous le panneau.
Future<void> _announce(FlutterView view, String message) =>
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);

/// Ouvre le Panneau + sur la Liste, qui reste visible au-dessus de lui.
///
/// [context] est sous le messager de la Liste : un Annuler encore possible
/// à la fermeture du panneau y est remontré ; sinon l'emplacement est vidé.
Future<void> showAddSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final undo = container.read(undoProvider);
  final panel = container.read(listePanelProvider);
  final pending = PanelUndo();
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    // La barrière couvre toute l'app, Barre de navigation comprise ; son voile
    // léger assombrit un peu la Liste, qu'elle garde visible et inerte, et un
    // tap hors du panneau le ferme toujours.
    useRootNavigator: true,
    barrierColor: Theme.of(context).colorScheme.scrim,
    isScrollControlled: true,
    useSafeArea: true,
    // La feuille ne fait que porter la carte flottante du panneau.
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => AddSheet(pendingUndo: pending, listMessenger: messenger),
  );
  panel.close();
  final entry = pending.entry;
  if (entry == null) return;
  if (context.mounted && undo.canUndo(entry)) {
    showUndoSnackBar(context, pending.message, entry);
  } else {
    undo.clear(entry);
  }
}

/// Panneau + : carte flottante au-dessus du clavier, sans bordure. Poignée,
/// Champ d'ajout focalisé, Tag Quantité, Tag Rayon et bouton Valider, puis
/// le titre « Ajouts fréquents » et les fréquents en liste plate dans l'ordre
/// du parcours, sans En-tête de rayon, ou les résultats dès qu'un texte est
/// saisi. Un tap ajoute l'article, ou le retire s'il est déjà dans la liste
/// (avec Annuler). Reste ouvert après un ajout pour enchaîner.
///
/// Entrée ajoute le texte tapé (R25) : l'article de ce nom, sinon un article
/// hors catalogue (Divers, sans unité) ; déjà dans la liste, rien ne change
/// et la Liste montre sa ligne. Le champ se vide et le clavier reste ouvert.
/// Sans résultat, une seule ligne « Ajouter « … » » fait comme Entrée.
///
/// Les tags (R28) sont un brouillon d'écran, jamais écrit avant l'ajout : ils
/// s'appliquent à Entrée et au tap sur un résultat hors liste, puis reviennent
/// à zéro ; déjà dans la liste, Entrée remplace la quantité et le rayon de sa
/// plus ancienne ligne non cochée. Un tap sur un fréquent, ou sur un résultat
/// qui retire, les laisse intacts.
///
/// Rien ne se déplie après un ajout : l'article se voit dans la Liste,
/// au-dessus du panneau (AD-19). Dans la liste, une ligne (fréquent ou
/// résultat) montre un tag quantité à gauche de sa coche, qui ouvre la Popup
/// quantité de sa plus ancienne ligne non cochée (R26, AD-13) ; le panneau
/// reste ouvert dessous et son messager montre les erreurs. Aucune feuille ne
/// s'ouvre depuis le panneau.
///
/// Sa hauteur suit le contenu : clavier ouvert, seul le titre des fréquents
/// dépasse ; clavier fermé, quelques fréquents ; pendant la saisie, jusqu'à
/// trois résultats. Il publie sa géométrie à la Liste dans [ListePanel] à
/// chaque changement.
class AddSheet extends ConsumerStatefulWidget {
  const AddSheet({super.key, this.pendingUndo, this.listMessenger});

  /// Reçoit le dernier Annuler du panneau tant que son snackbar est ouvert.
  final PanelUndo? pendingUndo;

  /// Messager de la Liste : erreur d'une écriture finie après la
  /// fermeture.
  final ScaffoldMessengerState? listMessenger;

  @override
  ConsumerState<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<AddSheet> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  List<CatalogueArticle> _lastResults = const [];

  /// Tag Quantité : quantité de l'ajout suivant, nulle sans quantité.
  StoredQuantity? _draftQuantity;

  /// Tag Rayon : rayon choisi pour l'ajout suivant, nul tant qu'aucun ne l'est.
  Rayon? _draftRayon;

  /// Articles dont l'écriture est en cours : un second tap est ignoré.
  final _pending = <String>{};

  /// Un ajout par Entrée est en cours : une seconde Entrée est ignorée.
  bool _submitting = false;

  /// Messager propre au panneau.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Le Module quantité est ouvert : un second tag est ignoré.
  bool _quantityOpen = false;

  /// ⚡ Fréquents (V2 2g) : le clavier se ferme et les fréquents s'affichent
  /// en pastilles ; sinon, rien sous les tags sans saisie.
  bool _frequentsOpen = false;

  /// ⚡ Fréquents : bascule entre les fréquents et le clavier.
  void _toggleFrequents() {
    setState(() => _frequentsOpen = !_frequentsOpen);
    if (_frequentsOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      _fieldFocus.requestFocus();
    }
  }

  /// Hauteur de la rangée des tags à la dernière mesure : une cible tactile
  /// avant la première, puis ce que la rangée occupe vraiment.
  double? _tagsHeight;

  /// Rangée des tags mesurée à [height] : le budget du panneau la suit, pour
  /// que la rangée passée sur deux lignes ne prenne pas la place des
  /// résultats.
  void _onTagsHeight(double height) {
    if (!mounted || height == _tagsHeight) return;
    setState(() => _tagsHeight = height);
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  /// Snackbar [message] dans le panneau, ou sur la Liste s'il est fermé.
  void _showMessage(String message) {
    final panel = _messengerKey.currentState;
    final messenger = panel != null && panel.mounted
        ? panel
        : widget.listMessenger;
    if (messenger == null) return;
    showErrorSnackBar(messenger, message);
  }

  /// Article du catalogue au nom exact de [text] (casse et accents ignorés,
  /// AD-17), parmi les derniers résultats.
  CatalogueArticle? _exactArticle(String text) {
    final normalized = normalizeName(text);
    return _lastResults
        .where((article) => normalizeName(article.name) == normalized)
        .firstOrNull;
  }

  /// Remet à zéro les tags consommés par un ajout de [quantity] et [rayon] ;
  /// un tag réglé pendant l'écriture vaut pour l'ajout d'après.
  void _clearTags(StoredQuantity? quantity, Rayon? rayon) {
    if (_draftQuantity == quantity) _draftQuantity = null;
    if (_draftRayon == rayon) _draftRayon = null;
  }

  /// Entrée ou « Ajouter « … » » : ajoute le texte tapé avec les tags (R25,
  /// R28) puis vide le champ ; déjà dans la liste, demande à la Liste de
  /// montrer sa ligne. Un texte vide ne fait rien ; un échec garde la saisie
  /// et les tags.
  Future<void> _addTyped() async {
    final text = _controller.text;
    // Une seule écriture consomme les tags à la fois.
    if (text.trim().isEmpty || _submitting || _pending.isNotEmpty) return;
    _submitting = true;
    final quantity = _draftQuantity;
    final rayon = _draftRayon;
    final view = View.of(context);
    final panel = ref.read(listePanelProvider);
    final TexteAjoute result;
    try {
      result = await ref
          .read(ajouterTexteProvider)
          .call(
            text,
            quantity: quantity?.quantity,
            unit: quantity?.unit,
            rayon: rayon,
          );
    } catch (_) {
      _showMessage(StringsFr.ajoutImpossible);
      return;
    } finally {
      _submitting = false;
    }
    if (mounted) {
      if (!result.ajoute) panel.reveal(result.lineId);
      setState(() {
        // Une frappe pendant l'écriture est gardée.
        if (_controller.text == text) _controller.clear();
        _clearTags(quantity, rayon);
      });
    }
    final article = result.article;
    await _announce(
      view,
      result.ajoute
          ? StringsFr.ajouteAnnonce(
              article.name,
              (rayon ?? article.rayon).spokenLabel,
            )
          : quantity != null || rayon != null
          ? StringsFr.modifieAnnonce(article.name)
          : StringsFr.dansLaListeAnnonce(article.name),
    );
  }

  /// Ajoute [article], avec les tags si [withTags], ou le retire s'il est dans
  /// la liste (AD-4), avec le snackbar Annuler (AD-10).
  ///
  /// [context] est sous le messager du panneau : ses snackbars s'affichent
  /// dans le panneau, au-dessus de la barrière.
  Future<void> _toggle(
    BuildContext context,
    CatalogueArticle article, {
    bool withTags = false,
  }) async {
    // Une seule écriture consomme les tags à la fois.
    if (withTags && (_submitting || _pending.isNotEmpty)) return;
    // État « dans la liste » pas encore connu : le tap est ignoré.
    final inListIds = ref.read(inListProvider).value;
    if (inListIds == null || !_pending.add(article.id)) return;
    try {
      if (inListIds.contains(article.id)) {
        await _remove(context, article);
      } else {
        await _add(context, article, withTags: withTags);
      }
    } finally {
      _pending.remove(article.id);
    }
  }

  Future<void> _add(
    BuildContext context,
    CatalogueArticle article, {
    required bool withTags,
  }) async {
    final quantity = withTags ? _draftQuantity : null;
    final rayon = withTags ? _draftRayon : null;
    final text = _controller.text;
    final messenger = ScaffoldMessenger.of(context);
    final view = View.of(context);
    try {
      await ref
          .read(ajouterArticleProvider)
          .call(
            article.id,
            quantity: quantity?.quantity,
            unit: quantity?.unit,
            rayon: rayon,
          );
    } catch (_) {
      // Le panneau a pu se fermer pendant l'écriture.
      showErrorSnackBar(messenger, StringsFr.ajoutImpossible);
      return;
    }
    // Un résultat ajouté vide aussi le champ, comme Entrée ; une frappe
    // pendant l'écriture est gardée.
    if (mounted && withTags) {
      setState(() {
        _clearTags(quantity, rayon);
        if (_controller.text == text) _controller.clear();
      });
    }
    await _announce(
      view,
      StringsFr.ajouteAnnonce(
        article.name,
        (rayon ?? article.rayon).spokenLabel,
      ),
    );
  }

  Future<void> _remove(BuildContext context, CatalogueArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<UndoRow> rows;
    try {
      rows = await ref.read(listeRepositoryProvider).removeArticle(article.id);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
      return;
    }
    if (!context.mounted) return;
    _showUndo(context, rows, StringsFr.retireDeLaListe(article.name));
  }

  /// Tag quantité de [line] : ouvre la Popup quantité et écrit ce qui a changé
  /// (AD-5) ; une erreur s'affiche dans le panneau.
  Future<void> _editQuantity(ListeItem line) async {
    if (_quantityOpen) return;
    _quantityOpen = true;
    final repository = ref.read(listeRepositoryProvider);
    final QuantityEdit? edit;
    try {
      edit = await showQuantitySheet(
        context,
        title: line.name,
        leading: Picto(pictoKey: '', rayon: line.rayon),
        quantity: line.quantity,
        unit: line.unit,
        initialUnit: initialInputUnit(line),
      );
    } finally {
      _quantityOpen = false;
    }
    if (edit == null) return;
    final value = edit.value;
    try {
      await repository.setQuantity(
        line.lineId,
        value?.quantity,
        unit: value?.unit,
      );
    } catch (_) {
      _showMessage(StringsFr.modificationImpossible);
    }
  }

  /// Tag Quantité : ouvre la Popup quantité sur le brouillon, sans rien écrire,
  /// puis rend le focus au Champ d'ajout.
  Future<void> _editDraftQuantity() async {
    if (_quantityOpen) return;
    _quantityOpen = true;
    final text = _controller.text.trim();
    final draft = _draftQuantity;
    final exact = _exactArticle(text);
    final unit = draft?.unit ?? exact?.unit;
    final QuantityEdit? edit;
    try {
      edit = await showQuantitySheet(
        context,
        title: text.isEmpty ? StringsFr.quantite : text,
        leading: Picto(
          pictoKey: exact?.pictoKey ?? '',
          rayon: _draftRayon ?? exact?.rayon ?? Rayon.divers,
        ),
        quantity: draft?.quantity,
        unit: draft?.unit,
        initialUnit: unit == null ? InputUnit.piece : InputUnit.of(unit),
      );
    } finally {
      _quantityOpen = false;
    }
    if (!mounted) return;
    if (!_frequentsOpen) _fieldFocus.requestFocus();
    if (edit case final edit?) setState(() => _draftQuantity = edit.value);
  }

  /// Snackbar Annuler de [rows] dans le panneau (AD-10), gardé pour la
  /// Liste si le panneau se ferme avant sa fin. Rien sans ligne écrite.
  void _showUndo(BuildContext context, List<UndoRow> rows, String message) {
    if (rows.isEmpty) return;
    final entry = ref.read(undoProvider).record(rows);
    final pending = widget.pendingUndo
      ?..entry = entry
      ..message = message;
    showUndoSnackBar(context, message, entry).closed.then((_) {
      // Fermé normalement, panneau ouvert : plus rien à reprendre.
      if (pending != null && identical(pending.entry, entry)) {
        pending.entry = null;
      }
    });
  }

  /// Publie le haut [top] et la hauteur [height] du panneau après la frame.
  ///
  /// Une fois la fermeture lancée, le clavier qui se ferme reconstruit encore
  /// le panneau pendant sa descente : la route n'est plus active et il ne se
  /// rouvre pas.
  void _publishGeometry({required double top, required double height}) {
    final route = ModalRoute.of(context);
    final panel = ref.read(listePanelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || route?.isActive == false) return;
      panel.open(top: top, height: height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _controller.text;
    final searching = query.trim().isNotEmpty;
    // Garder les derniers résultats tant que la nouvelle saisie n'a pas
    // encore reçu sa première valeur, pour éviter un clignotement à chaque
    // lettre.
    final fresh = searching
        ? ref.watch(articleSearchProvider(query)).value
        : null;
    final results = searching
        ? fresh ?? _lastResults
        : const <CatalogueArticle>[];
    _lastResults = results;
    final draftQuantity = _draftQuantity;
    final draftRayon = _draftRayon;
    final quantityValue = formatQuantity(
      draftQuantity?.quantity,
      draftQuantity?.unit,
    );
    // « Ajouter « … » » attend les résultats de cette saisie : jamais
    // proposé sur des résultats périmés.
    final showAddTyped = fresh != null && fresh.isEmpty;
    final frequents = searching || !_frequentsOpen
        ? null
        : ref.watch(frequentsInRouteProvider).value;
    final route = ref.watch(settingsProvider).value?.routeOrder ?? Rayon.values;
    final inList = ref.watch(inListProvider).value ?? const <String>{};
    final lines =
        ref.watch(oldestLineByArticleProvider).value ??
        const <String, ListeItem>{};

    final keyboardOpen = media.viewInsets.bottom > 0;
    // La feuille retire les marges de son MediaQuery ; la vue les garde.
    final view = MediaQueryData.fromView(View.of(context));
    // Au repos, rien sous les tags ; fréquents ouverts, le titre et environ
    // deux pastilles par rangée.
    final double rows = searching
        ? math
              .min(results.length + (showAddTyped ? 1 : 0), _maxResultRows)
              .clamp(1, _maxResultRows)
              .toDouble()
        : _frequentsOpen
        ? 1 +
              math.min(
                ((frequents?.length ?? 0) / 2).ceilToDouble(),
                addPanelFrequentRows,
              )
        : 0;
    final height = addPanelHeight(
      media.copyWith(padding: EdgeInsets.only(top: view.padding.top)),
      rows: rows,
      // Avant la première mesure : un tag de 36 dp ou sa ligne de texte
      // agrandie, plus 12 dp de cible.
      tagsHeight:
          _tagsHeight ??
          math.max(KadiSpacing.touchTarget, media.textScaler.scale(20) + 12),
    );
    // Clavier fermé, la carte reste au-dessus de la barre de gestes.
    final bottom =
        (keyboardOpen ? media.viewInsets.bottom : view.padding.bottom) +
        _panelInset;
    final top = media.size.height - bottom - height;
    _publishGeometry(
      top: top,
      height: media.size.height - media.viewInsets.bottom - top,
    );

    // Contenu sous le Champ d'ajout ; [context] est sous le messager du
    // panneau.
    Widget content(BuildContext context) {
      if (searching) {
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          itemCount: results.length + (showAddTyped ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == results.length) {
              return AddTypedRow(
                key: const ValueKey(AddTypedRow),
                name: query.trim(),
                onTap: _addTyped,
              );
            }
            final article = results[i];
            return SearchResultRow(
              key: ValueKey(article.id),
              article: article,
              inList: inList.contains(article.id),
              line: lines[article.id],
              onTap: () => _toggle(context, article, withTags: true),
              onQuantityTap: _editQuantity,
            );
          },
        );
      }
      return switch (frequents) {
        null => const SizedBox.shrink(),
        [] => const EmptyState(message: StringsFr.pasDeFrequents),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          children: [
            const FrequentsTitle(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KadiSpacing.margin,
              ),
              child: Wrap(
                spacing: KadiSpacing.s2,
                children: [
                  for (final article in frequents)
                    FrequentChip(
                      key: ValueKey(article.id),
                      article: article,
                      inList: inList.contains(article.id),
                      onTap: () => _toggle(context, article),
                    ),
                ],
              ),
            ),
          ],
        ),
      };
    }

    // Messager et Scaffold propres au panneau : la feuille vit sur le
    // navigateur racine, au-dessus du Scaffold de la Liste, dont les
    // snackbars resteraient sous la barrière. La hauteur exclut déjà le
    // clavier : le Scaffold ne se redimensionne pas. Le fond reste celui de
    // la feuille.
    final fieldStyle = theme.textTheme.titleLarge;
    return Padding(
      padding: EdgeInsets.fromLTRB(_panelInset, 0, _panelInset, bottom),
      child: SizedBox(
        height: height,
        child: Material(
          // Panneau en bas de l'écran (V2 2f) : rayon 28 en haut seulement.
          color: scheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(KadiRadius.xl),
            ),
          ),
          child: ScaffoldMessenger(
            key: _messengerKey,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const PanelHandle(),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: KadiSpacing.margin,
                        end: KadiSpacing.s1,
                      ),
                      child: SizedBox(
                        height: KadiSpacing.addFieldHeight,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _fieldFocus,
                                autofocus: true,
                                textInputAction: TextInputAction.done,
                                // Majuscule en début de saisie, comme une liste.
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textAlignVertical: TextAlignVertical.center,
                                style: fieldStyle?.copyWith(
                                  color: scheme.onSurface,
                                ),
                                // Retaper dans le champ referme les fréquents.
                                onTap: () {
                                  if (_frequentsOpen) {
                                    setState(() => _frequentsOpen = false);
                                  }
                                },
                                onChanged: (_) =>
                                    setState(() => _frequentsOpen = false),
                                onSubmitted: (_) => _addTyped(),
                                // Le clavier reste ouvert après Entrée.
                                onEditingComplete: () {},
                                decoration: InputDecoration(
                                  // Sans fond ni icône : le texte posé sur la carte.
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: StringsFr.ajouterUnArticle,
                                  hintStyle: fieldStyle?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  suffixIcon: query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: StringsFr.effacerLeTexte,
                                          icon: const Icon(Icons.close),
                                          onPressed: () =>
                                              setState(_controller.clear),
                                        ),
                                ),
                              ),
                            ),
                            _SendButton(
                              onPressed: searching ? _addTyped : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Les puces s'alignent sur le Champ d'ajout, leur pourtour
                    // tappable déborde dans la marge ; Valider fait comme
                    // Entrée, au bout de la rangée. Sa hauteur mesurée entre
                    // dans celle du panneau.
                    _HeightReporter(
                      onHeight: _onTagsHeight,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: KadiSpacing.margin - 3,
                          end: KadiSpacing.s1,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                // Une seule rangée, sans retour à la ligne
                                // (V2 2f) : elle défile si la place manque.
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      PanelQuantityTag(
                                        value: quantityValue,
                                        emptyLabel: StringsFr.quantite,
                                        semanticLabel: StringsFr.quantiteTag(
                                          quantityValue,
                                        ),
                                        onTap: _editDraftQuantity,
                                      ),
                                      RayonTag(
                                        rayon:
                                            draftRayon ??
                                            _exactArticle(query)?.rayon ??
                                            Rayon.divers,
                                        chosen: draftRayon != null,
                                        route: route,
                                        onSelected: (rayon) =>
                                            setState(() => _draftRayon = rayon),
                                      ),
                                      AddTag(
                                        color: _frequentsOpen
                                            ? scheme.onSurface
                                            : scheme.surfaceContainerHigh,
                                        selected: _frequentsOpen,
                                        semanticLabel: StringsFr.frequents,
                                        onTap: _toggleFrequents,
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: 6,
                                              end: 10,
                                            ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bolt,
                                              size: 18,
                                              color: _frequentsOpen
                                                  ? scheme.surface
                                                  : scheme.onSurface,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              StringsFr.frequents,
                                              style: addTagTextStyle(
                                                context,
                                                _frequentsOpen
                                                    ? scheme.surface
                                                    : scheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: content(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Remonte la hauteur de [child] après chaque mise en page où elle change,
/// une fois la frame finie.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

/// Bouton d'envoi du Panneau + (V2 2f) : 40 × 40, rayon 12, flèche vers le
/// haut ; grisé quand le champ est vide, argile quand il est rempli. Fait
/// comme Entrée.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return IconButton(
      tooltip: StringsFr.envoyer,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.surfaceContainerHigh,
        disabledForegroundColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KadiRadius.md)),
        ),
      ),
      icon: Icon(
        Icons.arrow_upward,
        size: 24,
        color: enabled ? scheme.onPrimary : scheme.outline,
      ),
    );
  }
}
