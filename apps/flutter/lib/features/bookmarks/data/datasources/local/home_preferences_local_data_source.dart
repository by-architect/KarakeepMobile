import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/bookmark_list.dart';
import '../../../domain/entities/bookmark_scope.dart';
import '../../../domain/repositories/home_preferences_repository.dart';

/// [HomePreferencesRepository] on shared preferences. Nothing secret here;
/// the API key stays in secure storage.
class HomePreferencesLocalDataSource implements HomePreferencesRepository {
  const HomePreferencesLocalDataSource(this._prefs);

  static const _showArchivedKey = 'home.showArchived';
  static String _scopeKey(String account) => 'home.scope.$account';
  static String _countsKey(String account) => 'home.counts.$account';

  final SharedPreferencesWithCache _prefs;

  @override
  bool get showArchived => _prefs.getBool(_showArchivedKey) ?? false;

  @override
  Future<void> setShowArchived(bool value) =>
      _prefs.setBool(_showArchivedKey, value);

  @override
  BookmarkScope? lastScope(String accountKey) {
    final raw = _prefs.getString(_scopeKey(accountKey));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json case {'key': final String key}) {
        return BookmarkScope.fromKey(
          key,
          name: json['name'] as String?,
          icon: json['icon'] as String?,
        );
      }
    } on FormatException {
      // Fall through: treat as unset.
    }
    return null;
  }

  @override
  Future<void> setLastScope(String accountKey, BookmarkScope scope) {
    return _prefs.setString(
      _scopeKey(accountKey),
      jsonEncode({
        'key': scope.key,
        if (scope case ListScope(:final name, :final icon)) ...{
          'name': name,
          'icon': icon,
        },
      }),
    );
  }

  @override
  Map<String, ItemCount> cachedCounts(String accountKey) {
    final raw = _prefs.getString(_countsKey(accountKey));
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return {
        for (final MapEntry(:key, :value) in json.entries)
          if (value case [final num total, final num? unarchived])
            key: ItemCount(total: total.toInt(), unarchived: unarchived?.toInt()),
      };
    } on Object {
      return const {};
    }
  }

  @override
  Future<void> setCachedCounts(
    String accountKey,
    Map<String, ItemCount> counts,
  ) {
    return _prefs.setString(
      _countsKey(accountKey),
      jsonEncode({
        for (final MapEntry(:key, :value) in counts.entries)
          key: [value.total, value.unarchived],
      }),
    );
  }
}
