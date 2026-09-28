import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../bookmarks_providers.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../../domain/entities/sort_order.dart';
import '../../domain/feed_rules.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../../domain/repositories/home_preferences_repository.dart';
import '../bookmark_actions.dart';
import '../feed_host.dart';
import '../state/home_feed_state.dart';

/// The bookmark feed on the home screen: which scope, in which order,
/// whether archived items show, and paging. All of it is remembered on the
/// device.
class HomeFeedViewModel extends Notifier<HomeFeedState>
    with BookmarkFeedHost {
  /// Bumped whenever the query changes, so late pages of an old query drop.
  var _generation = 0;

  BookmarksRepository get _repo => ref.read(bookmarksRepositoryProvider);
  HomePreferencesRepository get _prefs => ref.read(homePreferencesProvider);
  String get _account => ref.read(accountKeyProvider);

  @override
  HomeFeedState build() {
    final prefs = ref.watch(homePreferencesProvider);
    final account = ref.watch(accountKeyProvider);
    Future.microtask(_loadFirstPage);
    return HomeFeedState(
      scope: prefs.lastScope(account) ?? const AllScope(),
      showArchived: prefs.showArchived,
      sortOrder: prefs.sortOrder,
    );
  }

  // ── BookmarkFeedHost ──────────────────────────────────────────────────

  @override
  List<Bookmark> get items => state.bookmarks;

  @override
  set items(List<Bookmark> value) => state = state.copyWith(bookmarks: value);

  @override
  bool get isActive => ref.mounted;

  @override
  bool get canLoadMore => state.hasMore;

  @override
  bool keeps(Bookmark bookmark) => belongsInFeed(
        bookmark,
        state.scope,
        includeArchived: state.showArchived,
      );

  @override
  void removedFromList(String listId, String bookmarkId) {
    if (state.scope case ListScope(:final id) when id == listId) {
      remove(bookmarkId);
    }
  }

  // ── Scope, order & filter ─────────────────────────────────────────────

  Future<void> selectScope(BookmarkScope scope) async {
    if (scope == state.scope) return;
    state = _fresh(scope: scope);
    await Future.wait([_prefs.setLastScope(_account, scope), _loadFirstPage()]);
  }

  Future<void> setShowArchived(bool value) async {
    if (value == state.showArchived) return;
    state = _fresh(showArchived: value);
    await Future.wait([_prefs.setShowArchived(value), _loadFirstPage()]);
  }

  Future<void> setSortOrder(SortOrder value) async {
    if (value == state.sortOrder) return;
    state = _fresh(sortOrder: value);
    await Future.wait([_prefs.setSortOrder(value), _loadFirstPage()]);
  }

  /// A tag was deleted: take it off the cards already on screen.
  void forgetTag(String tagId) {
    if (!state.bookmarks.any((b) => b.tags.any((t) => t.id == tagId))) return;
    items = [
      for (final b in state.bookmarks)
        b.tags.any((t) => t.id == tagId)
            ? b.copyWith(tags: [...b.tags.where((t) => t.id != tagId)])
            : b,
    ];
  }

  /// Empty feed for a new query, keeping whatever isn't changed.
  HomeFeedState _fresh({
    BookmarkScope? scope,
    bool? showArchived,
    SortOrder? sortOrder,
  }) =>
      HomeFeedState(
        scope: scope ?? state.scope,
        showArchived: showArchived ?? state.showArchived,
        sortOrder: sortOrder ?? state.sortOrder,
      );

  /// Pull-to-refresh: keeps current items on screen until the new page lands.
  Future<void> refresh() => _loadFirstPage(keepItems: true);

  Future<void> retry() {
    state = state.copyWith(status: FeedStatus.loading, error: () => null);
    return _loadFirstPage();
  }

  /// A fresh page without items whose delete is still waiting out its Undo:
  /// the server has them until then.
  List<Bookmark> _visible(BookmarkPage page) {
    final actions = ref.read(bookmarkActionsProvider);
    return [
      for (final b in page.bookmarks)
        if (!actions.isBeingDeleted(b.id)) b,
    ];
  }

  Future<void> _loadFirstPage({bool keepItems = false}) async {
    final generation = ++_generation;
    final scope = state.scope;
    if (!keepItems) {
      state = state.copyWith(
        status: FeedStatus.loading,
        bookmarks: const [],
        nextCursor: () => null,
        error: () => null,
        loadMoreError: () => null,
      );
    }
    try {
      final page = await _repo.getBookmarks(
        scope,
        includeArchived: state.showArchived,
        order: state.sortOrder,
      );
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        status: FeedStatus.ready,
        bookmarks: _visible(page),
        nextCursor: () => page.nextCursor,
        error: () => null,
        loadMoreError: () => null,
        loadingMore: false,
      );
    } on NotFoundFailure {
      // The remembered list was deleted (maybe on another device).
      if (!ref.mounted || generation != _generation) return;
      if (scope is ListScope) {
        await selectScope(const AllScope());
      }
    } on Failure catch (f) {
      if (!ref.mounted || generation != _generation) return;
      if (keepItems && state.bookmarks.isNotEmpty) {
        state = state.copyWith(loadMoreError: () => f.message);
      } else {
        state = state.copyWith(status: FeedStatus.error, error: () => f.message);
      }
    }
  }

  @override
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore) return;
    if (state.status != FeedStatus.ready) return;

    final generation = _generation;
    state = state.copyWith(loadingMore: true, loadMoreError: () => null);
    try {
      final page = await _repo.getBookmarks(
        state.scope,
        includeArchived: state.showArchived,
        order: state.sortOrder,
        cursor: cursor,
      );
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        bookmarks: [...state.bookmarks, ..._visible(page)],
        nextCursor: () => page.nextCursor,
        loadingMore: false,
      );
    } on Failure catch (f) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        loadingMore: false,
        loadMoreError: () => f.message,
      );
    }
  }
}

final homeFeedViewModelProvider =
    NotifierProvider.autoDispose<HomeFeedViewModel, HomeFeedState>(
  HomeFeedViewModel.new,
);
