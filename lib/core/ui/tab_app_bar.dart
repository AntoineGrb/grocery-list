import 'package:material_ui/material_ui.dart';

import '../theme/kadi_theme.dart';
import '../theme/kadi_tokens.dart';

/// Barre d'application d'un onglet (README redesign §5) : 56 dp, titre
/// display à gauche (marge 16), actions en boutons de 48 dp.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 56,
    centerTitle: false,
    titleSpacing: KadiSpacing.margin,
    automaticallyImplyLeading: false,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: KadiText.screenTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
    actions: [
      ...actions,
      const SizedBox(width: KadiSpacing.s2),
    ],
  );
}
