import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/di/core_providers.dart';
import '../bookmarks/bookmarks_providers.dart';
import 'data/app_cache_cleaner.dart';
import 'data/settings_local_data_source.dart';
import 'domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsLocalDataSource(ref.watch(sharedPreferencesProvider));
});

final cacheCleanerProvider = Provider<CacheCleaner>((ref) {
  return AppCacheCleaner(
    homePreferences: ref.watch(homePreferencesProvider),
    accountKey: ref.watch(accountKeyProvider),
  );
});

/// e.g. `1.0.0 (1)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});
