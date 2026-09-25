import 'package:shared_preferences/shared_preferences.dart';

import '../domain/settings_repository.dart';

class SettingsLocalDataSource implements SettingsRepository {
  const SettingsLocalDataSource(this._prefs);

  static const _linkOpenModeKey = 'settings.linkOpenMode';
  static const _viewerModeKey = 'settings.viewerMode';
  static const _swipeRightKey = 'settings.swipeRight';
  static const _swipeLeftKey = 'settings.swipeLeft';

  final SharedPreferencesWithCache _prefs;

  @override
  LinkOpenMode get linkOpenMode {
    final name = _prefs.getString(_linkOpenModeKey);
    return LinkOpenMode.values.asNameMap()[name] ??
        LinkOpenMode.inAppBrowser;
  }

  @override
  Future<void> setLinkOpenMode(LinkOpenMode mode) =>
      _prefs.setString(_linkOpenModeKey, mode.name);

  @override
  ViewerMode get viewerMode =>
      _read(_viewerModeKey, ViewerMode.values, ViewerMode.browser);

  @override
  Future<void> setViewerMode(ViewerMode mode) =>
      _prefs.setString(_viewerModeKey, mode.name);

  @override
  SwipeAction get swipeRight =>
      _read(_swipeRightKey, SwipeAction.values, SwipeAction.archive);

  @override
  Future<void> setSwipeRight(SwipeAction action) =>
      _prefs.setString(_swipeRightKey, action.name);

  @override
  SwipeAction get swipeLeft =>
      _read(_swipeLeftKey, SwipeAction.values, SwipeAction.favourite);

  @override
  Future<void> setSwipeLeft(SwipeAction action) =>
      _prefs.setString(_swipeLeftKey, action.name);

  T _read<T extends Enum>(String key, List<T> values, T fallback) =>
      values.asNameMap()[_prefs.getString(key)] ?? fallback;
}
