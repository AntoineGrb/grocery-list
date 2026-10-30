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

/// Unités de saisie du Choix d'unité (AD-6) : pièce, g, kg, ml, L. kg et L
/// ne sont jamais stockées : [storedQuantity] les convertit ×1000 en g et
/// ml. Aucune conversion entre pièces, poids et volumes.
enum InputUnit {
  piece(Unit.piece, 1000, 0),
  g(Unit.g, 1, 0),
  kg(Unit.g, 1000, 3),
  ml(Unit.ml, 1, 0),
  l(Unit.ml, 1000, 3);

  const InputUnit(this.stored, this.factor, this.decimals);

  /// Unité stockée en base.
  final Unit stored;

  /// Quantité stockée pour une unité saisie : 1 kg = 1000 g, 1 pièce =
  /// 1000 millièmes.
  final int factor;

  /// Décimales admises à la saisie (virgule) : 3 pour kg et L, aucune
  /// sinon.
  final int decimals;

  /// Unité de saisie d'une unité stockée : g, ml ou pièce (jamais kg ni L).
  static InputUnit of(Unit unit) => switch (unit) {
    Unit.g => InputUnit.g,
    Unit.ml => InputUnit.ml,
    Unit.piece => InputUnit.piece,
  };
}

/// Quantité stockée et son unité (AD-6).
typedef StoredQuantity = ({int quantity, Unit unit});

/// Seule conversion d'une saisie en quantité stockée (AD-6) : [text] lu
/// dans [unit], virgule (ou point) décimale pour kg et L, au plus
/// [InputUnit.decimals] décimales. « 1,5 » kg → 1500 g, « 2 » L → 2000 ml,
/// « 3 » pièces → 3000. Vide, 0 ou illisible : `null`, « sans quantité ».
StoredQuantity? storedQuantity(String text, InputUnit unit) {
  // « ,5 » vaut « 0,5 » : le Champ quantité accepte une virgule en tête.
  final match = RegExp(r'^(\d*)(?:[,.](\d*))?$').firstMatch(text.trim());
  if (match == null) return null;
  final digits = match.group(1)!;
  final fraction = match.group(2) ?? '';
  if (digits.isEmpty && fraction.isEmpty) return null;
  if (fraction.length > unit.decimals) return null;
  final whole = digits.isEmpty ? 0 : int.parse(digits);
  // Décimales complétées à 3 chiffres : des millièmes de l'unité saisie.
  final thousandths = fraction.isEmpty
      ? 0
      : int.parse(fraction.padRight(3, '0'));
  final quantity = whole * unit.factor + thousandths * unit.factor ~/ 1000;
  if (quantity <= 0) return null;
  return (quantity: quantity, unit: unit.stored);
}

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
