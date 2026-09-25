import '../entities/bookmark.dart';
import '../entities/bookmark_list.dart';
import '../entities/bookmark_scope.dart';

class BookmarkPage {
  const BookmarkPage({required this.bookmarks, this.nextCursor});

  final List<Bookmark> bookmarks;

  /// Opaque; null on the last page.
  final String? nextCursor;
}

/// Account-wide totals.
class LibraryTotals {
  const LibraryTotals({
    required this.bookmarks,
    required this.favourites,
    required this.archived,
  });

  final int bookmarks;
  final int favourites;
  final int archived;
}

/// Every method throws a `Failure` (core/error) on error.
abstract interface class BookmarksRepository {
  /// One page of [scope], newest first. With [includeArchived] false,
  /// archived items are left out (ignored for [ArchivedScope]).
  Future<BookmarkPage> getBookmarks(
    BookmarkScope scope, {
    required bool includeArchived,
    String? cursor,
  });

  Future<List<BookmarkList>> getLists();

  /// Total items per list id (archived included).
  Future<Map<String, int>> getListTotals();

  Future<LibraryTotals> getLibraryTotals();

  /// Unarchived items in [scope]. Karakeep has no endpoint for this, so it
  /// pages through the items — cost grows with the scope's size.
  Future<int> countUnarchived(BookmarkScope scope);
}
