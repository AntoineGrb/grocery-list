import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/photo_from_link.dart';
import '../state/recettes_providers.dart';

/// Dialogue « Photo depuis un lien » : rend le texte collé, `null` si
/// Antoine annule.
Future<String?> showPhotoLinkDialog(
  BuildContext context, {
  required String recipeName,
}) => showDialog<String>(
  context: context,
  builder: (_) => PhotoLinkDialog(recipeName: recipeName),
);

/// Champ d'adresse d'image, prérempli par le presse-papiers s'il contient
/// un lien d'image (et de nouveau au retour du navigateur, champ vide) ;
/// bouton « Coller » ; « Chercher sur Google Images » ouvre le navigateur
/// sur le nom de la recette. « Ajouter » rend le texte.
class PhotoLinkDialog extends ConsumerStatefulWidget {
  const PhotoLinkDialog({super.key, required this.recipeName});

  final String recipeName;

  @override
  ConsumerState<PhotoLinkDialog> createState() => _PhotoLinkDialogState();
}

class _PhotoLinkDialogState extends ConsumerState<PhotoLinkDialog> {
  final _controller = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _fillFromClipboard);
    _fillFromClipboard();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Champ vide et lien d'image au presse-papiers : il le prend.
  Future<void> _fillFromClipboard() async {
    if (_controller.text.trim().isNotEmpty) return;
    final text = await _clipboardText();
    if (!mounted || text == null || parseImageLink(text) == null) return;
    if (_controller.text.trim().isNotEmpty) return;
    setState(() => _controller.text = text.trim());
  }

  Future<void> _paste() async {
    final text = await _clipboardText();
    if (!mounted || text == null) return;
    setState(() => _controller.text = text.trim());
  }

  static Future<String?> _clipboardText() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _search() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = widget.recipeName.trim();
    var opened = false;
    try {
      opened = await ref.read(openLinkProvider)(
        googleImagesSearch(name.isEmpty ? StringsFr.recette : name),
      );
    } catch (_) {}
    if (!opened && messenger != null) {
      showErrorSnackBar(messenger, StringsFr.lienImpossible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = _controller.text.trim();
    return AlertDialog(
      title: const Text(StringsFr.photoDepuisUnLien),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              StringsFr.photoLienAide,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: KadiSpacing.s3),
            OutlinedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.image_search),
              label: const Text(StringsFr.chercherSurGoogleImages),
            ),
            const SizedBox(height: KadiSpacing.s3),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              maxLines: 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: StringsFr.adresseDeLImage,
                suffixIcon: IconButton(
                  onPressed: _paste,
                  tooltip: StringsFr.collerLAdresse,
                  icon: const Icon(Icons.content_paste),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(StringsFr.annuler),
        ),
        TextButton(
          onPressed: text.isEmpty
              ? null
              : () => Navigator.of(context).pop(text),
          child: const Text(StringsFr.ajouter),
        ),
      ],
    );
  }
}
