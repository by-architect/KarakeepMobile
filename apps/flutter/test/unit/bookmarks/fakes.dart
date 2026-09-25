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
