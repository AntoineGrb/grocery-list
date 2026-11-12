import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/app/actions/vider_les_recettes.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/failing_clear_selections.dart';
import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository liste;
  late RecettesRepository recettes;
  late Undo undo;
  late ViderLesRecettes vider;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    liste = ListeRepository(db, clock);
    recettes = RecettesRepository(db, clock);
    undo = Undo(db, clock);
    vider = ViderLesRecettes(db, liste, recettes, undo);
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

  /// Les trois tables, `updated_at` exclu.
  Future<List<Map<String, dynamic>>> snapshot() async => [
    for (final l in await db.select(db.listLines).get())
      l.toJson()..remove('updatedAt'),
    for (final c in await db.select(db.listContributions).get())
      c.toJson()..remove('updatedAt'),
    for (final s in await db.select(db.weekSelections).get())
      s.toJson()..remove('updatedAt'),
  ];

  test('retire les lignes venues des seules recettes, cochées comprises ; '
      'garde les ajouts et les lignes complétées à la main', () async {
    await validate([SeedRecipeIds.carbonara, SeedRecipeIds.quiche]);
    await recettes.select(SeedRecipeIds.chili);
    final fromRecipes = await liste.watchUnchecked().first;
    expect(fromRecipes.length, greaterThan(2));
    // Une ligne de recette aussi ajoutée à la main, une autre cochée.
    final shared = fromRecipes.first;
    await liste.addArticle(shared.articleId);
    await liste.check(fromRecipes.last.lineId);
    // Un ajout seul du Panneau +.
    final manual = await liste.addArticle(SeedIds.lait);
    now = 5000;

    final entry = await vider();

    expect(entry, isNotNull);
    final left = await liste.watchUnchecked().first;
    expect(left.map((i) => i.lineId).toSet(), {shared.lineId, manual.lineId});
    // La ligne partagée ne garde que l'ajout : plus de recette d'origine.
    expect(
      left.firstWhere((i) => i.lineId == shared.lineId).recipeNames,
      isEmpty,
    );
    expect(await liste.watchChecked().first, isEmpty);
    final selections = await db.select(db.weekSelections).get();
    expect(selections.every((s) => s.deletedAt != null), isTrue);
    final cards = await recettes.watchCards().first;
    expect(cards.every((c) => !c.selected && !c.validated), isTrue);
    expect(cards, hasLength(4));
  });

  test('Annuler remet les recettes et leurs ingrédients', () async {
    await validate([SeedRecipeIds.carbonara]);
    await liste.addArticle(SeedIds.lait);
    final before = await snapshot();
    now = 5000;

    final entry = (await vider())!;
    expect(await snapshot(), isNot(before));
    now = 6000;
    expect(await undo.undo(entry), isTrue);

    expect(await snapshot(), before);
  });

  test('sans recette : rien n’est écrit, pas d’Annuler', () async {
    await liste.addArticle(SeedIds.lait);
    final before = await snapshot();
    final last = clock.last;

    expect(await vider(), isNull);

    expect(clock.last, last);
    expect(await snapshot(), before);
  });

  test('échec : rien n’est écrit', () async {
    await validate([SeedRecipeIds.carbonara]);
    final before = await snapshot();
    final failing = ViderLesRecettes(
      db,
      liste,
      FailingClearSelectionsRepository(db, clock),
      undo,
    );

    await expectLater(failing(), throwsStateError);

    expect(await snapshot(), before);
  });
}
