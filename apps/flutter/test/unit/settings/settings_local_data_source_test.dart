import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/features/settings/data/settings_local_data_source.dart';
import 'package:karakeep_client/features/settings/domain/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  Future<SettingsLocalDataSource> launch() async => SettingsLocalDataSource(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        ),
      );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('defaults: in-app viewer, browser view, archive → / favorite ←',
      () async {
    final s = await launch();
    expect(s.linkOpenMode, LinkOpenMode.inAppBrowser);
    expect(s.viewerMode, ViewerMode.browser);
    expect(s.swipeRight, SwipeAction.archive);
    expect(s.swipeLeft, SwipeAction.favourite);
  });

  test('choices survive a relaunch', () async {
    final first = await launch();
    await first.setLinkOpenMode(LinkOpenMode.externalBrowser);
    await first.setViewerMode(ViewerMode.reader);
    await first.setSwipeRight(SwipeAction.delete);
    await first.setSwipeLeft(SwipeAction.none);

    final second = await launch();
    expect(second.linkOpenMode, LinkOpenMode.externalBrowser);
    expect(second.viewerMode, ViewerMode.reader);
    expect(second.swipeRight, SwipeAction.delete);
    expect(second.swipeLeft, SwipeAction.none);
  });
}
