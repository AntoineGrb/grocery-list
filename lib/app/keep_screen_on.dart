import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/screen/screen_awake.dart';

/// Vrai quand l'écran doit rester allumé (R14) : le réglage est actif, la
/// Liste est l'emplacement du routeur (aucune page poussée au-dessus ; une
/// feuille, le Panneau + ou la popup quantité ne changent pas l'emplacement)
/// et l'app est au premier plan.
///
/// [lifecycle] nul : état pas encore connu, l'app dessine ses frames ; compté
/// comme au premier plan.
bool shouldKeepScreenOn({
  required bool setting,
  required String path,
  required AppLifecycleState? lifecycle,
}) =>
    setting &&
    path == AppRoutes.liste &&
    (lifecycle == null || lifecycle == AppLifecycleState.resumed);

/// Demande ou relâche le maintien de l'écran par [ScreenAwake] quand l'état
/// voulu change, jamais deux fois de suite la même demande. L'écran n'est pas
/// maintenu au départ.
class KeepScreenOnController {
  KeepScreenOnController(this._screen);

  final ScreenAwake _screen;
  bool _active = false;

  /// Vrai tant que le maintien est demandé.
  bool get active => _active;

  /// Recalcule l'état voulu ([shouldKeepScreenOn]) et l'applique s'il change.
  void update({
    required bool setting,
    required String path,
    required AppLifecycleState? lifecycle,
  }) {
    _apply(
      shouldKeepScreenOn(setting: setting, path: path, lifecycle: lifecycle),
    );
  }

  /// Relâche le maintien s'il est demandé (app démontée).
  void release() => _apply(false);

  void _apply(bool wanted) {
    if (wanted == _active) return;
    _active = wanted;
    // Un échec de la plateforme n'a pas d'autre effet que l'écran qui
    // s'éteint ou reste allumé selon le système : rien à montrer.
    unawaited(
      (wanted ? _screen.enable() : _screen.disable()).catchError((Object _) {}),
    );
  }
}
