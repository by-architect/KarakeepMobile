import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../auth_providers.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/entities/server_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/server_url.dart';
import '../state/login_state.dart';
import 'session_controller.dart';

/// Drives the login screen: server check, credentials, sign-in.
///
/// Navigation after success is not an effect here — publishing the session
/// to [SessionController] makes the router redirect.
class LoginViewModel extends Notifier<LoginState> {
  var _nextHeaderId = 0;

  /// Bumped on every edit that invalidates a running server check, so a
  /// slow, stale response can't overwrite a newer state.
  var _probeToken = 0;

  /// The running check, shared by callers that ask while it's in flight
  /// (field blur and the "Check" button fire together).
  Future<ServerInfo?>? _pendingCheck;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  LoginState build() => const LoginState();

  // ── Server ────────────────────────────────────────────────────────────

  void serverUrlChanged(String value) {
    if (value == state.serverUrl) return;
    _probeToken++;
    state = state.copyWith(
      serverUrl: value,
      serverStatus: ServerStatus.unchecked,
      serverInfo: () => null,
      serverError: () => null,
      formError: () => null,
    );
  }

  void useCloudServer() => serverUrlChanged(AppConfig.defaultServerUrl);

  /// Checks the server once the user is done typing (field blur, "Check").
  /// Returns the info when the server is usable.
  Future<ServerInfo?> checkServer() {
    if (state.serverStatus == ServerStatus.reachable) {
      return Future.value(state.serverInfo);
    }
    if (state.serverStatus == ServerStatus.checking && _pendingCheck != null) {
      return _pendingCheck!;
    }
    return _pendingCheck = _runCheck();
  }

  Future<ServerInfo?> _runCheck() async {
    final connection = _connectionOrReport();
    if (connection == null) return null;

    final token = ++_probeToken;
    state = state.copyWith(
      serverStatus: ServerStatus.checking,
      serverError: () => null,
    );
    try {
      final info = await _repo.probeServer(connection);
      if (token != _probeToken) return null;
      final forceApiKey = info.passwordAuthDisabled;
      state = state.copyWith(
        serverStatus: ServerStatus.reachable,
        serverInfo: () => info,
        method: forceApiKey ? AuthMethod.apiKey : null,
      );
      return info;
    } on Failure catch (f) {
      if (token != _probeToken) return null;
      state = state.copyWith(
        serverStatus: ServerStatus.failed,
        serverError: () => f.message,
      );
      return null;
    }
  }

  ServerConnection? _connectionOrReport() {
    switch (normalizeServerUrl(state.serverUrl)) {
      case InvalidServerUrl(:final message):
        state = state.copyWith(
          serverStatus: ServerStatus.failed,
          serverError: () => message,
        );
        return null;
      case ValidServerUrl(:final url):
        return ServerConnection(baseUrl: url, headers: _headerMap());
    }
  }

  Map<String, String> _headerMap() => {
        for (final h in state.headers)
          if (h.name.trim().isNotEmpty) h.name.trim(): h.value.trim(),
      };

  // ── Custom headers ────────────────────────────────────────────────────

  void toggleAdvanced() =>
      state = state.copyWith(showAdvanced: !state.showAdvanced);

  void addHeader() {
    state = state.copyWith(
      showAdvanced: true,
      headers: [...state.headers, HeaderEntry(id: _nextHeaderId++)],
    );
  }

  void updateHeader(int id, {String? name, String? value}) {
    _invalidateServerCheck();
    state = state.copyWith(
      headers: [
        for (final h in state.headers)
          h.id == id ? h.copyWith(name: name, value: value) : h,
      ],
    );
  }

  void removeHeader(int id) {
    _invalidateServerCheck();
    state = state.copyWith(
      headers: state.headers.where((h) => h.id != id).toList(),
    );
  }

  /// Headers can decide whether a proxy lets us through at all.
  void _invalidateServerCheck() {
    if (state.serverStatus == ServerStatus.unchecked) return;
    _probeToken++;
    state = state.copyWith(
      serverStatus: ServerStatus.unchecked,
      serverError: () => null,
    );
  }

  // ── Credentials ───────────────────────────────────────────────────────

  void methodChanged(AuthMethod method) {
    if (method == AuthMethod.password && !state.passwordAuthAvailable) return;
    state = state.copyWith(method: method, formError: () => null);
  }

  void emailChanged(String v) =>
      state = state.copyWith(email: v, formError: () => null);

  void passwordChanged(String v) =>
      state = state.copyWith(password: v, formError: () => null);

  void apiKeyChanged(String v) =>
      state = state.copyWith(apiKey: v, formError: () => null);

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(submitting: true, formError: () => null);

    final info = await checkServer();
    final connection = info == null ? null : _connectionOrReport();
    if (info == null || connection == null) {
      state = state.copyWith(submitting: false);
      return;
    }

    if (state.method == AuthMethod.password && info.passwordAuthDisabled) {
      state = state.copyWith(
        submitting: false,
        method: AuthMethod.apiKey,
        formError: () =>
            'This server has password sign-in turned off. Use an API key.',
      );
      return;
    }

    try {
      final session = switch (state.method) {
        AuthMethod.password => await _repo.signInWithPassword(
            server: connection,
            email: state.email,
            password: state.password,
          ),
        AuthMethod.apiKey => await _repo.signInWithApiKey(
            server: connection,
            apiKey: state.apiKey,
          ),
      };
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false);
      ref.read(sessionControllerProvider.notifier).signedIn(session);
    } on Failure catch (f) {
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false, formError: () => f.message);
    }
  }
}

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
  LoginViewModel.new,
);
