import 'package:material_ui/material_ui.dart';

const _entranceDuration = Duration(milliseconds: 250);
const _highlightDuration = Duration(milliseconds: 1200);

/// Part du surlignage où le fond reste plein avant de s'effacer.
const _highlightHold = 0.25;

/// Décalage de départ du glissement, en fraction de la hauteur de la ligne.
const _slideFrom = Offset(0, 0.25);

/// Arrivée d'une ligne dans la Liste : fondu, léger glissement vertical et
/// fond [color] qui s'efface. La hauteur de la ligne ne s'anime pas (voir la
/// Liste) ; rien ne bouge si les animations sont coupées.
class RowHighlight extends StatefulWidget {
  const RowHighlight({
    super.key,
    required this.color,
    required this.child,
    this.arriving = false,
    this.replays = 0,
  });

  /// Fond du surlignage : la pastille du rayon.
  final Color color;

  /// La ligne vient d'arriver : l'animation part au montage.
  final bool arriving;

  /// Chaque changement rejoue le seul surlignage, sur une ligne présente.
  final int replays;

  final Widget child;

  @override
  State<RowHighlight> createState() => _RowHighlightState();
}

class _RowHighlightState extends State<RowHighlight>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _highlight;
  late final CurvedAnimation _fade;
  late final Animation<Offset> _slide;
  bool _mountChecked = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: _entranceDuration,
      value: 1,
    );
    _highlight = AnimationController(
      vsync: this,
      duration: _highlightDuration,
      value: 1,
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween(begin: _slideFrom, end: Offset.zero).animate(_fade);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery n'est pas lisible dans initState.
    if (_mountChecked) return;
    _mountChecked = true;
    if (widget.arriving) _play(entrance: true);
  }

  @override
  void didUpdateWidget(RowHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replays != widget.replays) _play(entrance: false);
  }

  @override
  void dispose() {
    _fade.dispose();
    _entrance.dispose();
    _highlight.dispose();
    super.dispose();
  }

  void _play({required bool entrance}) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (entrance) _entrance.forward(from: 0);
    _highlight.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      alwaysIncludeSemantics: true,
      child: SlideTransition(
        position: _slide,
        child: AnimatedBuilder(
          animation: _highlight,
          builder: (context, child) {
            final fading =
                (_highlight.value - _highlightHold) / (1 - _highlightHold);
            final opacity = 1 - Curves.easeOut.transform(fading.clamp(0, 1));
            return ColoredBox(
              color: widget.color.withValues(alpha: widget.color.a * opacity),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
