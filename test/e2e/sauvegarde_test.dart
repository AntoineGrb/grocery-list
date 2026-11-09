import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/rayons/rayon.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/catalogue/data/frequent_id.dart';
import 'package:kadi/features/recettes/data/recipe_photos.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:kadi/features/recettes/ui/fiche_recette_photo.dart';
import 'package:kadi/features/reglages/ui/frequents_screen.dart';
import 'package:kadi/features/reglages/ui/parametres_screen.dart';
import 'package:kadi/features/reglages/ui/parcours_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e_harness.dart';

/// Image PNG de 1 × 1 px.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Directory _tempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows : un fichier encore ouvert par le décodeur d'image.
    }
  });
  return dir;
}

/// Photos de recette dans [documents], copiées en E/S synchrones (la zone
/// de test des widgets n'attend pas les E/S asynchrones).
class _SyncPhotos extends RecipePhotos {
  _SyncPhotos(this.documents) : super(() async => documents);

  final Directory documents;

  Directory get dir => Directory(
    '${documents.path}${Platform.pathSeparator}${RecipePhotos.folder}',
  );

  @override
  Future<String> importPhoto(String sourcePath) async {
    dir.createSync(recursive: true);
    const name = 'gratin.jpg';
    File(sourcePath).copySync(RecipePhotos.fileIn(dir, name).path);
    return name;
  }
}

/// Contenu comparé d'une base : chaque table hors réglages, ligne à ligne,
/// et les réglages repris d'une sauvegarde.
Future<Map<String, Object?>> _contents(AppDatabase db) async {
  final settings = await db.select(db.settings).getSingle();
  return {
    for (final t in db.allTables)
      if (t.actualTableName != db.settings.actualTableName)
        t.actualTableName: [
          for (final row
              in await db
                  .customSelect(
                    'SELECT * FROM "${t.actualTableName}" ORDER BY id',
                  )
                  .get())
            row.data,
        ],
    'settings': {
      'routeOrder': settings.routeOrder,
      'groupByRayon': settings.groupByRayon,
      'keepScreenOn': settings.keepScreenOn,
    },
  };
}

Future<void> _back(WidgetTester tester) =>
    tapAndSettle(tester, find.byType(BackButton).first);

void sauvegarde() {
  group('Sauvegarde — export puis import sur une base neuve', () {
    testBothThemes('recette avec photo, liste, fréquent, parcours et '
        'réglages : identiques après l’aller-retour', (tester) async {
      phone(tester, size: const Size(412, 1400));
      final documents = _tempDir('kadi_e2e_a_');
      final photos = _SyncPhotos(documents);
      final pick = File('${documents.path}${Platform.pathSeparator}pick.png')
        ..writeAsBytesSync(_png);
      final shared = <List<int>>[];
      final source = await pumpE2e(
        tester,
        overrides: [
          recipePhotosProvider.overrideWithValue(photos),
          photoPickerProvider.overrideWithValue((_) async => pick.path),
        ],
        // Double de la feuille de partage : garde les octets du fichier.
        shareFile: (file) async {
          shared.add(file.readAsBytesSync());
          return true;
        },
      );

      // Une recette avec photo.
      await openTab(tester, StringsFr.tabRecettes);
      await tapAndSettle(tester, find.byTooltip(StringsFr.nouvelleRecette));
      await tester.enterText(ficheNameField, 'Gratin');
      await tester.pumpAndSettle();
      await addIngredientBySheet(tester, 'courg', 'Courgettes');
      await tapAndSettle(tester, find.text(StringsFr.ajouterUnePhoto));
      expect(find.byType(PhotoSourceSheet), findsOneWidget);
      await tapAndSettle(tester, find.text(StringsFr.galerie));
      await saveFiche(tester);
      expect((await recipeNamed(source, 'Gratin'))!.photo, 'gratin.jpg');

      // Une liste : le Gratin validé.
      await tapRecipeCard(tester, 'Gratin');
      await openRevue(tester, 1);
      await tapAndSettle(tester, ajouterALaListe);
      expect(itemRow('Courgettes'), findsOneWidget);
      await letSnackBarClose(tester);

      // Un fréquent ajouté.
      await openParametres(tester);
      await tapParametre(tester, StringsFr.frequentsTitre);
      await tester.enterText(
        find.descendant(
          of: find.byType(FrequentsScreen),
          matching: find.byType(TextField),
        ),
        'pil',
      );
      await tester.pumpAndSettle();
      await tapAndSettle(
        tester,
        find.byWidgetPredicate(
          (w) => w is FrequentResultLine && w.article.name == 'Piles',
        ),
      );
      await _back(tester);

      // Le parcours : Boulangerie glissée en tête par sa poignée.
      await tapParametre(tester, StringsFr.parcours);
      final handle = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is RouteRow && w.rayon == Rayon.boulangerie,
        ),
        matching: find.byType(ReorderableDragStartListener),
      );
      final rowHeight = tester
          .getSize(
            find.byWidgetPredicate(
              (w) => w is RouteRow && w.rayon == Rayon.fruitsLegumes,
            ),
          )
          .height;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(Offset(0, -1.5 * rowHeight / 6));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await _back(tester);

      // Les réglages : Écran allumé activé, groupement coupé.
      for (final title in [
        StringsFr.garderEcranAllume,
        StringsFr.grouperParRayon,
      ]) {
        await tapAndSettle(tester, find.widgetWithText(SwitchListTile, title));
      }

      final before = await _contents(source);
      final settings = before['settings']! as Map<String, Object?>;
      expect(
        SettingsRepository.decodeRouteOrder(settings['routeOrder']! as String)
            .first,
        Rayon.boulangerie,
      );
      expect(settings['keepScreenOn'], isTrue);
      expect(settings['groupByRayon'], isFalse);
      expect(
        (await (source.select(
              source.frequents,
            )..where((f) => f.id.equals(frequentId(_piles)))).getSingle())
            .deletedAt,
        isNull,
      );

      // Export par la ligne des Paramètres.
      await tapParametre(tester, StringsFr.exporterMesDonnees);
      expect(shared, hasLength(1));
      expect(find.text(StringsFr.sauvegardePrete), findsOneWidget);
      await letSnackBarClose(tester);

      // Base neuve : premier lancement, puis Importer une sauvegarde.
      final fresh = _tempDir('kadi_e2e_b_');
      final freshPhotos = Directory(
        '${fresh.path}${Platform.pathSeparator}${RecipePhotos.folder}',
      );
      final target = await pumpE2e(
        tester,
        firstLaunch: true,
        overrides: [
          recipePhotosProvider.overrideWithValue(
            RecipePhotos(() async => fresh),
          ),
        ],
        pickBackupFile: () async => shared.single,
      );
      expect(await recipeNamed(target, 'Gratin'), isNull);
      await openParametres(tester);
      await tapParametre(tester, StringsFr.importerUneSauvegarde);
      expect(find.text(StringsFr.sauvegardeImportee), findsOneWidget);

      // Recettes, photo, catalogue, fréquents, parcours, réglages et liste
      // en cours identiques.
      expect(await _contents(target), before);
      expect(
        RecipePhotos.fileIn(freshPhotos, 'gratin.jpg').readAsBytesSync(),
        _png,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, StringsFr.grouperParRayon),
            )
            .value,
        isFalse,
      );
      expect(find.byType(ParametresScreen), findsOneWidget);
      await letSnackBarClose(tester);
    });
  });
}

/// Id de l'article Piles fourni.
const _piles = '647841c6-7cff-40f4-a8dd-69d7e781eb8b';

void main() => sauvegarde();
