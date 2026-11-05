import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show SynchronousFuture, listEquals;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/rayon_pastille.dart';
import 'package:material_ui/material_ui.dart';

/// Élévation M3 d'une ligne glissée (celle de `ReorderableListView`).
const _dragElevation = 6.0;

/// Paramètres › Parcours (R19) : les 13 rayons dans l'ordre du parcours,
/// réordonnés par glisser-déposer sur la poignée de chaque Ligne de parcours
/// (seul glisser-déposer de l'app, C10 : pas d'appui long), ou par les
/// actions TalkBack « Monter » et « Descendre ».
///
/// L'ordre affiché est celui de `settings` (AD-1) ; chaque déposer y écrit
/// les 13 rayons dans le nouvel ordre par le `SettingsRepository` (AD-2). Le
/// nouvel ordre n'est gardé à l'écran que le temps de l'écriture : une
/// écriture qui échoue rend l'ordre de la base et montre un snackbar.
class ParcoursScreen extends ConsumerStatefulWidget {
  const ParcoursScreen({super.key});

  @override
  ConsumerState<ParcoursScreen> createState() => _ParcoursScreenState();
}

class _ParcoursScreenState extends ConsumerState<ParcoursScreen> {
  /// Ordre du dernier déplacement, affiché jusqu'à ce que la base le
  /// renvoie, ou que son écriture échoue.
  List<Rayon>? _pending;

  /// Index de départ du glisser en cours ; nul hors glisser. Un glisser
  /// annulé (doigt perdu) ne le remet pas à zéro : la liste ne le signale
  /// pas. Il ne décide donc de rien seul : voir [_dropping].
  int? _dragFrom;

  /// Vrai entre un déposer qui déplace la ligne et le déplacement qu'il
  /// annonce. Tout déplacement reçu hors de cette fenêtre vient d'une action
  /// TalkBack, même après un glisser annulé ou fini.
  bool _dropping = false;

  void _onReorderStart(int index) {
    _dragFrom = index;
    _dropping = false;
  }

  /// [insertIndex] compte la ligne glissée encore en place : déposée sur
  /// elle-même (même index ou le suivant), aucun déplacement ne suivra.
  void _onReorderEnd(int insertIndex) {
    final from = _dragFrom;
    _dragFrom = null;
    _dropping = from != null && insertIndex != from && insertIndex != from + 1;
  }

  /// Déplacement de [oldIndex] à [newIndex] (index après retrait de la
  /// ligne). Hors déposer, c'est « Monter » ou « Descendre » : un cran vers
  /// le voisin, dans le sens demandé, puis annoncé.
  void _onReorderItem(List<Rayon> order, int oldIndex, int newIndex) {
    final byDrag = _dropping;
    _dropping = false;
    _dragFrom = null;
    if (byDrag) {
      _move(order, oldIndex, newIndex);
    } else {
      _move(
        order,
        oldIndex,
        newIndex < oldIndex ? oldIndex - 1 : oldIndex + 1,
        announce: true,
      );
    }
  }

  Future<void> _move(
    List<Rayon> order,
    int from,
    int to, {
    bool announce = false,
  }) async {
    if (from == to || to < 0 || to >= order.length) return;
    final next = [...order];
    final rayon = next.removeAt(from);
    next.insert(to, rayon);

    // Tout est lu maintenant : l'écran peut être fermé pendant l'écriture.
    final view = View.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(settingsRepositoryProvider);
    setState(() => _pending = next);
    try {
      await repository.setRouteOrder(next);
    } catch (_) {
      if (mounted && identical(_pending, next)) {
        setState(() => _pending = null);
      }
      showErrorSnackBar(messenger, StringsFr.parcoursImpossible);
      return;
    }
    // La base avait déjà cet ordre (rien d'écrit, aucun flux) : rien à
    // garder non plus.
    if (mounted &&
        identical(_pending, next) &&
        listEquals(ref.read(settingsProvider).value?.routeOrder, next)) {
      setState(() => _pending = null);
    }
    if (announce) {
      await SemanticsService.sendAnnouncement(
        view,
        StringsFr.positionSur(rayon.spokenLabel, to + 1, next.length),
        TextDirection.ltr,
      );
    }
  }

