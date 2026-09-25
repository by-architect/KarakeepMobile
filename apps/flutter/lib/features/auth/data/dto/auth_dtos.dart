// Wire shapes. Field names follow the server; only what we use is parsed.

/// tRPC `config.clientConfig` (packages/shared/types/config.ts).
class ClientConfigDto {
  const ClientConfigDto({
    this.serverVersion,
    this.disablePasswordAuth = false,
    this.disableSignups = false,
    this.demoMode = false,
  });

  factory ClientConfigDto.fromJson(Map<String, Object?> json) {
    final auth = json['auth'];
    return ClientConfigDto(
      serverVersion: json['serverVersion'] as String?,
      disablePasswordAuth:
          auth is Map && auth['disablePasswordAuth'] == true,
      disableSignups: auth is Map && auth['disableSignups'] == true,
      demoMode: json['demoMode'] == true,
    );
  }

  final String? serverVersion;
  final bool disablePasswordAuth;
  final bool disableSignups;
  final bool demoMode;
}

/// tRPC `apiKeys.exchange` output.
class ApiKeyDto {
  const ApiKeyDto({required this.id, required this.key});

  factory ApiKeyDto.fromJson(Map<String, Object?> json) => ApiKeyDto(
        id: json['id']! as String,
        key: json['key']! as String,
      );

  final String id;
  final String key;
}

/// REST `GET /api/v1/users/me`.
class UserDto {
  const UserDto({required this.id, this.name, this.email});

  factory UserDto.fromJson(Map<String, Object?> json) => UserDto(
        id: json['id']! as String,
        name: json['name'] as String?,
        email: json['email'] as String?,
      );

  final String id;
  final String? name;
  final String? email;
}
