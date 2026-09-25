import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/bookmark_list.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../state/lists_nav_state.dart';
import '../viewmodels/lists_nav_view_model.dart';
import 'create_list_tag.dart';

/// Left drawer: pick what the feed shows. Every row carries
/// `unarchived / total`.
class ListsDrawer extends ConsumerWidget {
  const ListsDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onOpenSettings,
  });

  /// Tags shown before "Show all".
  static const topTags = 10;

  final BookmarkScope selected;
  final ValueChanged<BookmarkScope> onSelect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listsNavViewModelProvider);
    final vm = ref.read(listsNavViewModelProvider.notifier);

    Widget scopeRow(
      BookmarkScope scope, {
      required Widget leading,
      required String label,
      int depth = 0,
      bool smart = false,
      bool totalOnly = false,
      ItemCount? count,
    }) {
      return _ScopeRow(
        leading: leading,
        label: label,
        depth: depth,
        smart: smart,
        count: count ?? state.counts[scope.key],
        totalOnly: totalOnly,
        selected: scope == selected,
        onTap: () => onSelect(scope),
      );
    }

    return Drawer(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(),
      width: 312,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AccountHeader(),
            const Divider(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: vm.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  children: [
                    scopeRow(
                      const AllScope(),
                      leading: const _RowIcon(Icons.inbox_rounded),
                      label: 'All bookmarks',
                    ),
                    scopeRow(
                      const FavouritesScope(),
                      leading: const _RowIcon(Icons.star_rounded),
                      label: 'Favorites',
                    ),
                    scopeRow(
                      const ArchivedScope(),
                      leading: const _RowIcon(Icons.archive_rounded),
                      label: 'Archived',
                      totalOnly: true,
                    ),
                    _SectionHeader(
                      title: 'LISTS',
                      legend: 'unarchived / total',
                      busy: state.counting,
                    ),
                    ..._lists(state, scopeRow, vm),
                    _AddRow(
                      label: 'Add list',
                      onTap: () => showCreateListSheet(context),
                    ),
                    const _SectionHeader(title: 'TAGS', legend: 'total'),
                    if (!state.tagsLoaded)
                      const _Loading()
                    else if (state.tagsError != null)
                      _ErrorRetry(message: state.tagsError!, onRetry: vm.loadTags)
                    else if (state.tags.isEmpty)
                      const _Hint('No tags yet.')
                    else ...[
                      for (final tag in state.showAllTags
                          ? state.tags
                          : state.tags.take(topTags))
                        scopeRow(
                          TagScope(id: tag.id, name: tag.name),
                          leading: const _RowIcon(Icons.tag_rounded),
                          label: tag.name,
                          totalOnly: true,
                          count: ItemCount(total: tag.count),
                        ),
                      if (state.tags.length > topTags)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: vm.toggleAllTags,
                            child: Text(
                              state.showAllTags
                                  ? 'Show fewer'
                                  : 'Show all ${state.tags.length} tags',
                            ),
                          ),
                        ),
                    ],
                    _AddRow(
                      label: 'Add tag',
                      onTap: () => showCreateTagDialog(context),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: AppColors.mutedForeground,
                size: 20,
              ),
              title: const Text('Settings', style: TextStyle(fontSize: 15)),
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lists(
    ListsNavState state,
    Widget Function(
      BookmarkScope, {
      required Widget leading,
      required String label,
      int depth,
      bool smart,
      bool totalOnly,
      ItemCount? count,
    }) scopeRow,
    ListsNavViewModel vm,
  ) {
    switch (state.status) {
      case ListsStatus.loading when state.lists.isEmpty:
        return const [_Loading()];
      case ListsStatus.error:
        return [
          _ErrorRetry(
            message: state.error ?? 'Couldn’t load lists.',
            onRetry: vm.refresh,
          ),
        ];
      case _ when state.lists.isEmpty:
        return const [_Hint('No lists yet. Create them on the web for now.')];
      case _:
        return [
          for (final entry in state.lists)
            scopeRow(
              ListScope(
                id: entry.list.id,
                name: entry.list.name,
                icon: entry.list.icon,
              ),
              leading: _Emoji(entry.list.icon),
              label: entry.list.name,
              depth: entry.depth,
              smart: entry.list.kind == ListKind.smart,
            ),
        ];
    }
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final host = Uri.tryParse(session.server.baseUrl)?.host ?? '';
    final name = session.user.displayName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppConfig.appName,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.popover,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.legend,
    this.busy = false,
  });

  final String title;

  /// What the numbers on the right mean.
  final String legend;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                color: AppColors.muted,
              ),
            ),
          ),
          if (busy)
            const Tooltip(
              message: 'Updating counts',
              child: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            legend,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.leading,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.depth = 0,
    this.smart = false,
    this.totalOnly = false,
  });

  final Widget leading;
  final String label;
  final ItemCount? count;
  final bool selected;
  final VoidCallback onTap;
  final int depth;
  final bool smart;

  /// Only the total shows: Archived (its unarchived count is always 0) and
  /// tags (counting each would cost a request per tag).
  final bool totalOnly;

  @override
  Widget build(BuildContext context) {
    final countText = _countText();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? AppColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.0 + depth * 18, 11, 12, 11),
            child: Row(
              children: [
                SizedBox(width: 22, child: Center(child: leading)),
                const SizedBox(width: 12),
                // Label (+ smart badge) takes the free space so counts
                // line up on the right edge.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.foreground
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      if (smart)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: AppColors.muted,
                            semanticLabel: 'Smart list',
                          ),
                        ),
                    ],
                  ),
                ),
                if (countText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      countText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _countText() {
    final count = this.count;
    if (count == null) return null;
    if (totalOnly) return '${count.total}';
    return '${count.unarchived ?? '…'} / ${count.total}';
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 20, color: AppColors.mutedForeground);
}

class _Emoji extends StatelessWidget {
  const _Emoji(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) =>
      Text(emoji, style: const TextStyle(fontSize: 17));
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.destructive),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              child: Center(
                child: Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
