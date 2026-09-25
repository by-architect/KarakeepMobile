import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/entities/server_info.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/session_local_data_source.dart';
import '../datasources/remote/auth_remote_data_source.dart';
import '../mappers/session_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._remote,
    required this._local,
    Random? random,
  }) : _random = random ?? Random.secure();

  final AuthRemoteDataSource _remote;
  final SessionLocalDataSource _local;
  final Random _random;

  @override
  Future<ServerInfo> probeServer(ServerConnection server) => _guard(() async {
        await _remote.checkHealth(server);
        // Neither of these throws; they return null when unavailable.
        final (version, config) = await (
          _remote.fetchVersion(server),
          _remote.fetchClientConfig(server),
        ).wait;
        return ServerInfo(
          version: config?.serverVersion ?? version,
          passwordAuthDisabled: config?.disablePasswordAuth ?? false,
          signupsDisabled: config?.disableSignups ?? false,
          demoMode: config?.demoMode ?? false,
        );
      });

  @override
  Future<Session> signInWithPassword({
    required ServerConnection server,
    required String email,
    required String password,
  }) =>
      _guard(
        unauthorizedMessage: 'Wrong email or password.',
        () async {
          final key = await _remote.exchangeApiKey(
            server,
            email: email.trim(),
            password: password,
            keyName: '${AppConfig.apiKeyNamePrefix} (${_suffix()})',
          );
          return _completeSignIn(server, apiKey: key.key, apiKeyId: key.id);
        },
      );

  @override
  Future<Session> signInWithApiKey({
    required ServerConnection server,
    required String apiKey,
  }) =>
      _guard(
        unauthorizedMessage: 'This API key isn’t valid on this server.',
        () => _completeSignIn(server, apiKey: apiKey.trim()),
      );

  Future<Session> _completeSignIn(
    ServerConnection server, {
    required String apiKey,
    String? apiKeyId,
  }) async {
    final versionFuture = _remote.fetchVersion(server);
    final user = await _remote.fetchCurrentUser(server, apiKey: apiKey);
    final version = await versionFuture;
    final session = Session(
      server: server,
      apiKey: apiKey,
      apiKeyId: apiKeyId,
      user: user.toEntity(),
      serverVersion: version,
    );
    await _local.write(session);
    return session;
  }

  @override
  Future<Session?> restoreSession() => _local.read();

  @override
  Future<void> signOut() => _local.clear();

  /// Short random tag so several devices' keys are told apart on the web.
  String _suffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(5, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  Future<T> _guard<T>(
    Future<T> Function() body, {
    String? unauthorizedMessage,
  }) async {
    try {
      return await body();
    } on Failure {
      rethrow;
    } on DioException catch (e) {
      throw mapDioException(e, unauthorizedMessage: unauthorizedMessage);
    } on FormatException {
      throw const NotKarakeepFailure();
    } on TypeError {
      // A 200 whose body isn't the shape Karakeep sends.
      throw const NotKarakeepFailure();
    }
  }
}
