import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/app/actions/importer_une_sauvegarde.dart';
import 'package:kadi/core/backup/backup_archive.dart';
import 'package:kadi/core/backup/backup_import.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/catalogue/data/catalogue_repository.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/test_db.dart';

/// Lignes d'une table, telles que SQLite les stocke, par id.
typedef Rows = List<Map<String, Object?>>;

/// Repository de la liste dont la réconciliation écrit puis échoue, dans la
/// transaction de l'import.
class _FailingListe extends ListeRepository {
  _FailingListe(super.db, super.clock);

  @override
  Future<void> reconcileImported({
    required Map<String, String> articles,
    required Map<String, String> selections,
  }) async {
    await super.reconcileImported(articles: articles, selections: selections);
    throw StateError('échec simulé');
  }
}

/// Une base et ses repositories, sur une seule horloge.
class _Phone {
  _Phone(this.db, this.photos) : clock = Clock() {
    catalogue = CatalogueRepository(db, clock);
    liste = ListeRepository(db, clock);
    recettes = RecettesRepository(db, clock);
    settings = SettingsRepository(db, clock);
  }

  final AppDatabase db;
  final Directory photos;
  final Clock clock;
  late final CatalogueRepository catalogue;
  late final ListeRepository liste;
  late final RecettesRepository recettes;
  late final SettingsRepository settings;

  /// Écrit la photo [name] dans le dossier des photos.
  void photo(String name, List<int> bytes) {
    photos.createSync(recursive: true);
    File('${photos.path}${Platform.pathSeparator}$name')
        .writeAsBytesSync(bytes);
  }

  /// Sélectionne [recipeId] et l'ajoute à la liste par la Revue.
  Future<void> selectAndValidate(String recipeId) async {
    await recettes.select(recipeId);
    final pending = await recettes.pendingSelections();
    await AjouterALaListe(db, liste, recettes)(
      buildRevue(
        selectionIds: pending.selectionIds,
        ingredients: pending.ingredients,
        routeOrder: Rayon.values,
      ),
    );
  }

  /// L'action Importer une sauvegarde, avec [bytes] pour fichier choisi
  /// (`null` : sélecteur fermé).
  ImporterUneSauvegarde importer(
    List<int>? bytes, {
    Undo? undo,
    ListeRepository? liste,
  }) => ImporterUneSauvegarde(
    db,
    BackupImporter(db, settings),
    catalogue,
    recettes,
    liste ?? this.liste,
    undo ?? Undo(db, clock),
    () async => photos,
    () async => bytes,
  );

  Future<ImportResult> import(List<int>? bytes) => importer(bytes)();

  /// Toutes les tables, lignes triées par id.
  Future<Map<String, Rows>> tables() async => {
    for (final t in db.allTables)
      t.actualTableName: [
        for (final row
            in await db
                .customSelect(
                  'SELECT * FROM "${t.actualTableName}" ORDER BY id',
                )
                .get())
          row.data,
      ],
  };

  /// Le dossier des photos : nom → octets ; vide s'il n'existe pas.
  Map<String, List<int>> photoFiles() => !photos.existsSync()
      ? {}
      : {
          for (final f in photos.listSync().whereType<File>())
            f.uri.pathSegments.last: f.readAsBytesSync(),
        };

  Future<Rows> activeRows(String table, [String where = '1']) async => [
    for (final row
        in await db
            .customSelect(
              'SELECT * FROM "$table" WHERE deleted_at IS NULL AND $where '
              'ORDER BY id',
            )
            .get())
      row.data,
  ];
}

