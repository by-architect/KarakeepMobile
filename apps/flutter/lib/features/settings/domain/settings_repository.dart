/// How tapping a bookmark opens its link.
enum LinkOpenMode {
  /// The phone's default browser app.
  externalBrowser,

  /// The app's own viewer, with bookmark actions and swipe between items.
  /// (Name kept for saved preferences.)
  inAppBrowser,
}

/// What the in-app viewer shows for a link.
enum ViewerMode {
  /// The live page.
  browser,

  /// Karakeep's saved, cleaned-up article.
  reader,
}

/// What swiping a bookmark card does.
enum SwipeAction { none, favourite, archive, addToList, addTag, delete }

/// App preferences kept on this device.
abstract interface class SettingsRepository {
  LinkOpenMode get linkOpenMode;
  Future<void> setLinkOpenMode(LinkOpenMode mode);

  ViewerMode get viewerMode;
  Future<void> setViewerMode(ViewerMode mode);

  /// Swipe to the right (start → end).
  SwipeAction get swipeRight;
  Future<void> setSwipeRight(SwipeAction action);

  /// Swipe to the left (end → start).
  SwipeAction get swipeLeft;
  Future<void> setSwipeLeft(SwipeAction action);

  /// Ask "Delete bookmark?" first. When off, deleting relies on Undo.
  bool get confirmDelete;
  Future<void> setConfirmDelete(bool value);
}

/// Drops locally cached data: images, and anything else that is only a
/// cache of what the server has.
abstract interface class CacheCleaner {
  Future<void> clear();
}
