import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../domain/entities/session.dart';
import '../../mappers/session_mapper.dart';

/// The session — API key included — lives only in the platform keystore.
class SessionLocalDataSource {
  const SessionLocalDataSource(this._storage);

  static const _key = 'auth.session';

  final FlutterSecureStorage _storage;

  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return SessionJson.decode(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(SessionJson.encode(session)));

  Future<void> clear() => _storage.delete(key: _key);
}
