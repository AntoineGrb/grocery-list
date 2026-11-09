import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_theme.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_sheet.dart';
import 'package:kadi/core/ui/rayon_menu.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/state/liste_notice.dart';
import 'package:material_ui/material_ui.dart';

import '../state/recettes_providers.dart';
import '../state/revue.dart';
import 'revue_row.dart';

/// Revue (README redesign 2d) : écran poussé, flèche retour. « Qu'as-tu
/// déjà ? », sa consigne, puis une carte par rayon dans l'ordre du parcours
/// avec ses ingrédients, tous gardés à l'ouverture (R4). Un tap sur une
/// ligne la passe en « J'ai ! » ; son tag ouvre le Module quantité pour
/// corriger la quantité à acheter. Bouton d'action « Ajouter N articles à la
/// liste » (R5).
///
/// La Revue lit les sélections à valider à son ouverture et garde cet
/// instantané (AD-1) : « Ajouter à la liste » valide exactement celles-là.
/// Quitter la Revue ne valide rien (AD-16).
class RevueScreen extends ConsumerStatefulWidget {
  const RevueScreen({super.key});

  @override
  ConsumerState<RevueScreen> createState() => _RevueScreenState();
}

class _RevueScreenState extends ConsumerState<RevueScreen> {
  late final Future<Revue> _revue = ref.read(revueLoaderProvider)();

  /// Brouillon d'écran (AD-1), jamais persisté : il meurt avec l'écran, et
  /// un retour n'écrit rien. Clés des lignes « J'ai ! ».
  final _unchecked = <String>{};

  /// Quantités corrigées par le Module quantité, par clé de ligne ; nulle :
  /// sans quantité.
  final _corrections = <String, StoredQuantity?>{};

  /// Écriture en cours : le bouton ne réagit plus.
  bool _adding = false;

  /// Le Module quantité est ouvert.
  bool _quantityOpen = false;

  void _toggle(RevueLine line) => setState(() {
    if (!_unchecked.remove(line.key)) _unchecked.add(line.key);
  });

  /// Quantité montrée de [line] : corrigée, sinon d'origine.
  StoredQuantity? _valueOf(RevueLine line) {
    if (_corrections.containsKey(line.key)) return _corrections[line.key];
    final quantity = line.quantity;
    final unit = line.unit;
    return quantity == null || unit == null
        ? null
        : (quantity: quantity, unit: unit);
  }

  Future<void> _editQuantity(RevueLine line) async {
    if (_quantityOpen || _adding) return;
    _quantityOpen = true;
    final value = _valueOf(line);
    final QuantityEdit? edit;
    try {
      edit = await showQuantitySheet(
        context,
        title: line.name,
        leading: RayonDot(rayon: line.rayon),
        caption: StringsFr.quantiteAAcheter,
        quantity: value?.quantity,
        unit: value?.unit,
        initialUnit: InputUnit.of(line.fieldUnit),
      );
    } finally {
      _quantityOpen = false;
    }
    if (edit == null || !mounted) return;
    final corrected = edit.value;
    setState(() => _corrections[line.key] = corrected);
  }

  RevueDraft _draft() => RevueDraft(
    unchecked: {..._unchecked},
    corrections: {
      for (final MapEntry(:key, :value) in _corrections.entries)
        key: value?.quantity,
    },
    units: {
      for (final MapEntry(:key, :value) in _corrections.entries)
        if (value != null) key: value.unit,
    },
  );

  Future<void> _ajouter(BuildContext context, Revue revue) async {
    if (_adding) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final notice = ref.read(listeNoticeProvider.notifier);
    try {
      await ref.read(ajouterALaListeProvider).call(revue, draft: _draft());
    } catch (_) {
      if (mounted) setState(() => _adding = false);
      showErrorSnackBar(messenger, StringsFr.ajoutImpossible);
      return;
    }
    // La Liste remplace la Revue et montre son avis sous son messager.
    router.go(AppRoutes.liste);
    notice.show(StringsFr.listePrete);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FutureBuilder<Revue>(
      future: _revue,
      builder: (context, snapshot) {
        final revue = snapshot.data;
        final kept = revue == null
            ? 0
            : [
                for (final g in revue.groups)
                  for (final l in g.lines)
                    if (!_unchecked.contains(l.key)) l,
              ].length;
        return Scaffold(
          appBar: AppBar(),
          body: revue == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KadiSpacing.margin,
                        0,
                        KadiSpacing.margin,
                        KadiSpacing.s3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              StringsFr.quAsTuDeja,
                              style: KadiText.revueTitle.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: KadiSpacing.s1),
                          Text(
                            StringsFr.revueConsigneV2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              height: 20 / 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final group in revue.groups)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KadiSpacing.s3,
                          0,
                          KadiSpacing.s3,
                          10,
                        ),
                        child: _RayonCard(
                          group: group,
                          kept: group.lines
                              .where((l) => !_unchecked.contains(l.key))
                              .length,
                          rows: [
                            for (final line in group.lines)
                              RevueRow(
                                key: ValueKey(line.key),
                                line: line,
                                checked: !_unchecked.contains(line.key),
                                quantity: _valueOf(line)?.quantity,
                                unit: _valueOf(line)?.unit,
                                onToggle: () => _toggle(line),
                                onQuantityTap: () => _editQuantity(line),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
          bottomNavigationBar: revue == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KadiSpacing.margin,
                      KadiSpacing.s2,
                      KadiSpacing.margin,
                      KadiSpacing.margin,
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _adding
                          ? null
                          : () => _ajouter(context, revue),
                      child: Text(
                        kept == 0
                            ? StringsFr.ajouterALaListe
                            : StringsFr.ajouterNArticles(kept),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Carte d'un rayon de la Revue : `surface-container`, rayon 18 ; en-tête
/// avec le point du rayon, son nom et « gardés/total ».
class _RayonCard extends StatelessWidget {
  const _RayonCard({
    required this.group,
    required this.kept,
    required this.rows,
  });

  final RevueGroup group;
  final int kept;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(KadiRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    RayonDot(rayon: group.rayon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.rayon.label,
                        semanticsLabel: group.rayon.spokenLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      StringsFr.gardesSur(kept, group.lines.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}
