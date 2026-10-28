/// Horloge unique des écritures (AD-7).
///
/// Toute écriture prend son `updated_at` ici :
/// `max(maintenant, ancien updated_at + 1)`, et jamais moins que le dernier
/// horodatage émis, pour qu'un horodatage ne recule jamais.
class Clock {
  Clock({int Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final int Function() _now;
  int _last = 0;

  /// Dernier horodatage émis, 0 avant la première écriture.
  ///
  /// Témoin d'écriture d'Annuler (AD-10) : il bouge à chaque écriture.
  int get last => _last;

  /// Horodatage en millisecondes UTC pour une écriture.
  ///
  /// [previous] est l'ancien `updated_at` de la ligne modifiée, s'il existe.
  int stamp([int? previous]) {
    var t = _now();
    if (previous != null && t <= previous) t = previous + 1;
    if (t <= _last) t = _last + 1;
    _last = t;
    return t;
  }
}
