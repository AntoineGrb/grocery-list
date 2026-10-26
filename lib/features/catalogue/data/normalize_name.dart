/// Seule normalisation des noms d'article (AD-17) : espaces retirés,
/// minuscules, sans accents. « Œufs », « oeufs » et « O E U F S » donnent
/// `oeufs`.
String normalizeName(String name) {
  final lower = name.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.trim().isEmpty) continue;
    out.write(_unaccented[ch] ?? ch);
  }
  return out.toString();
}

const _unaccented = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'æ': 'ae', 'ç': 'c', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
  'ñ': 'n', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', //
  'œ': 'oe', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y', //
};
