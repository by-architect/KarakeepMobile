import 'package:dio/dio.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/dio_factory.dart';
import '../../../../../core/network/trpc.dart';
import '../../../domain/entities/server_connection.dart';
import '../../dto/auth_dtos.dart';

/// Raw calls to the server. Throws [DioException] / [Failure]; the
/// repository turns transport errors into [Failure]s with context.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dioFactory);

  final DioFactory _dioFactory;

  Dio _dio(ServerConnection server, {String? apiKey}) => _dioFactory.create(
        baseUrl: server.baseUrl,
        headers: server.headers,
        apiKey: apiKey,
      );

  /// `GET /api/health` → `{"status":"ok"}`. A proxy login page or some other
  /// site answers with something else, which we reject.
  Future<void> checkHealth(ServerConnection server) async {
    final response = await _dio(server).get<Object?>('/api/health');
    final body = response.data;
    if (body is! Map || body['status'] != 'ok') {
      throw const NotKarakeepFailure();
    }
  }

  /// Optional extras: older servers or proxies may not serve these, and sign-in
  /// works without them, so failures come back as null.
  Future<String?> fetchVersion(ServerConnection server) async {
    try {
      final response = await _dio(server).get<Object?>('/api/version');
      final body = response.data;
      return body is Map ? body['version'] as String? : null;
    } on Object {
      return null;
    }
  }

  Future<ClientConfigDto?> fetchClientConfig(ServerConnection server) async {
    try {
      final json = await _dio(server).trpcQuery('config.clientConfig');
      return json is Map<String, Object?> ? ClientConfigDto.fromJson(json) : null;
    } on Object {
      return null;
    }
  }

  Future<ApiKeyDto> exchangeApiKey(
    ServerConnection server, {
    required String email,
    required String password,
    required String keyName,
  }) async {
    final json = await _dio(server).trpcMutation('apiKeys.exchange', {
      'email': email,
      'password': password,
      'keyName': keyName,
    });
    return ApiKeyDto.fromJson(json! as Map<String, Object?>);
  }

  /// `GET /api/v1/users/me` — doubles as the API key check.
  Future<UserDto> fetchCurrentUser(
    ServerConnection server, {
    required String apiKey,
  }) async {
    final response = await _dio(server, apiKey: apiKey)
        .get<Map<String, Object?>>('/api/v1/users/me');
    return UserDto.fromJson(response.data!);
  }
}
