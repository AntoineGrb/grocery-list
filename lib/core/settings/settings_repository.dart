import 'dart:convert';

import 'package:drift/drift.dart';

import '../clock/clock.dart';
import '../db/app_database.dart';
import '../rayons/rayon.dart';
import 'app_settings.dart';

/// Seul écrivain de la table `settings` (AD-2) : une ligne unique à id fixe.
class SettingsRepository {
  SettingsRepository(this._db, this._clock);

  /// Id fixe de la ligne de réglages (AD-7, clé naturelle).
  static const rowId = 'settings';

  final AppDatabase _db;
  final Clock _clock;

  SimpleSelectStatement<$SettingsTable, SettingsRow> get _row =>
      _db.select(_db.settings)
        ..where((s) => s.id.equals(rowId) & s.deletedAt.isNull());

  /// Réglages actuels ; les valeurs par défaut tant que la ligne n'existe pas.
  Stream<AppSettings> watch() => _row.watchSingleOrNull().map(
    (r) => r == null ? AppSettings.defaults : _toModel(r),
  );

  Future<AppSettings> read() async {
    final r = await _row.getSingleOrNull();
    return r == null ? AppSettings.defaults : _toModel(r);
  }

  /// `true` si la ligne de réglages existe (même supprimée).
  Future<bool> exists() async {
    final r = await (_db.select(
      _db.settings,
    )..where((s) => s.id.equals(rowId))).getSingleOrNull();
    return r != null;
  }

  /// Insère les réglages par défaut avec [seedVersions], `updated_at = 0`
  /// (AD-8). Sans effet si la ligne existe déjà.
  Future<void> insertDefaults({required Map<String, int> seedVersions}) async {
    final d = AppSettings.defaults;
    await _db
        .into(_db.settings)
        .insert(
          SettingsCompanion.insert(
            id: rowId,
            updatedAt: 0,
            routeOrder: encodeRouteOrder(d.routeOrder),
            groupByRayon: d.groupByRayon,
            keepScreenOn: d.keepScreenOn,
            firstLaunch: d.firstLaunch,
            seedVersions: jsonEncode(seedVersions),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Enregistre les `seed_version` après un chargement du contenu fourni.
  Future<void> setSeedVersions(Map<String, int> seedVersions) async {
    final r = await (_db.select(
      _db.settings,
    )..where((s) => s.id.equals(rowId))).getSingle();
    await (_db.update(_db.settings)..where((s) => s.id.equals(rowId))).write(
      SettingsCompanion(
        seedVersions: Value(jsonEncode(seedVersions)),
        updatedAt: Value(_clock.stamp(r.updatedAt)),
      ),
    );
  }

  static String encodeRouteOrder(List<Rayon> order) =>
      order.map((r) => r.code).join(',');

  /// Décode l'ordre du parcours ; un code inconnu est ignoré et un rayon
  /// manquant est ajouté à la fin, pour toujours avoir les 13 rayons.
  static List<Rayon> decodeRouteOrder(String encoded) {
    final order = <Rayon>[];
    for (final code in encoded.split(',')) {
      final r = Rayon.tryFromCode(code.trim());
      if (r != null && !order.contains(r)) order.add(r);
    }
    for (final r in Rayon.values) {
      if (!order.contains(r)) order.add(r);
    }
    return List.unmodifiable(order);
  }

  static Map<String, int> decodeSeedVersions(String encoded) {
    final raw = jsonDecode(encoded) as Map<String, dynamic>;
    return {for (final e in raw.entries) e.key: e.value as int};
  }

  static AppSettings _toModel(SettingsRow r) => AppSettings(
    routeOrder: decodeRouteOrder(r.routeOrder),
    groupByRayon: r.groupByRayon,
    keepScreenOn: r.keepScreenOn,
    firstLaunch: r.firstLaunch,
    seedVersions: Map.unmodifiable(decodeSeedVersions(r.seedVersions)),
  );
}
