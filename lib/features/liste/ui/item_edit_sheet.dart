import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/pictos/picto.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_sheet.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';
import 'add_sheet_rows.dart';
import 'quantity_input.dart';
import 'quantity_tag.dart';
import 'rayon_tag.dart';

/// Résultat de la Feuille d'édition d'article rendu à son ouvreur.
enum ItemEditResult {
  /// « Supprimer » touché : la Liste supprime la ligne et montre le snackbar
  /// Annuler sous son propre messager.
  delete,
}

/// Ouvre la Feuille d'édition d'article de [item] : appui long ou
/// « Modifier » de la Liste.
///
/// La feuille écrit elle-même la quantité, l'unité et le rayon au bouton
/// ✎ ; elle rend [ItemEditResult.delete] au lieu de supprimer. Ses erreurs
/// d'écriture s'affichent sous le messager de [context], celui de la Liste.
Future<ItemEditResult?> showItemEditSheet(
  BuildContext context,
  ListeItem item,
) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<ItemEditResult>(
    context: context,
    // La barrière couvre toute l'app, Barre de navigation comprise.
    useRootNavigator: true,
    barrierColor: Theme.of(context).colorScheme.scrim,
    isScrollControlled: true,
    useSafeArea: true,
    // Comme le Panneau + : la feuille ne porte que la carte.
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => ItemEditSheet(item: item, messenger: messenger),
  );
}

/// Feuille d'édition d'article, au dessin du Panneau + (V2 2f) : poignée,
/// le nom de l'article à la place du champ, le bouton ✎ à sa droite, puis
/// les tags Quantité et Rayon préremplis et un tag Supprimer. Pas de
/// fréquents ni de clavier.
///
/// Les tags sont un brouillon : ✎ écrit la quantité (et son unité, AD-5) et
/// le rayon qui ont changé, puis ferme la feuille. Fermer autrement n'écrit
/// rien. ✎ est grisé tant que rien n'a changé.
class ItemEditSheet extends ConsumerStatefulWidget {
  const ItemEditSheet({super.key, required this.item, required this.messenger});

  final ListeItem item;

  /// Messager de la Liste, pour les erreurs d'écriture.
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<ItemEditSheet> {
  late final StoredQuantity? _initialQuantity = storedQuantityOf(
    widget.item.quantity,
    widget.item.unit,
  );
  late StoredQuantity? _quantity = _initialQuantity;
  late Rayon _rayon = widget.item.rayon;
  bool _quantityOpen = false;
  bool _saving = false;

  bool get _changed =>
      _quantity != _initialQuantity || _rayon != widget.item.rayon;

  Future<void> _editQuantity() async {
    if (_quantityOpen) return;
    _quantityOpen = true;
    final item = widget.item;
    final QuantityEdit? edit;
    try {
      edit = await showQuantitySheet(
        context,
        title: item.name,
        leading: Picto(pictoKey: '', rayon: _rayon),
        quantity: _quantity?.quantity,
        unit: _quantity?.unit,
        initialUnit: _quantity == null
            ? initialInputUnit(item)
            : InputUnit.of(_quantity!.unit),
      );
    } finally {
      _quantityOpen = false;
    }
    if (edit case final edit? when mounted) {
      setState(() => _quantity = edit.value);
    }
  }

  /// ✎ : écrit ce qui a changé, puis ferme. Un échec montre un snackbar
  /// sous la Liste ; la feuille se ferme quand même.
  Future<void> _save() async {
    if (!_changed || _saving) return;
    setState(() => _saving = true);
    final repository = ref.read(listeRepositoryProvider);
    final item = widget.item;
    try {
      if (_rayon != item.rayon) await repository.setRayon(item.lineId, _rayon);
      if (_quantity != _initialQuantity) {
        await repository.setQuantity(
          item.lineId,
          _quantity?.quantity,
          unit: _quantity?.unit,
        );
      }
    } catch (_) {
      showErrorSnackBar(widget.messenger, StringsFr.modificationImpossible);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = MediaQueryData.fromView(View.of(context));
    final route = ref.watch(settingsProvider).value?.routeOrder ?? Rayon.values;
    final quantityValue = formatQuantity(_quantity?.quantity, _quantity?.unit);

    return Padding(
      // Au-dessus de la barre de gestes, comme le Panneau + clavier fermé.
      padding: EdgeInsets.only(bottom: view.padding.bottom),
      child: Material(
        color: scheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KadiRadius.xl),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: KadiSpacing.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PanelHandle(),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: KadiSpacing.margin,
                  end: KadiSpacing.s1,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: KadiSpacing.addFieldHeight,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            widget.item.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      _SaveButton(
                        onPressed: _changed && !_saving ? _save : null,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: KadiSpacing.margin - 3,
                  end: KadiSpacing.s1,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PanelQuantityTag(
                          value: quantityValue,
                          emptyLabel: StringsFr.quantite,
                          semanticLabel: StringsFr.quantiteTag(quantityValue),
                          onTap: _editQuantity,
                        ),
                        RayonTag(
                          rayon: _rayon,
                          chosen: true,
                          route: route,
                          onSelected: (rayon) => setState(() => _rayon = rayon),
                        ),
                        AddTag(
                          color: scheme.surfaceContainerHigh,
                          semanticLabel: StringsFr.supprimer,
                          onTap: () =>
                              Navigator.pop(context, ItemEditResult.delete),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: scheme.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                StringsFr.supprimer,
                                style: addTagTextStyle(context, scheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton ✎ de la Feuille d'édition : le bouton d'envoi du Panneau + avec un
/// crayon ; grisé tant que rien n'a changé, argile sinon.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return IconButton(
      tooltip: StringsFr.enregistrerLesModifications,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.surfaceContainerHigh,
        disabledForegroundColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KadiRadius.md)),
        ),
      ),
      icon: Icon(
        Icons.edit_outlined,
        size: 22,
        color: enabled ? scheme.onPrimary : scheme.outline,
      ),
    );
  }
}
