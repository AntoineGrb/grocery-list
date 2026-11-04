import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/backup/backup_archive.dart';
import 'package:kadi/core/backup/backup_providers.dart';
import 'package:kadi/core/db/app_database.dart';
import 'package:kadi/core/db/db_providers.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/settings_action.dart';
import 'package:kadi/features/recettes/data/recipe_photos.dart';
import 'package:kadi/features/recettes/state/recettes_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_db.dart';

/// Exporteur qui échoue toujours.
class _FailingExporter extends BackupExporter {
  _FailingExporter(super.db);

  @override
  Future<File> export({
    required Directory photos,
    required Directory target,
    DateTime? now,
  }) async => throw const FileSystemException('échec simulé');
}

/// Double de la feuille de partage : note les fichiers partagés et rend
/// [result] (vrai = partagé), ou attend [pending] s'il est posé.
class _FakeShare {
  final shared = <File>[];
  bool result = true;
  Completer<bool>? pending;

  Future<bool> call(File file) async {
    shared.add(file);
    final wait = pending;
    if (wait != null) return wait.future;
    return result;
  }
}

class _Env {
  _Env(this.db, this.share, this.photos);
  final AppDatabase db;
  final _FakeShare share;
  final Directory photos;
}

Finder get _exportRow =>
    find.widgetWithText(ListTile, StringsFr.exporterMesDonnees);

/// Kadi ouvert sur Paramètres ; photos dans un dossier temporaire, partage
/// remplacé par un double.
Future<_Env> _openParametres(
  WidgetTester tester, {
  bool failingExporter = false,
}) async {
  final documents = Directory.systemTemp.createTempSync('kadi_docs_');
  addTearDown(() {
    try {
      documents.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows : un fichier encore ouvert.
    }
  });
  final photos = Directory(
    '${documents.path}${Platform.pathSeparator}${RecipePhotos.folder}',
  );
  final share = _FakeShare();
  final db = await pumpKadi(
    tester,
    shareFile: share.call,
    overrides: [
      recipePhotosProvider.overrideWithValue(
        RecipePhotos(() async => documents),
      ),
      if (failingExporter)
        backupExporterProvider.overrideWith(
          (ref) => _FailingExporter(ref.watch(databaseProvider)),
        ),
    ],
  );
  await tester.tap(find.byType(SettingsAction));
  await tester.pumpAndSettle();
  return _Env(db, share, photos);
}

Future<void> _tapExport(WidgetTester tester) async {
  await tester.tap(_exportRow);
  await tester.pumpAndSettle();
}

/// Laisse partir le snackbar affiché.
Future<void> _dismissSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester) =>
    tester.widget<ListTile>(_exportRow).enabled;

