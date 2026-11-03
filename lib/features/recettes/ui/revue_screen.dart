import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/state/liste_notice.dart';
import 'package:kadi/features/liste/ui/rayon_header.dart';
import 'package:material_ui/material_ui.dart';

import '../state/recettes_providers.dart';
import '../state/revue.dart';
import 'revue_row.dart';

/// Revue : écran poussé plein écran, flèche retour, sans Barre de
/// navigation. Les ingrédients des recettes à valider, groupés par rayon
/// dans l'ordre du parcours, cochés à l'ouverture (R4) ; on y décoche ce
/// qu'on a déjà et corrige une quantité ; Bouton d'action « Ajouter à la
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
  /// un retour n'écrit rien. Clés des lignes décochées.
  final _unchecked = <String>{};

  /// Texte du Champ quantité de chaque ligne chiffrée, par clé de ligne ;
  /// une ligne sans quantité n'a pas de champ.
  final _controllers = <String, TextEditingController>{};

  /// Écriture en cours : le bouton ne réagit plus.
  bool _adding = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Texte d'origine du champ de [line] : sa quantité exacte dans son unité.
  static String _originalText(RevueLine line) =>
      quantityFieldText(line.quantity, InputUnit.of(line.fieldUnit));

  /// Le contrôleur du champ de [line], nul pour une ligne sans quantité.
  TextEditingController? _controllerFor(RevueLine line) => line.quantity == null
      ? null
      : _controllers.putIfAbsent(
          line.key,
          () => TextEditingController(text: _originalText(line)),
        );

  void _toggle(RevueLine line) => setState(() {
    if (!_unchecked.remove(line.key)) _unchecked.add(line.key);
  });

  /// Le brouillon : lignes décochées et champs dont le texte a changé. Une
  /// ligne sans quantité n'a pas de champ : jamais de correction, elle garde
  /// ses parts d'origine.
  RevueDraft _draft(Revue revue) {
    final corrections = <String, int?>{};
    for (final group in revue.groups) {
      for (final line in group.lines) {
        if (line.quantity == null) continue;
        final text = _controllers[line.key]?.text;
        if (text == null || text == _originalText(line)) continue;
        corrections[line.key] = quantityFromFieldText(
          text,
          InputUnit.of(line.fieldUnit),
        )?.quantity;
      }
    }
    return RevueDraft(unchecked: {..._unchecked}, corrections: corrections);
  }

  Future<void> _ajouter(BuildContext context, Revue revue) async {
    if (_adding) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final notice = ref.read(listeNoticeProvider.notifier);
    try {
      await ref.read(ajouterALaListeProvider).call(revue, draft: _draft(revue));
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
    return FutureBuilder<Revue>(
      future: _revue,
      builder: (context, snapshot) {
        final revue = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text(StringsFr.revue)),
          body: revue == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.only(bottom: KadiSpacing.s4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KadiSpacing.margin,
                        KadiSpacing.s2,
                        KadiSpacing.margin,
                        0,
                      ),
                      child: Text(
                        StringsFr.revueConsigne,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final group in revue.groups) ...[
                      RayonHeader(rayon: group.rayon),
                      for (final line in group.lines)
                        RevueRow(
                          key: ValueKey(line.key),
                          line: line,
                          checked: !_unchecked.contains(line.key),
                          controller: _controllerFor(line),
                          onToggle: () => _toggle(line),
                        ),
                    ],
                  ],
                ),
          // Clavier ouvert (saisie d'une quantité) : le bouton reste visible
          // juste au-dessus ; fermé, il ne bouge pas.
          bottomNavigationBar: revue == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KadiSpacing.margin,
                        KadiSpacing.s2,
                        KadiSpacing.margin,
                        KadiSpacing.s2,
                      ),
                      child: FilledButton(
                        onPressed: _adding
                            ? null
                            : () => _ajouter(context, revue),
                        child: const Text(StringsFr.ajouterALaListe),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