  /// Ligne soulevée pendant le glisser ; animations coupées, elle l'est
  /// d'un coup.
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    final color = Theme.of(context).colorScheme.surface;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Material(elevation: _dragElevation, color: color, child: child);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        elevation: lerpDouble(
          0,
          _dragElevation,
          Curves.easeInOut.transform(animation.value),
        )!,
        color: color,
        child: child,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // La base a rendu l'ordre écrit : il n'y a plus rien à garder.
    ref.listen(settingsProvider, (_, next) {
      final stored = next.value?.routeOrder;
      final pending = _pending;
      if (pending != null && stored != null && listEquals(stored, pending)) {
        setState(() => _pending = null);
      }
    });
    final stored = ref.watch(settingsProvider).value?.routeOrder;
    final order = _pending ?? stored;

    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.parcours)),
      body: order == null
          ? const SizedBox.shrink()
          : Localizations.override(
              context: context,
              delegates: [
                _RouteActionsDelegate(WidgetsLocalizations.of(context)),
              ],
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                proxyDecorator: _proxyDecorator,
                onReorderStart: _onReorderStart,
                onReorderEnd: _onReorderEnd,
                onReorderItem: (oldIndex, newIndex) =>
                    _onReorderItem(order, oldIndex, newIndex),
                itemCount: order.length,
                itemBuilder: (context, i) => RouteRow(
                  key: ValueKey(order[i]),
                  rayon: order[i],
                  index: i,
                  count: order.length,
                ),
              ),
            ),
    );
  }
}

/// Ligne de parcours (`route-row`) : Pastille du rayon, comme l'En-tête de
/// rayon, et poignée de glisser à droite en `on-surface-variant` ; ligne et
/// poignée de 48 dp au moins. Seule la poignée lance le glisser.
///
/// Lue « Fruits et légumes, position 1 sur 13 » ; ses actions TalkBack
/// « Monter » (sauf la première) et « Descendre » (sauf la dernière) sont
/// celles de la liste réordonnable, renommées par [_RouteActionsDelegate].
class RouteRow extends StatelessWidget {
  const RouteRow({
    super.key,
    required this.rayon,
    required this.index,
    required this.count,
  });

  final Rayon rayon;

  /// Position dans le parcours, à partir de 0, parmi [count] rayons.
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: StringsFr.positionSur(rayon.spokenLabel, index + 1, count),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KadiSpacing.rowMinHeight),
        child: Padding(
          padding: const EdgeInsets.only(
            left: KadiSpacing.margin,
            right: KadiSpacing.s1,
            top: KadiSpacing.s1,
            bottom: KadiSpacing.s1,
          ),
          child: Row(
            children: [
              // Flexible : en très grande police, le nom passe à la ligne
              // dans la pastille au lieu de déborder.
              Expanded(
                child: Row(
                  children: [Flexible(child: RayonPastille(rayon: rayon))],
                ),
              ),
              const SizedBox(width: KadiSpacing.s2),
              ReorderableDragStartListener(
                index: index,
                child: SizedBox.square(
                  dimension: KadiSpacing.touchTarget,
                  child: Icon(Icons.drag_handle, color: variant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renomme les actions TalkBack de la liste réordonnable : « Monter » et
/// « Descendre ». Ses actions « au début » et « à la fin » portent le même
/// nom : elles se fondent dans les deux premières, et chaque ligne n'a que
/// « Monter » et « Descendre », traitées comme un cran vers le voisin.
class _RouteActionsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RouteActionsDelegate(this.base);

  final WidgetsLocalizations base;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(_RouteActionsLocalizations(base));

  @override
  bool shouldReload(_RouteActionsDelegate old) => !identical(old.base, base);
}

/// Les textes de [_base], sauf les quatre actions de réordonnancement
/// verticales.
class _RouteActionsLocalizations implements WidgetsLocalizations {
  const _RouteActionsLocalizations(this._base);

  final WidgetsLocalizations _base;

  @override
  String get reorderItemUp => StringsFr.monter;

  @override
  String get reorderItemToStart => StringsFr.monter;

  @override
  String get reorderItemDown => StringsFr.descendre;

  @override
  String get reorderItemToEnd => StringsFr.descendre;

  @override
  TextDirection get textDirection => _base.textDirection;

  @override
  String get reorderItemLeft => _base.reorderItemLeft;

  @override
  String get reorderItemRight => _base.reorderItemRight;

  @override
  String get searchResultsFound => _base.searchResultsFound;

  @override
  String get noResultsFound => _base.noResultsFound;

  @override
  String get copyButtonLabel => _base.copyButtonLabel;

  @override
  String get cutButtonLabel => _base.cutButtonLabel;

  @override
  String get pasteButtonLabel => _base.pasteButtonLabel;

  @override
  String get selectAllButtonLabel => _base.selectAllButtonLabel;

  @override
  String get lookUpButtonLabel => _base.lookUpButtonLabel;

  @override
  String get searchWebButtonLabel => _base.searchWebButtonLabel;

  @override
  String get shareButtonLabel => _base.shareButtonLabel;

  @override
  String get radioButtonUnselectedLabel => _base.radioButtonUnselectedLabel;
}
