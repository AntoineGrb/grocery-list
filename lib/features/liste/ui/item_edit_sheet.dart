import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/ui/rayon_picker.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../data/liste_repository.dart';
import '../state/liste_providers.dart';

/// Résultat de la Feuille d'édition d'article rendu à la Liste.
enum ItemEditResult {
  /// « Supprimer » touché : la Liste supprime la ligne et montre le
  /// snackbar Annuler sous son propre messager.
  delete,
}

/// Ouvre la Feuille d'édition d'article de [item] (appui long, « Modifier »).
///
/// La feuille écrit elle-même la quantité et le rayon ; elle rend
/// [ItemEditResult.delete] au lieu de supprimer. Ses erreurs d'écriture
/// s'affichent sous le messager de [context] (celui de la Liste).
Future<ItemEditResult?> showItemEditSheet(
  BuildContext context,
  ListeItem item,
) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<ItemEditResult>(
    context: context,
    // La barrière couvre toute l'app, Barre de navigation comprise.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ItemEditSheet(item: item, messenger: messenger),
  );
}

/// Feuille d'édition d'article (DESIGN `item-edit-sheet`) : nom en titre,
/// Champ quantité prérempli, Choix de rayon, « Supprimer » en `error`.
///
/// Le rayon s'écrit au tap, la feuille reste ouverte. La quantité s'écrit
/// à la validation du clavier et à la fermeture, si la valeur a changé, une
/// seule fois ; jamais après « Supprimer ». Le Champ quantité saisit dans
/// l'unité de la ligne, sinon dans celle de l'article ; sans l'une ni
/// l'autre, il est absent.
class ItemEditSheet extends ConsumerStatefulWidget {
  const ItemEditSheet({super.key, required this.item, required this.messenger});

  final ListeItem item;

  /// Messager de la Liste, pour les erreurs d'écriture.
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<ItemEditSheet> {
  // Lu une fois : l'écriture de fermeture se fait aussi dans dispose.
  late final ListeRepository _repository;
  late final Unit? _unit = widget.item.unit ?? widget.item.articleUnit;
  late final TextEditingController _controller;

  /// Quantité stockée de la ligne, ou dernière écrite (pas le texte
  /// prérempli, arrondi pour les pièces).
  late int? _written = widget.item.quantity;

  /// Le champ a été saisi ou validé : sans cela, rien n'est écrit (un
  /// préremplissage arrondi ne réécrit pas la ligne).
  bool _edited = false;
  late Rayon _rayon = widget.item.rayon;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(listeRepositoryProvider);
    final unit = _unit;
    final text = unit == null
        ? ''
        : quantityFieldText(widget.item.quantity, unit);
    _controller = TextEditingController(text: text);
  }

  @override
  void dispose() {
    // Fermeture sans passer par le pop (rare) : la quantité est écrite.
    _commitQuantity();
    _controller.dispose();
    super.dispose();
  }

  void _showError() =>
      showErrorSnackBar(widget.messenger, StringsFr.modificationImpossible);

  /// Écrit la quantité saisie si le champ a été saisi et qu'elle diffère
  /// de la quantité stockée ou dernière écrite.
  void _commitQuantity() {
    final unit = _unit;
    if (unit == null || _deleted || !_edited) return;
    final value = quantityFromFieldText(_controller.text, unit);
    final previous = _written;
    if (value == previous) return;
    _written = value;
    _repository.setQuantity(widget.item.lineId, value, unit: unit).catchError((
      Object _,
    ) {
      // Un nouvel essai reste possible (validation ou fermeture).
      if (_written == value) _written = previous;
      _showError();
    });
  }

  Future<void> _selectRayon(Rayon rayon) async {
    if (rayon == _rayon) return;
    final previous = _rayon;
    setState(() => _rayon = rayon);
    try {
      await _repository.setRayon(widget.item.lineId, rayon);
    } catch (_) {
      if (mounted && _rayon == rayon) setState(() => _rayon = previous);
      _showError();
    }
  }

  void _delete() {
    _deleted = true;
    Navigator.pop(context, ItemEditResult.delete);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = _unit;
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return PopScope<ItemEditResult>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result != ItemEditResult.delete) _commitQuantity();
      },
      child: Padding(
        // Marge du clavier : le Champ quantité reste visible.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
              Semantics(
                header: true,
                child: Text(
                  widget.item.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(height: KadiSpacing.s5),
                Row(
                  children: [
                    Expanded(
                      child: Text(StringsFr.quantite, style: labelStyle),
                    ),
                    SizedBox(
                      width: _quantityFieldWidth,
                      child: QuantityField(
                        controller: _controller,
                        unit: unit,
                        onChanged: (_) => _edited = true,
                        onSubmitted: (_) {
                          _edited = true;
                          _commitQuantity();
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: KadiSpacing.s5),
              Text(StringsFr.rayon, style: labelStyle),
              const SizedBox(height: KadiSpacing.s2),
              RayonPicker(selected: _rayon, onSelected: _selectRayon),
              const SizedBox(height: KadiSpacing.s4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(StringsFr.supprimer),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size(
                      KadiSpacing.touchTarget,
                      KadiSpacing.touchTarget,
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

/// Largeur du Champ quantité dans la feuille.
const _quantityFieldWidth = 160.0;
