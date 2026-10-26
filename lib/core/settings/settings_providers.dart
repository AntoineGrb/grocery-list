import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/db_providers.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      SettingsRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Réglages observés par toutes les fonctionnalités.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
