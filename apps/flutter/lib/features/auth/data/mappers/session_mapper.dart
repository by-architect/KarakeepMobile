import '../../domain/entities/server_connection.dart';
import '../../domain/entities/session.dart';
import '../dto/auth_dtos.dart';

extension UserDtoMapper on UserDto {
  AuthUser toEntity() => AuthUser(id: id, name: name, email: email);
}

/// Storage format for a [Session]. Versioned so it can migrate later.
abstract final class SessionJson {
  static const version = 1;

  static Map<String, Object?> encode(Session s) => {
        'v': version,
        'baseUrl': s.server.baseUrl,
        'headers': s.server.headers,
        'apiKey': s.apiKey,
        'apiKeyId': s.apiKeyId,
        'serverVersion': s.serverVersion,
        'user': {'id': s.user.id, 'name': s.user.name, 'email': s.user.email},
      };

  /// Returns null for anything unreadable, so a corrupt entry signs the user
  /// out instead of crashing the app.
  static Session? decode(Object? json) {
    if (json case {
      'v': version,
      'baseUrl': final String baseUrl,
      'apiKey': final String apiKey,
      'user': {'id': final String userId},
    }) {
      final map = json as Map<String, Object?>;
      final user = map['user']! as Map<String, Object?>;
      final headers = map['headers'];
      return Session(
        server: ServerConnection(
          baseUrl: baseUrl,
          headers: headers is Map
              ? headers.map((k, v) => MapEntry('$k', '$v'))
              : const {},
        ),
        apiKey: apiKey,
        apiKeyId: map['apiKeyId'] as String?,
        serverVersion: map['serverVersion'] as String?,
        user: AuthUser(
          id: userId,
          name: user['name'] as String?,
          email: user['email'] as String?,
        ),
      );
    }
    return null;
  }
}
