import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/core/backup/backup_archive.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/test_db.dart';

/// Archive de sauvegarde (AD-9) : `data.json` générique et `photos/`.
void main() {
  late Directory root;
  late Directory photos;
  late Directory target;
  late AppDatabase db;

  /// Instant fixe de l'export, en heure locale.
  final now = DateTime(2026, 11, 4, 23, 30);

  setUp(() {
    root = Directory.systemTemp.createTempSync('kadi_backup_');
    photos = Directory('${root.path}${Platform.pathSeparator}photos');
    target = Directory('${root.path}${Platform.pathSeparator}tmp')
      ..createSync();
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  File photo(String name, List<int> bytes) {
    photos.createSync(recursive: true);
    return File('${photos.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(bytes);
  }

  Future<File> export() =>
      BackupExporter(db).export(photos: photos, target: target, now: now);

  Archive unzip(File file) => ZipDecoder().decodeBytes(file.readAsBytesSync());

  Map<String, Object?> dataOf(Archive archive) =>
      jsonDecode(utf8.decode(archive.findFile(BackupFormat.dataFile)!.content))
          as Map<String, Object?>;

  Map<String, Object?> tablesOf(Map<String, Object?> data) =>
      data[BackupFormat.tablesKey]! as Map<String, Object?>;

  Set<String> photoNames(Archive archive) => {
    for (final f in archive.files)
      if (f.isFile && f.name.startsWith(BackupFormat.photosFolder))
        f.name.substring(BackupFormat.photosFolder.length),
  };

  Future<List<Map<String, Object?>>> rawRows(String table) async => [
    for (final row in await db.customSelect('SELECT * FROM "$table"').get())
      row.data,
  ];

  /// Fichiers laissés dans le dossier d'export.
  List<String> filesIn(Directory dir) => [
    for (final f in dir.listSync().whereType<File>()) f.uri.pathSegments.last,
  ];

  test('Export complet : 8 tables, lignes brutes, ligne supprimée présente, '
      'format_version = 3, photo sous photos/', () async {
    db = await seededDatabase();
    final clock = Clock();
    final liste = ListeRepository(db, clock);
    final recettes = RecettesRepository(db, clock);

    // Recette avec photo.
    final bytes = List<int>.generate(5000, (i) => i % 251);
    photo('chili.jpg', bytes);
    await (db.update(db.recipes)
          ..where((r) => r.id.equals(SeedRecipeIds.chili)))
        .write(const RecipesCompanion(photo: Value('chili.jpg')));
    // Sélection validée : lignes et contributions `week_selection`.
    await recettes.select(SeedRecipeIds.chili);
    final pending = await recettes.pendingSelections();
    await AjouterALaListe(db, liste, recettes)(
      buildRevue(
        selectionIds: pending.selectionIds,
        ingredients: pending.ingredients,
        routeOrder: Rayon.values,
      ),
    );
    // Ajout du Panneau +, parcours modifié, une recette supprimée.
    await liste.addArticle(SeedIds.lait);
    await SettingsRepository(
      db,
      clock,
    ).setRouteOrder(Rayon.values.reversed.toList());
    await recettes.deleteRecipe(SeedRecipeIds.quiche);

    final file = await export();
    expect(file.uri.pathSegments.last, 'kadi-sauvegarde-2026-11-04.zip');
    expect(file.parent.path, target.path);
    expect(filesIn(target), ['kadi-sauvegarde-2026-11-04.zip']);

    final archive = unzip(file);
    final data = dataOf(archive);
    expect(data[BackupFormat.formatVersionKey], 3);
    expect(data[BackupFormat.formatVersionKey], db.schemaVersion);
    expect(
      data[BackupFormat.exportedAtKey],
      now.toUtc().millisecondsSinceEpoch,
    );

    final tables = tablesOf(data);
    expect(tables.keys, hasLength(8));
    // Chaque table, ligne par ligne, telle que SQLite la stocke.
    for (final name in tables.keys) {
      expect(tables[name], await rawRows(name), reason: name);
    }
    for (final name in [
      'articles',
      'frequents',
      'list_lines',
      'list_contributions',
      'settings',
      'recipes',
      'recipe_ingredients',
      'week_selections',
    ]) {
      expect(tables[name], isNotEmpty, reason: name);
    }

    final recipes = [
      for (final r in tables['recipes']! as List) r as Map<String, Object?>,
    ];
    final quiche = recipes.singleWhere((r) => r['id'] == SeedRecipeIds.quiche);
    expect(quiche['deleted_at'], isA<int>());
    final chili = recipes.singleWhere((r) => r['id'] == SeedRecipeIds.chili);
    expect(chili['photo'], 'chili.jpg');

    final settings = (tables['settings']! as List).single as Map;
    expect(
      settings['route_order'],
      Rayon.values.reversed.map((r) => r.code).join(','),
    );
    // Booléens stockés en entiers par SQLite.
    expect(settings['group_by_rayon'], isA<int>());

    final sources = {
      for (final c in tables['list_contributions']! as List)
        (c as Map)['source'],
    };
    expect(sources, hasLength(2));

    expect(photoNames(archive), {'chili.jpg'});
    final stored = archive.findFile('${BackupFormat.photosFolder}chili.jpg')!;
    expect(stored.content, bytes);
    expect(stored.compression, CompressionType.none);
  });

  test('Tables exportées : exactement celles de la base', () async {
    db = await seededDatabase();
    final tables = tablesOf(dataOf(unzip(await export())));
    expect(tables.keys.toSet(), {
      for (final t in db.allTables) t.actualTableName,
    });
    // Et toutes les tables SQLite de la base : aucune n'échappe à l'export.
    final sqlite = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(tables.keys.toSet(), {
      for (final row in sqlite) row.read<String>('name'),
    });
  });

  test('Base fraîche sans photo : archive valide, aucune photo', () async {
    db = memoryDatabase();
    expect(photos.existsSync(), isFalse);

    final archive = unzip(await export());
    final tables = tablesOf(dataOf(archive));
    expect(tables.keys, hasLength(8));
    for (final rows in tables.values) {
      expect(rows, isEmpty);
    }
    expect(photoNames(archive), isEmpty);
    expect(filesIn(target), ['kadi-sauvegarde-2026-11-04.zip']);
  });

  test(
    'Photo manquante : export réussi sans elle, les autres sont là',
    () async {
      db = await seededDatabase();
      photo('chili.jpg', [1, 2, 3]);
      await (db.update(db.recipes)
            ..where((r) => r.id.equals(SeedRecipeIds.chili)))
          .write(const RecipesCompanion(photo: Value('chili.jpg')));
      await (db.update(db.recipes)
            ..where((r) => r.id.equals(SeedRecipeIds.ratatouille)))
          .write(const RecipesCompanion(photo: Value('x.jpg')));

      final archive = unzip(await export());
      expect(photoNames(archive), {'chili.jpg'});
      final recipes = tablesOf(dataOf(archive))['recipes']! as List;
      expect(recipes.any((r) => (r as Map)['photo'] == 'x.jpg'), isTrue);
    },
  );

  test('Export du même jour : le fichier précédent est remplacé', () async {
    db = await seededDatabase();
    await export();
    await SettingsRepository(db, Clock()).setKeepScreenOn(true);
    final file = await export();
    expect(filesIn(target), ['kadi-sauvegarde-2026-11-04.zip']);
    final settings =
        (tablesOf(dataOf(unzip(file)))['settings']! as List).single as Map;
    expect(settings['keep_screen_on'], 1);
  });

  group('Échec d’écriture', () {
    test('archive écrite mais impossible à poser : lève, aucun .zip ni '
        '.part laissé', () async {
      db = await seededDatabase();
      photo('chili.jpg', [1, 2, 3]);
      // Un dossier occupe le nom de l'archive : le renommage échoue.
      Directory(
        '${target.path}${Platform.pathSeparator}kadi-sauvegarde-2026-11-04.zip',
      ).createSync();

      await expectLater(export(), throwsA(isA<FileSystemException>()));
      expect(filesIn(target), isEmpty);
    });

    test('dossier d’export impossible à créer : lève, rien d’écrit', () async {
      db = await seededDatabase();
      final blocker = File('${root.path}${Platform.pathSeparator}bloque')
        ..writeAsStringSync('x');
      target = Directory('${blocker.path}${Platform.pathSeparator}tmp');

      await expectLater(export(), throwsA(isA<FileSystemException>()));
      expect(
        filesIn(root).where((f) => f.endsWith('.zip') || f.endsWith('.part')),
        isEmpty,
      );
    });
  });
}
