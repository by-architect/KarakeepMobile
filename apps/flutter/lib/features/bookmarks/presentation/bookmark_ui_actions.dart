import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/error/failure.dart';
import '../../settings/presentation/settings_view_model.dart';
import '../domain/entities/bookmark.dart';
import 'bookmark_actions.dart';
import 'feed_host.dart';
import 'undo_snackbar.dart';
import 'widgets/bookmark_sheets.dart';

/// Bookmark actions as the UI runs them — the change plus its snackbar with
/// Undo. Shared by card swipes and the viewer toolbar so both behave alike.

Future<void> favouriteWithUndo(
  BuildContext context,
  WidgetRef ref,
  BookmarkFeedHost host,
  Bookmark bookmark,
) async {
  final actions = ref.read(bookmarkActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final index = host.indexOf(bookmark.id);
  try {
    final after = await actions.toggleFavourite(host, bookmark);
    showUndoSnackBar(
      messenger,
      after.favourited ? 'Added to favorites' : 'Removed from favorites',
      onUndo: () => _run(
        messenger,
        () async {
          host.restore(after, index); // back in the feed if it had left
          await actions.toggleFavourite(host, after);
        },
      ),
    );
  } on Failure catch (f) {
    _fail(messenger, f);
  }
}

/// [onUndo] runs just before the bookmark comes back (the viewer uses it to
/// show that bookmark again).
Future<void> archiveWithUndo(
  BuildContext context,
  WidgetRef ref,
  BookmarkFeedHost host,
  Bookmark bookmark, {
  VoidCallback? onUndo,
}) async {
  final actions = ref.read(bookmarkActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final index = host.indexOf(bookmark.id);
  try {
    final after = await actions.toggleArchive(host, bookmark);
    showUndoSnackBar(
      messenger,
      after.archived ? 'Archived' : 'Unarchived',
      onUndo: () => _run(messenger, () {
        onUndo?.call();
        return actions.undoArchive(host, bookmark, index);
      }),
    );
  } on Failure catch (f) {
    _fail(messenger, f);
  }
}

/// Asks first when Settings says so ([askFirst] null = follow Settings).
/// Returns whether the bookmark was (tentatively) deleted.
Future<bool> deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  BookmarkFeedHost host,
  Bookmark bookmark, {
  bool? askFirst,
  VoidCallback? onUndo,
}) async {
  final ask = askFirst ?? ref.read(settingsViewModelProvider).confirmDelete;
  if (ask && !await confirmDelete(context, bookmark)) return false;
  if (!context.mounted) return false;

  final actions = ref.read(bookmarkActionsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final index = actions.stageDelete(host, bookmark);
  var undone = false;
  showUndoSnackBar(
    messenger,
    'Deleted',
    onUndo: () {
      undone = true;
      onUndo?.call();
      actions.undoDelete(host, bookmark, index);
    },
    onCommit: () {
      if (undone) return;
      _run(messenger, () => actions.commitDelete(host, bookmark, index));
    },
  );
  return true;
}

Future<void> _run(
  ScaffoldMessengerState messenger,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Failure catch (f) {
    _fail(messenger, f);
  }
}

void _fail(ScaffoldMessengerState messenger, Failure f) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(f.message)));
}
