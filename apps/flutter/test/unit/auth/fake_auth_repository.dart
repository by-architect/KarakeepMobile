import 'dart:async';

import 'package:karakeep_client/core/error/failure.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_connection.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_info.dart';
import 'package:karakeep_client/features/auth/domain/entities/session.dart';
import 'package:karakeep_client/features/auth/domain/repositories/auth_repository.dart';

/// Scriptable [AuthRepository] for view model and widget tests.
class FakeAuthRepository implements AuthRepository {
  ServerInfo serverInfo = const ServerInfo(version: '0.33.0');
  Failure? probeFailure;
  Failure? signInFailure;

  /// When set, probes wait on it — for testing in-flight states.
  Completer<void>? probeGate;

  final probed = <ServerConnection>[];
  final passwordSignIns = <({String email, String password})>[];
  final apiKeySignIns = <String>[];
  Session? stored;

  @override
  Future<ServerInfo> probeServer(ServerConnection server) async {
    probed.add(server);
    await probeGate?.future;
    if (probeFailure != null) throw probeFailure!;
    return serverInfo;
  }

  @override
  Future<Session> signInWithPassword({
    required ServerConnection server,
    required String email,
    required String password,
  }) async {
    passwordSignIns.add((email: email, password: password));
    if (signInFailure != null) throw signInFailure!;
    return stored = _session(server);
  }

  @override
  Future<Session> signInWithApiKey({
    required ServerConnection server,
    required String apiKey,
  }) async {
    apiKeySignIns.add(apiKey);
    if (signInFailure != null) throw signInFailure!;
    return stored = _session(server);
  }

  @override
  Future<Session?> restoreSession() async => stored;

  @override
  Future<void> signOut() async => stored = null;

  Session _session(ServerConnection server) => Session(
        server: server,
        apiKey: 'ak2_test',
        user: const AuthUser(id: 'u1', name: 'Ada'),
      );
}
