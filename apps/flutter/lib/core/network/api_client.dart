import 'package:dio/dio.dart';

/// Everything a feature needs to talk to the signed-in server.
class ApiClient {
  const ApiClient({
    required this.dio,
    required this.baseUrl,
    required this.serverHeaders,
  });

  /// Carries the API key and custom headers on every request.
  final Dio dio;
  final String baseUrl;

  /// Auth + custom headers, for things that fetch outside [dio] (images).
  /// Only ever send these to [baseUrl] — never to third-party hosts.
  final Map<String, String> serverHeaders;

  /// Server-stored file (banner, screenshot, uploaded image).
  String assetUrl(String assetId) => '$baseUrl/api/assets/$assetId';
}
