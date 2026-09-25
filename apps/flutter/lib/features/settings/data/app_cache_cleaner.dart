import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';

import '../../bookmarks/domain/repositories/home_preferences_repository.dart';
import '../domain/settings_repository.dart';

/// Clears the image disk + memory caches and the saved list counts.
class AppCacheCleaner implements CacheCleaner {
  const AppCacheCleaner({
    required this.homePreferences,
    required this.accountKey,
  });

  final HomePreferencesRepository homePreferences;
  final String accountKey;

  @override
  Future<void> clear() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await homePreferences.setCachedCounts(accountKey, const {});
  }
}
