import 'package:dio/dio.dart';

/// Minimal client for Karakeep's tRPC endpoint (`/api/trpc`, superjson).
///
/// Only for what REST `/api/v1` doesn't offer — see
/// docs/research/karakeep-server.md §2. Non-batched calls only.
extension TrpcDio on Dio {
  Future<Object?> trpcQuery(String procedure) async {
    final response = await get<Object?>('/api/trpc/$procedure');
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
