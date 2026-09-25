import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../bookmarks_providers.dart';
import '../../domain/entities/bookmark_list.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../state/lists_nav_state.dart';

/// The list picker in the drawer: lists as a tree, each with
/// `unarchived / total`.
///
/// Totals come straight from the server. Karakeep has no unarchived count,
/// so those are counted in the background, a few scopes at a time, and cached
/// on the device so the drawer shows last known numbers instantly.
class ListsNavViewModel extends Notifier<ListsNavState> {
  static const _parallelCounts = 3;
  static const _staleAfter = Duration(minutes: 2);

  var _generation = 0;
  DateTime? _lastRefresh;

  BookmarksRepository get _repo => ref.read(bookmarksRepositoryProvider);

  @override
  ListsNavState build() {
    final cached =
        ref.watch(homePreferencesProvider).cachedCounts(ref.watch(accountKeyProvider));
    Future.microtask(refresh);
    return ListsNavState(counts: cached);
  }

  /// Called when the drawer opens; skips if the data is recent.
  void refreshIfStale() {
    final last = _lastRefresh;
    if (last == null || DateTime.now().difference(last) > _staleAfter) {
      refresh();
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _lastRefresh = DateTime.now();
    try {
      final results = await Future.wait<Object>([
        _repo.getLists(),
        _repo.getListTotals(),
        _repo.getLibraryTotals(),
      ]);
      final lists = results[0] as List<BookmarkList>;
      final totals = results[1] as Map<String, int>;
      final library = results[2] as LibraryTotals;
      if (!_current(generation)) return;

      final previous = state.counts;
      ItemCount withOld(String key, int total) =>
          ItemCount(total: total, unarchived: previous[key]?.unarchived);

      final counts = <String, ItemCount>{
        AllScope.keyValue: ItemCount(
          total: library.bookmarks,
          unarchived: library.bookmarks - library.archived,
        ),
        FavouritesScope.keyValue:
            withOld(FavouritesScope.keyValue, library.favourites),
        ArchivedScope.keyValue:
            ItemCount(total: library.archived, unarchived: 0),
        for (final list in lists)
          ListScope.prefix + list.id:
              withOld(ListScope.prefix + list.id, totals[list.id] ?? 0),
      };

      state = state.copyWith(
        status: ListsStatus.ready,
        lists: buildTree(lists),
        counts: counts,
        counting: true,
        error: () => null,
      );
      await _countUnarchived(generation, [
        const FavouritesScope(),
        for (final list in lists)
          ListScope(id: list.id, name: list.name, icon: list.icon),
      ]);
    } on Failure catch (f) {
      _fail(generation, f);
    }
  }

  Future<void> _countUnarchived(
    int generation,
    List<BookmarkScope> scopes,
  ) async {
    final queue = [...scopes];
    Future<void> worker() async {
      while (queue.isNotEmpty && _current(generation)) {
        final scope = queue.removeAt(0);
        final total = state.counts[scope.key]?.total ?? 0;
        try {
          final unarchived =
              total == 0 ? 0 : await _repo.countUnarchived(scope);
          if (!_current(generation)) return;
          state = state.copyWith(
            counts: {
              ...state.counts,
              scope.key: ItemCount(total: total, unarchived: unarchived),
            },
          );
        } on Failure {
          // Keep the last known number; the next refresh tries again.
        }
      }
    }

    await Future.wait(List.generate(_parallelCounts, (_) => worker()));
    if (!_current(generation)) return;
    state = state.copyWith(counting: false);
    await ref
        .read(homePreferencesProvider)
        .setCachedCounts(ref.read(accountKeyProvider), state.counts);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  void _fail(int generation, Failure failure) {
    if (!_current(generation)) return;
    state = state.copyWith(
      status: state.lists.isEmpty ? ListsStatus.error : state.status,
      counting: false,
      error: () => failure.message,
    );
  }

  /// Roots sorted by name, each followed by its children. Lists whose parent
  /// isn't visible (e.g. shared from someone else) become roots.
  static List<ListEntry> buildTree(List<BookmarkList> lists) {
    final ids = {for (final l in lists) l.id};
    final children = <String?, List<BookmarkList>>{};
    for (final l in lists) {
      final parent = ids.contains(l.parentId) ? l.parentId : null;
      children.putIfAbsent(parent, () => []).add(l);
    }
    for (final group in children.values) {
      group.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final out = <ListEntry>[];
    final visited = <String>{};
    void visit(String? parentId, int depth) {
      for (final l in children[parentId] ?? const <BookmarkList>[]) {
        if (!visited.add(l.id)) continue; // guards against parent cycles
        out.add(ListEntry(list: l, depth: depth));
        visit(l.id, depth + 1);
      }
    }

    visit(null, 0);
    // Lists caught in a parent cycle never hang off a root; show them anyway.
    for (final l in lists) {
      if (visited.add(l.id)) {
        out.add(ListEntry(list: l, depth: 0));
        visit(l.id, 1);
      }
    }
    return out;
  }
}

final listsNavViewModelProvider =
    NotifierProvider.autoDispose<ListsNavViewModel, ListsNavState>(
  ListsNavViewModel.new,
);