void main() {
  late Directory root;
  final opened = <AppDatabase>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('kadi_import_');
  });
  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
    root.deleteSync(recursive: true);
  });

  Directory dir(String name) =>
      Directory('${root.path}${Platform.pathSeparator}$name');

  /// Un téléphone : base semée (contenu fourni chargé), dossier de photos
  /// propre.
  Future<_Phone> phone(String name) async {
    final db = await seededDatabase();
    opened.add(db);
    return _Phone(db, dir('$name-photos'));
  }

  /// Exporte [source] par l'exporteur de la story 2 et rend l'archive.
  var exports = 0;
  Future<List<int>> exportOf(_Phone source) async {
    final file = await BackupExporter(source.db)
        .export(photos: source.photos, target: dir('export-${exports++}'));
    return file.readAsBytesSync();
  }

  /// `data.json` de l'archive [bytes].
  Map<String, Object?> dataOf(List<int> bytes) => jsonDecode(
    utf8.decode(
      ZipDecoder().decodeBytes(bytes).findFile(BackupFormat.dataFile)!.content,
    ),
  ) as Map<String, Object?>;

  /// Archive faite de [entries] (nom → contenu).
  List<int> zip(Map<String, List<int>> entries) {
    final archive = Archive();
    for (final MapEntry(:key, :value) in entries.entries) {
      archive.addFile(ArchiveFile.bytes(key, Uint8List.fromList(value)));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  List<int> json(Object? data) => utf8.encode(jsonEncode(data));

  Rows rowsOf(Map<String, Object?> data, String table) => [
    for (final row
        in (data[BackupFormat.tablesKey]! as Map<String, Object?>)[table]!
            as List)
      row as Map<String, Object?>,
  ];

  test('Restauration : sur une base neuve semée, les tables métier '
      'deviennent celles de la sauvegarde, réglages utilisateur compris, '
      'premier lancement et seed_version locaux gardés', () async {
    final a = await phone('a');
    final photoBytes = List<int>.generate(3000, (i) => i % 251);
    a.photo('chili.jpg', photoBytes);
    await (a.db.update(
      a.db.recipes,
    )..where((r) => r.id.equals(SeedRecipeIds.chili))).write(
      RecipesCompanion(
        photo: const Value('chili.jpg'),
        updatedAt: Value(a.clock.stamp()),
      ),
    );
    await a.selectAndValidate(SeedRecipeIds.chili);
    await a.recettes.select(SeedRecipeIds.carbonara);
    await a.liste.addArticle(SeedIds.lait, quantity: 2000, unit: Unit.piece);
    final piles = await a.db.transaction(
      () => a.catalogue.createArticle('Piles'),
    );
    await a.db
        .into(a.db.frequents)
        .insert(
          FrequentsCompanion.insert(
            id: frequentId(piles.id),
            updatedAt: a.clock.stamp(),
            articleId: piles.id,
            position: 99,
          ),
        );
    await a.liste.addArticle(piles.id);
    final checked = await a.liste.firstUnchecked(piles.id);
    await a.liste.check(checked!.lineId);
    await a.recettes.deleteRecipe(SeedRecipeIds.quiche);
    await a.settings.setRouteOrder(Rayon.values.reversed.toList());
    await a.settings.setGroupByRayon(false);
    await a.settings.setKeepScreenOn(true);
    // Valeurs locales de A, à ne pas reprendre.
    await a.settings.setFirstLaunch(false);
    await a.settings.setSeedVersions({'articles': 1, 'autre': 7});
    final bytes = await exportOf(a);

    // B : installation neuve, premier lancement écrit après l'export.
    final b = await phone('b');
    final bSettings = await b.settings.read();
    expect(bSettings.firstLaunch, isTrue);

    expect(await b.import(bytes), ImportResult.imported);

    final aTables = await a.tables();
    final bTables = await b.tables();
    for (final name in aTables.keys) {
      if (name == a.db.settings.actualTableName) continue;
      expect(bTables[name], aTables[name], reason: name);
    }
    final settings = await b.settings.read();
    expect(settings.routeOrder, Rayon.values.reversed.toList());
    expect(settings.groupByRayon, isFalse);
    expect(settings.keepScreenOn, isTrue);
    expect(settings.firstLaunch, bSettings.firstLaunch);
    expect(settings.seedVersions, bSettings.seedVersions);

    expect(b.photoFiles().keys, ['chili.jpg']);
    expect(b.photoFiles()['chili.jpg'], photoBytes);
  });

  test('Local plus récent : la recette modifiée après l’export est '
      'gardée', () async {
    final a = await phone('a');
    final bytes = await exportOf(a);
    await (a.db.update(
      a.db.recipes,
    )..where((r) => r.id.equals(SeedRecipeIds.chili))).write(
      RecipesCompanion(
        name: const Value('Chili maison'),
        updatedAt: Value(a.clock.stamp()),
      ),
    );

    await a.import(bytes);
    final chili = await (a.db.select(
      a.db.recipes,
    )..where((r) => r.id.equals(SeedRecipeIds.chili))).getSingle();
    expect(chili.name, 'Chili maison');
  });

  test(
    'Fichier plus récent : la ligne du fichier remplace la locale',
    () async {
      final a = await phone('a');
      final b = await phone('b');
      await (a.db.update(
        a.db.recipes,
      )..where((r) => r.id.equals(SeedRecipeIds.chili))).write(
        RecipesCompanion(
          name: const Value('Chili de A'),
          link: const Value('https://exemple.fr/chili'),
          updatedAt: Value(a.clock.stamp()),
        ),
      );

      await b.import(await exportOf(a));
      final chili = await (b.db.select(
        b.db.recipes,
      )..where((r) => r.id.equals(SeedRecipeIds.chili))).getSingle();
      expect(chili.name, 'Chili de A');
      expect(chili.link, 'https://exemple.fr/chili');
    },
  );

  test('Égalité de updated_at : la ligne locale reste', () async {
    final a = await phone('a');
    final b = await phone('b');
    // Même updated_at (0, contenu fourni), contenu différent.
    await (a.db.update(a.db.recipes)
          ..where((r) => r.id.equals(SeedRecipeIds.chili)))
        .write(const RecipesCompanion(name: Value('Chili de A')));

    await b.import(await exportOf(a));
    final chili = await (b.db.select(
      b.db.recipes,
    )..where((r) => r.id.equals(SeedRecipeIds.chili))).getSingle();
    expect(chili.name, isNot('Chili de A'));
  });

  test('Suppression : une recette supprimée dans le fichier, plus récente, '
      'est supprimée localement', () async {
    final a = await phone('a');
    final b = await phone('b');
    await a.recettes.deleteRecipe(SeedRecipeIds.quiche);

    await b.import(await exportOf(a));
    final quiche = await (b.db.select(
      b.db.recipes,
    )..where((r) => r.id.equals(SeedRecipeIds.quiche))).getSingle();
    expect(quiche.deletedAt, isNotNull);
  });

  /// B a « Piles » (id X), A a « Piles » (id Y) avec une ligne, un
  /// ingrédient et un fréquent ; rend (B, X, Y, archive de A).
  Future<(_Phone, String, String, List<int>)> duplicateArticles() async {
    final b = await phone('b');
    final x = await b.db.transaction(() => b.catalogue.createArticle('Piles'));
    await b.liste.addArticle(x.id, quantity: 2000, unit: Unit.piece);

    final a = await phone('a');
    final y = await a.db.transaction(
      () => a.catalogue.resolveTypedArticle('piles'),
    );
    await a.liste.addArticle(y.id, quantity: 3000, unit: Unit.piece);
    await a.recettes.saveDraft(
      RecipeDraft(
        recipeId: a.recettes.newId(),
        name: 'Lampe',
        ingredients: [
          RecipeDraftIngredient(id: a.recettes.newId(), articleId: y.id),
        ],
      ),
    );
    await a.db
        .into(a.db.frequents)
        .insert(
          FrequentsCompanion.insert(
            id: frequentId(y.id),
            updatedAt: a.clock.stamp(),
            articleId: y.id,
            position: 42,
          ),
        );
    return (b, x.id, y.id, await exportOf(a));
  }

  test('Articles en double : un seul article gardé (le local), lignes, '
      'ingrédients et fréquent reportés, l’autre supprimé', () async {
    final (b, x, y, bytes) = await duplicateArticles();

    await b.import(bytes);

    final piles = await b.activeRows('articles', "normalized_name = 'piles'");
    expect([for (final a in piles) a['id']], [x]);
    expect(piles.single['in_catalogue'], 1);
    final removed = await (b.db.select(
      b.db.articles,
    )..where((a) => a.id.equals(y))).getSingle();
    expect(removed.deletedAt, isNotNull);

    // Lignes : une seule ligne non cochée Piles / pièce, quantité = somme.
    expect(await b.activeRows('list_lines', "article_id = '$y'"), isEmpty);
    final line = await b.liste.firstUnchecked(x);
    expect(line!.quantity, 5000);
    expect(await b.activeRows('list_lines', "article_id = '$x'"), hasLength(1));

    // Ingrédient reporté.
    final ingredients = await b.activeRows(
      'recipe_ingredients',
      "article_id IN ('$x', '$y')",
    );
    expect([for (final i in ingredients) i['article_id']], [x]);

    // Fréquent : celui de Y supprimé, celui de X (id dérivé) actif, à la
    // position de celui de Y.
    final frequents = await b.activeRows(
      'frequents',
      "article_id IN ('$x', '$y')",
    );
    expect(frequents, hasLength(1));
    expect(frequents.single['id'], frequentId(x));
    expect(frequents.single['article_id'], x);
    expect(frequents.single['position'], 42);
  });

  test('Articles en double : un fréquent en double sur l’article gardé est '
      'supprimé', () async {
    final (b, x, y, bytes) = await duplicateArticles();
    await b.db
        .into(b.db.frequents)
        .insert(
          FrequentsCompanion.insert(
            id: frequentId(x),
            updatedAt: b.clock.stamp(),
            articleId: x,
            position: 3,
          ),
        );

    await b.import(bytes);
    final frequents = await b.activeRows(
      'frequents',
      "article_id IN ('$x', '$y')",
    );
    expect(frequents, hasLength(1));
    expect(frequents.single['id'], frequentId(x));
    expect(frequents.single['position'], 3);
    final fromFile = await (b.db.select(
      b.db.frequents,
    )..where((f) => f.id.equals(frequentId(y)))).getSingle();
    expect(fromFile.deletedAt, isNotNull);
  });

  test('Lignes en double : deux lignes non cochées Lait / g deviennent une '
      'seule, contributions réunies, quantité = somme, manuelle', () async {
    final a = await phone('a');
    final b = await phone('b');
    await b.liste.addArticle(SeedIds.lait, quantity: 200, unit: Unit.g);
    final local = (await b.liste.firstUnchecked(SeedIds.lait))!;
    await a.liste.addArticle(SeedIds.lait, quantity: 300, unit: Unit.g);
    final imported = (await a.liste.firstUnchecked(SeedIds.lait))!;
    // La ligne importée est corrigée à la main (contribution `edition` de
    // 350 g) : la ligne gardée devient manuelle.
    await a.liste.setQuantity(imported.lineId, 350, unit: Unit.g);

    await b.import(await exportOf(a));

    final lines = await b.activeRows(
      'list_lines',
      "article_id = '${SeedIds.lait}' AND checked_at IS NULL",
    );
    expect(lines, hasLength(1));
    final kept = lines.single;
    // La plus ancienne des deux (`added_at`).
    final keptId = await b.db
        .customSelect(
          "SELECT id FROM list_lines WHERE id IN ('${local.lineId}', "
          "'${imported.lineId}') ORDER BY added_at, id LIMIT 1",
        )
        .getSingle();
    expect(kept['id'], keptId.read<String>('id'));
    expect(kept['manual_at'], isNotNull);
    final item = (await b.liste.firstUnchecked(SeedIds.lait))!;
    expect(item.unit, Unit.g);
    expect(item.quantity, 550);
    final contributions = await b.activeRows(
      'list_contributions',
      "line_id = '${kept['id']}'",
    );
    expect(contributions, hasLength(2));
  });

  test('Sélections en double : une seule sélection active de Chili, '
      'contributions reportées', () async {
    final a = await phone('a');
    final b = await phone('b');
    await b.selectAndValidate(SeedRecipeIds.chili);
    await a.selectAndValidate(SeedRecipeIds.chili);

    await b.import(await exportOf(a));

    final selections = await b.activeRows(
      'week_selections',
      "recipe_id = '${SeedRecipeIds.chili}'",
    );
    expect(selections, hasLength(1));
    final kept = selections.single['id'];
    expect(selections.single['validated_at'], isNotNull);
    final contributions = await b.activeRows(
      'list_contributions',
      "source = '${ContributionSource.weekSelection}'",
    );
    expect(contributions, isNotEmpty);
    for (final c in contributions) {
      expect(c['week_selection_id'], kept);
    }
    // Lignes des deux Chili réunies : chaque ingrédient une fois.
    final lines = await b.activeRows('list_lines', 'checked_at IS NULL');
    final keys = {for (final l in lines) (l['article_id'], l['unit'])};
    expect(keys, hasLength(lines.length));
  });

  test('Sélections en double : une validée est gardée de préférence à une '
      'non validée', () async {
    final a = await phone('a');
    final b = await phone('b');
    await b.recettes.select(SeedRecipeIds.chili);
    await a.selectAndValidate(SeedRecipeIds.chili);

    await b.import(await exportOf(a));
    final selections = await b.activeRows(
      'week_selections',
      "recipe_id = '${SeedRecipeIds.chili}'",
    );
    expect(selections, hasLength(1));
    expect(selections.single['validated_at'], isNotNull);
  });

  test('Idempotence : le même fichier importé deux fois donne le même état '
      '(hors updated_at des réglages)', () async {
    final (b, _, _, bytes) = await duplicateArticles();
    await b.selectAndValidate(SeedRecipeIds.chili);

    await b.import(bytes);
    final once = await b.tables();
    await b.import(bytes);
    final twice = await b.tables();

    for (final name in once.keys) {
      if (name == b.db.settings.actualTableName) continue;
      expect(twice[name], once[name], reason: name);
    }
    Map<String, Object?> withoutStamp(Map<String, Object?> row) =>
        Map.of(row)..remove('updated_at');
    expect(
      twice['settings']!.map(withoutStamp).toList(),
      once['settings']!.map(withoutStamp).toList(),
    );
  });

  test('Colonnes absentes d’une ligne : valeur par défaut de la '
      'colonne', () async {
    final a = await phone('a');
    final b = await phone('b');
    final article = await a.db.transaction(
      () => a.catalogue.createArticle('Bougies'),
    );
    final data = dataOf(await exportOf(a));
    final row = rowsOf(
      data,
      'articles',
    ).singleWhere((r) => r['id'] == article.id);
    row
      ..remove('in_catalogue')
      ..remove('unit')
      ..remove('deleted_at');

    await b.import(zip({BackupFormat.dataFile: json(data)}));
    final imported = await (b.db.select(
      b.db.articles,
    )..where((x) => x.id.equals(article.id))).getSingle();
    expect(imported.inCatalogue, isTrue);
    expect(imported.unit, isNull);
    expect(imported.deletedAt, isNull);
    expect(imported.name, 'Bougies');
  });

  group('Invalide : rien ne change, ni la base ni le dossier photos', () {
    late _Phone b;
    late List<int> valid;
    late Map<String, Object?> data;

    setUp(() async {
      final a = await phone('a');
      a.photo('chili.jpg', [1, 2, 3]);
      await a.liste.addArticle(SeedIds.lait);
      valid = await exportOf(a);
      data = dataOf(valid);
      b = await phone('b');
      b.photo('garde.jpg', [9, 9]);
      await b.liste.addArticle(SeedIds.oeufs);
    });

    /// [data] modifié par [change], sous `data.json`, avec la photo.
    List<int> withData(void Function(Map<String, Object?> data) change) {
      final copy = jsonDecode(jsonEncode(data)) as Map<String, Object?>;
      change(copy);
      return zip({
        BackupFormat.dataFile: json(copy),
        '${BackupFormat.photosFolder}nouvelle.jpg': [4, 5, 6],
      });
    }

    Map<String, Object?> tablesIn(Map<String, Object?> d) =>
        d[BackupFormat.tablesKey]! as Map<String, Object?>;

    final cases = <String, List<int> Function()>{
      'zip sans data.json': () => zip({
        '${BackupFormat.photosFolder}nouvelle.jpg': [4, 5, 6],
      }),
      'JSON tronqué': () {
        final text = jsonEncode(data);
        return zip({
          BackupFormat.dataFile: utf8.encode(
            text.substring(0, text.length ~/ 2),
          ),
          '${BackupFormat.photosFolder}nouvelle.jpg': [4, 5, 6],
        });
      },
      'data.json qui n’est pas un objet': () => zip({
        BackupFormat.dataFile: json([1, 2, 3]),
      }),
      'format_version 99': () =>
          withData((d) => d[BackupFormat.formatVersionKey] = 99),
      'format_version 2 (sans migration)': () =>
          withData((d) => d[BackupFormat.formatVersionKey] = 2),
      'format_version absent': () =>
          withData((d) => d.remove(BackupFormat.formatVersionKey)),
      'tables absent': () => withData((d) => d.remove(BackupFormat.tablesKey)),
      'table inconnue': () => withData((d) => tablesIn(d)['inconnue'] = []),
      'colonne inconnue': () => withData(
        (d) => ((tablesIn(d)['articles']! as List).first as Map)['x'] = 1,
      ),
      'colonne requise absente': () => withData(
        (d) => ((tablesIn(d)['articles']! as List).first as Map).remove('name'),
      ),
      'id absent': () => withData(
        (d) => ((tablesIn(d)['list_lines']! as List).first as Map).remove('id'),
      ),
      'updated_at texte': () => withData(
        (d) => ((tablesIn(d)['recipes']! as List).first as Map)['updated_at'] =
            'hier',
      ),
      'booléen hors 0/1': () => withData(
        (d) =>
            ((tablesIn(d)['articles']! as List).first as Map)['in_catalogue'] =
                2,
      ),
      'id en double': () => withData((d) {
        final rows = tablesIn(d)['recipes']! as List;
        rows.add(Map.of(rows.first as Map));
      }),
      'entrée photos/../x': () => zip({
        BackupFormat.dataFile: json(data),
        '${BackupFormat.photosFolder}nouvelle.jpg': [4, 5, 6],
        '${BackupFormat.photosFolder}../x': [7],
      }),
      'entrée photos/sous/x.jpg': () => zip({
        BackupFormat.dataFile: json(data),
        '${BackupFormat.photosFolder}sous/x.jpg': [7],
      }),
      'fichier non zip': () => utf8.encode('Ceci est une liste de courses.'),
      'fichier vide': () => const <int>[],
    };

    for (final MapEntry(key: name, value: bytes) in cases.entries) {
      test(name, () async {
        final tables = await b.tables();
        final photos = b.photoFiles();
        final file = bytes();

        await expectLater(
          b.import(file),
          throwsA(isA<InvalidBackupException>()),
        );
        expect(await b.tables(), tables);
        expect(b.photoFiles(), photos);
        // Rien n'est écrit à côté du dossier des photos.
        expect(
          File('${root.path}${Platform.pathSeparator}x').existsSync(),
          isFalse,
        );
      });
    }

    test('le même fichier, valide, s’importe', () async {
      expect(await b.import(valid), ImportResult.imported);
      expect(b.photoFiles().keys.toSet(), {'garde.jpg', 'chili.jpg'});
    });
  });

  test('Échec en transaction : base inchangée, photos copiées supprimées, '
      'l’erreur remonte', () async {
    final a = await phone('a');
    a.photo('chili.jpg', [1, 2, 3]);
    a.photo('commune.jpg', [5, 5]);
    await a.selectAndValidate(SeedRecipeIds.chili);
    final bytes = await exportOf(a);
    final b = await phone('b');
    b.photo('commune.jpg', [6, 6]);
    await b.liste.addArticle(SeedIds.lait);
    final tables = await b.tables();
    final photos = b.photoFiles();

    await expectLater(
      b.importer(bytes, liste: _FailingListe(b.db, b.clock))(),
      throwsA(isA<StateError>()),
    );
    expect(await b.tables(), tables);
    expect(b.photoFiles(), photos);
  });

  test('Photos : seules les absentes sont copiées, une photo locale du même '
      'nom reste', () async {
    final a = await phone('a');
    a.photo('chili.jpg', [1, 2, 3]);
    a.photo('commune.jpg', [5, 5]);
    final b = await phone('b');
    b.photo('commune.jpg', [6, 6]);

    await b.import(await exportOf(a));
    expect(b.photoFiles(), {
      'chili.jpg': [1, 2, 3],
      'commune.jpg': [6, 6],
    });
  });

  test('Annulé : sélecteur fermé, rien ne change', () async {
    final b = await phone('b');
    final tables = await b.tables();
    expect(await b.import(null), ImportResult.cancelled);
    expect(await b.tables(), tables);
    expect(b.photoFiles(), isEmpty);
  });

  test('Après un import réussi, l’emplacement Annuler est vidé', () async {
    final a = await phone('a');
    final b = await phone('b');
    // Horloge propre au service : seul `clear` peut rendre l'entrée caduque.
    final undo = Undo(b.db, Clock());
    final entry = undo.record([UndoRow.absent(b.db.recipes, 'x')]);
    expect(undo.canUndo(entry), isTrue);

    await b.importer(await exportOf(a), undo: undo)();
    expect(undo.canUndo(entry), isFalse);
  });
}
