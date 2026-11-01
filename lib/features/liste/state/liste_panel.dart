import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Seul objet partagé entre le Panneau + et la Liste (AD-19) : la géométrie
/// du panneau ouvert et la demande de montrer une ligne déjà présente.
///
/// Aucune donnée persistée n'y passe (AD-1) : la Liste repère elle-même les
/// lignes nouvelles sur son flux.
class ListePanel extends ChangeNotifier {
  double? _top;
  double? _height;
  String? _reveal;

  /// Haut du panneau en coordonnées globales ; nul quand il est fermé.
  double? get top => _top;

  /// Hauteur du panneau au-dessus du clavier ; nulle quand il est fermé.
  double? get height => _height;

  bool get isOpen => _top != null;

  /// Publie la géométrie du panneau ouvert, ou sa mise à jour quand le
  /// clavier bouge. Sans changement, ne prévient personne.
  void open({required double top, required double height}) {
    if (top == _top && height == _height) return;
    _top = top;
    _height = height;
    notifyListeners();
  }

  /// Le panneau se ferme : la Liste retrouve sa réserve normale.
  void close() {
    if (!isOpen) return;
    _top = null;
    _height = null;
    _reveal = null;
    notifyListeners();
  }

  /// Demande à la Liste de montrer et surligner la ligne [lineId], déjà
  /// présente. Ignorée quand le panneau est fermé.
  void reveal(String lineId) {
    if (!isOpen) return;
    _reveal = lineId;
    notifyListeners();
  }

  /// Rend la ligne à montrer et consomme la demande.
  String? takeReveal() {
    final lineId = _reveal;
    _reveal = null;
    return lineId;
  }
}