void main() {
  testWidgets('ligne « Exporter mes données » sous les deux switches, avec '
      'son aide, cible de 48 dp au moins', (tester) async {
    await _openParametres(tester);

    expect(_exportRow, findsOneWidget);
    expect(find.text(StringsFr.exporterMesDonneesDetail), findsOneWidget);
    final row = tester.getRect(_exportRow);
    final switchRow = tester.getRect(
      find.widgetWithText(SwitchListTile, StringsFr.grouperParRayon),
    );
    expect(row.top, greaterThanOrEqualTo(switchRow.bottom));
    expect(row.height, greaterThanOrEqualTo(48));
    expect(_enabled(tester), isTrue);
  });

  testWidgets('toucher : la feuille de partage reçoit kadi-sauvegarde-'
      '<date>.zip avec data.json et la photo, puis « Sauvegarde prête. »', (
    tester,
  ) async {
    final env = await _openParametres(tester);
    env.photos.createSync(recursive: true);
    File('${env.photos.path}${Platform.pathSeparator}chili.jpg')
        .writeAsBytesSync([1, 2, 3]);
    await (env.db.update(env.db.recipes)
          ..where((r) => r.id.equals(SeedRecipeIds.chili)))
        .write(const RecipesCompanion(photo: Value('chili.jpg')));

    await _tapExport(tester);

    expect(env.share.shared, hasLength(1));
    final file = env.share.shared.single;
    expect(
      file.uri.pathSegments.last,
      matches(RegExp(r'^kadi-sauvegarde-\d{4}-\d{2}-\d{2}\.zip$')),
    );
    expect(file.existsSync(), isTrue);
    final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
    expect(archive.findFile(BackupFormat.dataFile), isNotNull);
    expect(archive.findFile('${BackupFormat.photosFolder}chili.jpg')!.content, [
      1,
      2,
      3,
    ]);
    expect(find.text(StringsFr.sauvegardePrete), findsOneWidget);
    expect(find.text(StringsFr.exportImpossible), findsNothing);
    expect(_enabled(tester), isTrue);
    await _dismissSnackBar(tester);
  });

  testWidgets('pendant l’export : la ligne est désactivée, un second toucher '
      'ne relance rien', (tester) async {
    final env = await _openParametres(tester);
    final pending = env.share.pending = Completer<bool>();

    await _tapExport(tester);
    expect(env.share.shared, hasLength(1));
    expect(_enabled(tester), isFalse);
    await tester.tap(_exportRow, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(env.share.shared, hasLength(1));
    expect(find.text(StringsFr.sauvegardePrete), findsNothing);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(_enabled(tester), isTrue);
    expect(find.text(StringsFr.sauvegardePrete), findsOneWidget);
    await _dismissSnackBar(tester);
  });

  testWidgets('partage annulé : aucun snackbar', (tester) async {
    final env = await _openParametres(tester);
    env.share.result = false;

    await _tapExport(tester);
    expect(env.share.shared, hasLength(1));
    expect(find.text(StringsFr.sauvegardePrete), findsNothing);
    expect(find.text(StringsFr.exportImpossible), findsNothing);
    expect(_enabled(tester), isTrue);
  });

  testWidgets('échec de l’export : « Export impossible. », rien partagé', (
    tester,
  ) async {
    final env = await _openParametres(tester, failingExporter: true);

    await _tapExport(tester);
    expect(env.share.shared, isEmpty);
    expect(find.text(StringsFr.exportImpossible), findsOneWidget);
    expect(find.text(StringsFr.sauvegardePrete), findsNothing);
    expect(_enabled(tester), isTrue);
    await _dismissSnackBar(tester);
  });

  testWidgets('TalkBack : la ligne est lue avec son libellé et son aide, et '
      'se touche', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await _openParametres(tester);

    expect(
      tester.getSemantics(_exportRow),
      isSemantics(
        label:
            '${StringsFr.exporterMesDonnees}\n'
            '${StringsFr.exporterMesDonneesDetail}',
        hasTapAction: true,
        isEnabled: true,
      ),
    );
    tester.semantics.tap(
      find.semantics.byLabel(RegExp('^${StringsFr.exporterMesDonnees}')),
    );
    await tester.pumpAndSettle();
    expect(env.share.shared, hasLength(1));
    await _dismissSnackBar(tester);
    handle.dispose();
  });

  testWidgets('police ×2 sur 360 dp : libellé et aide entiers, sans '
      'débordement', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await _openParametres(tester);
    expect(tester.takeException(), isNull);

    for (final text in [
      StringsFr.exporterMesDonnees,
      StringsFr.exporterMesDonneesDetail,
    ]) {
      final finder = find.text(text);
      // La ligne Parcours, au-dessus, peut la pousser hors de l'écran.
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: text);
      expect(tester.getRect(finder).right, lessThanOrEqualTo(360));
      expect(tester.widget<Text>(finder).overflow, isNull, reason: text);
      expect(tester.widget<Text>(finder).maxLines, isNull, reason: text);
    }
    expect(_exportRow.hitTestable(), findsOneWidget);
  });
}
