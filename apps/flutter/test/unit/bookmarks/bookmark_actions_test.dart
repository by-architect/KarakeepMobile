import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/core/error/failure.dart';
import 'package:karakeep_client/features/bookmarks/bookmarks_providers.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:karakeep_client/features/bookmarks/presentation/bookmark_actions.dart';
import 'package:karakeep_client/features/bookmarks/presentation/viewmodels/home_feed_view_model.dart';

import 'fakes.dart';

void main() {
  const account = 'acc';
  late FakeBookmarksRepository repo;
  late InMemoryHomePreferences prefs;
  late ProviderContainer container;

  HomeFeedViewModel home() => container.read(homeFeedViewModelProvider.notifier);
  List<String> ids() =>
      container.read(homeFeedViewModelProvider).bookmarks.map((b) => b.id).toList();
  BookmarkActions actions() => container.read(bookmarkActionsProvider);

  setUp(() async {
    repo = FakeBookmarksRepository(
      pageSize: 20,
      items: {
        'all': [link('a'), link('b'), link('c', favourited: true)],
        'favourites': [link('c', favourited: true)],
        'list:L1': [link('a'), link('b')],
      },
    );
    prefs = InMemoryHomePreferences();
    container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider.overrideWithValue(repo),
        homePreferencesProvider.overrideWithValue(prefs),
        accountKeyProvider.overrideWithValue(account),
      ],
    );
    container.listen(homeFeedViewModelProvider, (_, _) {});
    await pumpEventQueue();
  });

  tearDown(() => container.dispose());

  test('archiving with archived hidden drops it; undo puts it back', () async {
    final b = home().items[1];
    await actions().toggleArchive(home(), b);
    expect(ids(), ['a', 'c']);

    await actions().undoArchive(home(), b, 1);
    expect(ids(), ['a', 'b', 'c']);
    expect(repo.items['all']![1].archived, isFalse);
  });

  test('archiving with archived shown keeps it, marked', () async {
    await home().setShowArchived(true);
    await actions().toggleArchive(home(), home().items[0]);
    expect(ids(), ['a', 'b', 'c']);
    expect(home().items[0].archived, isTrue);
  });

  test('a failed change is rolled back', () async {
    repo.failing.add('b');
    await expectLater(
      actions().toggleArchive(home(), home().items[1]),
      throwsA(isA<NetworkFailure>()),
    );
    expect(ids(), ['a', 'b', 'c']);
    await expectLater(
      actions().delete(home(), home().items[1]),
      throwsA(isA<NetworkFailure>()),
    );
    expect(ids(), ['a', 'b', 'c']);
  });

  test('unfavoriting inside Favorites drops it', () async {
    await home().selectScope(const FavouritesScope());
    await actions().toggleFavourite(home(), home().items.single);
    expect(ids(), isEmpty);
  });

  test('removing from the open list drops it', () async {
    await home().selectScope(
      const ListScope(id: 'L1', name: 'Reading', icon: '📚'),
    );
    await actions().setInList(home(), home().items[0], 'L1', member: false);
    expect(ids(), ['b']);
  });

  test('tag changes come back from the server', () async {
    final updated = await actions().attachTag(home(), home().items[0], 'dart');
    expect(updated.tags.single.name, 'dart');
    expect(home().items[0].tags.single.name, 'dart');
  });
}
