import 'dart:io';

import 'package:uuid/uuid.dart';

/// Source d'une photo de recette : le sélecteur de photos du système ou
/// l'application photo du téléphone (C2 : aucune permission).
enum PhotoSource { galerie, appareilPhoto }

/// Choisit une image à [source], plafonnée (côté 1600 px) et réencodée
/// (JPEG 85), et rend son chemin temporaire ; `null` si Antoine annule.
typedef PickPhoto = Future<String?> Function(PhotoSource source);

/// Ouvre [uri] hors de l'app (navigateur) ; faux si rien ne l'ouvre.
typedef OpenLink = Future<bool> Function(Uri uri);

/// Plafond du côté d'une photo de recette, en pixels.
const photoMaxSide = 1600.0;

/// Qualité JPEG d'une photo de recette.
const photoQuality = 85;

/// Photos de recette dans `photos/` du dossier documents de l'app (AD-18) :
/// la table `recipes` ne stocke que le nom du fichier.
///
/// [documents] rend le dossier documents de l'app (`path_provider` en
/// production, un dossier temporaire en test).
class RecipePhotos {
  RecipePhotos(this._documents, {this._uuid = const Uuid()});

  /// Sous-dossier des photos dans le dossier documents.
  static const folder = 'photos';

  final Future<Directory> Function() _documents;
  final Uuid _uuid;
  Future<Directory>? _directory;

  /// Dossier des photos (lu une fois, pas créé). Un échec n'est pas gardé :
  /// l'appel suivant relit le dossier documents.
  Future<Directory> directory() => _directory ??= _documents().then(
    (docs) => Directory('${docs.path}${Platform.pathSeparator}$folder'),
    onError: (Object error, StackTrace stack) {
      _directory = null;
      Error.throwWithStackTrace(error, stack);
    },
  );

  /// Fichier de la photo [name] dans le dossier [directory].
  static File fileIn(Directory directory, String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  /// Copie l'image déjà réencodée et plafonnée [sourcePath] sous
  /// `photos/<uuid v4>.jpg` et rend ce nom de fichier. Lève sur un échec,
  /// sans laisser de fichier.
  Future<String> importPhoto(String sourcePath) async {
    final dir = await directory();
    await dir.create(recursive: true);
    final name = '${_uuid.v4()}.jpg';
    final target = fileIn(dir, name);
    try {
      await File(sourcePath).copy(target.path);
    } catch (_) {
      await _deleteFile(target);
      rethrow;
    }
    return name;
  }

  /// Supprime la photo [name] si elle existe ; un échec est ignoré (au pire,
  /// un fichier orphelin reste dans `photos/`).
  Future<void> delete(String name) async {
    if (!_isFileName(name)) return;
    final Directory dir;
    try {
      dir = await directory();
    } catch (_) {
      return;
    }
    await _deleteFile(fileIn(dir, name));
  }

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Un nom de fichier seul, sans chemin : rien hors de `photos/` n'est
  /// supprimé.
  static bool _isFileName(String name) =>
      name.isNotEmpty &&
      !name.contains('/') &&
      !name.contains(r'\') &&
      name != '.' &&
      name != '..';
}
