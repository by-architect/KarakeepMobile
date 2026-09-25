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

  /// Karakeep query-language search (docs/research §6), best match first.
  Future<BookmarkPage> search(String query, {String? cursor});

  Future<List<BookmarkList>> getLists();

  /// Tags by usage, most used first.
  Future<List<TagSummary>> getTags();

  /// A smart list needs a [query] (search syntax); a manual one ignores it.
  Future<BookmarkList> createList({
    required String name,
    required String icon,
    required ListKind kind,
    String? query,
    String? parentId,
  });

  Future<TagSummary> createTag(String name);

  /// Total items per list id (archived included).
  Future<Map<String, int>> getListTotals();

  Future<LibraryTotals> getLibraryTotals();

  /// Fresh copy with tags, e.g. after tags changed.
  Future<Bookmark> getBookmark(String id);

  /// Karakeep's cleaned-up article HTML for reader view, or null when the
  /// page wasn't crawled or had no readable content.
  Future<String?> getReaderHtml(String id);

  Future<void> setFavourited(String id, bool value);
  Future<void> setArchived(String id, bool value);
  Future<void> deleteBookmark(String id);

  /// Ids of the lists [bookmarkId] is in.
  Future<Set<String>> listIdsOf(String bookmarkId);
  Future<void> addToList(String listId, String bookmarkId);
  Future<void> removeFromList(String listId, String bookmarkId);

  /// Attaches a tag by name, creating it if needed.
  Future<void> attachTag(String bookmarkId, String tagName);
  Future<void> detachTag(String bookmarkId, String tagId);

  /// A short-lived URL for a server file that needs no headers, so a browser
  /// or PDF app can open it.
  Future<String> openableAssetUrl(String assetId);

  /// Unarchived items in [scope]. Karakeep has no endpoint for this, so it
  /// pages through the items — cost grows with the scope's size.
  Future<int> countUnarchived(BookmarkScope scope);
}
