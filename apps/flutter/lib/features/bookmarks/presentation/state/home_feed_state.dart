import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_scope.dart';

enum FeedStatus { loading, ready, error }

class HomeFeedState {
  const HomeFeedState({
    required this.scope,
    required this.showArchived,
    this.status = FeedStatus.loading,
    this.bookmarks = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final BookmarkScope scope;
  final bool showArchived;
  final FeedStatus status;
  final List<Bookmark> bookmarks;
  final String? nextCursor;
  final bool loadingMore;

  /// First page failed.
  final String? error;

  /// A later page failed; the items already shown stay.
  final String? loadMoreError;

  bool get hasMore => nextCursor != null;

  /// "Show archived" means nothing when looking at the archive itself.
  bool get archivedFilterApplies => scope is! ArchivedScope;

  HomeFeedState copyWith({
    BookmarkScope? scope,
    bool? showArchived,
    FeedStatus? status,
    List<Bookmark>? bookmarks,
    String? Function()? nextCursor,
    bool? loadingMore,
    String? Function()? error,
    String? Function()? loadMoreError,
  }) {
    return HomeFeedState(
      scope: scope ?? this.scope,
      showArchived: showArchived ?? this.showArchived,
      status: status ?? this.status,
      bookmarks: bookmarks ?? this.bookmarks,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error != null ? error() : this.error,
      loadMoreError:
          loadMoreError != null ? loadMoreError() : this.loadMoreError,
    );
  }
}
