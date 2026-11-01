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
import 'quantity_input.dart';

/// Résultat de la Feuille d'édition d'article rendu à son ouvreur.
enum ItemEditResult {
  /// « Supprimer » touché : la Liste supprime la ligne et montre le snackbar
  /// Annuler sous son propre messager.
  delete,
}

/// Ouvre la Feuille d'édition d'article de [item] : appui long ou
/// « Modifier » de la Liste.
///
/// La feuille écrit elle-même la quantité, l'unité et le rayon ; elle rend
/// [ItemEditResult.delete] au lieu de supprimer. Ses erreurs d'écriture
/// s'affichent sous le messager de [context], celui de la Liste.
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
/// Champ quantité prérempli, Choix d'unité, Choix de rayon, « Supprimer »
/// en `error`. Hauteur au contenu.
///
/// Le rayon s'écrit au tap, la feuille reste ouverte. Quantité et unité
/// s'écrivent ensemble (AD-5) à la validation du clavier et à la
/// fermeture, une seule fois, si le champ a été saisi ou la puce changée et
/// que le résultat diffère de la ligne ; jamais après « Supprimer ».
/// Changer de puce garde le nombre tapé : la puce dit seulement dans quelle
/// unité il est lu (sans les décimales qu'elle n'admet pas).
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
  late final QuantityInput _input;

  /// Quantité stockée de la ligne, ou dernière écrite (pas le texte
  /// prérempli, arrondi pour les pièces).
  late StoredQuantity? _written = storedQuantityOf(
    widget.item.quantity,
    widget.item.unit,
  );
  late Rayon _rayon = widget.item.rayon;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(listeRepositoryProvider);
    _input = QuantityInput(
      quantity: widget.item.quantity,
      initialUnit: initialInputUnit(widget.item),
    );
  }

  @override
  void dispose() {
    // Fermeture sans passer par le pop (rare) : la quantité est écrite.
    _commitQuantity();
    _input.dispose();
    super.dispose();
  }

  void _showError() =>
      showErrorSnackBar(widget.messenger, StringsFr.modificationImpossible);

  /// Écrit la quantité et l'unité saisies si le champ a été saisi ou la
  /// puce changée, et qu'elles diffèrent des stockées ou dernières écrites.
  void _commitQuantity() {
    if (_deleted || !_input.touched) return;
    final value = _input.value;
    final previous = _written;
    if (value == previous) return;
    _written = value;
    _repository
        .setQuantity(widget.item.lineId, value?.quantity, unit: value?.unit)
        .catchError((Object _) {
          // Un nouvel essai reste possible (validation ou fermeture).
          if (_written == value) _written = previous;
          _showError();
        });
  }

  void _selectUnit(InputUnit unit) {
    if (unit == _input.unit) return;
    setState(() => _input.selectUnit(unit));
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: KadiSpacing.s4),
              Row(
                children: [
                  Expanded(
                    // Le champ porte lui-même le nom lu « Quantité ».
                    child: ExcludeSemantics(
                      child: Text(StringsFr.quantite, style: labelStyle),
                    ),
                  ),
                  SizedBox(
                    width: _quantityFieldWidth,
                    child: Semantics(
                      label: StringsFr.quantite,
                      child: QuantityField(
                        controller: _input.controller,
                        unit: _input.unit,
                        onChanged: (_) => _input.edited = true,
                        onSubmitted: (_) {
                          // Valider compte comme une saisie.
                          _input.edited = true;
                          _commitQuantity();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KadiSpacing.s4),
              Text(StringsFr.unite, style: labelStyle),
              const SizedBox(height: KadiSpacing.s2),
              UnitChoice(selected: _input.unit, onSelected: _selectUnit),
              const SizedBox(height: KadiSpacing.s4),
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
