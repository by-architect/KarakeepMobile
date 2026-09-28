import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/settings_repository.dart';
import '../../../settings/presentation/settings_view_model.dart';
import '../../domain/entities/bookmark.dart';
import '../bookmark_ui_actions.dart';
import '../feed_host.dart';
import '../widgets/bookmark_page_views.dart';
import '../widgets/bookmark_sheets.dart';

/// Reads bookmarks one at a time, in the order of the feed they were opened
/// from. Swipe left/right for next/previous; the toolbar acts on the one
/// shown. Items the feed drops (e.g. archived while archived are hidden)
/// disappear here too and the next one slides in — from the server's next
/// page when the loaded ones run out. Closes when nothing is left.
class BookmarkViewerScreen extends ConsumerStatefulWidget {
  const BookmarkViewerScreen({
    super.key,
    required this.bookmarkId,
    required this.source,
  });

  final String bookmarkId;
  final FeedSource source;

  @override
  ConsumerState<BookmarkViewerScreen> createState() =>
      _BookmarkViewerScreenState();
}

class _BookmarkViewerScreenState extends ConsumerState<BookmarkViewerScreen> {
  late final PageController _pages;
  late int _index;

  /// The bookmark on screen; tracked by id so removals don't lose our place.
  /// Null on the page after the last one, while more are loading.
  String? _currentId;

  BookmarkFeedHost get _host => feedHost(ref, widget.source);

  @override
  void initState() {
    super.initState();
    _index = _host.indexOf(widget.bookmarkId).clamp(0, 1 << 30);
    _currentId = widget.bookmarkId;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, List<Bookmark> items) {
    setState(() {
      _index = index;
      _currentId = index < items.length ? items[index].id : null;
    });
  }

  /// After the feed changed, keep showing the same bookmark — or, if it was
  /// removed, whatever now sits at its position: the next one, or the
  /// loading page when the next ones aren't here yet. Runs during build;
  /// only the page jump waits for the frame.
  void _sync(List<Bookmark> items, int pageCount) {
    final id = _currentId;
    final byId = id == null ? -1 : items.indexWhere((b) => b.id == id);
    if (byId >= 0 && byId == _index) return;
    final target = byId >= 0 ? byId : _index.clamp(0, pageCount - 1);
    _index = target;
    _currentId = target < items.length ? items[target].id : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients && _pages.page?.round() != target) {
        _pages.jumpToPage(target);
      }
    });
  }

  /// Fetch the server's next page while a few loaded ones are still ahead —
  /// whether we got here by swiping or because archiving moved us along.
  void _loadMoreIfNear(FeedView feed) {
    if (!feed.hasMore || feed.loadingMore || feed.error != null) return;
    if (_index < feed.items.length - 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _host.loadMore();
    });
  }

  /// Show [b] again once Undo brings it back.
  void _showAgain(Bookmark b) => _currentId = b.id;

  Future<void> _share(Bookmark b) async {
    final url = b.url;
    if (url == null) {
      if (b.content case TextContent(:final text)) {
        await SharePlus.instance.share(ShareParams(text: text));
      }
      return;
    }
    await SharePlus.instance.share(ShareParams(text: url, subject: b.displayTitle));
  }

  Future<void> _openExternally(Bookmark b) async {
    final url = b.url;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final feed = watchFeed(ref, widget.source);
    final items = feed.items;
    final mode = ref.watch(settingsViewModelProvider.select((s) => s.viewerMode));
    final pageBuilder = ref.watch(bookmarkPageBuilderProvider);

    // One page per bookmark, plus one that waits for the server's next page.
    final pageCount = items.length + (feed.hasMore ? 1 : 0);
    if (pageCount == 0) {
      // Everything was archived or deleted away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }
    _sync(items, pageCount);
    _loadMoreIfNear(feed);
    final current = _index < items.length ? items[_index] : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: current == null
            ? const Text(
                'Loading more…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              )
            : _TitleMenu(
                bookmark: current,
                mode: mode,
                onMode:
                    ref.read(settingsViewModelProvider.notifier).setViewerMode,
              ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: pageCount,
        onPageChanged: (i) => _onPageChanged(i, items),
        itemBuilder: (context, i) => i < items.length
            ? KeyedSubtree(
                key: ValueKey('${items[i].id}-${mode.name}'),
                child: pageBuilder(items[i], mode),
              )
            : _MorePage(error: feed.error, onRetry: _host.loadMore),
      ),
      bottomNavigationBar: current == null ? null : _toolbar(current, feed),
    );
  }

  Widget _toolbar(Bookmark current, FeedView feed) {
    return _Toolbar(
      bookmark: current,
      position: '${_index + 1} / ${feed.items.length}${feed.hasMore ? '+' : ''}',
      onLists: () => showListsSheet(context, host: _host, bookmark: current),
      onFavourite: () => favouriteWithUndo(context, ref, _host, current),
      onShare: () => _share(current),
      onBrowser: current.url == null ? null : () => _openExternally(current),
      onArchive: () => archiveWithUndo(
        context,
        ref,
        _host,
        current,
        onUndo: () => _showAgain(current),
      ),
      onDelete: () => deleteWithUndo(
        context,
        ref,
        _host,
        current,
        onUndo: () => _showAgain(current),
      ),
      onTags: () => showTagsSheet(context, host: _host, bookmark: current),
      onCopy: current.url == null
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: current.url!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied')),
              );
            },
    );
  }
}

