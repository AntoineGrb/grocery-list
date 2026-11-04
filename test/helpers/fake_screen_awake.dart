import 'package:kadi/core/screen/screen_awake.dart';

/// Double du maintien de l'écran : compte les demandes, sans plateforme.
class FakeScreenAwake implements ScreenAwake {
  /// Demandes reçues, dans l'ordre : `true` pour enable, `false` pour
  /// disable.
  final calls = <bool>[];

  /// Vrai tant que la dernière demande est enable.
  bool get enabled => calls.isNotEmpty && calls.last;

  int get enables => calls.where((c) => c).length;
  int get disables => calls.where((c) => !c).length;

  @override
  Future<void> enable() async => calls.add(true);

  @override
  Future<void> disable() async => calls.add(false);
}
