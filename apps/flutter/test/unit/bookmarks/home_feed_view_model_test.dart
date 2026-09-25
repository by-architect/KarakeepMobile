import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/core/error/failure.dart';
import 'package:karakeep_client/features/bookmarks/bookmarks_providers.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:karakeep_client/features/bookmarks/presentation/state/home_feed_state.dart';
import 'package:karakeep_client/features/bookmarks/presentation/viewmodels/home_feed_view_model.dart';

import 'fakes.dart';

void main() {
  const account = 'https://keep.example.com|u1';
  const reading = ListScope(id: 'L1', name: 'Reading', icon: '📚');

  late FakeBookmarksRepository repo;
  late InMemoryHomePreferences prefs;
  late ProviderContainer container;

  HomeFeedViewModel vm() => container.read(homeFeedViewModelProvider.notifier);
  HomeFeedState state() => container.read(homeFeedViewModelProvider);

  Future<void> start() async {
    container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider.overrideWithValue(repo),
        homePreferencesProvider.overrideWithValue(prefs),
        accountKeyProvider.overrideWithValue(account),
      ],
    );
    container.listen(homeFeedViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() {
    repo = FakeBookmarksRepository(
      items: {
        'all': [link('a'), link('b', archived: true), link('c')],
        reading.key: [link('r1'), link('r2', archived: true)],
      },
    );
    prefs = InMemoryHomePreferences();
  });

  tearDown(() => container.dispose());

  test('starts on All with archived hidden', () async {
    await start();
    expect(state().scope, const AllScope());
    expect(state().status, FeedStatus.ready);
    expect(state().bookmarks.map((b) => b.id), ['a', 'c']);
    expect(repo.calls.single.includeArchived, isFalse);
  });

  test('restores the remembered scope and filter', () async {
    prefs
      ..showArchived = true
      ..scopes[account] = reading;
    await start();
    expect(state().scope, reading);
    expect(state().showArchived, isTrue);
    expect(state().bookmarks.map((b) => b.id), ['r1', 'r2']);
  });

  test('selecting a list shows it and is remembered', () async {
    await start();
    await vm().selectScope(reading);
    expect(state().bookmarks.map((b) => b.id), ['r1']);
    expect(prefs.scopes[account], reading);
  });

  test('toggling show archived reloads and is remembered', () async {
    await start();
    await vm().setShowArchived(true);
    expect(prefs.showArchived, isTrue);
    expect(state().bookmarks.map((b) => b.id), ['a', 'b']);
    expect(state().hasMore, isTrue);
  });

  test('loads more pages', () async {
    await start();
    await vm().setShowArchived(true);
    await vm().loadMore();
    expect(state().bookmarks.map((b) => b.id), ['a', 'b', 'c']);
    expect(state().hasMore, isFalse);
  });

  test('a remembered list that was deleted falls back to All', () async {
    prefs.scopes[account] = reading;
    repo.missing.add(reading.key);
    await start();
    await pumpEventQueue();
    expect(state().scope, const AllScope());
    expect(state().status, FeedStatus.ready);
    expect(prefs.scopes[account], const AllScope());
  });

  test('shows an error and retries', () async {
    repo.failure = const NetworkFailure();
    await start();
    expect(state().status, FeedStatus.error);
    repo.failure = null;
    await vm().retry();
    expect(state().status, FeedStatus.ready);
  });

  test('refresh failure keeps the items on screen', () async {
    await start();
    repo.failure = const NetworkFailure();
    await vm().refresh();
    expect(state().status, FeedStatus.ready);
    expect(state().bookmarks, isNotEmpty);
    expect(state().loadMoreError, isNotNull);
  });
}
