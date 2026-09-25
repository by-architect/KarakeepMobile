import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../feed_host.dart';
import '../open_bookmark.dart';
import '../state/search_state.dart';
import '../viewmodels/search_view_model.dart';
import '../widgets/bookmark_card.dart';
import '../widgets/swipeable_bookmark.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();

  SearchViewModel get _vm => ref.read(searchViewModelProvider.notifier);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);

    // Help chips edit the text from the view model side.
    ref.listen(searchViewModelProvider.select((s) => s.text), (_, text) {
      if (_field.text != text) {
        _field.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          controller: _field,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 17),
          decoration: const InputDecoration(hintText: 'Search bookmarks'),
          onChanged: _vm.textChanged,
          onSubmitted: (_) => _vm.search(),
        ),
        actions: [
          if (state.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _field.clear();
                _vm.textChanged('');
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Filters(state: state, vm: _vm),
          Expanded(child: _results(state)),
        ],
      ),
    );
  }

  Widget _results(SearchState state) {
    switch (state.status) {
      case SearchStatus.idle:
        return _SyntaxHelp(onToken: _vm.insertToken);
      case SearchStatus.loading:
        return const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case SearchStatus.error:
        return _Centered(
          icon: Icons.cloud_off_rounded,
          title: 'Search failed',
          body: state.error,
        );
      case SearchStatus.ready when state.results.isEmpty:
        return const _Centered(
          icon: Icons.search_off_rounded,
          title: 'No matches',
        );
      case SearchStatus.ready:
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 800) _vm.loadMore();
            return false;
          },
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: state.results.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == state.results.length) {
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
              final bookmark = state.results[i];
              return SwipeableBookmark(
                key: ValueKey(bookmark.id),
                host: _vm,
                bookmark: bookmark,
                child: BookmarkCard(
                  bookmark: bookmark,
                  onTap: () => openBookmark(
                    context,
                    ref,
                    bookmark,
                    source: FeedSource.search,
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.vm});

  final SearchState state;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final within = state.within;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (within != null)
            InputChip(
              label: Text('In ${_scopeLabel(within)}'),
              onDeleted: vm.clearScope,
              deleteButtonTooltipMessage: 'Search everywhere',
              backgroundColor: AppColors.card,
              side: BorderSide.none,
            ),
          if (state.archivedToggleApplies)
            FilterChip(
              label: const Text('Include archived'),
              selected: state.includeArchived,
              onSelected: vm.setIncludeArchived,
              backgroundColor: AppColors.card,
              selectedColor: AppColors.primary.withValues(alpha: 0.25),
              checkmarkColor: AppColors.foreground,
              side: BorderSide.none,
            ),
        ],
      ),
    );
  }

  static String _scopeLabel(BookmarkScope scope) => switch (scope) {
        AllScope() => 'All bookmarks',
        FavouritesScope() => 'Favorites',
        ArchivedScope() => 'Archived',
        ListScope(:final icon, :final name) => '$icon $name',
        TagScope(:final name) => '#$name',
      };
}

/// Shown before typing: the query syntax, tappable.
class _SyntaxHelp extends StatelessWidget {
  const _SyntaxHelp({required this.onToken});

  final ValueChanged<String> onToken;

  static const _examples = [
    ('is:fav', 'favorites'),
    ('#tag', 'has a tag'),
    ('url:github.com', 'address contains'),
    ('title:flutter', 'title contains'),
    ('is:link', 'links only'),
    ('after:2026-01-01', 'saved after'),
    ('age:<1w', 'saved this week'),
    ('-is:tagged', 'untagged'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Type words to search titles and content, or narrow it down:',
          style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (token, meaning) in _examples)
              ActionChip(
                backgroundColor: AppColors.card,
                side: BorderSide.none,
                label: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: token,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      TextSpan(
                        text: '  $meaning',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                onPressed: () => onToken(token),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Combine with spaces (and), “or”, parentheses, and “-” to exclude.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
