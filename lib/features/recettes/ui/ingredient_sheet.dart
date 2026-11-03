import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart' show PanelHandle;
import 'package:material_ui/material_ui.dart';

import 'fiche_recette_rows.dart';

/// Résultats visibles pendant la saisie.
const _maxResultRows = 3;

/// Part maximale de la zone libre prise par la popup : la fiche reste
/// visible au-dessus.
const _sheetMaxShare = 2 / 3;

/// Écart entre la carte de la popup et les bords de l'écran ou le clavier.
const _sheetInset = KadiSpacing.s2;

/// Annonce TalkBack : la fiche est inaccessible sous la popup.
Future<void> _announce(FlutterView view, String message) =>
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);

/// Ouvre la popup d'ajout d'ingrédient au-dessus de la Fiche recette, qui
/// reste visible derrière ; rendue quand elle se ferme (glissement vers le
/// bas, tap hors du panneau ou retour).
///
/// [inRecipe] dit si un article est déjà ingrédient ; [onAdd] ajoute un
/// article en dernier ingrédient et rend `false` s'il l'est déjà ;
/// [onCreate] crée au catalogue l'article du texte tapé (ou prend l'article
/// actif de ce nom), l'ajoute et le rend, nul s'il était déjà ingrédient ;
/// il lève une erreur en cas d'échec. [onTop] reçoit le haut de la carte en
/// coordonnées globales à chaque changement. [ficheMessenger] montre une
/// erreur arrivée après la fermeture.
Future<void> showIngredientSheet(
  BuildContext context, {
  required bool Function(String articleId) inRecipe,
  required bool Function(CatalogueArticle article) onAdd,
  required Future<CatalogueArticle?> Function(String text) onCreate,
  required ValueChanged<double> onTop,
  ScaffoldMessengerState? ficheMessenger,
}) => showModalBottomSheet<void>(
  context: context,
  // Comme le Panneau + : la barrière couvre tout l'écran, son voile léger
  // garde la fiche visible et inerte, un tap hors du panneau le ferme.
  useRootNavigator: true,
  barrierColor: Theme.of(context).colorScheme.scrim,
  isScrollControlled: true,
  useSafeArea: true,
  // La feuille ne fait que porter la carte flottante de la popup.
  backgroundColor: Colors.transparent,
  elevation: 0,
  builder: (_) => IngredientSheet(
    inRecipe: inRecipe,
    onAdd: onAdd,
    onCreate: onCreate,
    onTop: onTop,
    ficheMessenger: ficheMessenger,
  ),
);

