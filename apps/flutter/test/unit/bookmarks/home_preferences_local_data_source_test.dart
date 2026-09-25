import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/features/bookmarks/data/datasources/local/home_preferences_local_data_source.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_list.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  /// A fresh instance over the same storage = the app being relaunched.
  Future<HomePreferencesLocalDataSource> launch() async =>
      HomePreferencesLocalDataSource(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        ),
      );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('defaults: archived hidden, no scope, no counts', () async {
    final prefs = await launch();
    expect(prefs.showArchived, isFalse);
    expect(prefs.lastScope('acc'), isNull);
    expect(prefs.cachedCounts('acc'), isEmpty);
  });

  test('survives a relaunch', () async {
    final first = await launch();
    await first.setShowArchived(true);
    await first.setLastScope(
      'acc',
      const ListScope(id: 'L1', name: 'Reading', icon: '📚'),
    );
    await first.setCachedCounts('acc', {
      'list:L1': const ItemCount(total: 9, unarchived: 4),
      'favourites': const ItemCount(total: 3),
    });

    final second = await launch();
    expect(second.showArchived, isTrue);
    final scope = second.lastScope('acc')! as ListScope;
    expect(scope.id, 'L1');
    expect(scope.name, 'Reading');
    expect(scope.icon, '📚');
    expect(second.cachedCounts('acc')['list:L1']!.unarchived, 4);
    expect(second.cachedCounts('acc')['favourites']!.unarchived, isNull);
  });

  test('scope is per account', () async {
    final prefs = await launch();
    await prefs.setLastScope('a', const FavouritesScope());
    expect(prefs.lastScope('a'), const FavouritesScope());
    expect(prefs.lastScope('b'), isNull);
  });
}
