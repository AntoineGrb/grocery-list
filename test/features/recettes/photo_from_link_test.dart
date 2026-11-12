import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kadi/features/recettes/data/photo_from_link.dart';

Uint8List _png(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

void main() {
  group('parseImageLink', () {
    test('lien https direct', () {
      final link = parseImageLink('  https://exemple.fr/chili.jpg ');
      expect(link, isA<RemoteImageLink>());
      expect(
        (link! as RemoteImageLink).uri.toString(),
        'https://exemple.fr/chili.jpg',
      );
    });

    test('page Google Images : l’adresse de son imgurl', () {
      final link = parseImageLink(
        'https://www.google.com/imgres?imgurl=https%3A%2F%2Fexemple.fr%2Fa.png'
        '&imgrefurl=https%3A%2F%2Fexemple.fr',
      );
      expect(
        (link! as RemoteImageLink).uri.toString(),
        'https://exemple.fr/a.png',
      );
    });

    test('data:image en base64', () {
      final bytes = _png(2, 2);
      final link = parseImageLink(
        'data:image/png;base64,${base64Encode(bytes)}',
      );
      expect((link! as InlineImageLink).bytes, bytes);
    });

    test('autre texte : null', () {
      for (final text in [
        '',
        'chili',
        'ftp://exemple.fr/a.jpg',
        'data:text/plain;base64,YQ==',
        'data:image/png;base64,%%%',
      ]) {
        expect(parseImageLink(text), isNull, reason: text);
      }
    });
  });

  group('toRecipeJpeg', () {
    test('plafonne le grand côté à 1600 px, en JPEG', () {
      final jpeg = toRecipeJpeg(_png(3200, 1000));
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, 1600);
      expect(decoded.height, 500);
    });

    test('petite image : taille gardée', () {
      final decoded = img.decodeJpg(toRecipeJpeg(_png(40, 30)))!;
      expect((decoded.width, decoded.height), (40, 30));
    });

    test('pas une image : PhotoLinkException notAnImage', () {
      expect(
        () => toRecipeJpeg(Uint8List.fromList(utf8.encode('<html>'))),
        throwsA(
          isA<PhotoLinkException>().having(
            (e) => e.failure,
            'failure',
            PhotoLinkFailure.notAnImage,
          ),
        ),
      );
    });
  });

  test(
    'photoFromLink : texte qui n’est pas un lien, sans téléchargement',
    () async {
      var downloads = 0;
      await expectLater(
        photoFromLink('chili', (_) async {
          downloads++;
          return Uint8List(0);
        }),
        throwsA(isA<PhotoLinkException>()),
      );
      expect(downloads, 0);
    },
  );

  test(
    'photoFromChoice : une image copiée est réencodée sans réseau',
    () async {
      final jpeg = await photoFromChoice((
        text: null,
        image: _png(10, 10),
      ), (_) async => throw StateError('pas de réseau'));
      expect(img.decodeJpg(jpeg), isNotNull);
    },
  );
}
