import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/state/catalogue_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'article_lines.dart';
import 'picto_grid_sheet.dart';

/// Clé de picto d'un article en création sans picto choisi : le repli du
/// rayon.
const _newArticlePicto = 'article';

/// Ouvre la Fiche article (AD-13 : feuille modale du navigateur racine) :
/// celle de [article], ou une création préremplie de [name].
Future<void> showArticleSheet(
  BuildContext context, {
  CatalogueArticle? article,
  String name = '',
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => ArticleSheet(article: article, initialName: name),
);

/// Fiche article (DESIGN `article-sheet`) : titre (nom de l'article ou
/// « Nouvel article ») à côté de son Picto (repli du rayon pour une
/// création), un bouton lu « Changer le picto » qui ouvre la grille de
/// pictos ; le picto choisi s'affiche dans la fiche et « Enregistrer »
/// l'écrit ; champ Nom ; « Rayon par défaut » par
/// le Choix de rayon ; « Unité par défaut » par les puces pièce · g · ml ·
/// sans (jamais kg ni L, AD-6) ; « Enregistrer ».
///
/// « Enregistrer » est actif dès que le nom n'est pas vide et qu'un champ a
/// changé (en création, le nom suffit). Il écrit par le repository
/// `catalogue` et ferme la fiche. Un nom déjà porté par un autre article est
/// refusé sous le champ ; un échec d'écriture montre un snackbar dans la
/// fiche, qui reste ouverte. Fermer la fiche sans enregistrer n'écrit rien.
class ArticleSheet extends ConsumerStatefulWidget {
  const ArticleSheet({super.key, this.article, this.initialName = ''});

  /// L'article modifié ; nul pour une création.
  final CatalogueArticle? article;

  /// Nom prérempli d'une création.
  final String initialName;

  @override
  ConsumerState<ArticleSheet> createState() => _ArticleSheetState();
}

class _ArticleSheetState extends ConsumerState<ArticleSheet> {
  late final _nameController = TextEditingController(
    text: widget.article?.name ?? widget.initialName,
  );
  late Rayon _rayon = widget.article?.rayon ?? Rayon.divers;
  late Unit? _unit = widget.article?.unit;

  /// `picto_key` affichée : celle de l'article, ou le nom de l'icône
  /// choisie dans la grille.
  late String _pictoKey = widget.article?.pictoKey ?? _newArticlePicto;

  /// « Un article porte déjà ce nom. », jusqu'à la prochaine frappe.
  String? _nameError;
  bool _saving = false;

  /// Messager propre à la fiche : ses snackbars restent au-dessus d'elle.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _cleanName => CatalogueRepository.cleanName(_nameController.text);

  bool get _canSave {
    if (_saving) return false;
    final name = _cleanName;
    if (name.isEmpty) return false;
    final article = widget.article;
    if (article == null) return true;
    return name != article.name ||
        _rayon != article.rayon ||
        _unit != article.unit ||
        _pictoKey != article.pictoKey;
  }

  /// Ouvre la grille de pictos ; l'icône choisie s'affiche dans la fiche.
  /// Fermée sans choix, rien ne change.
  Future<void> _choosePicto() async {
    final chosen = await showPictoGridSheet(
      context,
      selected: PictoResolver.iconNameFor(_pictoKey, _rayon),
      rayon: _rayon,
    );
    if (chosen != null && mounted) setState(() => _pictoKey = chosen);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final view = View.of(context);
    final repository = ref.read(catalogueRepositoryProvider);
    final article = widget.article;
    final name = _cleanName;
    setState(() => _saving = true);
    try {
      if (article == null) {
        await repository.createCatalogueArticle(
          name,
          rayon: _rayon,
          unit: _unit,
          pictoKey: _pictoKey == _newArticlePicto ? null : _pictoKey,
        );
      } else {
        await repository.updateArticle(
          article.id,
          name: name,
          rayon: _rayon,
          unit: _unit,
          pictoKey: _pictoKey,
        );
      }
    } on ArticleNameTakenException {
      if (mounted) {
        setState(() {
          _saving = false;
          _nameError = StringsFr.nomDejaPris;
        });
      }
      await SemanticsService.sendAnnouncement(
        view,
        StringsFr.nomDejaPris,
        TextDirection.ltr,
      );
      return;
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      final messenger = _messengerKey.currentState;
      if (messenger != null) {
        showErrorSnackBar(messenger, StringsFr.articleImpossible);
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final article = widget.article;

    final content = Padding(
      // Marge du clavier : le champ Nom reste visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KadiSpacing.margin,
          0,
          KadiSpacing.margin,
          KadiSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArticleSheetTitle(
              pictoKey: _pictoKey,
              rayon: _rayon,
              title: article?.name ?? StringsFr.nouvelArticle,
              onPictoTap: _saving ? null : _choosePicto,
            ),
            const SizedBox(height: KadiSpacing.s4),
            // Le champ porte lui-même le nom lu « Nom ».
            ExcludeSemantics(child: Text(StringsFr.nom, style: labelStyle)),
            const SizedBox(height: KadiSpacing.s2),
            Semantics(
              label: StringsFr.nom,
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                ),
                onChanged: (_) => setState(() => _nameError = null),
                decoration: InputDecoration(
                  constraints: const BoxConstraints(
                    minHeight: KadiSpacing.touchTarget,
                  ),
                  errorText: _nameError,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: KadiSpacing.s4),
            Text(StringsFr.rayonParDefaut, style: labelStyle),
            const SizedBox(height: KadiSpacing.s2),
            RayonPicker(
              selected: _rayon,
              onSelected: (rayon) => setState(() => _rayon = rayon),
            ),
            const SizedBox(height: KadiSpacing.s4),
            Text(StringsFr.uniteParDefaut, style: labelStyle),
            const SizedBox(height: KadiSpacing.s2),
            DefaultUnitChoice(
              selected: _unit,
              onSelected: (unit) => setState(() => _unit = unit),
            ),
            const SizedBox(height: KadiSpacing.s5),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text(StringsFr.enregistrer),
            ),
          ],
        ),
      ),
    );

    // Messager et Scaffold propres à la fiche, à sa taille : la feuille vit
    // sur le navigateur racine, au-dessus du Scaffold de l'écran. Le
    // Scaffold ne sert qu'à montrer le snackbar, au-dessus du clavier, et
    // laisse passer les taps.
    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: ScaffoldMessenger(
              key: _messengerKey,
              child: const Scaffold(
                backgroundColor: Colors.transparent,
                body: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unité par défaut d'un article (DESIGN `article-sheet`) : puces de choix
/// M3 pièce · g · ml · sans (`null`), jamais kg ni L (AD-6), cible de
/// 48 dp ; la puce [selected] en contour `on-surface` avec sa coche, jamais
/// en argile. Chaque puce est lue par son libellé, choisie ou non.
class DefaultUnitChoice extends StatelessWidget {
  const DefaultUnitChoice({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Unit? selected;
  final ValueChanged<Unit?> onSelected;

  static const _choices = <(Unit?, String)>[
    (Unit.piece, StringsFr.puceUnitePiece),
    (Unit.g, StringsFr.puceUniteG),
    (Unit.ml, StringsFr.puceUniteMl),
    (null, StringsFr.puceUniteSans),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: KadiSpacing.s2,
      children: [
        for (final (unit, label) in _choices)
          ChoiceChip(
            key: ValueKey('unit-${unit?.code ?? 'sans'}'),
            label: Text(label),
            selected: unit == selected,
            onSelected: (_) => onSelected(unit),
            showCheckmark: true,
            checkmarkColor: scheme.onSurface,
            // Fond de la feuille : seul le contour marque le choix.
            color: const WidgetStatePropertyAll(Colors.transparent),
            labelStyle: TextStyle(color: scheme.onSurface),
            side: BorderSide(
              color: unit == selected ? scheme.onSurface : scheme.outline,
            ),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}
