import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/app/actions/deselectionner_une_recette.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/core/units/unit.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/test_db.dart';

/// Retire les contributions, puis échoue, dans la transaction de l'action.
class _FailingListeRepository extends ListeRepository {
  _FailingListeRepository(super.db, super.clock);

  @override
  Future<List<UndoRow>> removeSelectionContributions(
    String weekSelectionId,
  ) async {
    await super.removeSelectionContributions(weekSelectionId);
    throw StateError('échec simulé');
  }
}

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository liste;
  late RecettesRepository recettes;
  late Undo undo;
  late DeselectionnerUneRecette deselectionner;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    liste = ListeRepository(db, clock);
    recettes = RecettesRepository(db, clock);
    undo = Undo(db, clock);
    deselectionner = DeselectionnerUneRecette(db, liste, recettes, undo);
  });
  tearDown(() => db.close());

  /// Sélectionne [recipeIds], puis Ajouter à la liste depuis leur Revue.
  Future<void> validate(List<String> recipeIds) async {
    for (final id in recipeIds) {
      await recettes.select(id);
    }
    final pending = await recettes.pendingSelections();
    await AjouterALaListe(db, liste, recettes)(
      buildRevue(
        selectionIds: pending.selectionIds,
        ingredients: pending.ingredients,
        routeOrder: Rayon.values,
      ),
    );
  }

  Future<Map<String, ListeItem>> unchecked() async => {
    for (final i in await liste.watchUnchecked().first) i.name: i,
  };

  Future<WeekSelection> selectionOf(String recipeId) => (db.select(
    db.weekSelections,
  )..where((s) => s.recipeId.equals(recipeId))).getSingle();

  /// Les trois tables, `updated_at` exclu.
  Future<List<Map<String, dynamic>>> snapshot() async => [
    for (final l in await db.select(db.listLines).get())
      l.toJson()..remove('updatedAt'),
    for (final c in await db.select(db.listContributions).get())
      c.toJson()..remove('updatedAt'),
    for (final s in await db.select(db.weekSelections).get())
      s.toJson()..remove('updatedAt'),
  ];

  test('Carbonara + Quiche validées, Carbonara désélectionnée : « Lardons '
      '200 g », ses lignes seules supprimées, sélection supprimée', () async {
    await validate([SeedRecipeIds.carbonara, SeedRecipeIds.quiche]);
    expect((await unchecked())['Lardons']!.quantity, 400);
    now = 5000;

    final entry = await deselectionner(SeedRecipeIds.carbonara);

    expect(entry, isNotNull);
    final items = await unchecked();
    expect((items['Lardons']!.quantity, items['Lardons']!.unit), (200, Unit.g));
    expect((items['Œufs']!.quantity, items['Œufs']!.unit), (3000, Unit.piece));
    expect(items.keys, isNot(contains('Pâtes')));
    expect(items.keys, isNot(contains('Parmesan')));
    expect(items.keys, isNot(contains('Poivre')));
    expect(items, hasLength(5));

    final carbonara = await selectionOf(SeedRecipeIds.carbonara);
    expect(carbonara.deletedAt, isNotNull);
    expect(carbonara.updatedAt, carbonara.deletedAt);
    expect(carbonara.updatedAt, greaterThanOrEqualTo(5000));
    expect((await selectionOf(SeedRecipeIds.quiche)).deletedAt, isNull);
    final cards = await recettes.watchCards().first;
    final card = cards.singleWhere(
      (c) => c.recipeId == SeedRecipeIds.carbonara,
    );
    expect((card.selected, card.validated), (false, false));
  });

  test('ligne cochée : reste cochée avec sa quantité', () async {
    await validate([SeedRecipeIds.carbonara]);
    final pates = (await unchecked())['Pâtes']!;
    await liste.check(pates.lineId);

    await deselectionner(SeedRecipeIds.carbonara);

    final checked = (await liste.watchChecked().first).single;
    expect(
      (checked.lineId, checked.quantity, checked.unit),
      (pates.lineId, 500, Unit.g),
    );
    expect(await liste.watchUnchecked().first, isEmpty);
  });

  test('ligne corrigée à la main : garde sa quantité', () async {
    await validate([SeedRecipeIds.carbonara]);
    final lardons = (await unchecked())['Lardons']!;
    await liste.setQuantity(lardons.lineId, 250, unit: Unit.g);

    await deselectionner(SeedRecipeIds.carbonara);

    final items = await unchecked();
    expect(items.keys, ['Lardons']);
    expect((items['Lardons']!.quantity, items['Lardons']!.unit), (250, Unit.g));
  });

  test('mêlée à un ajout sans quantité : ligne gardée, sans quantité ni '
      'unité', () async {
    await validate([SeedRecipeIds.chili]);
    final riz = (await unchecked())['Riz']!;
    await liste.addArticle(SeedIds.riz);

    await deselectionner(SeedRecipeIds.chili);

    final items = await unchecked();
    expect(items.keys, ['Riz']);
    expect(
      (items['Riz']!.lineId, items['Riz']!.quantity, items['Riz']!.unit),
      (riz.lineId, null, null),
    );
  });

  test('Annuler juste après : lignes, contributions et sélection exactement '
      'comme avant', () async {
    await validate([SeedRecipeIds.carbonara, SeedRecipeIds.quiche]);
    await liste.check((await unchecked())['Pâtes']!.lineId);
    await liste.addArticle(SeedIds.lardons);
    await liste.addArticle(SeedIds.lait);
    final before = await snapshot();
    now = 5000;

    final entry = (await deselectionner(SeedRecipeIds.carbonara))!;
    expect(await snapshot(), isNot(before));
    now = 6000;
    expect(await undo.undo(entry), isTrue);

    expect(await snapshot(), before);
    expect((await unchecked())['Lardons']!.quantity, 400);
    final card = (await recettes.watchCards().first).singleWhere(
      (c) => c.recipeId == SeedRecipeIds.carbonara,
    );
    expect((card.selected, card.validated), (true, true));
    expect((await recettes.pendingSelections()).selectionIds, isEmpty);
  });

  test('autre écriture entre-temps : Annuler sans effet', () async {
    await validate([SeedRecipeIds.carbonara]);
    final entry = (await deselectionner(SeedRecipeIds.carbonara))!;
    await liste.addArticle(SeedIds.lait);
    final after = await snapshot();

    expect(await undo.undo(entry), isFalse);
    expect(await snapshot(), after);
  });

  test('aucune ligne touchée (tout décoché en Revue) : entrée Annuler '
      'quand même, qui rétablit la sélection', () async {
    await recettes.select(SeedRecipeIds.chili);
    final pending = await recettes.pendingSelections();
    await AjouterALaListe(db, liste, recettes)(
      Revue(selectionIds: pending.selectionIds, groups: const []),
    );
    final before = await snapshot();

    final entry = await deselectionner(SeedRecipeIds.chili);

    expect(entry, isNotNull);
    expect((await selectionOf(SeedRecipeIds.chili)).deletedAt, isNotNull);
    expect(await undo.undo(entry!), isTrue);
    expect(await snapshot(), before);
  });

  test(
    'carte non validée : rien n’est écrit ni enregistré, rend null',
    () async {
      await recettes.select(SeedRecipeIds.chili);
      final before = await snapshot();
      final last = clock.last;

      expect(await deselectionner(SeedRecipeIds.chili), isNull);
      expect(await deselectionner(SeedRecipeIds.ratatouille), isNull);

      expect(clock.last, last);
      expect(await snapshot(), before);
    },
  );

  test('ensuite, une autre recette validée : la Revue n’en montre que les '
      'ingrédients (Flux 5)', () async {
    await validate([SeedRecipeIds.chili]);
    await deselectionner(SeedRecipeIds.chili);
    await recettes.select(SeedRecipeIds.ratatouille);

    final pending = await recettes.pendingSelections();
    expect(pending.selectionIds, [
      (await selectionOf(SeedRecipeIds.ratatouille)).id,
    ]);
    expect(pending.ingredients.map((i) => i.name).toSet(), {
      'Courgettes',
      'Aubergines',
      'Poivrons',
      'Tomates',
      'Oignons',
      'Huile d\'olive',
      'Herbes de Provence',
    });
  });

  test('échec : rien n’est écrit, rien n’est enregistré', () async {
    await validate([SeedRecipeIds.carbonara]);
    final before = await snapshot();
    final failing = DeselectionnerUneRecette(
      db,
      _FailingListeRepository(db, clock),
      recettes,
      undo,
    );

    await expectLater(failing(SeedRecipeIds.carbonara), throwsStateError);

    expect(await snapshot(), before);
    final card = (await recettes.watchCards().first).singleWhere(
      (c) => c.recipeId == SeedRecipeIds.carbonara,
    );
    expect((card.selected, card.validated), (true, true));
  });
}
