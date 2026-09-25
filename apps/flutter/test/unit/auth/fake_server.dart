import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:karakeep_client/features/auth/data/datasources/local/session_local_data_source.dart';
import 'package:karakeep_client/features/auth/domain/entities/session.dart';

typedef FakeResponse = ({int status, Object? body});
typedef FakeRoutes = Map<String, FakeResponse Function(RequestOptions)>;

/// A scripted HTTP server: `'GET /api/health' → (status: 200, body: {...})`.
class FakeServerAdapter implements HttpClientAdapter {
  FakeServerAdapter(this.routes);

  final FakeRoutes routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.uri.path}'];
    final response = handler?.call(options) ?? (status: 404, body: 'Not Found');
    final body = response.body;
    final isJson = body is! String;
    return ResponseBody.fromString(
      isJson ? jsonEncode(body) : body,
      response.status,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? Headers.jsonContentType : 'text/html',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Healthy Karakeep with password auth on and one known user.
FakeRoutes karakeepRoutes({
  bool passwordAuthDisabled = false,
}) =>
    {
      'GET /api/health': (_) => (
            status: 200,
            body: {'status': 'ok', 'message': 'Web app is working'},
          ),
      'GET /api/version': (_) => (status: 200, body: {'version': '0.33.0'}),
      'GET /api/trpc/config.clientConfig': (_) => (
            status: 200,
            body: {
              'result': {
                'data': {
                  'json': {
                    'serverVersion': '0.33.0',
                    'demoMode': false,
                    'auth': {
                      'disableSignups': false,
                      'disablePasswordAuth': passwordAuthDisabled,
                    },
                  },
                },
              },
            },
          ),
      'POST /api/trpc/apiKeys.exchange': (o) {
        final input = (o.data as Map)['json'] as Map;
        if (input['password'] != 'correct') {
          return (
            status: 401,
            body: {
              'error': {
                'json': {
                  'message': 'UNAUTHORIZED',
                  'code': -32001,
                  'data': {'code': 'UNAUTHORIZED', 'httpStatus': 401},
                },
              },
            },
          );
        }
        return (
          status: 200,
          body: {
            'result': {
              'data': {
                'json': {
                  'id': 'key-1',
                  'name': input['keyName'],
                  'key': 'ak2_abc_secret',
                  'createdAt': '2026-09-25T10:00:00.000Z',
                  'scopes': ['fullaccess'],
                },
                'meta': {
                  'values': {'createdAt': ['Date']},
                },
              },
            },
          },
        );
      },
      'GET /api/v1/users/me': (o) => o.headers['Authorization'] ==
                  'Bearer ak2_abc_secret' ||
              o.headers['Authorization'] == 'Bearer ak2_pasted'
          ? (
              status: 200,
              body: {
                'id': 'user-1',
                'name': 'Ada',
                'email': 'ada@example.com',
                'localUser': true,
              },
            )
          : (status: 401, body: 'Unauthorized'),
    };

class InMemorySessionStore implements SessionLocalDataSource {
  Session? stored;

  @override
  Future<Session?> read() async => stored;

  @override
  Future<void> write(Session session) async => stored = session;

  @override
  Future<void> clear() async => stored = null;
}