/// The page after the last loaded bookmark: a spinner while the server's
/// next page loads, or why it didn't.
class _MorePage extends StatelessWidget {
  const _MorePage({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _TitleMenu extends StatelessWidget {
  const _TitleMenu({
    required this.bookmark,
    required this.mode,
    required this.onMode,
  });

  final Bookmark bookmark;
  final ViewerMode mode;
  final ValueChanged<ViewerMode> onMode;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      bookmark.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
    if (bookmark.content is! LinkContent) return title;

    return PopupMenuButton<ViewerMode>(
      tooltip: 'View',
      color: AppColors.popover,
      initialValue: mode,
      onSelected: onMode,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: ViewerMode.browser,
          child: ListTile(
            leading: Icon(Icons.public_rounded),
            title: Text('Browser'),
            subtitle: Text('The live page'),
          ),
        ),
        PopupMenuItem(
          value: ViewerMode.reader,
          child: ListTile(
            leading: Icon(Icons.chrome_reader_mode_outlined),
            title: Text('Reader'),
            subtitle: Text('Karakeep’s saved article'),
          ),
        ),
      ],
      child: Row(
        children: [
          Flexible(child: title),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, color: AppColors.muted),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.bookmark,
    required this.position,
    required this.onLists,
    required this.onFavourite,
    required this.onShare,
    required this.onBrowser,
    required this.onArchive,
    required this.onDelete,
    required this.onTags,
    required this.onCopy,
  });

  final Bookmark bookmark;
  final String position;
  final VoidCallback onLists;
  final VoidCallback onFavourite;
  final VoidCallback onShare;
  final VoidCallback? onBrowser;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onTags;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _button(Icons.playlist_add_rounded, 'Lists', onLists),
                  _button(
                    bookmark.favourited
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    bookmark.favourited ? 'Unfavorite' : 'Favorite',
                    onFavourite,
                    color: bookmark.favourited ? AppColors.favourite : null,
                  ),
                  _button(Icons.ios_share_rounded, 'Share', onShare),
                  _button(Icons.public_rounded, 'Open in browser', onBrowser),
                  _button(
                    bookmark.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    bookmark.archived ? 'Unarchive' : 'Archive',
                    onArchive,
                    color: bookmark.archived ? AppColors.primary : null,
                  ),
                  _button(Icons.delete_outline_rounded, 'Delete', onDelete),
                  PopupMenuButton<VoidCallback>(
                    tooltip: 'More',
                    color: AppColors.popover,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: onTags,
                        child: const ListTile(
                          leading: Icon(Icons.tag_rounded),
                          title: Text('Tags'),
                        ),
                      ),
                      if (onCopy != null)
                        PopupMenuItem(
                          value: onCopy,
                          child: const ListTile(
                            leading: Icon(Icons.link_rounded),
                            title: Text('Copy link'),
                          ),
                        ),
                      PopupMenuItem(
                        enabled: false,
                        value: () {},
                        child: Text(
                          position,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
    );
  }
}
