import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/trpc.dart';

/// Raw bookmark calls. Returns decoded JSON; throws [DioException].
class BookmarksRemoteDataSource {
  const BookmarksRemoteDataSource(this._client);

  final ApiClient _client;

  Dio get _dio => _client.dio;

  /// REST `GET /api/v1/bookmarks`.
  Future<({List<Object?> bookmarks, String? nextCursor})> getBookmarks({
    bool? archived,
    bool? favourited,
    String? cursor,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/v1/bookmarks',
      queryParameters: {
        'archived': ?archived?.toString(),
        'favourited': ?favourited?.toString(),
        'cursor': ?cursor,
        'limit': limit,
        'includeContent': 'false',
      },
    );
    final body = response.data!;
    return (
      bookmarks: body['bookmarks']! as List<Object?>,
      nextCursor: body['nextCursor'] as String?,
    );
  }

  /// tRPC `bookmarks.getBookmarks` for one list or one tag. REST's list
  /// and tag endpoints can't filter by `archived`; this one can, smart lists
  /// included.
  ///
  /// The cursor is `{id, createdAt: Date}`; it travels as the JSON string
  /// of that object and is re-tagged as a Date for superjson.
  Future<({List<Object?> bookmarks, String? nextCursor})> getFilteredBookmarks({
    String? listId,
    String? tagId,
    bool? archived,
    String? cursor,
    required int limit,
  }) async {
    assert((listId == null) != (tagId == null), 'Exactly one filter');
    final json = await _dio.trpcQuery(
      'bookmarks.getBookmarks',
      input: {
        'listId': ?listId,
        'tagId': ?tagId,
        'archived': ?archived,
        'limit': limit,
        'useCursorV2': true,
        'includeContent': false,
        if (cursor != null) 'cursor': jsonDecode(cursor),
      },
      meta: cursor == null
          ? null
          : {
              'values': {
                'cursor.createdAt': ['Date'],
              },
            },
    );
    final body = json! as Map<String, Object?>;
    final next = body['nextCursor'];
    return (
      bookmarks: body['bookmarks']! as List<Object?>,
      nextCursor: next == null ? null : jsonEncode(next),
    );
  }

  /// REST `GET /api/v1/bookmarks/search`. The cursor is an offset.
  Future<({List<Object?> bookmarks, String? nextCursor})> search({
    required String query,
    String? cursor,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/v1/bookmarks/search',
      queryParameters: {
        'q': query,
        'limit': limit,
        'cursor': ?cursor,
        'includeContent': 'false',
      },
    );
    final body = response.data!;
    return (
      bookmarks: body['bookmarks']! as List<Object?>,
      nextCursor: body['nextCursor']?.toString(),
    );
  }

  /// REST `GET /api/v1/tags`, most used first. One page of up to 1000 (the
  /// server's max) is plenty for a picker.
  Future<List<Object?>> getTags() async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/v1/tags',
      queryParameters: {'sort': 'usage', 'limit': 1000},
    );
    return response.data!['tags']! as List<Object?>;
  }

  /// REST `GET /api/v1/bookmarks/{id}`. With [includeContent], link
  /// bookmarks carry `htmlContent` (the server inlines large stored content).
  Future<Map<String, Object?>> getBookmark(
    String id, {
    bool includeContent = false,
  }) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/v1/bookmarks/$id',
      queryParameters: {'includeContent': '$includeContent'},
    );
    return response.data!;
  }

  /// REST `PATCH /api/v1/bookmarks/{id}`.
  Future<void> patchBookmark(String id, Map<String, Object?> changes) =>
      _dio.patch<void>('/api/v1/bookmarks/$id', data: changes);

  Future<void> deleteBookmark(String id) =>
      _dio.delete<void>('/api/v1/bookmarks/$id');

  /// REST `GET /api/v1/bookmarks/{id}/lists`.
  Future<List<Object?>> getBookmarkLists(String id) async {
    final response =
        await _dio.get<Map<String, Object?>>('/api/v1/bookmarks/$id/lists');
    return response.data!['lists']! as List<Object?>;
  }

  Future<void> addToList(String listId, String bookmarkId) =>
      _dio.put<void>('/api/v1/lists/$listId/bookmarks/$bookmarkId');

  Future<void> removeFromList(String listId, String bookmarkId) =>
      _dio.delete<void>('/api/v1/lists/$listId/bookmarks/$bookmarkId');

  /// REST `POST|DELETE /api/v1/bookmarks/{id}/tags` with
  /// `{tags: [{tagName}|{tagId}]}`.
  Future<void> attachTags(String id, List<Map<String, Object?>> tags) =>
      _dio.post<void>('/api/v1/bookmarks/$id/tags', data: {'tags': tags});

  Future<void> detachTags(String id, List<Map<String, Object?>> tags) =>
      _dio.delete<void>('/api/v1/bookmarks/$id/tags', data: {'tags': tags});

  /// REST `GET /api/v1/assets/{id}/signed-url`. The server builds the URL
  /// from its configured public address, which on self-hosted setups is
  /// often `localhost`; keep only path and token and put them on the
  /// address we actually reach it at.
  Future<String> signedAssetUrl(String assetId) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/api/v1/assets/$assetId/signed-url',
    );
    final signed = Uri.parse(response.data!['signedUrl']! as String);
    final path = signed.path;
    final start = path.indexOf('/public/assets/');
    if (start < 0) return signed.toString();
    return '${_client.baseUrl}/api${path.substring(start)}?${signed.query}';
  }

  /// REST `POST /api/v1/lists` → the new list.
  Future<Map<String, Object?>> createList(Map<String, Object?> body) async {
    final response =
        await _dio.post<Map<String, Object?>>('/api/v1/lists', data: body);
    return response.data!;
  }

  /// REST `POST /api/v1/tags` → `{id, name}`.
  Future<Map<String, Object?>> createTag(String name) async {
    final response = await _dio
        .post<Map<String, Object?>>('/api/v1/tags', data: {'name': name});
    return response.data!;
  }

  /// REST `GET /api/v1/lists` — own and shared lists, not paginated.
  Future<List<Object?>> getLists() async {
    final response = await _dio.get<Map<String, Object?>>('/api/v1/lists');
    return response.data!['lists']! as List<Object?>;
  }

  /// tRPC `lists.stats` → `{listId: total}`. No REST equivalent.
  Future<Map<String, Object?>> getListStats() async {
    final json = await _dio.trpcQuery('lists.stats');
    return decodeSuperjsonMap((json! as Map<String, Object?>)['stats']);
  }

  /// REST `GET /api/v1/users/me/stats`.
  Future<Map<String, Object?>> getUserStats() async {
    final response =
        await _dio.get<Map<String, Object?>>('/api/v1/users/me/stats');
    return response.data!;
  }
}
