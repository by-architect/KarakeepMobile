import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/features/bookmarks/bookmarks_providers.dart';
import 'package:linkstow/features/bookmarks/domain/entities/bookmark_list.dart';
import 'package:linkstow/features/bookmarks/presentation/state/lists_nav_state.dart';
import 'package:linkstow/features/bookmarks/presentation/viewmodels/lists_nav_view_model.dart';

import 'fakes.dart';

void main() {
  const account = 'acc';

  group('buildTree', () {
    List<String> names(List<ListEntry> e) =>
        [for (final x in e) '${'  ' * x.depth}${x.list.name}'];

    test('sorts roots and nests children under parents', () {
      final tree = ListsNavViewModel.buildTree(const [
        BookmarkList(id: '3', name: 'zeta', icon: 'z'),
        BookmarkList(id: '2', name: 'Child', icon: 'c', parentId: '1'),
        BookmarkList(id: '1', name: 'Alpha', icon: 'a'),
        BookmarkList(id: '4', name: 'Orphan', icon: 'o', parentId: 'gone'),
      ]);
      expect(names(tree), ['Alpha', '  Child', 'Orphan', 'zeta']);
    });

    test('keeps lists caught in a parent cycle', () {
      final tree = ListsNavViewModel.buildTree(const [
        BookmarkList(id: '1', name: 'A', icon: 'a', parentId: '2'),
        BookmarkList(id: '2', name: 'B', icon: 'b', parentId: '1'),
      ]);
      expect(tree, hasLength(2));
    });
  });

  test('counts unarchived / total for every row and caches them', () async {
    final repo = FakeBookmarksRepository(
      lists: const [
        BookmarkList(id: 'L1', name: 'Reading', icon: '📚'),
        BookmarkList(id: 'L2', name: 'Empty', icon: '🫙'),
      ],
      items: {
        'all': [
          link('a', favourited: true),
          link('b', favourited: true, archived: true),
          link('c', archived: true),
          link('d'),
        ],
        'favourites': [
          link('a', favourited: true),
          link('b', favourited: true, archived: true),
        ],
        'list:L1': [link('a'), link('c', archived: true), link('d')],
      },
    );
    final prefs = InMemoryHomePreferences();
    final container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider.overrideWithValue(repo),
        homePreferencesProvider.overrideWithValue(prefs),
        accountKeyProvider.overrideWithValue(account),
      ],
    );
    addTearDown(container.dispose);
    container.listen(listsNavViewModelProvider, (_, _) {});
    await pumpEventQueue();

    final s = container.read(listsNavViewModelProvider);
    String c(String key) =>
        '${s.counts[key]!.unarchived} / ${s.counts[key]!.total}';

    expect(s.status, ListsStatus.ready);
    expect(s.counting, isFalse);
    expect(c('all'), '2 / 4');
    expect(c('favourites'), '1 / 2');
    expect(s.counts['archived']!.total, 2);
    expect(c('list:L1'), '2 / 3');
    expect(c('list:L2'), '0 / 0');
    // Empty lists aren't fetched just to count zero.
    expect(repo.countCalls, isNot(contains('list:L2')));
    expect(prefs.counts[account]!['list:L1']!.unarchived, 2);
  });

  group('delete', () {
    late FakeBookmarksRepository repo;
    late ProviderContainer container;

    ListsNavViewModel vm() => container.read(listsNavViewModelProvider.notifier);
    ListsNavState state() => container.read(listsNavViewModelProvider);

    setUp(() async {
      repo = FakeBookmarksRepository(
        lists: const [
          BookmarkList(id: 'L1', name: 'Reading', icon: '📚'),
          BookmarkList(id: 'L2', name: 'Later', icon: '⏰', parentId: 'L1'),
          BookmarkList(id: 'L3', name: 'Zines', icon: '📰'),
        ],
      );
      repo.tags = const [
        TagSummary(id: 'T1', name: 'flutter', count: 3),
        TagSummary(id: 'T2', name: 'rust', count: 1),
      ];
      container = ProviderContainer(
        overrides: [
          bookmarksRepositoryProvider.overrideWithValue(repo),
          homePreferencesProvider.overrideWithValue(InMemoryHomePreferences()),
          accountKeyProvider.overrideWithValue(account),
        ],
      );
      container.listen(listsNavViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test('a list: gone at once, lists inside it move to the top', () async {
      await vm().deleteList(state().lists.first.list);
      expect(repo.deletedLists, ['L1']);
      expect(
        [for (final e in state().lists) '${e.depth} ${e.list.name}'],
        ['0 Later', '0 Zines'],
      );
      await pumpEventQueue(); // the refresh agrees
      expect(state().lists.map((e) => e.list.name), ['Later', 'Zines']);
    });

    test('a tag', () async {
      await vm().deleteTag(state().tags.first);
      expect(repo.deletedTags, ['T1']);
      expect(state().tags.map((t) => t.name), ['rust']);
    });

    test('a new list shows up in the tree', () async {
      final created = vm().createList(
        name: 'Inbox',
        icon: '📥',
        kind: ListKind.manual,
      );
      await created;
      expect(state().lists.map((e) => e.list.name), contains('Inbox'));
    });
  });

  test('tags get unarchived / total too, cached like lists', () async {
    final repo = FakeBookmarksRepository(
      items: {
        'tag:T1': [link('a'), link('b', archived: true)],
      },
    )..tags = const [TagSummary(id: 'T1', name: 'flutter', count: 2)];
    final prefs = InMemoryHomePreferences();
    final container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider.overrideWithValue(repo),
        homePreferencesProvider.overrideWithValue(prefs),
        accountKeyProvider.overrideWithValue(account),
      ],
    );
    addTearDown(container.dispose);
    container.listen(listsNavViewModelProvider, (_, _) {});
    await pumpEventQueue();

    final count = container.read(listsNavViewModelProvider).counts['tag:T1']!;
    expect('${count.unarchived} / ${count.total}', '1 / 2');
    expect(prefs.counts[account]!['tag:T1']!.unarchived, 1);
  });

  test('shows cached counts before the server answers', () {
    final prefs = InMemoryHomePreferences()
      ..counts[account] = {'list:L1': const ItemCount(total: 9, unarchived: 4)};
    final container = ProviderContainer(
      overrides: [
        bookmarksRepositoryProvider
            .overrideWithValue(FakeBookmarksRepository()),
        homePreferencesProvider.overrideWithValue(prefs),
        accountKeyProvider.overrideWithValue(account),
      ],
    );
    addTearDown(container.dispose);
    final s = container.read(listsNavViewModelProvider);
    expect(s.counts['list:L1']!.unarchived, 4);
  });
}
