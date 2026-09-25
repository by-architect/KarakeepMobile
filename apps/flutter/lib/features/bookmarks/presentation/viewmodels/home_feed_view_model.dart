import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../bookmarks_providers.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../../domain/feed_rules.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../../domain/repositories/home_preferences_repository.dart';
import '../feed_host.dart';
import '../state/home_feed_state.dart';

/// The bookmark feed on the home screen: which scope, whether archived items
/// show, and paging. Scope and filter are remembered on the device.
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

  // ── Scope & filter ────────────────────────────────────────────────────

  Future<void> selectScope(BookmarkScope scope) async {
    if (scope == state.scope) return;
    state = HomeFeedState(scope: scope, showArchived: state.showArchived);
    await Future.wait([_prefs.setLastScope(_account, scope), _loadFirstPage()]);
  }

  Future<void> setShowArchived(bool value) async {
    if (value == state.showArchived) return;
    state = HomeFeedState(scope: state.scope, showArchived: value);
    await Future.wait([_prefs.setShowArchived(value), _loadFirstPage()]);
  }

  /// Pull-to-refresh: keeps current items on screen until the new page lands.
  Future<void> refresh() => _loadFirstPage(keepItems: true);

  Future<void> retry() {
    state = state.copyWith(status: FeedStatus.loading, error: () => null);
    return _loadFirstPage();
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
      );
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        status: FeedStatus.ready,
        bookmarks: page.bookmarks,
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
        cursor: cursor,
      );
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        bookmarks: [...state.bookmarks, ...page.bookmarks],
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
