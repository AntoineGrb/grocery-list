/// Unités sans conversion (AD-6). Une quantité et son unité sont nulles
/// ensemble : c'est « sans quantité ».
enum Unit {
  g('g'),
  ml('ml'),
  piece('piece');

  const Unit(this.code);

  /// Code stable stocké en base.
  final String code;

  static Unit? tryFromCode(String? code) {
    if (code == null) return null;
    for (final u in Unit.values) {
      if (u.code == code) return u;
    }
    return null;
  }

  /// L'unité de [code] (`null` pour « sans ») ; lève une [FormatException] si
  /// le code est inconnu.
  static Unit? fromCode(String? code) {
    if (code == null) return null;
    return tryFromCode(code) ??
        (throw FormatException('Unité inconnue : $code'));
  }
}

/// Clé d'unicité d'une ligne non cochée (AD-4) : l'unité, ou `-` sans quantité.
String unitKey(Unit? unit) => unit?.code ?? '-';

/// Seule fonction de lecture d'une quantité (AD-6).
///
/// Cette version ne connaît que « sans quantité », qui s'affiche vide.
/// L'arrondi de lecture (1,5 kg, 20 cl, ½) arrive avec la saisie de quantité.
String formatQuantity(int? quantity, Unit? unit) {
  if (quantity == null || quantity == 0 || unit == null) return '';
  throw UnimplementedError(
    'Affichage des quantités chiffrées : story de la saisie de quantité.',
  );
}
