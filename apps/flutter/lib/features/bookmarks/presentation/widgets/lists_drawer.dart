import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/presentation/viewmodels/session_controller.dart';
import '../../domain/entities/bookmark_list.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../state/lists_nav_state.dart';
import '../viewmodels/lists_nav_view_model.dart';

/// Left drawer: pick what the feed shows. Every row carries
/// `unarchived / total`.
class ListsDrawer extends ConsumerWidget {
  const ListsDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final BookmarkScope selected;
  final ValueChanged<BookmarkScope> onSelect;

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
    }) {
      return _ScopeRow(
        leading: leading,
        label: label,
        depth: depth,
        smart: smart,
        count: state.counts[scope.key],
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
                    _SectionHeader(counting: state.counting),
                    ..._lists(state, scopeRow, vm),
                  ],
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.destructive, size: 20),
              title: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.destructive, fontSize: 15),
              ),
              onTap: () => ref.read(sessionControllerProvider.notifier).signOut(),
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
    }) scopeRow,
    ListsNavViewModel vm,
  ) {
    switch (state.status) {
      case ListsStatus.loading when state.lists.isEmpty:
        return const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ];
      case ListsStatus.error:
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              state.error ?? 'Couldn’t load lists.',
              style: const TextStyle(fontSize: 13, color: AppColors.destructive),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: vm.refresh, child: const Text('Retry')),
          ),
        ];
      case _ when state.lists.isEmpty:
        return const [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              'No lists yet. Create them on the web for now.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ];
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
  const _SectionHeader({required this.counting});

  final bool counting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'LISTS',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.4,
                color: AppColors.muted,
              ),
            ),
          ),
          if (counting)
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
          const Text(
            'unarchived / total',
            maxLines: 1,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
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

  /// Archived: its unarchived count is always 0, so only the total shows.
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
