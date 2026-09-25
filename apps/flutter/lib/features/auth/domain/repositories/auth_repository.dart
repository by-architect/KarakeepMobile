import '../entities/server_connection.dart';
import '../entities/server_info.dart';
import '../entities/session.dart';

/// Every method throws a `Failure` (core/error) on error.
abstract interface class AuthRepository {
  /// Confirms [server] is a reachable Karakeep instance and reads what it
  /// allows (e.g. whether password sign-in is on).
  Future<ServerInfo> probeServer(ServerConnection server);

  /// Exchanges email + password for a new API key, then persists the session.
  Future<Session> signInWithPassword({
    required ServerConnection server,
    required String email,
    required String password,
  });

  /// Validates a key made on the web (the only path for SSO users) and
  /// persists the session.
  Future<Session> signInWithApiKey({
    required ServerConnection server,
    required String apiKey,
  });

  Future<Session?> restoreSession();

  /// Forgets the session on this device. The key itself can only be revoked
  /// from the web UI — Karakeep rejects revocation made with an API key.
  Future<void> signOut();
}
