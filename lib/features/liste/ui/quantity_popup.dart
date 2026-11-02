import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/quantity_field.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:material_ui/material_ui.dart';

import '../state/liste_panel.dart';
import '../state/liste_providers.dart';
import 'quantity_input.dart';
import 'rayon_tag.dart' show addPopupLeft, addPopupWidth;

/// Quantité saisie dans la Popup quantité ; [value] nulle : sans quantité.
typedef QuantityEdit = ({StoredQuantity? value});

/// Écart entre le bas de la carte et le haut du panneau.
const _panelGap = KadiSpacing.s2;

/// Hauteur gardée à la carte quand le panneau ne lui laisse pas la place :
/// elle passe alors sur lui, et défile.
const _cardMinHeight = KadiSpacing.touchTarget * 2;

/// Taille de la carte au début de son apparition, le reste vient du zoom.
const _startScale = 0.96;

const _transitionDuration = Duration(milliseconds: 150);

/// Ouvre la Popup quantité au-dessus du Panneau + (AD-13) : une carte
/// flottante, jamais une feuille ; le panneau reste ouvert dessous.
///
/// Préchargée avec [quantity] en [unit], lue dans [initialUnit]. Entrée, tap
/// hors de la carte et retour la ferment. Rend `null` si rien n'a changé :
/// sans saisie, ou une saisie égale à [quantity]. Sinon la valeur saisie, que
/// l'appelant écrit lui-même.
Future<QuantityEdit?> showQuantityPopup(
  BuildContext context, {
  required String title,
  int? quantity,
  Unit? unit,
  required InputUnit initialUnit,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final input = QuantityInput(quantity: quantity, initialUnit: initialUnit);
  // Curseur placé d'avance : sinon le focus automatique le place lui-même et
  // Flutter montre sa poignée, à cheval sur le bord du champ.
  input.controller.selection = TextSelection.collapsed(
    offset: input.controller.text.length,
  );
  return Navigator.of(context, rootNavigator: true).push(
    _QuantityPopupRoute(
      title: title,
      stored: storedQuantityOf(quantity, unit),
      input: input,
      panel: container.read(listePanelProvider),
      animated: !MediaQuery.disableAnimationsOf(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// Route légère de la popup. Elle possède la saisie : quelle que soit la
/// fermeture, son résultat est [currentResult].
class _QuantityPopupRoute extends PopupRoute<QuantityEdit> {
  _QuantityPopupRoute({
    required this.title,
    required this.stored,
    required this.input,
    required this.panel,
    required this.animated,
    required this.barrierLabel,
  });

  final String title;
  final StoredQuantity? stored;
  final QuantityInput input;
  final ListePanel panel;

  /// Faux si les animations sont coupées : la carte apparaît d'un coup.
  final bool animated;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      animated ? _transitionDuration : Duration.zero;

  @override
  QuantityEdit? get currentResult {
    if (!input.touched) return null;
    final value = input.value;
    return value == stored ? null : (value: value);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => QuantityPopup(
    title: title,
    input: input,
    panel: panel,
    animation: animation,
  );

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }
}

/// Bas de la carte en coordonnées globales : juste au-dessus du haut [panelTop]
/// du panneau, en gardant [_cardMinHeight] sous la marge haute et sans passer
/// sous le clavier.
double _cardBottom(MediaQueryData media, double? panelTop) {
  final keyboardTop = media.size.height - media.viewInsets.bottom;
  final wanted = (panelTop ?? keyboardTop) - _panelGap;
  final lowest = media.padding.top + _cardMinHeight;
  return math.min(math.max(wanted, lowest), keyboardTop);
}

/// Popup quantité (DESIGN `quantity-popup`) : carte compacte au fond des tags,
/// sans bordure ni titre visible, posée juste au-dessus du panneau sur sa marge
/// gauche : Champ quantité focalisé et bouton Valider, puis le Choix d'unité.
/// Jamais de rayon ni de « Supprimer ». Le nom [title] n'est que lu par
/// TalkBack. Elle suit le panneau quand le clavier le déplace, et défile si
/// elle ne tient pas (très grande police).
class QuantityPopup extends StatefulWidget {
  const QuantityPopup({
    super.key,
    required this.title,
    required this.input,
    required this.panel,
    required this.animation,
  });

  final String title;
  final QuantityInput input;
  final ListePanel panel;

  /// Avancement de la route : fondu et léger zoom depuis le bord bas.
  final Animation<double> animation;

  @override
  State<QuantityPopup> createState() => _QuantityPopupState();
}

class _QuantityPopupState extends State<QuantityPopup> {
  late final _curve = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOut,
  );
  late final _scale = Tween<double>(begin: _startScale, end: 1).animate(_curve);

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  /// Une seconde Entrée pendant la fermeture ne ferme pas le panneau dessous.
  void _close() {
    if (ModalRoute.isCurrentOf(context) ?? false) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final input = widget.input;

    final card = FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.bottomLeft,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: widget.title,
          child: Material(
            // Sans ombre ni contour, comme la liste des rayons.
            color: scheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(KadiRadius.lg)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KadiSpacing.s3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: StringsFr.quantite,
                          child: QuantityField(
                            controller: input.controller,
                            unit: input.unit,
                            autofocus: true,
                            filled: true,
                            onChanged: (_) => input.edited = true,
                            onSubmitted: (_) => _close(),
                          ),
                        ),
                      ),
                      const SizedBox(width: KadiSpacing.s2),
                      SubmitButton(
                        icon: Icons.check,
                        tooltip: StringsFr.valider,
                        onPressed: _close,
                      ),
                    ],
                  ),
                  const SizedBox(height: KadiSpacing.s1),
                  UnitChoice(
                    selected: input.unit,
                    dense: true,
                    onSelected: (unit) =>
                        setState(() => input.selectUnit(unit)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return ListenableBuilder(
      listenable: widget.panel,
      child: card,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final bottom = _cardBottom(media, widget.panel.top);
        return Padding(
          padding: EdgeInsets.only(
            left: addPopupLeft,
            right: addPopupLeft,
            top: media.padding.top,
            bottom: media.size.height - bottom,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: addPopupWidth(media.size.width),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Bouton Valider du Panneau + et de la Popup quantité : carré arrondi plein
/// en argile, comme le FAB +, grisé sans [onPressed]. Cible de 48 dp.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KadiRadius.md)),
        ),
      ),
    );
  }
}
