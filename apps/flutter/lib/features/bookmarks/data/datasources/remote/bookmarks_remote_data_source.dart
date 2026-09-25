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

  /// tRPC `bookmarks.getBookmarks` with a list. REST's list endpoint can't
  /// filter by `archived`; this one can, smart lists included.
  ///
  /// The cursor is `{id, createdAt: Date}`; it travels as the JSON string
  /// of that object and is re-tagged as a Date for superjson.
  Future<({List<Object?> bookmarks, String? nextCursor})> getListBookmarks({
    required String listId,
    bool? archived,
    String? cursor,
    required int limit,
  }) async {
    final json = await _dio.trpcQuery(
      'bookmarks.getBookmarks',
      input: {
        'listId': listId,
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
