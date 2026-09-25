import '../../domain/entities/server_info.dart';

enum AuthMethod { password, apiKey }

enum ServerStatus { unchecked, checking, reachable, failed }

class HeaderEntry {
  const HeaderEntry({required this.id, this.name = '', this.value = ''});

  /// Stable across edits so rows keep their text fields.
  final int id;
  final String name;
  final String value;

  bool get isBlank => name.trim().isEmpty && value.trim().isEmpty;

  HeaderEntry copyWith({String? name, String? value}) =>
      HeaderEntry(id: id, name: name ?? this.name, value: value ?? this.value);
}

/// Everything the login screen renders. One immutable object per frame.
class LoginState {
  const LoginState({
    this.serverUrl = '',
    this.serverStatus = ServerStatus.unchecked,
    this.serverInfo,
    this.serverError,
    this.method = AuthMethod.password,
    this.email = '',
    this.password = '',
    this.apiKey = '',
    this.headers = const [],
    this.showAdvanced = false,
    this.submitting = false,
    this.formError,
  });

  final String serverUrl;
  final ServerStatus serverStatus;
  final ServerInfo? serverInfo;
  final String? serverError;

  final AuthMethod method;
  final String email;
  final String password;
  final String apiKey;

  final List<HeaderEntry> headers;
  final bool showAdvanced;

  final bool submitting;
  final String? formError;

  bool get passwordAuthAvailable =>
      !(serverInfo?.passwordAuthDisabled ?? false);

  int get headerCount => headers.where((h) => h.name.trim().isNotEmpty).length;

  bool get canSubmit {
    if (submitting || serverUrl.trim().isEmpty) return false;
    return switch (method) {
      AuthMethod.password => email.trim().isNotEmpty && password.isNotEmpty,
      AuthMethod.apiKey => apiKey.trim().isNotEmpty,
    };
  }

  LoginState copyWith({
    String? serverUrl,
    ServerStatus? serverStatus,
    ServerInfo? Function()? serverInfo,
    String? Function()? serverError,
    AuthMethod? method,
    String? email,
    String? password,
    String? apiKey,
    List<HeaderEntry>? headers,
    bool? showAdvanced,
    bool? submitting,
    String? Function()? formError,
  }) {
    return LoginState(
      serverUrl: serverUrl ?? this.serverUrl,
      serverStatus: serverStatus ?? this.serverStatus,
      serverInfo: serverInfo != null ? serverInfo() : this.serverInfo,
      serverError: serverError != null ? serverError() : this.serverError,
      method: method ?? this.method,
      email: email ?? this.email,
      password: password ?? this.password,
      apiKey: apiKey ?? this.apiKey,
      headers: headers ?? this.headers,
      showAdvanced: showAdvanced ?? this.showAdvanced,
      submitting: submitting ?? this.submitting,
      formError: formError != null ? formError() : this.formError,
    );
  }
}
