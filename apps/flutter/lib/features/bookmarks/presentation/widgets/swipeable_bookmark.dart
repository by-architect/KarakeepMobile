import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/settings_repository.dart';
import '../../../settings/presentation/settings_view_model.dart';
import '../../domain/entities/bookmark.dart';
import '../bookmark_actions.dart';
import '../feed_host.dart';
import 'bookmark_sheets.dart';

/// A card that runs the swipe actions chosen in Settings.
///
/// Actions that take the item out of the feed (archive while archived items
/// are hidden, delete) let it slide away; the others spring back.
class SwipeableBookmark extends ConsumerWidget {
  const SwipeableBookmark({
    super.key,
    required this.host,
    required this.bookmark,
    required this.child,
  });

  final BookmarkFeedHost host;
  final Bookmark bookmark;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final right = settings.swipeRight;
    final left = settings.swipeLeft;
    if (right == SwipeAction.none && left == SwipeAction.none) return child;

    return Dismissible(
      key: ValueKey('swipe-${bookmark.id}'),
      direction: switch ((right, left)) {
        (SwipeAction.none, _) => DismissDirection.endToStart,
        (_, SwipeAction.none) => DismissDirection.startToEnd,
        _ => DismissDirection.horizontal,
      },
      background: _SwipeBackground(
        action: right,
        bookmark: bookmark,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        action: left,
        bookmark: bookmark,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) => _confirm(
        context,
        ref,
        direction == DismissDirection.startToEnd ? right : left,
      ),
      onDismissed: (direction) => _commit(
        context,
        ref,
        direction == DismissDirection.startToEnd ? right : left,
      ),
      child: child,
    );
  }

  /// Runs actions that keep the card, and says whether the card should slide
  /// away (the removal itself happens in [_commit]).
  Future<bool> _confirm(
    BuildContext context,
    WidgetRef ref,
    SwipeAction action,
  ) async {
    final actions = ref.read(bookmarkActionsProvider);
    try {
      switch (action) {
        case SwipeAction.none:
          return false;
        case SwipeAction.favourite:
          await actions.toggleFavourite(host, bookmark);
          return false;
        case SwipeAction.archive:
          final after = bookmark.copyWith(archived: !bookmark.archived);
          if (host.keeps(after)) {
            await actions.toggleArchive(host, bookmark);
            return false;
          }
          return true;
        case SwipeAction.delete:
          return await confirmDelete(context, bookmark);
        case SwipeAction.addToList:
          await showListsSheet(context, host: host, bookmark: bookmark);
          return false;
        case SwipeAction.addTag:
          await showTagsSheet(context, host: host, bookmark: bookmark);
          return false;
      }
    } on Failure catch (f) {
      if (context.mounted) showFailure(context, f);
      return false;
    }
  }

  Future<void> _commit(
    BuildContext context,
    WidgetRef ref,
    SwipeAction action,
  ) async {
    final actions = ref.read(bookmarkActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final index = host.indexOf(bookmark.id);
    try {
      switch (action) {
        case SwipeAction.archive:
          await actions.toggleArchive(host, bookmark);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(bookmark.archived ? 'Unarchived' : 'Archived'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () =>
                      actions.undoArchive(host, bookmark, index).ignore(),
                ),
              ),
            );
        case SwipeAction.delete:
          await actions.delete(host, bookmark);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Deleted')));
        case _:
          break;
      }
    } on Failure catch (f) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.action,
    required this.bookmark,
    required this.alignment,
  });

  final SwipeAction action;
  final Bookmark bookmark;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (action) {
      SwipeAction.favourite => bookmark.favourited
          ? (Icons.star_outline_rounded, 'Unfavorite', AppColors.favourite)
          : (Icons.star_rounded, 'Favorite', AppColors.favourite),
      SwipeAction.archive => bookmark.archived
          ? (Icons.unarchive_outlined, 'Unarchive', AppColors.primary)
          : (Icons.archive_outlined, 'Archive', AppColors.primary),
      SwipeAction.addToList =>
        (Icons.playlist_add_rounded, 'Lists', AppColors.success),
      SwipeAction.addTag => (Icons.tag_rounded, 'Tags', AppColors.success),
      SwipeAction.delete =>
        (Icons.delete_outline_rounded, 'Delete', AppColors.destructive),
      SwipeAction.none => (Icons.block, '', AppColors.card),
    };
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
