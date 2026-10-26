import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Règles de dépendance du spine, vérifiées sur les imports.
void main() {
  final importRe = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  List<File> dartFiles(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

  /// Imports de [file], rendus en chemins `lib/...` quand ils sont relatifs.
  List<String> importsOf(File file) {
    final source = file.readAsStringSync();
    return [
      for (final m in importRe.allMatches(source)) _resolve(file, m.group(1)!),
    ];
  }

  List<String> violations(String dir, bool Function(String import) banned) => [
    for (final f in dartFiles(dir))
      for (final i in importsOf(f))
        if (banned(i)) '${f.path} -> $i',
  ];

  bool isFeature(String i, [String feature = '']) =>
      i.startsWith('package:kadi/features/$feature') ||
      i.startsWith('lib/features/$feature');

  test('core ne dépend d’aucune fonctionnalité', () {
    expect(violations('lib/core', isFeature), isEmpty);
  });

  test('liste ne dépend jamais de recettes', () {
    expect(
      violations('lib/features/liste', (i) => isFeature(i, 'recettes/')),
      isEmpty,
    );
  });

  test('catalogue ne dépend d’aucune autre fonctionnalité', () {
    expect(
      violations(
        'lib/features/catalogue',
        (i) => isFeature(i) && !isFeature(i, 'catalogue/'),
      ),
      isEmpty,
    );
  });

  test('Material seulement par package:material_ui', () {
    bool banned(String i) => i == 'package:flutter/material.dart';
    expect([
      ...violations('lib', banned),
      ...violations('test', banned),
    ], isEmpty);
  });

  test('aucune couleur hex hors de lib/core/theme', () {
    final hex = RegExp(r'Color\(0x|#[0-9A-Fa-f]{6}\b');
    final offenders = [
      for (final f in dartFiles('lib'))
        if (!f.path.replaceAll(r'\', '/').startsWith('lib/core/theme/') &&
            hex.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('ni sqlite3_flutter_libs ni dateTime() ni générateur Riverpod', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('sqlite3_flutter_libs')));
    expect(pubspec, isNot(contains('riverpod_generator')));
    final tables = dartFiles('lib/core/db/tables')
        .map((f) => f.readAsStringSync())
        .join();
    expect(tables, isNot(contains('dateTime()')));
  });
}

String _resolve(File from, String import) {
  if (import.startsWith('package:') || import.startsWith('dart:')) {
    return import;
  }
  final dir = from.parent.uri;
  final resolved = dir.resolve(import).toFilePath().replaceAll(r'\', '/');
  final root = Directory.current.uri.toFilePath().replaceAll(r'\', '/');
  return resolved.startsWith(root) ? resolved.substring(root.length) : resolved;
}
