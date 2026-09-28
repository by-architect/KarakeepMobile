import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bookmark_list.dart';

/// The menu a long press on a list or tag opens, at the finger ([at], in
/// global coordinates). True when [label] (a delete action) was picked.
Future<bool> showDeleteMenu(
  BuildContext context, {
  required Offset at,
  required String label,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final point = overlay.globalToLocal(at);
  final picked = await showMenu<bool>(
    context: context,
    color: AppColors.popover,
    position: RelativeRect.fromRect(
      point & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        value: true,
        child: ListTile(
          leading: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.destructive,
          ),
          title: Text(
            label,
            style: const TextStyle(color: AppColors.destructive),
          ),
        ),
      ),
    ],
  );
  return picked ?? false;
}

/// Asks before deleting a list; there's no undo on the server.
Future<bool> confirmDeleteList(
  BuildContext context,
  BookmarkList list, {
  required bool hasSublists,
}) =>
    _confirm(
      context,
      title: 'Delete ${list.icon} ${list.name}?',
      body: 'The list is deleted from your Karakeep server. The bookmarks in '
          'it stay in your library'
          '${hasSublists ? ', and the lists inside it move to the top' : ''}.',
    );

/// Asks before deleting a tag; there's no undo on the server.
Future<bool> confirmDeleteTag(BuildContext context, TagSummary tag) =>
    _confirm(
      context,
      title: 'Delete #${tag.name}?',
      body: switch (tag.count) {
        0 => 'No bookmarks have this tag.',
        1 => 'It comes off the 1 bookmark that has it. The bookmark stays.',
        final n => 'It comes off the $n bookmarks that have it. The bookmarks '
            'stay.',
      },
    );

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.popover,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
