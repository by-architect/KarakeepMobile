import 'package:flutter_riverpod/misc.dart';
import 'package:karakeep_client/features/settings/domain/settings_repository.dart';
import 'package:karakeep_client/features/settings/settings_providers.dart';

class InMemorySettings implements SettingsRepository {
  @override
  LinkOpenMode linkOpenMode = LinkOpenMode.inAppBrowser;
  @override
  ViewerMode viewerMode = ViewerMode.browser;
  @override
  SwipeAction swipeRight = SwipeAction.archive;
  @override
  SwipeAction swipeLeft = SwipeAction.favourite;

  @override
  Future<void> setLinkOpenMode(LinkOpenMode mode) async => linkOpenMode = mode;
  @override
  Future<void> setViewerMode(ViewerMode mode) async => viewerMode = mode;
  @override
  Future<void> setSwipeRight(SwipeAction action) async => swipeRight = action;
  @override
  Future<void> setSwipeLeft(SwipeAction action) async => swipeLeft = action;
}

class FakeCacheCleaner implements CacheCleaner {
  var cleared = 0;

  @override
  Future<void> clear() async => cleared++;
}

/// Overrides every settings provider that would touch the platform.
List<Override> settingsOverrides({
  InMemorySettings? settings,
  FakeCacheCleaner? cleaner,
}) =>
    [
      settingsRepositoryProvider.overrideWithValue(
        settings ?? InMemorySettings(),
      ),
      cacheCleanerProvider.overrideWithValue(cleaner ?? FakeCacheCleaner()),
      appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
    ];
