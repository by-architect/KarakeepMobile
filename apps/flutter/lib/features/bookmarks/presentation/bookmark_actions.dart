import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../bookmarks_providers.dart';
import '../domain/entities/bookmark.dart';
import '../domain/repositories/bookmarks_repository.dart';
import 'feed_host.dart';
import 'viewmodels/lists_nav_view_model.dart';

/// Changes to a bookmark, shared by swipe actions, the viewer and sheets.
///
/// Updates are optimistic: the feed changes at once, the server call
/// follows, and a failure puts the item back and rethrows the [Failure] for
/// the caller to show.
class BookmarkActions {
  BookmarkActions(this._ref);

  final Ref _ref;

  BookmarksRepository get _repo => _ref.read(bookmarksRepositoryProvider);

  /// Drawer counts are now out of date.
  void _changed() => _ref.read(listsNavViewModelProvider.notifier).markStale();

  Future<Bookmark> toggleFavourite(BookmarkFeedHost host, Bookmark b) =>
      _update(
        host,
        b,
        b.copyWith(favourited: !b.favourited),
        () => _repo.setFavourited(b.id, !b.favourited),
      );

  Future<Bookmark> toggleArchive(BookmarkFeedHost host, Bookmark b) => _update(
        host,
        b,
        b.copyWith(archived: !b.archived),
        () => _repo.setArchived(b.id, !b.archived),
      );

  /// Undo an archive that removed [original] from the feed at [index].
  Future<void> undoArchive(
    BookmarkFeedHost host,
    Bookmark original,
    int index,
  ) async {
    host.restore(original, index);
    try {
      await _repo.setArchived(original.id, original.archived);
      _changed();
    } on Failure {
      host.applyChange(original.copyWith(archived: !original.archived));
      rethrow;
    }
  }

  Future<void> delete(BookmarkFeedHost host, Bookmark b) async {
    final index = host.indexOf(b.id);
    host.remove(b.id);
    try {
      await _repo.deleteBookmark(b.id);
      _changed();
    } on Failure {
      host.restore(b, index);
      rethrow;
    }
  }

  Future<Set<String>> listIdsOf(Bookmark b) => _repo.listIdsOf(b.id);

  Future<void> setInList(
    BookmarkFeedHost host,
    Bookmark b,
    String listId, {
    required bool member,
  }) async {
    if (member) {
      await _repo.addToList(listId, b.id);
    } else {
      await _repo.removeFromList(listId, b.id);
      host.removedFromList(listId, b.id);
    }
    _changed();
  }

  /// Returns the bookmark with its tags as the server now has them.
  Future<Bookmark> attachTag(
    BookmarkFeedHost host,
    Bookmark b,
    String name,
  ) async {
    await _repo.attachTag(b.id, name);
    return _refresh(host, b.id);
  }

  Future<Bookmark> detachTag(
    BookmarkFeedHost host,
    Bookmark b,
    BookmarkTag tag,
  ) async {
    await _repo.detachTag(b.id, tag.id);
    return _refresh(host, b.id);
  }

  Future<Bookmark> _refresh(BookmarkFeedHost host, String id) async {
    final fresh = await _repo.getBookmark(id);
    host.applyChange(fresh);
    _changed();
    return fresh;
  }

  Future<Bookmark> _update(
    BookmarkFeedHost host,
    Bookmark before,
    Bookmark after,
    Future<void> Function() call,
  ) async {
    final index = host.indexOf(before.id);
    host.applyChange(after);
    try {
      await call();
      _changed();
      return after;
    } on Failure {
      host.restore(before, index);
      rethrow;
    }
  }
}

final bookmarkActionsProvider = Provider<BookmarkActions>(BookmarkActions.new);
