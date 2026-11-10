import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'recipe_photos.dart';

/// Échec de « Photo depuis un lien ».
enum PhotoLinkFailure {
  /// Le texte n'est pas un lien, ou ce qu'il donne n'est pas une image.
  notAnImage,

  /// Pas de réponse (hors ligne, délai dépassé, erreur du serveur).
  network,
}

class PhotoLinkException implements Exception {
  const PhotoLinkException(this.failure);

  final PhotoLinkFailure failure;

  @override
  String toString() => 'PhotoLinkException($failure)';
}

/// Image désignée par un lien collé : une adresse à télécharger, ou des
/// octets déjà là (`data:image/…;base64,…`).
sealed class ImageLink {
  const ImageLink();
}

class RemoteImageLink extends ImageLink {
  const RemoteImageLink(this.uri);

  final Uri uri;
}

class InlineImageLink extends ImageLink {
  const InlineImageLink(this.bytes);

  final Uint8List bytes;
}

/// Lit le texte collé [text] :
///
/// - `data:image/…;base64,…`, ce que donne souvent « Copier l'adresse de
///   l'image » sur une miniature de Google Images ;
/// - un lien de page Google Images (`…/imgres?imgurl=…`) : l'adresse de
///   l'image qu'il porte ;
/// - un lien `http` ou `https`.
///
/// Rend `null` pour tout autre texte.
ImageLink? parseImageLink(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('data:')) {
    final comma = trimmed.indexOf(',');
    if (comma < 0) return null;
    final header = trimmed.substring(5, comma).toLowerCase();
    if (!header.startsWith('image/') || !header.endsWith(';base64')) {
      return null;
    }
    try {
      return InlineImageLink(base64Decode(trimmed.substring(comma + 1)));
    } on FormatException {
      return null;
    }
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  if (uri.host.isEmpty) return null;
  final imgurl = uri.queryParameters['imgurl'];
  if (imgurl != null && uri.path.endsWith('/imgres')) {
    return parseImageLink(imgurl);
  }
  return RemoteImageLink(uri);
}

/// Adresse de recherche Google Images pour [query].
Uri googleImagesSearch(String query) =>
    Uri.https('www.google.com', '/search', {'tbm': 'isch', 'q': query.trim()});

/// Plafond du téléchargement d'une image, en octets.
const photoLinkMaxBytes = 10 * 1024 * 1024;

/// Délai d'un téléchargement d'image.
const photoLinkTimeout = Duration(seconds: 15);

/// Télécharge les octets à [uri] ; remplacé en test.
typedef DownloadBytes = Future<Uint8List> Function(Uri uri);

/// Téléchargement par `dart:io` : redirections suivies, [photoLinkTimeout],
/// au plus [photoLinkMaxBytes]. Un statut autre que 200 ou une réponse qui
/// se déclare autre chose qu'une image lève une [PhotoLinkException].
Future<Uint8List> downloadImageBytes(Uri uri) async {
  final client = HttpClient()..connectionTimeout = photoLinkTimeout;
  try {
    final request = await client.getUrl(uri).timeout(photoLinkTimeout);
    // Certains sites refusent un client sans navigateur déclaré.
    request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Android)');
    request.headers.set(HttpHeaders.acceptHeader, 'image/*');
    final response = await request.close().timeout(photoLinkTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw const PhotoLinkException(PhotoLinkFailure.network);
    }
    final type = response.headers.contentType?.mimeType;
    if (type != null &&
        !type.startsWith('image/') &&
        type != 'application/octet-stream') {
      throw const PhotoLinkException(PhotoLinkFailure.notAnImage);
    }
    if (response.contentLength > photoLinkMaxBytes) {
      throw const PhotoLinkException(PhotoLinkFailure.notAnImage);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(photoLinkTimeout)) {
      builder.add(chunk);
      if (builder.length > photoLinkMaxBytes) {
        throw const PhotoLinkException(PhotoLinkFailure.notAnImage);
      }
    }
    return builder.takeBytes();
  } on PhotoLinkException {
    rethrow;
  } catch (_) {
    throw const PhotoLinkException(PhotoLinkFailure.network);
  } finally {
    client.close(force: true);
  }
}

/// Décode [bytes], plafonne le côté à [photoMaxSide] et réencode en JPEG
/// [photoQuality], comme une photo de la galerie. Lève une
/// [PhotoLinkException] si [bytes] n'est pas une image.
Uint8List toRecipeJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const PhotoLinkException(PhotoLinkFailure.notAnImage);
  }
  final maxSide = photoMaxSide.toInt();
  final image = decoded.width <= maxSide && decoded.height <= maxSide
      ? decoded
      : decoded.width >= decoded.height
      ? img.copyResize(decoded, width: maxSide)
      : img.copyResize(decoded, height: maxSide);
  return img.encodeJpg(image, quality: photoQuality);
}

/// Image JPEG prête pour `photos/` à partir du texte collé [text] : lien
/// lu ([parseImageLink]), téléchargé par [download] s'il le faut, puis
/// réencodé hors du fil de l'interface. Lève une [PhotoLinkException].
Future<Uint8List> photoFromLink(String text, DownloadBytes download) async {
  final link = parseImageLink(text);
  final Uint8List bytes = switch (link) {
    null => throw const PhotoLinkException(PhotoLinkFailure.notAnImage),
    InlineImageLink(:final bytes) => bytes,
    RemoteImageLink(:final uri) => await download(uri),
  };
  return Isolate.run(() => toRecipeJpeg(bytes));
}