/// Popup d'ajout d'ingrédient de la Fiche recette, sur le principe du
/// Panneau + de la Liste : carte flottante au-dessus du clavier, poignée,
/// champ « Ajouter un ingrédient » focalisé et, dès qu'un texte est saisi,
/// les résultats du catalogue (Picto, nom, rayon, indicateur ; coche pour un
/// article déjà ingrédient, dont le tap ne fait rien).
///
/// Un tap sur un résultat l'ajoute en dernier ingrédient. Entrée ajoute le
/// texte tapé : l'article de ce nom exact (casse et accents ignorés), sinon
/// un article créé au catalogue (Divers, sans unité) ; sans résultat exact,
/// une ligne « Créer « … » » fait comme Entrée. Texte vide : rien. Après
/// chaque ajout le champ se vide, le clavier et la popup restent ouverts
/// pour enchaîner, et TalkBack annonce « Haricots rouges ajouté ». Un échec
/// montre un snackbar dans la popup et garde la saisie.
///
/// Ni Tag Quantité, ni Tag Rayon, ni fréquents : la quantité se saisit dans
/// la fiche, si on le veut. Sa hauteur suit le contenu : le champ seul, puis
/// jusqu'à trois résultats.
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

  /// Un ajout par Entrée ou « Créer « … » » est en cours : un second est
  /// ignoré.
  bool _submitting = false;

  /// Messager propre à la popup : ses snackbars restent au-dessus de la
  /// barrière.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Le champ, mesuré après chaque frame ; nul avant la première.
  final _fieldKey = GlobalKey();
  double? _fieldHeight;

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  /// Article au nom exact de [text] (casse et accents ignorés, AD-17) parmi
  /// [results].
  static CatalogueArticle? _exactIn(
    List<CatalogueArticle> results,
    String text,
  ) {
    final normalized = normalizeName(text);
    return results
        .where((article) => normalizeName(article.name) == normalized)
        .firstOrNull;
  }

  /// Snackbar d'erreur dans la popup, ou sur la fiche si elle est fermée.
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
    unawaited(
      _announce(View.of(context), StringsFr.ingredientAjoute(article.name)),
    );
  }

  /// Entrée ou « Créer « … » » : l'article de ce nom exact, sinon créé au
  /// catalogue, puis ajouté. Un texte vide ne fait rien ; un échec garde la
  /// saisie.
  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _submitting) return;
    final exact = _exactIn(_lastResults, text);
    if (exact != null) {
      _add(exact);
      return;
    }
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
      // Une frappe pendant la création est gardée.
      setState(() {
        if (_controller.text == text) _controller.clear();
      });
    }
    await _announce(view, StringsFr.ingredientAjoute(article.name));
  }

  /// Après la frame : mesure le champ (son texte indicatif passe à la ligne
  /// en grande police) et publie le haut [top] de la carte, tant que la
  /// popup n'est pas en train de se fermer.
  void _afterLayout(double top) {
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || route?.isActive == false) return;
      final box = _fieldKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.height != _fieldHeight) {
        // La hauteur et le haut suivent à la frame suivante.
        setState(() => _fieldHeight = box.size.height);
        return;
      }
      widget.onTop(top);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _controller.text;
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
    final showCreate = fresh != null && _exactIn(fresh, query) == null;
    final count = results.length + (showCreate ? 1 : 0);

    // La feuille retire les marges de son MediaQuery ; la vue les garde.
    final view = MediaQueryData.fromView(View.of(context));
    final keyboardOpen = media.viewInsets.bottom > 0;
    final free =
        media.size.height -
        media.viewInsets.bottom -
        view.padding.top -
        kToolbarHeight;
    // Le champ n'est jamais coupé ; les résultats prennent le reste, jusqu'à
    // trois lignes et aux deux tiers de la zone libre.
    final chrome =
        KadiSpacing.panelHandleHeight +
        (_fieldHeight ?? media.textScaler.scale(KadiSpacing.addFieldHeight));
    final rows = searching
        ? math.min(count, _maxResultRows).clamp(1, _maxResultRows)
        : 0;
    final wanted = searching
        ? rows * media.textScaler.scale(KadiSpacing.rowMinHeight) +
              KadiSpacing.s2
        : 0.0;
    // Au moins une ligne de résultat, même sur un petit écran.
    final resultsHeight = searching
        ? math.max(
            math.min(wanted, free * _sheetMaxShare - chrome),
            media.textScaler.scale(KadiSpacing.rowMinHeight),
          )
        : 0.0;
    final height = chrome + resultsHeight;
    // Clavier fermé, la carte reste au-dessus de la barre de gestes.
    final bottom =
        (keyboardOpen ? media.viewInsets.bottom : view.padding.bottom) +
        _sheetInset;
    _afterLayout(media.size.height - bottom - height);

    final fieldStyle = theme.textTheme.titleLarge;
    final field = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: KadiSpacing.margin,
        end: KadiSpacing.s1,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: KadiSpacing.addFieldHeight,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            label: StringsFr.ajouterUnIngredient,
            child: TextField(
              controller: _controller,
              focusNode: _fieldFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              textAlignVertical: TextAlignVertical.center,
              style: fieldStyle?.copyWith(color: scheme.onSurface),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              // Le clavier reste ouvert après Entrée.
              onEditingComplete: () {},
              decoration: InputDecoration(
                // Sans fond ni icône : le texte posé sur la carte.
                filled: false,
                contentPadding: EdgeInsets.zero,
                // Lu par le libellé du champ, une seule fois.
                // Entier, sur plusieurs lignes en grande police ; retiré dès
                // la saisie, il ne garde pas sa hauteur sous le texte et
                // laisse la place aux résultats.
                hint: query.isEmpty
                    ? ExcludeSemantics(
                        child: Text(
                          StringsFr.ajouterUnIngredient,
                          style: fieldStyle?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : null,
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
      ),
    );

    // Messager et Scaffold propres à la popup : la feuille vit sur le
    // navigateur racine, au-dessus du Scaffold de la fiche. La hauteur exclut
    // déjà le clavier : le Scaffold ne se redimensionne pas.
    return Padding(
      padding: EdgeInsets.fromLTRB(_sheetInset, 0, _sheetInset, bottom),
      child: SizedBox(
        height: height,
        child: Material(
          // Sans ombre ni contour : le voile sur la fiche suffit à la détacher.
          color: scheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(KadiRadius.xl)),
          ),
          child: ScaffoldMessenger(
            key: _messengerKey,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              // Le champ mesuré change la hauteur une frame plus tard : la
              // différence est coupée le temps de cette frame, sans débord.
              body: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PanelHandle(),
                    KeyedSubtree(key: _fieldKey, child: field),
                    if (searching)
                      SizedBox(
                        height: resultsHeight,
                        child: ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(
                            bottom: KadiSpacing.s2,
                          ),
                          itemCount: count,
                          itemBuilder: (_, i) {
                            if (i == results.length) {
                              return CreateArticleRow(
                                key: const ValueKey(CreateArticleRow),
                                name: query.trim(),
                                onTap: _submit,
                              );
                            }
                            final article = results[i];
                            return IngredientResultRow(
                              key: ValueKey(article.id),
                              article: article,
                              inRecipe: widget.inRecipe(article.id),
                              onTap: () => _add(article),
                            );
                          },
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
  }
}
