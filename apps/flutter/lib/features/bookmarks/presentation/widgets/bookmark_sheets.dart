import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_list.dart';
import '../bookmark_actions.dart';
import '../feed_host.dart';
import '../state/lists_nav_state.dart';
import '../viewmodels/lists_nav_view_model.dart';

/// Asks before deleting. Deleting can't be undone on the server.
Future<bool> confirmDelete(BuildContext context, Bookmark bookmark) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.popover,
      title: const Text('Delete bookmark?'),
      content: Text(
        '“${bookmark.displayTitle}” will be deleted from your Karakeep '
        'server. This can’t be undone.',
      ),
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

void showFailure(BuildContext context, Failure failure) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failure.message)));
}

Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => child,
  );
}

/// Tick the lists a bookmark belongs to. Smart lists fill themselves, so
/// they're shown but can't be ticked.
Future<void> showListsSheet(
  BuildContext context, {
  required BookmarkFeedHost host,
  required Bookmark bookmark,
}) =>
    _showSheet(context, _ListsSheet(host: host, bookmark: bookmark));

class _ListsSheet extends ConsumerStatefulWidget {
  const _ListsSheet({required this.host, required this.bookmark});

  final BookmarkFeedHost host;
  final Bookmark bookmark;

  @override
  ConsumerState<_ListsSheet> createState() => _ListsSheetState();
}

class _ListsSheetState extends ConsumerState<_ListsSheet> {
  Set<String>? _member;
  final _busy = <String>{};
  String? _error;

  BookmarkActions get _actions => ref.read(bookmarkActionsProvider);

  @override
  void initState() {
    super.initState();
    _actions.listIdsOf(widget.bookmark).then(
      (ids) {
        if (mounted) setState(() => _member = ids);
      },
      onError: (Object e) {
        if (mounted) {
          setState(() => _error = e is Failure ? e.message : 'Failed to load');
        }
      },
    );
  }

  Future<void> _toggle(String listId, bool member) async {
    setState(() {
      _busy.add(listId);
      member ? _member!.add(listId) : _member!.remove(listId);
    });
    try {
      await _actions.setInList(
        widget.host,
        widget.bookmark,
        listId,
        member: member,
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() => member ? _member!.remove(listId) : _member!.add(listId));
      showFailure(context, f);
    } finally {
      if (mounted) setState(() => _busy.remove(listId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsNavViewModelProvider.select((s) => s.lists));
    final member = _member;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          const _SheetTitle('Add to lists'),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : member == null
                    ? const Center(child: CircularProgressIndicator())
                    : lists.isEmpty
                        ? const Center(
                            child: Text(
                              'No lists yet. Create them on the web.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView(
                            controller: controller,
                            children: [
                              for (final entry in lists)
                                _listRow(entry, member),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _listRow(ListEntry entry, Set<String> member) {
    final list = entry.list;
    final smart = list.kind == ListKind.smart;
    final busy = _busy.contains(list.id);
    return CheckboxListTile(
      contentPadding: EdgeInsets.only(left: 16.0 + entry.depth * 18, right: 8),
      value: member.contains(list.id),
      onChanged: smart || busy ? null : (v) => _toggle(list.id, v ?? false),
      activeColor: AppColors.primary,
      title: Text('${list.icon}  ${list.name}'),
      subtitle: smart ? const Text('Smart list — fills itself') : null,
    );
  }
}

/// Add or remove tags. Suggests existing tags as you type.
Future<void> showTagsSheet(
  BuildContext context, {
  required BookmarkFeedHost host,
  required Bookmark bookmark,
}) =>
    _showSheet(context, _TagsSheet(host: host, bookmark: bookmark));

class _TagsSheet extends ConsumerStatefulWidget {
  const _TagsSheet({required this.host, required this.bookmark});

  final BookmarkFeedHost host;
  final Bookmark bookmark;

  @override
  ConsumerState<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends ConsumerState<_TagsSheet> {
  late Bookmark _bookmark = widget.bookmark;
  var _busy = false;

  BookmarkActions get _actions => ref.read(bookmarkActionsProvider);

  Future<void> _run(Future<Bookmark> Function() change) async {
    setState(() => _busy = true);
    try {
      final updated = await change();
      if (mounted) setState(() => _bookmark = updated);
    } on Failure catch (f) {
      if (mounted) showFailure(context, f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _add(String name) {
    final tag = name.trim().replaceFirst(RegExp('^#'), '');
    if (tag.isEmpty) return;
    _run(() => _actions.attachTag(widget.host, _bookmark, tag));
  }

  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(listsNavViewModelProvider.select((s) => s.tags));
    final attached = {for (final t in _bookmark.tags) t.name.toLowerCase()};

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle('Tags', busy: _busy),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _bookmark.tags.isEmpty
                ? const Text(
                    'No tags yet.',
                    style: TextStyle(color: AppColors.muted),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _bookmark.tags)
                        InputChip(
                          label: Text('#${tag.name}'),
                          backgroundColor: AppColors.popover,
                          side: BorderSide.none,
                          onDeleted: _busy
                              ? null
                              : () => _run(
                                    () => _actions.detachTag(
                                      widget.host,
                                      _bookmark,
                                      tag,
                                    ),
                                  ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Autocomplete<String>(
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return const [];
                return allTags
                    .map((t) => t.name)
                    .where(
                      (n) =>
                          n.toLowerCase().contains(q) &&
                          !attached.contains(n.toLowerCase()),
                    )
                    .take(8);
              },
              onSelected: _add,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Add a tag',
                    filled: true,
                    fillColor: AppColors.popover,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Add',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        _add(controller.text);
                        controller.clear();
                      },
                    ),
                  ),
                  onSubmitted: (v) {
                    _add(v);
                    controller.clear();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.title, {this.busy = false});

  final String title;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
