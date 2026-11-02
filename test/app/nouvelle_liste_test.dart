import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/app/actions/ajouter_a_la_liste.dart';
import 'package:kadi/app/actions/nouvelle_liste.dart';
import 'package:kadi/app/actions/terminer_les_courses.dart';
import 'package:kadi/core/clock/clock.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/undo/undo.dart';
import 'package:kadi/features/liste/data/liste_repository.dart';
import 'package:kadi/features/recettes/data/recettes_repository.dart';
import 'package:kadi/features/recettes/state/revue.dart';

import '../helpers/test_db.dart';

/// Supprime les sélections puis échoue, dans la transaction de l'action.
class _FailingRecettesRepository extends RecettesRepository {
  _FailingRecettesRepository(super.db, super.clock);

  @override
  Future<List<UndoRow>> clearSelections() async {
    await super.clearSelections();
    throw StateError('échec simulé');
  }
}

void main() {
  late AppDatabase db;
  late Clock clock;
  late ListeRepository liste;
  late RecettesRepository recettes;
  late Undo undo;
  late NouvelleListe nouvelleListe;
  var now = 1000;

  setUp(() async {
    db = await seededDatabase();
    now = 1000;
    clock = Clock(now: () => now);
    liste = ListeRepository(db, clock);
    recettes = RecettesRepository(db, clock);
    undo = Undo(db, clock);
    nouvelleListe = NouvelleListe(db, liste, recettes, undo);
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

  /// Deux recettes validées, une sélectionnée non validée, la liste en
  /// partie cochée, plus un ajout du Panneau +.
  Future<void> semaineEnCours() async {
    await validate([SeedRecipeIds.carbonara, SeedRecipeIds.quiche]);
    await recettes.select(SeedRecipeIds.chili);
    await liste.addArticle(SeedIds.lait);
    final unchecked = await liste.watchUnchecked().first;
    await liste.check(unchecked.first.lineId);
    await liste.check(unchecked.last.lineId);
  }

  test('Effacer : liste vide, cochés compris, contributions et sélections '
      'supprimées logiquement, aucune carte sélectionnée', () async {
    await semaineEnCours();
    expect(await liste.watchChecked().first, hasLength(2));
    final lines = await db.select(db.listLines).get();
    final contributions = await db.select(db.listContributions).get();
    final selections = await db.select(db.weekSelections).get();
    expect(selections, hasLength(3));
    now = 5000;

    await nouvelleListe();

    expect(await liste.watchUnchecked().first, isEmpty);
    expect(await liste.watchChecked().first, isEmpty);
    final linesAfter = await db.select(db.listLines).get();
    expect(linesAfter.every((l) => l.deletedAt != null), isTrue);
    expect(linesAfter.every((l) => l.updatedAt >= 5000), isTrue);
    final contributionsAfter = await db.select(db.listContributions).get();
    expect(contributionsAfter.every((c) => c.deletedAt != null), isTrue);
    final selectionsAfter = await db.select(db.weekSelections).get();
    expect(selectionsAfter.every((s) => s.deletedAt != null), isTrue);
    expect(selectionsAfter.every((s) => s.updatedAt == s.deletedAt), isTrue);
    // Rien de supprimé physiquement.
    expect(linesAfter, hasLength(lines.length));
    expect(contributionsAfter, hasLength(contributions.length));
    expect(selectionsAfter, hasLength(selections.length));

    final cards = await recettes.watchCards().first;
    expect(cards.every((c) => !c.selected && !c.validated), isTrue);
    // Plus de « Valider ».
    expect((await recettes.pendingSelections()).selectionIds, isEmpty);
    // Les recettes restent.
    expect(cards, hasLength(4));
  });

  test('déjà vide : rien n’est écrit, pas d’erreur', () async {
    final before = await snapshot();
    final last = clock.last;

    await nouvelleListe();

    expect(clock.last, last);
    expect(await snapshot(), before);
  });

  test('pas d’Annuler : un Annuler de Terminer les courses encore affiché '
      'ne rend plus rien', () async {
    await validate([SeedRecipeIds.carbonara]);
    for (final item in await liste.watchUnchecked().first) {
      await liste.check(item.lineId);
    }
    final entry = (await TerminerLesCourses(db, liste, recettes, undo)())!;
    final cleared = await snapshot();

    // Liste et sélection déjà vides : rien n'est écrit, mais l'emplacement
    // Annuler est vidé.
    await nouvelleListe();

    expect(undo.canUndo(entry), isFalse);
    expect(await undo.undo(entry), isFalse);
    expect(await snapshot(), cleared);
  });

  test('échec : rien n’est écrit', () async {
    await semaineEnCours();
    final before = await snapshot();
    final failing = NouvelleListe(
      db,
      liste,
      _FailingRecettesRepository(db, clock),
      undo,
    );

    await expectLater(failing(), throwsStateError);

    expect(await snapshot(), before);
  });
}
