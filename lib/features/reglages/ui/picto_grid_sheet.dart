import 'package:kadi/core/pictos/phosphor_table.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_colors.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/features/catalogue/data/normalize_name.dart';
import 'package:material_ui/material_ui.dart';

import 'article_lines.dart';

/// Ouvre la grille de pictos de la Fiche article, au-dessus d'elle (AD-13 :
/// feuille modale du navigateur racine). Rend le nom de l'icône choisie, ou
/// `null` si la grille est fermée sans choix.
Future<String?> showPictoGridSheet(
  BuildContext context, {
  required String selected,
  required Rayon rayon,
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => PictoGridSheet(selected: selected, rayon: rayon),
);

/// Réduit [text] à `[a-z0-9]`, sans accents (« Pommes de terre » →
/// `pommesdeterre`, `orange-slice` → `orangeslice`).
String _searchable(String text) =>
    normalizeName(text).replaceAll(RegExp('[^a-z0-9]'), '');

/// Noms des articles du contenu de départ qui utilisent chaque icône, sous
/// forme cherchable.
final Map<String, List<String>> _articlesByIcon = () {
  final byIcon = <String, List<String>>{};
  for (final MapEntry(:key, :value) in pictoArticleIcons.entries) {
    if (value == null) continue;
    byIcon.putIfAbsent(value, () => []).add(_searchable(key));
  }
  return byIcon;
}();

/// Icônes de la grille qui répondent à [query], dans l'ordre de
/// [phosphorIcons] : celles dont le nom anglais, ou le nom d'un article qui
/// l'utilise, contient [query] (casse, accents et espaces ignorés). Toutes
/// pour une recherche vide.
List<String> pictoGridMatches(String query) {
  final q = _searchable(query);
  if (q.isEmpty) return phosphorIcons.keys.toList();
  return [
    for (final name in phosphorIcons.keys)
      if (_searchable(name).contains(q) ||
          (_articlesByIcon[name]?.any((a) => a.contains(q)) ?? false))
        name,
  ];
}

/// Grille de pictos (Fiche article) : Champ de recherche « Chercher un
/// picto », puis les icônes teintées de l'accent de [rayon], cible de 48 dp
/// au moins ; l'icône [selected] marquée d'un contour `on-surface`, jamais
/// d'argile. Toucher une icône ferme la grille et la rend.
class PictoGridSheet extends StatefulWidget {
  const PictoGridSheet({
    super.key,
    required this.selected,
    required this.rayon,
  });

  /// Nom de l'icône affichée dans la fiche.
  final String selected;
  final Rayon rayon;

  @override
  State<PictoGridSheet> createState() => _PictoGridSheetState();
}

class _PictoGridSheetState extends State<PictoGridSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = pictoGridMatches(_controller.text);
    final Widget results = matches.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(KadiSpacing.margin),
            child: Text(
              StringsFr.aucunPicto,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              KadiSpacing.margin,
              KadiSpacing.s2,
              KadiSpacing.margin,
              KadiSpacing.s4,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: KadiSpacing.touchTarget + KadiSpacing.s3,
              mainAxisSpacing: KadiSpacing.s1,
              crossAxisSpacing: KadiSpacing.s1,
            ),
            itemCount: matches.length,
            itemBuilder: (context, i) => PictoChoice(
              name: matches[i],
              rayon: widget.rayon,
              selected: matches[i] == widget.selected,
              onTap: () => Navigator.pop(context, matches[i]),
            ),
          );
    return Padding(
      // Marge du clavier : la grille reste au-dessus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CatalogueSearchField(
              controller: _controller,
              hint: StringsFr.chercherUnPicto,
              onChanged: () => setState(() {}),
            ),
            Expanded(child: results),
          ],
        ),
      ),
    );
  }
}

/// Une icône de la grille : bouton lu par son nom (« orange slice »), choisi
/// ou non ; le choix en contour `on-surface`.
class PictoChoice extends StatelessWidget {
  const PictoChoice({
    super.key,
    required this.name,
    required this.rayon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Rayon rayon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(KadiRadius.md));
    return Semantics(
      key: ValueKey('picto-$name'),
      button: true,
      selected: selected,
      label: name.replaceAll('-', ' '),
      // Un seul nœud : le libellé et le tap viennent d'ici.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: KadiSpacing.touchTarget,
              minHeight: KadiSpacing.touchTarget,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              phosphorIcons[name],
              size: KadiSpacing.picto,
              color: KadiColors.of(context).rayon(rayon).accent,
            ),
          ),
        ),
      ),
    );
  }
}
