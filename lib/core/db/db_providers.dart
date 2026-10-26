import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock/clock.dart';
import 'app_database.dart';

/// La base unique de l'app (AD-1). Remplacée par une base en mémoire en test.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// L'horloge unique des écritures (AD-7).
final clockProvider = Provider<Clock>((ref) => Clock());
