import 'dart:convert';

import 'package:dio/dio.dart';

/// Minimal client for Karakeep's tRPC endpoint (`/api/trpc`, superjson).
///
/// Only for what REST `/api/v1` doesn't offer — see
/// docs/research/karakeep-server.md §2. Non-batched calls only.
extension TrpcDio on Dio {
  /// [input] is superjson's `json` part; [meta] its `meta` part, needed when
  /// the input holds types plain JSON can't express (e.g. `Date`).
  Future<Object?> trpcQuery(
    String procedure, {
    Map<String, Object?>? input,
    Map<String, Object?>? meta,
  }) async {
    final response = await get<Object?>(
      '/api/trpc/$procedure',
      queryParameters: input == null
          ? null
          : {
              'input': jsonEncode({'json': input, 'meta': ?meta}),
            },
    );
    return _unwrap(response.data);
  }

  Future<Object?> trpcMutation(
    String procedure,
    Map<String, Object?> input,
  ) async {
    final response = await post<Object?>(
      '/api/trpc/$procedure',
      data: {'json': input},
    );
    return _unwrap(response.data);
  }
}

/// `{"result": {"data": {"json": <value>}}}` → `<value>`.
Object? _unwrap(Object? body) {
  if (body case {'result': {'data': {'json': final value}}}) return value;
  throw const FormatException('Unexpected tRPC response');
}

/// The error half of the envelope, pulled out of a failed [Response].
///
/// `{"error": {"json": {"message": ..., "data": {"code": "UNAUTHORIZED"}}}}`
({String? code, String? message}) parseTrpcError(Object? body) {
  if (body case {'error': {'json': final Map<Object?, Object?> json}}) {
    final data = json['data'];
    return (
      code: data is Map ? data['code'] as String? : null,
      message: json['message'] as String?,
    );
  }
  return (code: null, message: null);
}

/// superjson sends a `Map` as a list of `[key, value]` pairs.
Map<String, Object?> decodeSuperjsonMap(Object? json) => switch (json) {
      final List<Object?> pairs => {
          for (final pair in pairs)
            if (pair case [final String key, final value]) key: value,
        },
      final Map<Object?, Object?> map => map.map((k, v) => MapEntry('$k', v)),
      _ => const {},
    };
