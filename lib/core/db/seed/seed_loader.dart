import 'dart:convert';

import 'package:drift/drift.dart';

import '../../rayons/rayon.dart';
import '../../settings/settings_repository.dart';
import '../../units/unit.dart';
import '../app_database.dart';

/// Lit un asset texte (par défaut `rootBundle.loadString`).
typedef SeedAssetLoader = Future<String> Function(String path);

/// Chargeur unique du contenu fourni (AD-8), lancé à chaque démarrage.
///
/// Pour chaque fichier dont la `seed_version` dépasse celle des réglages, il
/// insère les UUID absents (une ligne supprimée compte comme présente) et ne
/// met jamais à jour une ligne existante. Lignes fournies et réglages par
/// défaut ont `updated_at = 0`. Tout se fait en une transaction : un échec
/// n'écrit rien.
class SeedLoader {
  SeedLoader({
    required this._db,
    required this._settings,
    required this._loadAsset,
    required this._normalizeName,
  });

  static const articlesFile = 'articles';
  static const articlesPath = 'assets/seed/articles.json';

  final AppDatabase _db;
  final SettingsRepository _settings;
  final SeedAssetLoader _loadAsset;
  final String Function(String name) _normalizeName;

  Future<void> run() async {
    // Lecture et validation hors transaction : un fichier invalide lève avant
    // toute écriture.
    final articles = _parseArticles(await _loadAsset(articlesPath));

    await _db.transaction(() async {
      final hasSettings = await _settings.exists();
      final current = hasSettings
          ? (await _settings.read()).seedVersions
          : const <String, int>{};
      final next = Map<String, int>.of(current);

      if (articles.version > (current[articlesFile] ?? 0)) {
        await _insertArticles(articles.rows);
        next[articlesFile] = articles.version;
      }

      if (!hasSettings) {
        await _settings.insertDefaults(seedVersions: next);
      } else if (!_sameVersions(current, next)) {
        await _settings.setSeedVersions(next);
      }
    });
  }

  Future<void> _insertArticles(List<ArticlesCompanion> rows) async {
    final existingIds = (await _db.select(_db.articles).get())
        .map((a) => a.id)
        .toSet();
    final activeNames =
        (await (_db.select(
              _db.articles,
            )..where((a) => a.deletedAt.isNull())).get())
            .map((a) => a.normalizedName)
            .toSet();
    for (final row in rows) {
      if (existingIds.contains(row.id.value)) continue;
      // Un nom normalisé reste unique parmi les articles actifs (AD-17).
      if (!activeNames.add(row.normalizedName.value)) continue;
      await _db.into(_db.articles).insert(row);
    }
  }

  _SeedFile<ArticlesCompanion> _parseArticles(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final version = json['seed_version'] as int;
    final ids = <String>{};
    final rows = <ArticlesCompanion>[];
    for (final raw in json['articles'] as List<dynamic>) {
      final a = raw as Map<String, dynamic>;
      final id = a['id'] as String;
      if (!ids.add(id)) throw FormatException('UUID en double : $id');
      final name = (a['name'] as String).trim();
      if (name.isEmpty) throw FormatException('Article sans nom : $id');
      final rayon = Rayon.fromCode(a['rayon'] as String);
      final unit = Unit.fromCode(a['unit'] as String?);
      rows.add(
        ArticlesCompanion.insert(
          id: id,
          updatedAt: 0,
          name: name,
          normalizedName: _normalizeName(name),
          rayon: rayon.code,
          unit: Value(unit?.code),
          pictoKey: a['picto_key'] as String,
        ),
      );
    }
    return _SeedFile(version, rows);
  }

  static bool _sameVersions(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

class _SeedFile<T> {
  const _SeedFile(this.version, this.rows);
  final int version;
  final List<T> rows;
}
