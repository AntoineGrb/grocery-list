import 'package:material_ui/material_ui.dart';

const _duration = Duration(milliseconds: 300);

/// Ouverture ou repli animé d'un élément de la Liste : hauteur et fondu
/// ensemble, 300 ms.
///
/// [appear] : l'élément s'ouvre depuis une hauteur nulle à son montage (une
/// ligne décochée qui revient, son En-tête de rayon). [vanish] : il se replie
/// à son montage puis appelle [onVanished] (l'En-tête d'un rayon devenu
/// vide). Sans l'un ni l'autre, rien ne bouge ; animations coupées, tout est
/// immédiat.
class SizeReveal extends StatefulWidget {
  const SizeReveal({
    super.key,
    required this.child,
    this.appear = false,
    this.vanish = false,
    this.onVanished,
  });

  final Widget child;
  final bool appear;
  final bool vanish;
  final VoidCallback? onVanished;

  @override
  State<SizeReveal> createState() => _SizeRevealState();
}

class _SizeRevealState extends State<SizeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.appear ? 0 : 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final instant = MediaQuery.disableAnimationsOf(context);
    if (widget.vanish) {
      if (instant) {
        _controller.value = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) => _done());
      } else {
        _controller.reverse(from: 1).whenComplete(_done);
      }
    } else if (widget.appear) {
      if (instant) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  void _done() {
    if (mounted) widget.onVanished?.call();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: _curve, child: widget.child),
  );
}
