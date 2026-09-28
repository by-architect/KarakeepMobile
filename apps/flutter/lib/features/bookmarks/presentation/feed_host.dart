import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/bookmark.dart';
import 'viewmodels/home_feed_view_model.dart';
import 'viewmodels/search_view_model.dart';

/// A screen's list of bookmarks that other parts of the app (the viewer,
/// swipe actions, sheets) can change. Home and search both are one; this
/// keeps each list the single source of truth for what it shows.
mixin BookmarkFeedHost {
  List<Bookmark> get items;
  set items(List<Bookmark> value);

  /// False once the screen owning this feed is gone.
  bool get isActive;

  bool get canLoadMore;
  Future<void> loadMore();

  /// Whether [bookmark] still belongs here after a change.
  bool keeps(Bookmark bookmark);

  /// Called after [bookmarkId] left list [listId]; feeds showing that list
  /// drop it.
  void removedFromList(String listId, String bookmarkId) {}

  int indexOf(String id) => items.indexWhere((b) => b.id == id);

  /// Replace the item, or drop it if it no longer belongs here.
  void applyChange(Bookmark bookmark) {
    if (!isActive) return; // e.g. Undo tapped after leaving the screen
    final index = indexOf(bookmark.id);
    if (index < 0) return;
    if (!keeps(bookmark)) return remove(bookmark.id);
    items = [...items]..[index] = bookmark;
  }

  void remove(String id) {
    if (!isActive) return;
    items = items.where((b) => b.id != id).toList();
  }

  /// Undo: put [bookmark] back at [index] (or update it if still present).
  void restore(Bookmark bookmark, int index) {
    if (!isActive) return;
    final current = indexOf(bookmark.id);
    if (current >= 0) {
      items = [...items]..[current] = bookmark;
      return;
    }
    final at = index.clamp(0, items.length);
    items = [...items]..insert(at, bookmark);
  }
}

/// Which screen's feed the viewer pages through.
enum FeedSource { home, search }

BookmarkFeedHost feedHost(WidgetRef ref, FeedSource source) => switch (source) {
      FeedSource.home => ref.read(homeFeedViewModelProvider.notifier),
      FeedSource.search => ref.read(searchViewModelProvider.notifier),
    };

/// What the viewer pages through: the items so far, and whether more are on
/// the server ([error] is why the last attempt to get them failed).
typedef FeedView = ({
  List<Bookmark> items,
  bool hasMore,
  bool loadingMore,
  String? error,
});

FeedView watchFeed(WidgetRef ref, FeedSource source) => switch (source) {
      FeedSource.home => ref.watch(
          homeFeedViewModelProvider.select(
            (s) => (
              items: s.bookmarks,
              hasMore: s.hasMore,
              loadingMore: s.loadingMore,
              error: s.loadMoreError,
            ),
          ),
        ),
      // Search stops paging when a page fails, so it has no error to show.
      FeedSource.search => ref.watch(
          searchViewModelProvider.select(
            (s) => (
              items: s.results,
              hasMore: s.hasMore,
              loadingMore: s.loadingMore,
              error: null,
            ),
          ),
        ),
    };
