import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/core/error/failure.dart';
import 'package:linkstow/features/auth/auth_providers.dart';
import 'package:linkstow/features/auth/domain/entities/server_info.dart';
import 'package:linkstow/features/auth/presentation/state/login_state.dart';
import 'package:linkstow/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:linkstow/features/auth/presentation/viewmodels/session_controller.dart';

import 'fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  LoginViewModel vm() => container.read(loginViewModelProvider.notifier);
  LoginState state() => container.read(loginViewModelProvider);

  setUp(() {
    repo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    // Keep the auto-dispose view model alive for the whole test.
    container.listen(loginViewModelProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('checks the server with the normalised url and headers', () async {
    vm().serverUrlChanged('keep.example.com/');
    vm().addHeader();
    final id = state().headers.single.id;
    vm().updateHeader(id, name: 'X-Proxy', value: 'secret');

    await vm().checkServer();

    expect(state().serverStatus, ServerStatus.reachable);
    expect(repo.probed.single.baseUrl, 'https://keep.example.com');
    expect(repo.probed.single.headers, {'X-Proxy': 'secret'});
  });

  test('concurrent checks share one request', () async {
    vm().serverUrlChanged('keep.example.com');
    await Future.wait([vm().checkServer(), vm().checkServer()]);
    expect(repo.probed, hasLength(1));
  });

  test('reports an invalid address without calling the server', () async {
    vm().serverUrlChanged('ftp://nope');
    await vm().checkServer();
    expect(state().serverStatus, ServerStatus.failed);
    expect(state().serverError, isNotNull);
    expect(repo.probed, isEmpty);
  });

  test('shows the failure message when the server is unreachable', () async {
    repo.probeFailure = const NetworkFailure();
    vm().serverUrlChanged('keep.example.com');
    await vm().checkServer();
    expect(state().serverStatus, ServerStatus.failed);
    expect(state().serverError, const NetworkFailure().message);
  });

  test('ignores a stale check after the url changed', () async {
    repo.probeGate = Completer();
    vm().serverUrlChanged('old.example.com');
    final pending = vm().checkServer();
    vm().serverUrlChanged('new.example.com');
    repo.probeGate!.complete();
    await pending;
    expect(state().serverStatus, ServerStatus.unchecked);
  });

  test('switches to API key on SSO-only servers', () async {
    repo.serverInfo = const ServerInfo(passwordAuthDisabled: true);
    vm().serverUrlChanged('keep.example.com');
    await vm().checkServer();
    expect(state().method, AuthMethod.apiKey);
    expect(state().passwordAuthAvailable, isFalse);

    vm().methodChanged(AuthMethod.password);
    expect(state().method, AuthMethod.apiKey);
  });

  test('editing headers invalidates a finished check', () async {
    vm().serverUrlChanged('keep.example.com');
    await vm().checkServer();
    vm().addHeader();
    vm().updateHeader(state().headers.single.id, name: 'X-A');
    expect(state().serverStatus, ServerStatus.unchecked);
  });

  group('submit', () {
    test('is disabled until the form is complete', () {
      expect(state().canSubmit, isFalse);
      vm().serverUrlChanged('keep.example.com');
      vm().emailChanged('ada@example.com');
      expect(state().canSubmit, isFalse);
      vm().passwordChanged('pw');
      expect(state().canSubmit, isTrue);
    });

    test('password sign-in publishes the session', () async {
      vm()
        ..serverUrlChanged('keep.example.com')
        ..emailChanged('ada@example.com')
        ..passwordChanged('pw');

      await vm().submit();

      expect(repo.passwordSignIns.single.email, 'ada@example.com');
      expect(state().submitting, isFalse);
      expect(container.read(sessionControllerProvider).value?.user.name, 'Ada');
    });

    test('api key sign-in uses the key', () async {
      vm()
        ..serverUrlChanged('keep.example.com')
        ..methodChanged(AuthMethod.apiKey)
        ..apiKeyChanged('ak2_pasted');

      await vm().submit();

      expect(repo.apiKeySignIns, ['ak2_pasted']);
    });

    test('shows the sign-in failure and stays signed out', () async {
      repo.signInFailure = const UnauthorizedFailure('Wrong email or password.');
      vm()
        ..serverUrlChanged('keep.example.com')
        ..emailChanged('ada@example.com')
        ..passwordChanged('bad');

      await vm().submit();

      expect(state().formError, 'Wrong email or password.');
      expect(state().submitting, isFalse);
      expect(container.read(sessionControllerProvider).value, isNull);
    });

    test('does not try to sign in when the server check fails', () async {
      repo.probeFailure = const NotKarakeepFailure();
      vm()
        ..serverUrlChanged('example.com')
        ..emailChanged('ada@example.com')
        ..passwordChanged('pw');

      await vm().submit();

      expect(repo.passwordSignIns, isEmpty);
      expect(state().serverStatus, ServerStatus.failed);
    });
  });
}
