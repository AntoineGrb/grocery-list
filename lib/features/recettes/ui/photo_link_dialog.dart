import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/theme/kadi_tokens.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:material_ui/material_ui.dart';

import '../data/photo_from_link.dart';
import '../state/recettes_providers.dart';

/// Dialogue « Photo depuis un lien » : rend l'image copiée ou le texte
/// collé, `null` si Antoine annule.
Future<ClipContent?> showPhotoLinkDialog(
  BuildContext context, {
  required String recipeName,
}) => showDialog<ClipContent>(
  context: context,
  builder: (_) => PhotoLinkDialog(recipeName: recipeName),
);

/// Champ d'adresse d'image, prérempli par le presse-papiers s'il contient
/// une image copiée (son aperçu remplace le champ) ou un lien d'image, et
/// de nouveau au retour du navigateur ; bouton « Coller » ; « Chercher sur Google Images » ouvre le navigateur
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

  /// Image copiée prise au presse-papiers.
  Uint8List? _image;

  @override
  void initState() {
    super.initState();
    // Au retour du navigateur, Android ne laisse lire le presse-papiers
    // qu'une fois la fenêtre au premier plan : un court délai.
    _lifecycle = AppLifecycleListener(
      onResume: () => Future<void>.delayed(
        const Duration(milliseconds: 300),
        _fillFromClipboard,
      ),
    );
    _fillFromClipboard();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Rien de saisi, et une image ou un lien d'image au presse-papiers :
  /// le dialogue le prend.
  Future<void> _fillFromClipboard() async {
    if (!mounted || _image != null || _controller.text.trim().isNotEmpty) {
      return;
    }
    final clip = await ref.read(clipboardReaderProvider)();
    if (!mounted || clip == null) return;
    if (_image != null || _controller.text.trim().isNotEmpty) return;
    final text = clip.text?.trim() ?? '';
    if (clip.image != null) {
      setState(() => _image = clip.image);
    } else if (parseImageLink(text) != null) {
      setState(() => _controller.text = text);
    }
  }

  /// « Coller » : l'image copiée, sinon le texte, quel qu'il soit.
  Future<void> _paste() async {
    final clip = await ref.read(clipboardReaderProvider)();
    if (!mounted || clip == null) return;
    setState(() {
      if (clip.image != null) {
        _image = clip.image;
        _controller.clear();
      } else if (clip.text case final text?) {
        _image = null;
        _controller.text = text.trim();
      }
    });
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
    final image = _image;
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
            if (image != null)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KadiRadius.sm),
                    child: Image.memory(
                      image,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      cacheWidth: 216,
                      errorBuilder: (_, _, _) =>
                          const SizedBox.square(dimension: 72),
                    ),
                  ),
                  const SizedBox(width: KadiSpacing.s3),
                  const Expanded(child: Text(StringsFr.imageCopiee)),
                  IconButton(
                    onPressed: () => setState(() => _image = null),
                    tooltip: StringsFr.effacerLeTexte,
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            else
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
          onPressed: image != null
              ? () => Navigator.of(context).pop((text: null, image: image))
              : text.isEmpty
              ? null
              : () => Navigator.of(context).pop((text: text, image: null)),
          child: const Text(StringsFr.ajouter),
        ),
      ],
    );
  }
}
