import 'package:flutter_test/flutter_test.dart';
import 'package:karakeep_client/features/auth/domain/server_url.dart';

String? ok(String input) => switch (normalizeServerUrl(input)) {
      ValidServerUrl(:final url) => url,
      InvalidServerUrl() => null,
    };

void main() {
  group('normalizeServerUrl', () {
    test('keeps a clean https url', () {
      expect(ok('https://keep.example.com'), 'https://keep.example.com');
    });

    test('adds https to a bare host and trims', () {
      expect(ok('  keep.example.com  '), 'https://keep.example.com');
    });

    test('keeps http, ports and LAN addresses', () {
      expect(ok('http://192.168.1.20:3000/'), 'http://192.168.1.20:3000');
    });

    test('lowercases scheme and host', () {
      expect(ok('HTTPS://Keep.Example.COM'), 'https://keep.example.com');
    });

    test('keeps a sub-path deployment', () {
      expect(ok('https://example.com/karakeep/'), 'https://example.com/karakeep');
    });

    test('cuts pasted api and page urls back to the base', () {
      expect(ok('https://keep.example.com/api/v1'), 'https://keep.example.com');
      expect(
        ok('https://example.com/karakeep/dashboard/bookmarks?x=1#y'),
        'https://example.com/karakeep',
      );
      expect(ok('keep.example.com/signin'), 'https://keep.example.com');
    });

    test('rejects empty, spaces and other schemes', () {
      expect(normalizeServerUrl('   '), isA<InvalidServerUrl>());
      expect(normalizeServerUrl('keep example.com'), isA<InvalidServerUrl>());
      expect(normalizeServerUrl('ftp://keep.example.com'), isA<InvalidServerUrl>());
      expect(normalizeServerUrl('https://'), isA<InvalidServerUrl>());
    });
  });
}
