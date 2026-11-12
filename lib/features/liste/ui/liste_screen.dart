import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/pictos/phosphor_table.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/confirm_dialog.dart';
import 'package:kadi/core/ui/empty_state.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/tab_app_bar.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/undo/undo_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_notice.dart';
import '../state/liste_panel.dart';
import '../state/liste_providers.dart';
import 'add_sheet.dart';
import 'checked_section.dart';
import 'item_edit_sheet.dart';
import 'item_row.dart';
import 'rayon_header.dart';
import 'row_highlight.dart';
import 'size_reveal.dart';

const _revealDuration = Duration(milliseconds: 250);

/// Liste : lignes groupées par rayon dans l'ordre du parcours (ou, sans
/// groupement, dans l'ordre d'ajout, sans En-tête de rayon), Section Cochés
/// en bas, FAB + ; Bouton d'action « Terminer les courses » quand
/// tout est coché (R4).
///
/// Tant que le Panneau + est ouvert (AD-19), la Liste reste visible au-dessus
/// de lui et réserve sa hauteur en bas ; toute ligne nouvelle de son flux y
/// arrive animée et, si elle serait masquée, la Liste défile pour la montrer.
/// Toutes les lignes sont bâties, pour pouvoir atteindre une ligne hors écran.
class ListeScreen extends ConsumerStatefulWidget {
  const ListeScreen({super.key});

  @override
  ConsumerState<ListeScreen> createState() => _ListeScreenState();
}

class _ListeScreenState extends ConsumerState<ListeScreen> {
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();

  /// Messager propre à la Liste, qui montre aussi son avis (« Ta liste est
  /// prête. »).
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final ListePanel _panel;

  /// Clé de chaque ligne non cochée, pour la mesurer.
  final _lineKeys = <String, GlobalKey>{};

  /// Lignes de la dernière émission du flux ; nul avant la première.
  Set<String>? _knownLines;

  /// Lignes apparues à la dernière émission, panneau ouvert.
  final _arriving = <String>{};

  /// Nombre de surlignages demandés par ligne présente.
  final _replays = <String, int>{};

  /// Ligne à montrer après la prochaine frame.
  String? _target;

  /// Dernière ligne montrée, panneau ouvert : revérifiée quand il bouge.
  String? _lastShown;

  /// Rayon de chaque ligne à la dernière émission.
  var _lineRayons = <String, Rayon>{};

  /// Rayons affichés à la dernière émission ; nul avant la première.
  Set<Rayon>? _rayonsShown;

  /// Rayons apparus à la dernière émission, panneau fermé : leur En-tête
  /// s'ouvre en fondu.
  final _appearingRayons = <Rayon>{};

  /// Rayons devenus vides : leur En-tête se replie, puis disparaît.
  final _vanishing = <Rayon>{};

  @override
  void initState() {
    super.initState();
    _panel = ref.read(listePanelProvider)..addListener(_onPanelChanged);
    ref.listenManual(listeNoticeProvider, (_, message) {
      if (message != null) _showNotice();
    }, fireImmediately: true);
  }

