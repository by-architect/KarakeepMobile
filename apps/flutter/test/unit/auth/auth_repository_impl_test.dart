import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/core/error/failure.dart';
import 'package:karakeep_client/core/network/dio_factory.dart';
import 'package:karakeep_client/features/auth/data/datasources/remote/auth_remote_data_source.dart';
import 'package:karakeep_client/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_connection.dart';

import 'fake_server.dart';

void main() {
  const server = ServerConnection(
    baseUrl: 'https://keep.example.com',
    headers: {'CF-Access-Client-Id': 'abc'},
  );

  late FakeServerAdapter adapter;
  late InMemorySessionStore store;

  AuthRepositoryImpl repo([FakeRoutes? r]) {
    adapter = FakeServerAdapter(r ?? karakeepRoutes());
    store = InMemorySessionStore();
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSource(DioFactory(adapter: adapter)),
      local: store,
    );
  }

  group('probeServer', () {
    test('reads version and auth options', () async {
      final info = await repo().probeServer(server);
      expect(info.version, '0.33.0');
      expect(info.passwordAuthDisabled, isFalse);
    });

    test('flags SSO-only servers', () async {
      final info = await repo(karakeepRoutes(passwordAuthDisabled: true))
          .probeServer(server);
      expect(info.passwordAuthDisabled, isTrue);
    });

    test('sends custom headers', () async {
      await repo().probeServer(server);
      expect(adapter.requests.first.headers['CF-Access-Client-Id'], 'abc');
    });

    test('rejects a proxy login page', () async {
      final r = repo({
        'GET /api/health': (_) => (status: 200, body: '<html>Sign in</html>'),
      });
      await expectLater(
        r.probeServer(server),
        throwsA(isA<NotKarakeepFailure>()),
      );
    });

    test('rejects a site without the health endpoint', () async {
      await expectLater(
        repo({}).probeServer(server),
        throwsA(isA<NotKarakeepFailure>()),
      );
    });

    test('still works when config and version are missing', () async {
      final info = await repo({
        'GET /api/health': (_) => (status: 200, body: {'status': 'ok'}),
      }).probeServer(server);
      expect(info.version, isNull);
      expect(info.passwordAuthDisabled, isFalse);
    });
  });

  group('signInWithPassword', () {
    test('exchanges for a key, loads the user and stores the session',
        () async {
      final session = await repo().signInWithPassword(
        server: server,
        email: ' ada@example.com ',
        password: 'correct',
      );
      expect(session.apiKey, 'ak2_abc_secret');
      expect(session.apiKeyId, 'key-1');
      expect(session.user.name, 'Ada');
      expect(session.serverVersion, '0.33.0');
      expect(store.stored?.apiKey, 'ak2_abc_secret');

      final exchange = adapter.requests
          .firstWhere((r) => r.path.endsWith('apiKeys.exchange'));
      final input = (exchange.data as Map)['json'] as Map;
      expect(input['email'], 'ada@example.com');
      expect(input['keyName'], startsWith('Keeper mobile ('));
    });

    test('maps wrong credentials to a clear message', () async {
      await expectLater(
        repo().signInWithPassword(
          server: server,
          email: 'ada@example.com',
          password: 'nope',
        ),
        throwsA(
          isA<UnauthorizedFailure>()
              .having((f) => f.message, 'message', 'Wrong email or password.'),
        ),
      );
      expect(store.stored, isNull);
    });

    test('surfaces the server reason on 403', () async {
      final r = repo({
        ...karakeepRoutes(),
        'POST /api/trpc/apiKeys.exchange': (_) => (
              status: 403,
              body: {
                'error': {
                  'json': {
                    'message': 'Password authentication is currently disabled',
                    'data': {'code': 'FORBIDDEN', 'httpStatus': 403},
                  },
                },
              },
            ),
      });
      await expectLater(
        r.signInWithPassword(server: server, email: 'a@b.c', password: 'x'),
        throwsA(
          isA<ForbiddenFailure>().having(
            (f) => f.message,
            'message',
            'Password authentication is currently disabled',
          ),
        ),
      );
    });
  });

  group('signInWithApiKey', () {
    test('validates the key against /users/me', () async {
      final session = await repo()
          .signInWithApiKey(server: server, apiKey: '  ak2_pasted ');
      expect(session.apiKey, 'ak2_pasted');
      expect(session.apiKeyId, isNull);
      expect(store.stored?.user.id, 'user-1');
    });

    test('rejects an invalid key', () async {
      await expectLater(
        repo().signInWithApiKey(server: server, apiKey: 'ak2_bad'),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });
  });
}
