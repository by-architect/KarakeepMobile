import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/features/auth/data/mappers/session_mapper.dart';
import 'package:karakeep_client/features/auth/domain/entities/server_connection.dart';
import 'package:karakeep_client/features/auth/domain/entities/session.dart';

void main() {
  test('round-trips a session', () {
    const session = Session(
      server: ServerConnection(
        baseUrl: 'https://keep.example.com',
        headers: {'X-Auth': '1'},
      ),
      apiKey: 'ak2_x_y',
      apiKeyId: 'k1',
      serverVersion: '0.33.0',
      user: AuthUser(id: 'u1', name: 'Ada', email: 'ada@example.com'),
    );
    final decoded = SessionJson.decode(SessionJson.encode(session))!;
    expect(decoded.server, session.server);
    expect(decoded.apiKey, 'ak2_x_y');
    expect(decoded.apiKeyId, 'k1');
    expect(decoded.user.email, 'ada@example.com');
  });

  test('treats unknown or corrupt data as signed out', () {
    expect(SessionJson.decode(null), isNull);
    expect(SessionJson.decode({'v': 99, 'baseUrl': 'x'}), isNull);
    expect(SessionJson.decode('garbage'), isNull);
  });
}
