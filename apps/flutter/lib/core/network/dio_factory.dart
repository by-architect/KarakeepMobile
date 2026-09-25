import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Builds a [Dio] bound to one Karakeep server.
///
/// User-supplied [headers] (reverse proxies, Cloudflare Access, …) go on every
/// request. They can't override `Authorization`, which always carries the key.
class DioFactory {
  const DioFactory({this.adapter});

  /// Swapped in tests to fake the server.
  final HttpClientAdapter? adapter;

  Dio create({
    required String baseUrl,
    Map<String, String> headers = const {},
    String? apiKey,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          ...headers,
          'Accept': 'application/json',
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter!;
    return dio;
  }
}
