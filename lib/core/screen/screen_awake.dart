import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Maintien de l'écran allumé (R14) : le seul accès au paquet du maintien,
/// surchargé par un double dans les tests.
abstract interface class ScreenAwake {
  /// Demande que l'écran reste allumé.
  Future<void> enable();

  /// Relâche le maintien : l'écran s'éteint de nouveau selon le système.
  Future<void> disable();
}

/// Maintien par `wakelock_plus` (`FLAG_KEEP_SCREEN_ON` sur Android, sans
/// permission, C2).
class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);