  /// Montre l'avis en attente sous le messager de la Liste, puis le vide,
  /// après la frame : l'avis peut arriver avant que la Liste soit montée.
  void _showNotice() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        final messenger = _messengerKey.currentState;
        if (!mounted || messenger == null) return;
        final message = ref.read(listeNoticeProvider.notifier).take();
        if (message != null) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      })
      ..scheduleFrame();
  }

  @override
  void dispose() {
    _panel.removeListener(_onPanelChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onPanelChanged() {
    final lineId = _panel.takeReveal();
    setState(() {
      if (!_panel.isOpen) _lastShown = null;
      if (lineId != null) {
        _replays.update(lineId, (n) => n + 1, ifAbsent: () => 1);
        _target = lineId;
      } else if (_lastShown != null) {
        // Le panneau a bougé : il peut couvrir la ligne qui vient d'être
        // montrée (clavier rouvert).
        _target = _lastShown;
      }
    });
  }

  /// Compare les lignes de deux émissions du flux : sans course avec
  /// l'écriture, quel que soit l'ordre des deux (AD-19). Une ligne remise par
  /// Annuler compte comme une arrivée.
  void _onGroups(List<RayonGroup>? groups) {
    if (groups == null) return;
    final rayons = {
      for (final group in groups)
        for (final item in group.items) item.lineId: item.rayon,
    };
    // Entrée a changé le rayon de la ligne qu'elle montre (R28) : la demande
    // précède souvent cette émission, et la ligne n'est plus là où elle était.
    final shown = _lastShown;
    final was = _lineRayons[shown];
    final now = rayons[shown];
    if (was != null && now != null && was != now) _target = shown;
    _lineRayons = rayons;
    final lines = [
      for (final group in groups)
        for (final item in group.items) item.lineId,
    ];
    final previous = _knownLines;
    final known = _knownLines = lines.toSet();
    _lineKeys.removeWhere((lineId, _) => !known.contains(lineId));
    _replays.removeWhere((lineId, _) => !known.contains(lineId));
    _arriving.clear();

    final rayonsNow = {for (final group in groups) ?group.rayon};
    final rayonsBefore = _rayonsShown;
    _rayonsShown = rayonsNow;
    _appearingRayons.clear();
    if (rayonsBefore != null && !_panel.isOpen) {
      _vanishing.addAll(rayonsBefore.difference(rayonsNow));
      _appearingRayons.addAll(rayonsNow.difference(rayonsBefore));
    }
    _vanishing.removeAll(rayonsNow);

    if (previous == null || !_panel.isOpen) return;
    _arriving.addAll(known.difference(previous));
    if (_arriving.isNotEmpty) _target = lines.lastWhere(_arriving.contains);
  }

  /// Fait défiler la Liste jusqu'à montrer [_target], juste au-dessus du
  /// panneau s'il la masquait ; rien si elle est déjà entièrement visible.
  void _showTarget() {
    final lineId = _target;
    _target = null;
    if (lineId == null || !mounted || !_scroll.hasClients) return;
    _lastShown = _panel.isOpen ? lineId : null;
    final row = _lineKeys[lineId]?.currentContext?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (row is! RenderBox || viewport is! RenderBox) return;

    final rowTop = row.localToGlobal(Offset.zero).dy;
    final rowBottom = rowTop + row.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    final limit = math.min(viewportBottom, _panel.top ?? viewportBottom);

    final double delta;
    if (rowBottom > limit) {
      delta = rowBottom - limit;
    } else if (rowTop < viewportTop) {
      // La marge laisse voir l'En-tête de rayon.
      delta = rowTop - viewportTop - KadiSpacing.touchTarget - KadiSpacing.s2;
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
      _scroll.animateTo(
        offset,
        duration: _revealDuration,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _terminer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final UndoEntry? entry;
    try {
      entry = await ref.read(terminerLesCoursesProvider).call();
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.terminerImpossible);
      return;
    }
    if (entry == null || !context.mounted) return;
    showUndoSnackBar(context, StringsFr.coursesTerminees, entry);
  }

  /// Vider la liste (↻ de la Barre d'application) : Dialogue de
  /// confirmation, puis toutes les lignes, cochées ou non, et la sélection
  /// de la semaine sont retirées, comme Terminer les courses, avec Annuler.
  ///
  /// [context] est celui du `Builder` de la Liste, sous son messager.
  Future<void> _vider(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: StringsFr.viderLaListeTitre,
      message: StringsFr.viderLaListeTexte,
      keepLabel: StringsFr.garder,
      confirmLabel: StringsFr.vider,
    );
    if (!confirmed || !context.mounted) return;
    final UndoEntry? entry;
    try {
      entry = await ref.read(terminerLesCoursesProvider).call();
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.viderLaListeImpossible);
      return;
    }
    if (entry == null || !context.mounted) return;
    showUndoSnackBar(context, StringsFr.listeVidee, entry);
  }

  /// Supprime la ligne de [item] (glisser, Feuille d'édition, TalkBack) et
  /// montre le snackbar Annuler sous le messager de la Liste (AD-10).
  ///
  /// [context] est celui du `Builder` de la Liste. Rend `false` si
  /// l'écriture a échoué (snackbar d'erreur, la ligne reste) ; une ligne
  /// déjà absente rend `true` sans snackbar.
  Future<bool> _remove(BuildContext context, ListeItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(listeRepositoryProvider);
    final undo = ref.read(undoProvider);
    final List<UndoRow> rows;
    try {
      rows = await repository.removeLine(item.lineId);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.suppressionImpossible);
      return false;
    }
    if (rows.isEmpty) return true;
    final entry = undo.record(rows);
    if (context.mounted) {
      showUndoSnackBar(context, StringsFr.retireDeLaListe(item.name), entry);
    }
    return true;
  }

  /// Ouvre la Feuille d'édition de [item] ; « Supprimer » y revient ici.
  Future<void> _edit(BuildContext context, ListeItem item) async {
    final result = await showItemEditSheet(context, item);
    if (result == ItemEditResult.delete && context.mounted) {
      await _remove(context, item);
    }
  }

  /// Ligne non cochée [item], mesurable et animée à son arrivée.
  Widget _uncheckedRow(BuildContext context, ListeItem item) {
    // Une ligne décochée qui revient s'ouvre en fondu.
    final returning = ref.read(listeReturningProvider).remove(item.lineId);
    return SizeReveal(
      key: ValueKey(('row', item.lineId)),
      appear: returning,
      child: _highlightedRow(context, item),
    );
  }

  Widget _highlightedRow(BuildContext context, ListeItem item) {
    return RowHighlight(
      key: _lineKeys.putIfAbsent(item.lineId, () => GlobalKey()),
      color: KadiColors.of(context).rayon(item.rayon).pastille,
      arriving: _arriving.contains(item.lineId),
      replays: _replays[item.lineId] ?? 0,
      child: ItemRow(
        key: ValueKey(item.lineId),
        item: item,
        onRemove: () => _remove(context, item),
        onEdit: () => _edit(context, item),
      ),
    );
  }

  /// Message de liste vide, centré dans la zone libre au-dessus du panneau.
  /// [context] est au-dessus du Scaffold de la Liste : il garde la marge haute.
  Widget _emptyList(BuildContext context) {
    // Liste vide : plus d'En-tête à replier.
    _vanishing.clear();
    final bodyTop = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return LayoutBuilder(
      builder: (_, constraints) {
        final panelTop = _panel.top;
        final hidden = panelTop == null
            ? 0.0
            : math.max(0.0, bodyTop + constraints.maxHeight - panelTop);
        return Padding(
          padding: EdgeInsets.only(bottom: hidden),
          child: EmptyState(
            glyph: phosphorIcons['basket'],
            title: StringsFr.listeVideTitre,
            message: StringsFr.listeVide,
            action: OutlinedButton(
              onPressed: () => context.go(AppRoutes.recettes),
              child: const Text(StringsFr.choisirDesRecettes),
            ),
          ),
        );
      },
    );
  }

  /// Groupes de [groups] et, à leur place dans le parcours, les rayons qui
  /// se replient (sans groupe).
  List<(Rayon?, RayonGroup?)> _entries(List<RayonGroup> groups) {
    final entries = <(Rayon?, RayonGroup?)>[
      for (final group in groups) (group.rayon, group),
      for (final rayon in _vanishing) (rayon, null),
    ];
    if (_vanishing.isEmpty) return entries;
    final route = ref.read(settingsProvider).value?.routeOrder ?? Rayon.values;
    int rank((Rayon?, RayonGroup?) e) =>
        e.$1 == null ? -1 : route.indexOf(e.$1!);
    // Tri stable : l'ordre des groupes est déjà celui du parcours.
    final indexed = entries.indexed.toList()
      ..sort((a, b) {
        final byRank = rank(a.$2).compareTo(rank(b.$2));
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    return [for (final (_, e) in indexed) e];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(listeGroupsProvider, (_, next) => _onGroups(next.value));
    final groups = ref.watch(listeGroupsProvider).value;
    final checked = ref.watch(listeCheckedProvider).value;
    final empty =
        groups != null && checked != null && groups.isEmpty && checked.isEmpty;
    final allChecked =
        groups != null &&
        checked != null &&
        groups.isEmpty &&
        checked.isNotEmpty;

    if (_target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTarget());
    }

    // Messager propre à la Liste : ses snackbars s'affichent dans son
    // Scaffold, au-dessus du FAB + et du Bouton d'action, pas dans la coque.
    // Le Builder donne un contexte sous ce messager, qui reste monté quand le
    // Bouton d'action disparaît.
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: TabAppBar(
            title: StringsFr.tabListe,
            actions: [
              if (groups != null && checked != null && !empty)
                IconButton(
                  onPressed: () => _vider(context),
                  tooltip: StringsFr.viderLaListe,
                  // Cible de 48 dp.
                  padding: const EdgeInsets.all(KadiSpacing.s3),
                  color: Theme.of(context).colorScheme.onSurface,
                  icon: const Icon(Icons.restart_alt),
                ),
            ],
          ),
          body: switch ((groups, checked)) {
            (final groups?, final checked?)
                when groups.isEmpty && checked.isEmpty =>
              _emptyList(context),
            (final groups?, final checked?) => SingleChildScrollView(
              key: _viewportKey,
              controller: _scroll,
              // Toute la hauteur du panneau : la dernière ligne reste
              // atteignable, et le surplus est invisible.
              padding: EdgeInsets.only(
                bottom: _panel.height ?? KadiSpacing.listBottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Progress(
                    checked: checked.length,
                    total:
                        checked.length +
                        groups.fold(0, (n, g) => n + g.items.length),
                  ),
                  for (final (rayon, group) in _entries(groups)) ...[
                    if (group == null)
                      // Rayon devenu vide : son En-tête se replie.
                      SizeReveal(
                        key: ValueKey(('vanish', rayon)),
                        vanish: true,
                        onVanished: () =>
                            setState(() => _vanishing.remove(rayon)),
                        child: RayonHeader(rayon: rayon!),
                      )
                    else ...[
                      // Sans groupement, une seule suite de lignes, sans
                      // En-tête de rayon. Un rayon tout coché disparaît.
                      if (rayon != null)
                        SizeReveal(
                          key: ValueKey(('header', rayon)),
                          appear: _appearingRayons.contains(rayon),
                          child: RayonHeader(rayon: rayon),
                        ),
                      for (final item in group.items)
                        _uncheckedRow(context, item),
                    ],
                  ],
                  // Clé : la section garde son état quand des groupes
                  // apparaissent ou disparaissent au-dessus d'elle.
                  if (checked.isNotEmpty)
                    CheckedSection(
                      key: const ValueKey('checked-section'),
                      items: checked,
                      onRemove: (item) => _remove(context, item),
                      onEdit: (item) => _edit(context, item),
                    ),
                ],
              ),
            ),
            _ => const SizedBox.shrink(),
          },
          // Dans le Scaffold de la Liste, le FAB + remonte au-dessus du bouton.
          bottomNavigationBar: allChecked
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                    KadiSpacing.margin,
                    KadiSpacing.s2,
                  ),
                  child: FilledButton(
                    onPressed: () => _terminer(context),
                    child: const Text(StringsFr.terminerLesCourses),
                  ),
                )
              : null,
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAddSheet(context),
            child: const Icon(
              Icons.add,
              semanticLabel: StringsFr.ajouterUnArticle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Progression des courses (V2 2e) : « X sur N dans le panier » et une
/// barre de 6 dp à l'encre, animée en 300 ms (sans animation si elles sont
/// coupées). Aucun libellé de recette.
class _Progress extends StatelessWidget {
  const _Progress({required this.checked, required this.total});

  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = total == 0 ? 0.0 : checked / total;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KadiSpacing.margin,
        0,
        KadiSpacing.margin,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            StringsFr.dansLePanier(checked, total),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KadiSpacing.s2),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio),
                  duration: duration,
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: scheme.surfaceContainerHigh),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: ColoredBox(color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
