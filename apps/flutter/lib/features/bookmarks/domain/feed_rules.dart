import 'entities/bookmark.dart';
import 'entities/bookmark_scope.dart';

/// Whether [bookmark] still belongs in a feed of [scope] after it changed
/// (archived, unfavorited, untagged…). Feeds drop items that don't.
///
/// List membership isn't on the bookmark, so removing from a list is handled
/// where it happens.
bool belongsInFeed(
  Bookmark bookmark,
  BookmarkScope? scope, {
  required bool includeArchived,
}) {
  switch (scope) {
    case ArchivedScope():
      return bookmark.archived;
    case FavouritesScope() when !bookmark.favourited:
      return false;
    case TagScope(:final id) when !bookmark.tags.any((t) => t.id == id):
      return false;
    default:
      return includeArchived || !bookmark.archived;
  }
}
