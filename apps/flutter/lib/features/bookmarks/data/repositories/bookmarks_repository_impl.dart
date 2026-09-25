import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_list.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../datasources/remote/bookmarks_remote_data_source.dart';
import '../mappers/bookmark_json.dart';

class BookmarksRepositoryImpl implements BookmarksRepository {
  BookmarksRepositoryImpl(this._remote);

  static const _pageSize = 30;

  /// Largest page the server allows; used when only counting.
  static const _countPageSize = 100;

  /// Stop counting past this many pages (10k items) rather than hammer the
  /// server; the count is then a lower bound.
  static const _maxCountPages = 100;

  final BookmarksRemoteDataSource _remote;

  @override
  Future<BookmarkPage> getBookmarks(
    BookmarkScope scope, {
    required bool includeArchived,
    String? cursor,
  }) =>
      _guard(() => _page(scope, includeArchived, cursor, _pageSize));

  Future<BookmarkPage> _page(
    BookmarkScope scope,
    bool includeArchived,
    String? cursor,
    int limit,
  ) async {
    final archived = includeArchived ? null : false;
    final result = switch (scope) {
      AllScope() => await _remote.getBookmarks(
          archived: archived,
          cursor: cursor,
          limit: limit,
        ),
      FavouritesScope() => await _remote.getBookmarks(
          favourited: true,
          archived: archived,
          cursor: cursor,
          limit: limit,
        ),
      ArchivedScope() => await _remote.getBookmarks(
          archived: true,
          cursor: cursor,
          limit: limit,
        ),
      ListScope(:final id) => await _remote.getFilteredBookmarks(
          listId: id,
          archived: archived,
          cursor: cursor,
          limit: limit,
        ),
      TagScope(:final id) => await _remote.getFilteredBookmarks(
          tagId: id,
          archived: archived,
          cursor: cursor,
          limit: limit,
        ),
    };
    return _toPage(result);
  }

  BookmarkPage _toPage(
    ({List<Object?> bookmarks, String? nextCursor}) result,
  ) {
    return BookmarkPage(
      bookmarks: [
        for (final b in result.bookmarks.cast<Map<String, Object?>>())
          BookmarkJson.bookmark(b),
      ],
      nextCursor: result.nextCursor,
    );
  }

  @override
  Future<BookmarkPage> search(String query, {String? cursor}) => _guard(
        () async => _toPage(
          await _remote.search(query: query, cursor: cursor, limit: _pageSize),
        ),
      );

  @override
  Future<List<TagSummary>> getTags() => _guard(() async {
        final tags = await _remote.getTags();
        return [
          for (final t in tags.cast<Map<String, Object?>>())
            TagSummary(
              id: t['id']! as String,
              name: t['name']! as String,
              count: (t['numBookmarks'] as num?)?.toInt() ?? 0,
            ),
        ];
      });

  @override
  Future<List<BookmarkList>> getLists() => _guard(() async {
        final lists = await _remote.getLists();
        return [
          for (final l in lists.cast<Map<String, Object?>>())
            BookmarkJson.list(l),
        ];
      });

  @override
  Future<Map<String, int>> getListTotals() => _guard(() async {
        final stats = await _remote.getListStats();
        return {
          for (final MapEntry(:key, :value) in stats.entries)
            if (value is num) key: value.toInt(),
        };
      });

  @override
  Future<LibraryTotals> getLibraryTotals() => _guard(() async {
        final stats = await _remote.getUserStats();
        int read(String key) => (stats[key] as num?)?.toInt() ?? 0;
        return LibraryTotals(
          bookmarks: read('numBookmarks'),
          favourites: read('numFavorites'),
          archived: read('numArchived'),
        );
      });

  @override
  Future<Bookmark> getBookmark(String id) =>
      _guard(() async => BookmarkJson.bookmark(await _remote.getBookmark(id)));

  @override
  Future<String?> getReaderHtml(String id) => _guard(() async {
        final json = await _remote.getBookmark(id, includeContent: true);
        final content = json['content'];
        final html = content is Map ? content['htmlContent'] as String? : null;
        return (html == null || html.trim().isEmpty) ? null : html;
      });

  @override
  Future<void> setFavourited(String id, bool value) =>
      _guard(() => _remote.patchBookmark(id, {'favourited': value}));

  @override
  Future<void> setArchived(String id, bool value) =>
      _guard(() => _remote.patchBookmark(id, {'archived': value}));

  @override
  Future<void> deleteBookmark(String id) =>
      _guard(() => _remote.deleteBookmark(id));

  @override
  Future<Set<String>> listIdsOf(String bookmarkId) => _guard(() async {
        final lists = await _remote.getBookmarkLists(bookmarkId);
        return {
          for (final l in lists.cast<Map<String, Object?>>()) l['id']! as String,
        };
      });

  @override
  Future<void> addToList(String listId, String bookmarkId) =>
      _guard(() => _remote.addToList(listId, bookmarkId));

  @override
  Future<void> removeFromList(String listId, String bookmarkId) =>
      _guard(() => _remote.removeFromList(listId, bookmarkId));

  @override
  Future<void> attachTag(String bookmarkId, String tagName) => _guard(
        () => _remote.attachTags(bookmarkId, [
          {'tagName': tagName.trim(), 'attachedBy': 'human'},
        ]),
      );

  @override
  Future<void> detachTag(String bookmarkId, String tagId) => _guard(
        () => _remote.detachTags(bookmarkId, [
          {'tagId': tagId},
        ]),
      );

  @override
  Future<String> openableAssetUrl(String assetId) =>
      _guard(() => _remote.signedAssetUrl(assetId));

  @override
  Future<int> countUnarchived(BookmarkScope scope) => _guard(() async {
        var count = 0;
        String? cursor;
        for (var page = 0; page < _maxCountPages; page++) {
          final result = await _page(scope, false, cursor, _countPageSize);
          count += result.bookmarks.length;
          cursor = result.nextCursor;
          if (cursor == null) break;
        }
        return count;
      });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Failure {
      rethrow;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on FormatException {
      throw const UnknownFailure('Unexpected response from the server.');
    } on TypeError {
      throw const UnknownFailure('Unexpected response from the server.');
    }
  }
}
