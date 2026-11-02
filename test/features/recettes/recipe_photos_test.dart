import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/features/recettes/data/recipe_link.dart';
import 'package:kadi/features/recettes/data/recipe_photos.dart';

/// Photos de recette sous `photos/` (AD-18) et lien de recette.
void main() {
  group('photos', () {
    late Directory documents;
    late RecipePhotos photos;

    setUp(() {
      documents = Directory.systemTemp.createTempSync('kadi_photos_');
      photos = RecipePhotos(() async => documents);
    });
    tearDown(() => documents.deleteSync(recursive: true));

    File source(String name, List<int> bytes) =>
        File('${documents.path}/$name')..writeAsBytesSync(bytes);

    test('copie sous photos/<uuid v4>.jpg, rend ce seul nom', () async {
      final picked = source('pick.jpg', [1, 2, 3]);
      final name = await photos.importPhoto(picked.path);
      expect(
        name,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}\.jpg$',
          ),
        ),
      );
      final dir = await photos.directory();
      expect(dir.path, '${documents.path}${Platform.pathSeparator}photos');
      final copy = RecipePhotos.fileIn(dir, name);
      expect(copy.readAsBytesSync(), [1, 2, 3]);
      // La source reste où elle est.
      expect(picked.existsSync(), isTrue);

      final other = await photos.importPhoto(picked.path);
      expect(other, isNot(name));
    });

    test('source illisible : lève, aucun fichier dans photos/', () async {
      await expectLater(
        photos.importPhoto('${documents.path}/absente.jpg'),
        throwsA(isA<FileSystemException>()),
      );
      final dir = await photos.directory();
      expect(dir.existsSync() ? dir.listSync() : const [], isEmpty);
    });

    test('suppression : le fichier part ; absent, rien ne lève ; un chemin '
        'hors de photos/ n’est jamais supprimé', () async {
      final name = await photos.importPhoto(source('p.jpg', [9]).path);
      final file = RecipePhotos.fileIn(await photos.directory(), name);
      await photos.delete(name);
      expect(file.existsSync(), isFalse);
      await photos.delete(name);

      final outside = source('dehors.jpg', [7]);
      await photos.delete('../dehors.jpg');
      await photos.delete(r'..\dehors.jpg');
      await photos.delete('..');
      await photos.delete('');
      expect(outside.existsSync(), isTrue);
    });
  });

  group('dossier documents illisible', () {
    test(
      'l’échec n’est pas gardé : l’appel suivant relit le dossier',
      () async {
        final documents = Directory.systemTemp.createTempSync('kadi_retry_');
        addTearDown(() => documents.deleteSync(recursive: true));
        var calls = 0;
        final photos = RecipePhotos(() async {
          if (++calls == 1) throw const FileSystemException('échec simulé');
          return documents;
        });
        await expectLater(
          photos.directory(),
          throwsA(isA<FileSystemException>()),
        );
        final dir = await photos.directory();
        expect(dir.path, '${documents.path}${Platform.pathSeparator}photos');
        expect(calls, 2);
        await photos.directory();
        expect(calls, 2);
      },
    );

    test('suppression : l’échec est ignoré, rien ne lève', () async {
      final photos = RecipePhotos(
        () async => throw const FileSystemException('échec simulé'),
      );
      await expectLater(photos.delete('a.jpg'), completes);
    });
  });

  group('lien', () {
    test('nettoyé : espaces de bord retirés, vide ou blanc = nul', () {
      expect(cleanRecipeLink('  marmiton.org/chili '), 'marmiton.org/chili');
      expect(cleanRecipeLink('   '), isNull);
      expect(cleanRecipeLink(''), isNull);
      expect(cleanRecipeLink(null), isNull);
    });

    test('ouvert : https:// ajouté sans schéma, gardé sinon', () {
      expect(
        recipeLinkUri(' marmiton.org/chili '),
        Uri.parse('https://marmiton.org/chili'),
      );
      expect(
        recipeLinkUri('http://exemple.fr/a?b=1'),
        Uri.parse('http://exemple.fr/a?b=1'),
      );
      expect(
        recipeLinkUri('HTTPS://Exemple.fr'),
        Uri.parse('HTTPS://Exemple.fr'),
      );
      expect(recipeLinkUri('   '), isNull);
      expect(recipeLinkUri('https://'), isNull);
    });
  });
}
