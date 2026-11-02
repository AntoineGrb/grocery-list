/// Lien de recette écrit pour la saisie [input] : sans espaces de bord ;
/// vide, `null` (pas de lien).
String? cleanRecipeLink(String? input) {
  final link = input?.trim() ?? '';
  return link.isEmpty ? null : link;
}

final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

/// Adresse ouverte par l'icône « Ouvrir le lien » : le lien nettoyé, avec
/// `https://` devant s'il n'a pas de schéma (« marmiton.org/chili » →
/// `https://marmiton.org/chili`). `null` sans lien ou s'il est illisible.
Uri? recipeLinkUri(String input) {
  final link = cleanRecipeLink(input);
  if (link == null) return null;
  final uri = Uri.tryParse(_scheme.hasMatch(link) ? link : 'https://$link');
  if (uri == null || uri.host.isEmpty) return null;
  return uri;
}
