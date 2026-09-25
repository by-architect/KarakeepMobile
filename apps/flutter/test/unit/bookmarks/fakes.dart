import 'package:karakeep_client/core/error/failure.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_list.dart';
import 'package:karakeep_client/features/bookmarks/domain/entities/bookmark_scope.dart';
import 'package:karakeep_client/features/bookmarks/domain/repositories/bookmarks_repository.dart';
import 'package:karakeep_client/features/bookmarks/domain/repositories/home_preferences_repository.dart';

Bookmark link(
  String id, {
  bool archived = false,
  bool favourited = false,
  String? title,
}) =>
    Bookmark(
      id: id,
      createdAt: DateTime.utc(2026, 9, 1),
      archived: archived,
      favourited: favourited,
      content: LinkContent(
        url: 'https://example.com/$id',
        title: title ?? 'Article $id',
        description: 'About $id',
      ),
    );

/// In-memory library: [items] per scope key; pages of [pageSize].
class FakeBookmarksRepository implements BookmarksRepository {
  FakeBookmarksRepository({
    Map<String, List<Bookmark>>? items,
    this.lists = const [],
    this.pageSize = 2,
  }) : items = items ?? {};

  final Map<String, List<Bookmark>> items;
  List<BookmarkList> lists;
  List<TagSummary> tags = const [];

  /// Results for [search], keyed by the exact query string.
  final searchResults = <String, List<Bookmark>>{};
  final searchQueries = <String>[];
  final int pageSize;
  Failure? failure;

  /// Scope keys whose load fails with [NotFoundFailure] (deleted list).
  final missing = <String>{};

  final calls = <({String scope, bool includeArchived, String? cursor})>[];
  final countCalls = <String>[];

  List<Bookmark> _visible(BookmarkScope scope, bool includeArchived) {
    final all = items[scope.key] ?? const [];
    if (scope is ArchivedScope || includeArchived) return all;
    return all.where((b) => !b.archived).toList();
  }

  @override
  Future<BookmarkPage> getBookmarks(
    BookmarkScope scope, {
    required bool includeArchived,
    String? cursor,
  }) async {
    calls.add((
      scope: scope.key,
      includeArchived: includeArchived,
      cursor: cursor,
    ));
    if (failure != null) throw failure!;
    if (missing.contains(scope.key)) throw const NotFoundFailure();
    final visible = _visible(scope, includeArchived);
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, visible.length);
    return BookmarkPage(
      bookmarks: visible.sublist(start, end),
      nextCursor: end < visible.length ? '$end' : null,
    );
  }

  @override
  Future<BookmarkPage> search(String query, {String? cursor}) async {
    searchQueries.add(query);
    if (failure != null) throw failure!;
    return BookmarkPage(bookmarks: searchResults[query] ?? const []);
  }

  @override
  Future<List<TagSummary>> getTags() async => tags;

  @override
  Future<List<BookmarkList>> getLists() async {
    if (failure != null) throw failure!;
    return lists;
  }

  @override
  Future<Map<String, int>> getListTotals() async => {
        for (final l in lists)
          l.id: (items[ListScope.prefix + l.id] ?? const []).length,
      };

  @override
  Future<LibraryTotals> getLibraryTotals() async {
    final all = items[AllScope.keyValue] ?? const [];
    return LibraryTotals(
      bookmarks: all.length,
      favourites: all.where((b) => b.favourited).length,
      archived: all.where((b) => b.archived).length,
    );
  }

  // ── Mutations: applied to every scope's items, like the server would. ──

  /// Ids whose mutations fail, to test rollbacks.
  final failing = <String>{};
  final deleted = <String>[];
  final listMembership = <String, Set<String>>{};

  void _check(String id) {
    if (failing.contains(id)) throw const NetworkFailure();
  }

  void _updateEverywhere(String id, Bookmark Function(Bookmark) change) {
    for (final entry in items.entries) {
      items[entry.key] = [
        for (final b in entry.value) b.id == id ? change(b) : b,
      ];
    }
  }

  Bookmark _find(String id) =>
      items.values.expand((l) => l).firstWhere((b) => b.id == id);

  @override
  Future<Bookmark> getBookmark(String id) async => _find(id);

  @override
  Future<String?> getReaderHtml(String id) async => '<p>Reader $id</p>';

  @override
  Future<void> setFavourited(String id, bool value) async {
    _check(id);
    _updateEverywhere(id, (b) => b.copyWith(favourited: value));
  }

  @override
  Future<void> setArchived(String id, bool value) async {
    _check(id);
    _updateEverywhere(id, (b) => b.copyWith(archived: value));
  }

  @override
  Future<void> deleteBookmark(String id) async {
    _check(id);
    deleted.add(id);
    for (final entry in items.entries) {
      items[entry.key] = entry.value.where((b) => b.id != id).toList();
    }
  }

  @override
  Future<Set<String>> listIdsOf(String bookmarkId) async =>
      {...?listMembership[bookmarkId]};

  @override
  Future<void> addToList(String listId, String bookmarkId) async {
    _check(bookmarkId);
    listMembership.putIfAbsent(bookmarkId, () => {}).add(listId);
  }

  @override
  Future<void> removeFromList(String listId, String bookmarkId) async {
    _check(bookmarkId);
    listMembership[bookmarkId]?.remove(listId);
  }

  @override
  Future<void> attachTag(String bookmarkId, String tagName) async {
    _check(bookmarkId);
    _updateEverywhere(
      bookmarkId,
      (b) => b.copyWith(
        tags: [...b.tags, BookmarkTag(id: 'tag-$tagName', name: tagName)],
      ),
    );
  }

  @override
  Future<void> detachTag(String bookmarkId, String tagId) async {
    _check(bookmarkId);
    _updateEverywhere(
      bookmarkId,
      (b) => b.copyWith(tags: b.tags.where((t) => t.id != tagId).toList()),
    );
  }

  @override
  Future<String> openableAssetUrl(String assetId) async =>
      'https://keep.example.com/api/public/assets/$assetId?token=t';

  @override
  Future<int> countUnarchived(BookmarkScope scope) async {
    countCalls.add(scope.key);
    return _visible(scope, false).length;
  }
}

class InMemoryHomePreferences implements HomePreferencesRepository {
  InMemoryHomePreferences({this.showArchived = false});

  @override
  bool showArchived;
  final scopes = <String, BookmarkScope>{};
  final counts = <String, Map<String, ItemCount>>{};

  @override
  Future<void> setShowArchived(bool value) async => showArchived = value;

  @override
  BookmarkScope? lastScope(String accountKey) => scopes[accountKey];

  @override
  Future<void> setLastScope(String accountKey, BookmarkScope scope) async =>
      scopes[accountKey] = scope;

  @override
  Map<String, ItemCount> cachedCounts(String accountKey) =>
      counts[accountKey] ?? const {};

  @override
  Future<void> setCachedCounts(
    String accountKey,
    Map<String, ItemCount> value,
  ) async =>
      counts[accountKey] = value;
}
