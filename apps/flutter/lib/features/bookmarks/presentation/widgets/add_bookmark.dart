import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_list.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../bookmark_actions.dart';
import '../viewmodels/home_feed_view_model.dart';
import '../viewmodels/lists_nav_view_model.dart';

/// Picks a photo; swapped in tests, where there's no gallery.
typedef ImagePick = Future<({String path, String name})?> Function();

final imagePickProvider = Provider<ImagePick>((ref) => () async {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      return file == null ? null : (path: file.path, name: file.name);
    });

/// The home screen's Add button: a link, a note or a picture. What's added
/// lands in the list, tag or favorites open on home.
Future<void> showAddBookmarkSheet(
  BuildContext context,
  WidgetRef ref, {
  required BookmarkScope scope,
}) async {
  final choice = await showModalBottomSheet<_Kind>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final kind in _Kind.values)
            ListTile(
              leading: Icon(kind.icon, color: AppColors.mutedForeground),
              title: Text(kind.label),
              onTap: () => Navigator.pop(context, kind),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  Future<Bookmark> Function(BookmarksRepository repo)? make;
  switch (choice) {
    case _Kind.link:
      final url = await _askLink(context);
      if (url != null) make = (repo) => repo.createLink(url);
    case _Kind.note:
      final text = await _askNote(context);
      if (text != null) make = (repo) => repo.createNote(text);
    case _Kind.image:
      final file = await ref.read(imagePickProvider)();
      if (file != null) {
        make = (repo) => repo.createImage(file.path, file.name);
      }
  }
  if (make == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(choice == _Kind.image ? 'Uploading…' : 'Saving…'),
      ),
    );
  final manualList = scope is ListScope &&
      ref
          .read(listsNavViewModelProvider)
          .lists
          .any((e) => e.list.id == scope.id && e.list.kind == ListKind.manual);
  try {
    await ref.read(bookmarkActionsProvider).create(
          make,
          scope: scope,
          manualList: manualList,
        );
    if (context.mounted) {
      await ref.read(homeFeedViewModelProvider.notifier).refresh();
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved')));
  } on Failure catch (f) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(f.message)));
  }
}

enum _Kind {
  link('Add link', Icons.link_rounded),
  note('Add text', Icons.notes_rounded),
  image('Add image', Icons.image_outlined);

  const _Kind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The web address to save; starts with the clipboard's if it holds one.
Future<String?> _askLink(BuildContext context) async {
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
  final start = clip != null && RegExp(r'^https?://\S+$').hasMatch(clip)
      ? clip
      : '';
  if (!context.mounted) return null;
  return _ask(
    context,
    title: 'Add link',
    hint: 'https://…',
    initial: start,
    keyboard: TextInputType.url,
    check: (v) {
      final uri = Uri.tryParse(v.contains('://') ? v : 'https://$v');
      return uri != null && uri.host.contains('.')
          ? null
          : 'That doesn’t look like a web address.';
    },
    clean: (v) => v.contains('://') ? v : 'https://$v',
  );
}

Future<String?> _askNote(BuildContext context) => _ask(
      context,
      title: 'Add text',
      hint: 'Write a note',
      lines: 6,
      keyboard: TextInputType.multiline,
    );

Future<String?> _ask(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  int lines = 1,
  TextInputType? keyboard,
  String? Function(String value)? check,
  String Function(String value)? clean,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskDialog(
      title: title,
      hint: hint,
      initial: initial,
      lines: lines,
      keyboard: keyboard,
      check: check,
      clean: clean,
    ),
  );
}

class _AskDialog extends StatefulWidget {
  const _AskDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.lines,
    this.keyboard,
    this.check,
    this.clean,
  });

  final String title;
  final String hint;
  final String initial;
  final int lines;
  final TextInputType? keyboard;
  final String? Function(String value)? check;
  final String Function(String value)? clean;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    final problem = widget.check?.call(value);
    if (problem != null) return setState(() => _error = problem);
    Navigator.pop(context, widget.clean?.call(value) ?? value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.popover,
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: widget.lines,
        maxLines: widget.lines == 1 ? 1 : 12,
        keyboardType: widget.keyboard,
        textInputAction:
            widget.lines == 1 ? TextInputAction.done : TextInputAction.newline,
        onSubmitted: widget.lines == 1 ? (_) => _save() : null,
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _error,
          filled: true,
          fillColor: AppColors.input.withValues(alpha: 0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
