import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/bookmark_list.dart';
import '../viewmodels/lists_nav_view_model.dart';

Future<void> showCreateListSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _CreateListSheet(),
  );
}

/// New list: name, emoji, manual or smart (saved search), optional parent.
class _CreateListSheet extends ConsumerStatefulWidget {
  const _CreateListSheet();

  @override
  ConsumerState<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends ConsumerState<_CreateListSheet> {
  final _name = TextEditingController();
  final _icon = TextEditingController(text: '📋');
  final _query = TextEditingController();
  var _kind = ListKind.manual;
  String? _parentId;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final icon = _icon.text.trim();
    final query = _query.text.trim();
    final problem = switch (()) {
      _ when name.isEmpty => 'Give the list a name.',
      _ when name.length > 100 => 'Names can be at most 100 characters.',
      _ when icon.isEmpty => 'Pick an emoji for the list.',
      _ when _kind == ListKind.smart && query.isEmpty =>
        'A smart list needs a search query.',
      _ => null,
    };
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final list =
          await ref.read(listsNavViewModelProvider.notifier).createList(
                name: name,
                icon: icon,
                kind: _kind,
                query: query,
                parentId: _parentId,
              );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Created ${list.icon} ${list.name}')),
      );
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parents = ref
        .watch(listsNavViewModelProvider.select((s) => s.lists))
        .where((e) => e.list.kind == ListKind.manual)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New list',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: _Field(
                    controller: _icon,
                    hint: '📋',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    controller: _name,
                    hint: 'Name',
                    autofocus: true,
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<ListKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ListKind.manual, label: Text('Manual')),
                ButtonSegment(
                  value: ListKind.smart,
                  label: Text('Smart'),
                  icon: Icon(Icons.bolt_rounded, size: 16),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
            const SizedBox(height: 8),
            Text(
              _kind == ListKind.manual
                  ? 'You add bookmarks to it yourself.'
                  : 'Fills itself with everything matching a search.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            if (_kind == ListKind.smart) ...[
              const SizedBox(height: 12),
              _Field(
                controller: _query,
                hint: 'e.g. #reading -is:archived',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
              ),
            ],
            if (parents.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                dropdownColor: AppColors.popover,
                decoration: _decoration(null, label: 'Inside'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Top level')),
                  for (final e in parents)
                    DropdownMenuItem(
                      value: e.list.id,
                      child: Text(
                        '${'   ' * e.depth}${e.list.icon} ${e.list.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              InlineBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Create list',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCreateTagDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CreateTagDialog(),
  );
}

class _CreateTagDialog extends ConsumerStatefulWidget {
  const _CreateTagDialog();

  @override
  ConsumerState<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends ConsumerState<_CreateTagDialog> {
  final _name = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim().replaceFirst(RegExp('^#'), '');
    if (name.isEmpty) return setState(() => _error = 'Type a tag name.');
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final tag =
          await ref.read(listsNavViewModelProvider.notifier).createTag(name);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Created #${tag.name}')));
    } on Failure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.popover,
      title: const Text('New tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            controller: _name,
            hint: 'Tag name',
            autofocus: true,
            prefix: '#',
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineBanner(message: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

InputDecoration _decoration(String? hint, {String? prefix, String? label}) =>
    InputDecoration(
      hintText: hint,
      labelText: label,
      prefixText: prefix,
      filled: true,
      fillColor: AppColors.input.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.prefix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final String? prefix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textAlign: textAlign,
      style: style ?? const TextStyle(fontSize: 16),
      decoration: _decoration(hint, prefix: prefix),
      onSubmitted: onSubmitted,
    );
  }
}
