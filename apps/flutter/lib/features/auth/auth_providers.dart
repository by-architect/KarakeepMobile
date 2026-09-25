import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/network/api_client.dart';
import 'data/datasources/local/session_local_data_source.dart';
import 'data/datasources/remote/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/entities/session.dart';
import 'domain/repositories/auth_repository.dart';
import 'presentation/viewmodels/session_controller.dart';

/// Composition root for the auth feature. Presentation depends on the
/// [AuthRepository] interface only; tests override this provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSource(ref.watch(dioFactoryProvider)),
    local: SessionLocalDataSource(ref.watch(secureStorageProvider)),
  );
});

/// The signed-in session. Only read from screens behind the login guard.
///
/// On sign-out those screens still rebuild once before the router removes
/// them; they keep seeing the last session for that frame instead of
/// crashing.
class CurrentSession extends Notifier<Session> {
  Session? _last;

  @override
  Session build() {
    final session = ref.watch(sessionControllerProvider).value ?? _last;
    if (session == null) throw StateError('No signed-in session');
    return _last = session;
  }
}

final currentSessionProvider =
    NotifierProvider<CurrentSession, Session>(CurrentSession.new);

/// Client for the signed-in server; rebuilt when the session changes.
final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(currentSessionProvider);
  final server = session.server;
  return ApiClient(
    dio: ref.watch(dioFactoryProvider).create(
          baseUrl: server.baseUrl,
          headers: server.headers,
          apiKey: session.apiKey,
        ),
    baseUrl: server.baseUrl,
    serverHeaders: {
      ...server.headers,
      'Authorization': 'Bearer ${session.apiKey}',
    },
  );
});
