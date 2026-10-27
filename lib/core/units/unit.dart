import 'package:kadi/core/strings/strings_fr.dart';

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

/// Espace insécable entre le nombre et son unité.
const _nbsp = ' ';

/// Seule fonction de lecture d'une quantité (AD-6), à l'affichage seulement.
///
/// « Sans quantité » s'affiche vide. Virgule décimale, au plus 2 décimales,
/// zéros de fin retirés : 300 g, 1,5 kg, 20 cl, 15 ml, 1 l, ½ pièce,
/// 1 ½ pièce, 2 pièces.
String formatQuantity(int? quantity, Unit? unit) {
  if (quantity == null || quantity == 0 || unit == null) return '';
  switch (unit) {
    case Unit.g:
      if (quantity < 1000) return '$quantity$_nbsp${StringsFr.uniteG}';
      return '${_thousandths(quantity)}$_nbsp${StringsFr.uniteKg}';
    case Unit.ml:
      if (quantity >= 1000) {
        return '${_thousandths(quantity)}$_nbsp${StringsFr.uniteL}';
      }
      if (quantity % 10 == 0) {
        return '${quantity ~/ 10}$_nbsp${StringsFr.uniteCl}';
      }
      return '$quantity$_nbsp${StringsFr.uniteMl}';
    case Unit.piece:
      final hundredths = _roundToHundredths(quantity);
      final suffix = hundredths >= 200
          ? StringsFr.unitePieces
          : StringsFr.unitePiece;
      return '${_pieces(quantity)}$_nbsp$suffix';
  }
}

/// Fractions lues d'une pièce, en millièmes.
const _fractions = {250: '¼', 500: '½', 750: '¾'};

/// Nombre de pièces : ¼ ½ ¾ pour ces fractions exactes, sinon décimal.
String _pieces(int thousandths) {
  final fraction = _fractions[thousandths % 1000];
  if (fraction == null) return _thousandths(thousandths);
  final whole = thousandths ~/ 1000;
  return whole == 0 ? fraction : '$whole$_nbsp$fraction';
}

/// Millièmes arrondis au centième le plus proche (demi vers le haut).
int _roundToHundredths(int thousandths) => (thousandths + 5) ~/ 10;

/// [thousandths] / 1000 avec au plus 2 décimales, virgule française, sans
/// zéros de fin : 1500 → « 1,5 », 1234 → « 1,23 », 1000 → « 1 ».
String _thousandths(int thousandths) {
  final hundredths = _roundToHundredths(thousandths);
  final whole = hundredths ~/ 100;
  final cents = hundredths % 100;
  if (cents == 0) return '$whole';
  if (cents % 10 == 0) return '$whole,${cents ~/ 10}';
  return '$whole,${cents.toString().padLeft(2, '0')}';
}
