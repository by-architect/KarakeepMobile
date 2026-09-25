import 'server_connection.dart';

class AuthUser {
  const AuthUser({required this.id, this.name, this.email});

  final String id;
  final String? name;
  final String? email;

  String get displayName => name ?? email ?? 'Karakeep user';
}

/// A signed-in account: one server plus the API key that talks to it.
class Session {
  const Session({
    required this.server,
    required this.apiKey,
    required this.user,
    this.apiKeyId,
    this.serverVersion,
  });

  final ServerConnection server;
  final String apiKey;

  /// Set when we created the key ourselves (password sign-in), so the user
  /// can find it on the web. Null for pasted keys.
  final String? apiKeyId;
  final AuthUser user;
  final String? serverVersion;
}
