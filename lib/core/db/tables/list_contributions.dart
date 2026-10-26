import 'package:drift/drift.dart';

import 'list_lines.dart';
import 'sync_columns.dart';

/// Contributions d'une ligne (provenance). Propriétaire : `liste` (AD-2).
class ListContributions extends Table with SyncColumns {
  /// Parent de la contribution : sa ligne, pas sa source (AD-7).
  TextColumn get lineId => text().references(ListLines, #id)();

  /// `week_selection`, `ajout` (Panneau +) ou `edition` (AD-4, AD-5).
  TextColumn get source => text()();

  /// Sélection de recette validée quand [source] vaut `week_selection`.
  TextColumn get weekSelectionId => text().nullable()();

  /// Entier (g, ml ou millièmes de pièce), nul avec [unit] (AD-6).
  IntColumn get quantity => integer().nullable()();

  TextColumn get unit => text().nullable()();
}
