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
  /// (AD-8), et le drapeau de premier lancement levé si [firstLaunch] (des
  /// recettes exemples viennent d'être insérées, AD-13). Sans effet si la
  /// ligne existe déjà.
  Future<void> insertDefaults({
    required Map<String, int> seedVersions,
    bool firstLaunch = false,
  }) async {
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
            firstLaunch: firstLaunch || d.firstLaunch,
            seedVersions: jsonEncode(seedVersions),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Enregistre les `seed_version` après un chargement du contenu fourni,
  /// et lève dans la même écriture le drapeau de premier lancement si
  /// [raiseFirstLaunch] (AD-13).
  Future<void> setSeedVersions(
    Map<String, int> seedVersions, {
    bool raiseFirstLaunch = false,
  }) async {
    final r = await (_db.select(
      _db.settings,
    )..where((s) => s.id.equals(rowId))).getSingle();
    await (_db.update(_db.settings)..where((s) => s.id.equals(rowId))).write(
      SettingsCompanion(
        seedVersions: Value(jsonEncode(seedVersions)),
        firstLaunch: raiseFirstLaunch
            ? const Value(true)
            : const Value.absent(),
        updatedAt: Value(_clock.stamp(r.updatedAt)),
      ),
    );
  }

  /// Fixe le drapeau de premier lancement (AD-13) ; sans ligne de réglages,
  /// ou drapeau déjà à [value], rien n'est écrit.
  Future<void> setFirstLaunch(bool value) async {
    final r = await _row.getSingleOrNull();
    if (r == null || r.firstLaunch == value) return;
    await (_db.update(_db.settings)..where((s) => s.id.equals(rowId))).write(
      SettingsCompanion(
        firstLaunch: Value(value),
        updatedAt: Value(_clock.stamp(r.updatedAt)),
      ),
    );
  }

  /// Écran allumé (R14) ; sans ligne de réglages, ou valeur inchangée, rien
  /// n'est écrit.
  Future<void> setKeepScreenOn(bool value) => _write(
    (r) => r.keepScreenOn == value,
    SettingsCompanion(keepScreenOn: Value(value)),
  );

  /// Groupement de la Liste par rayon ; sans ligne de réglages, ou valeur
  /// inchangée, rien n'est écrit.
  Future<void> setGroupByRayon(bool value) => _write(
    (r) => r.groupByRayon == value,
    SettingsCompanion(groupByRayon: Value(value)),
  );

  /// Ordre du parcours (R19) : [order] porte les 13 rayons, chacun une fois,
  /// sinon [ArgumentError]. Sans ligne de réglages, ou ordre inchangé, rien
  /// n'est écrit.
  Future<void> setRouteOrder(List<Rayon> order) {
    if (order.length != Rayon.values.length ||
        order.toSet().length != Rayon.values.length) {
      throw ArgumentError.value(
        order,
        'order',
        'doit contenir les ${Rayon.values.length} rayons, chacun une fois',
      );
    }
    final encoded = encodeRouteOrder(order);
    return _write(
      (r) => r.routeOrder == encoded,
      SettingsCompanion(routeOrder: Value(encoded)),
    );
  }

  /// Écrit [changes] sur la ligne de réglages, horodatée par l'horloge
  /// (AD-7), sauf si elle n'existe pas ou si [unchanged] la dit déjà à jour.
  Future<void> _write(
    bool Function(SettingsRow r) unchanged,
    SettingsCompanion changes,
  ) async {
    final r = await _row.getSingleOrNull();
    if (r == null || unchanged(r)) return;
    await (_db.update(_db.settings)..where((s) => s.id.equals(rowId))).write(
      changes.copyWith(updatedAt: Value(_clock.stamp(r.updatedAt))),
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
