import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/settings_repository.dart';
import '../../../settings/presentation/settings_view_model.dart';
import '../../domain/entities/bookmark.dart';
import '../bookmark_ui_actions.dart';
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
    switch (action) {
      case SwipeAction.none:
        return false;
      case SwipeAction.favourite:
        await favouriteWithUndo(context, ref, host, bookmark);
        return false;
      case SwipeAction.archive:
        final after = bookmark.copyWith(archived: !bookmark.archived);
        if (host.keeps(after)) {
          await archiveWithUndo(context, ref, host, bookmark);
          return false;
        }
        return true;
      case SwipeAction.delete:
        final ask = ref.read(settingsViewModelProvider).confirmDelete;
        return !ask || await confirmDelete(context, bookmark);
      case SwipeAction.addToList:
        await showListsSheet(context, host: host, bookmark: bookmark);
        return false;
      case SwipeAction.addTag:
        await showTagsSheet(context, host: host, bookmark: bookmark);
        return false;
    }
  }

  /// The card has slid away: make the change, with Undo.
  void _commit(BuildContext context, WidgetRef ref, SwipeAction action) {
    switch (action) {
      case SwipeAction.archive:
        archiveWithUndo(context, ref, host, bookmark);
      case SwipeAction.delete:
        deleteWithUndo(context, ref, host, bookmark, askFirst: false);
      case _:
        break;
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
