import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/app/actions/ajout_panneau.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
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
import 'quantity_popup.dart';
import 'quantity_tag.dart';
import 'rayon_tag.dart';

/// Dernier Annuler montré dans le Panneau +, repris par la Liste quand le
/// panneau se ferme avant la fin de son snackbar (AD-10).
class PanelUndo {
  UndoEntry? entry;
  String message = '';
}

/// Part de la zone libre prise par le Panneau + ; le reste montre la Liste.
const _panelFreeZoneShare = 2 / 3;

/// Hauteur minimale du panneau : poignée, Champ d'ajout, tags, une ligne.
const _panelMinHeight =
    KadiSpacing.panelHandleHeight +
    KadiSpacing.touchTarget +
    KadiSpacing.touchTarget +
    KadiSpacing.rowMinHeight;

/// Sans voile, seule l'ombre détache le panneau de la Liste.
const _panelElevation = 8.0;

/// Hauteur du Panneau + au-dessus du clavier : environ deux tiers de la zone
/// libre (écran − clavier − marge haute − Barre d'application) de [media],
/// dont `padding.top` doit porter la marge haute de l'écran.
double addPanelHeight(MediaQueryData media) {
  final free =
      media.size.height -
      media.viewInsets.bottom -
      media.padding.top -
      kToolbarHeight;
  return math.max(free * _panelFreeZoneShare, _panelMinHeight);
}

/// Forme du panneau : haut arrondi, filet sur le seul bord haut.
class _TopOutlineBorder extends RoundedRectangleBorder {
  const _TopOutlineBorder({required super.side})
    : super(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KadiRadius.xl),
        ),
      );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    const radius = Radius.circular(KadiRadius.xl);
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + KadiRadius.xl)
        ..arcToPoint(
          Offset(rect.left + KadiRadius.xl, rect.top),
          radius: radius,
        )
        ..lineTo(rect.right - KadiRadius.xl, rect.top)
        ..arcToPoint(
          Offset(rect.right, rect.top + KadiRadius.xl),
          radius: radius,
        ),
      side.toPaint(),
    );
  }
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
    // La barrière couvre toute l'app, Barre de navigation comprise ; sans
    // couleur, elle laisse voir la Liste, qu'elle garde inerte, et un tap
    // hors du panneau le ferme toujours.
    useRootNavigator: true,
    barrierColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    elevation: _panelElevation,
    shape: _TopOutlineBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
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

/// Panneau + : poignée, Champ d'ajout focalisé, Tag Quantité et Tag Rayon, puis
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
/// Le panneau se pose au-dessus du clavier et publie sa géométrie à la Liste
/// dans [ListePanel] à chaque changement.
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

  /// Une Popup quantité est ouverte : un second tag est ignoré.
  bool _quantityOpen = false;

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
    if (mounted && withTags) setState(() => _clearTags(quantity, rayon));
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
      edit = await showQuantityPopup(
        context,
        title: line.name,
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
    final unit = draft?.unit ?? _exactArticle(text)?.unit;
    final QuantityEdit? edit;
    try {
      edit = await showQuantityPopup(
        context,
        title: text.isEmpty ? StringsFr.quantite : text,
        quantity: draft?.quantity,
        unit: draft?.unit,
        initialUnit: unit == null ? InputUnit.piece : InputUnit.of(unit),
      );
    } finally {
      _quantityOpen = false;
    }
    if (!mounted) return;
    _fieldFocus.requestFocus();
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
    // La feuille retire la marge haute de son MediaQuery ; la vue la garde.
    final height = addPanelHeight(
      media.copyWith(
        padding: EdgeInsets.only(
          top: MediaQueryData.fromView(View.of(context)).padding.top,
        ),
      ),
    );
    _publishGeometry(
      top: media.size.height - media.viewInsets.bottom - height,
      height: height,
    );

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
    final frequents = searching
        ? null
        : ref.watch(frequentsInRouteProvider).value;
    final route = ref.watch(settingsProvider).value?.routeOrder ?? Rayon.values;
    final inList = ref.watch(inListProvider).value ?? const <String>{};
    final lines =
        ref.watch(oldestLineByArticleProvider).value ??
        const <String, ListeItem>{};

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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
          children: [
            const FrequentsTitle(),
            for (final article in frequents)
              FrequentRow(
                key: ValueKey(article.id),
                article: article,
                inList: inList.contains(article.id),
                line: lines[article.id],
                onTap: () => _toggle(context, article),
                onQuantityTap: _editQuantity,
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
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: KadiSpacing.margin,
                    ),
                    child: SizedBox(
                      height: KadiSpacing.touchTarget,
                      child: TextField(
                        controller: _controller,
                        focusNode: _fieldFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _addTyped(),
                        // Le clavier reste ouvert après Entrée.
                        onEditingComplete: () {},
                        decoration: InputDecoration(
                          hintText: StringsFr.ajouterUnArticle,
                          prefixIcon: const Icon(Icons.add),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: StringsFr.effacerLeTexte,
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(_controller.clear),
                                ),
                        ),
                      ),
                    ),
                  ),
                  // Les puces s'alignent sur le Champ d'ajout, leur pourtour
                  // tappable déborde dans la marge.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KadiSpacing.margin - KadiSpacing.s2,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      // En grande police, le Tag Rayon passe à la ligne.
                      child: Wrap(
                        children: [
                          QuantityTag(
                            value: quantityValue,
                            emptyLabel: StringsFr.quantite,
                            semanticLabel: StringsFr.quantiteTag(quantityValue),
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
    );
  }
}
