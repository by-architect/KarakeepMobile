import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../state/home_feed_state.dart';
import '../viewmodels/home_feed_view_model.dart';
import '../viewmodels/lists_nav_view_model.dart';
import '../widgets/bookmark_card.dart';
import '../widgets/lists_drawer.dart';

/// Home: the bookmark feed for the scope picked in the drawer.
class BookmarksHomeScreen extends ConsumerStatefulWidget {
  const BookmarksHomeScreen({super.key});

  @override
  ConsumerState<BookmarksHomeScreen> createState() =>
      _BookmarksHomeScreenState();
}

class _BookmarksHomeScreenState extends ConsumerState<BookmarksHomeScreen> {
  final _scrollController = ScrollController();

  HomeFeedViewModel get _vm => ref.read(homeFeedViewModelProvider.notifier);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _select(BookmarkScope scope) {
    Navigator.of(context).pop(); // close the drawer
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _vm.selectScope(scope);
  }

  Future<void> _refresh() => Future.wait([
        _vm.refresh(),
        ref.read(listsNavViewModelProvider.notifier).refresh(),
      ]);

  Future<void> _open(Bookmark bookmark) async {
    final url = switch (bookmark.content) {
      LinkContent(:final url) => url,
      TextContent(:final sourceUrl?) => sourceUrl,
      AssetContent(:final sourceUrl?) => sourceUrl,
      _ => null,
    };
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeFeedViewModelProvider);
    // Keep the drawer's data alive (and counting) while home is shown.
    ref.watch(listsNavViewModelProvider.select((s) => s.status));

    return Scaffold(
      onDrawerChanged: (open) {
        if (open) ref.read(listsNavViewModelProvider.notifier).refreshIfStale();
      },
      drawer: ListsDrawer(selected: state.scope, onSelect: _select),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Lists',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: _ScopeTitle(scope: state.scope),
        actions: [
          _FilterMenu(
            showArchived: state.showArchived,
            enabled: state.archivedFilterApplies,
            onChanged: _vm.setShowArchived,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _body(state),
      ),
    );
  }

  Widget _body(HomeFeedState state) {
    switch (state.status) {
      case FeedStatus.loading:
        return const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case FeedStatus.error:
        return _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn’t load bookmarks',
          body: state.error,
          action: TextButton(onPressed: _vm.retry, child: const Text('Retry')),
        );
      case FeedStatus.ready when state.bookmarks.isEmpty:
        return _Message(
          icon: Icons.bookmark_border_rounded,
          title: _emptyTitle(state.scope),
          body: state.archivedFilterApplies && !state.showArchived
              ? 'Archived items are hidden. Turn on “Show archived” to see them.'
              : null,
        );
      case FeedStatus.ready:
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 800) _vm.loadMore();
            return false;
          },
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: state.bookmarks.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == state.bookmarks.length) return _footer(state);
              final bookmark = state.bookmarks[i];
              return BookmarkCard(
                key: ValueKey(bookmark.id),
                bookmark: bookmark,
                onTap: () => _open(bookmark),
              );
            },
          ),
        );
    }
  }

  Widget _footer(HomeFeedState state) {
    if (state.loadMoreError != null) {
      return Column(
        children: [
          InlineBanner(message: state.loadMoreError!),
          TextButton(onPressed: _vm.loadMore, child: const Text('Try again')),
        ],
      );
    }
    if (state.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  static String _emptyTitle(BookmarkScope scope) => switch (scope) {
        AllScope() => 'No bookmarks yet',
        FavouritesScope() => 'No favorites yet',
        ArchivedScope() => 'Nothing archived',
        ListScope() => 'This list is empty',
      };
}

class _ScopeTitle extends StatelessWidget {
  const _ScopeTitle({required this.scope});

  final BookmarkScope scope;

  @override
  Widget build(BuildContext context) {
    final (String? emoji, String label) = switch (scope) {
      AllScope() => (null, 'All bookmarks'),
      FavouritesScope() => (null, 'Favorites'),
      ArchivedScope() => (null, 'Archived'),
      ListScope(:final icon, :final name) => (icon, name),
    };
    return Row(
      children: [
        if (emoji != null) ...[
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.showArchived,
    required this.enabled,
    required this.onChanged,
  });

  final bool showArchived;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = enabled && showArchived;
    return PopupMenuButton<bool>(
      tooltip: 'Filter',
      color: AppColors.popover,
      icon: Badge(
        isLabelVisible: active,
        smallSize: 7,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.filter_list_rounded),
      ),
      onSelected: onChanged,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: !showArchived,
          checked: showArchived,
          enabled: enabled,
          child: const Text('Show archived'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh works on empty and error states too.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      body!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
