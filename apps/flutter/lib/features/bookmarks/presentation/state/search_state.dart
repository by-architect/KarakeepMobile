import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_scope.dart';

enum SearchStatus { idle, loading, ready, error }

class SearchState {
  const SearchState({
    this.text = '',
    this.within,
    this.includeArchived = false,
    this.status = SearchStatus.idle,
    this.results = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.error,
  });

  final String text;

  /// Search only inside this scope (the one open on home), or everywhere.
  final BookmarkScope? within;
  final bool includeArchived;

  final SearchStatus status;
  final List<Bookmark> results;
  final String? nextCursor;
  final bool loadingMore;
  final String? error;

  bool get hasMore => nextCursor != null;

  /// Searching the archive always includes archived items.
  bool get archivedToggleApplies => within is! ArchivedScope;

  SearchState copyWith({
    String? text,
    BookmarkScope? Function()? within,
    bool? includeArchived,
    SearchStatus? status,
    List<Bookmark>? results,
    String? Function()? nextCursor,
    bool? loadingMore,
    String? Function()? error,
  }) {
    return SearchState(
      text: text ?? this.text,
      within: within != null ? within() : this.within,
      includeArchived: includeArchived ?? this.includeArchived,
      status: status ?? this.status,
      results: results ?? this.results,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error != null ? error() : this.error,
    );
  }
}
