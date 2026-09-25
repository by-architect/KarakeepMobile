import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../bookmarks_providers.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_scope.dart';
import '../../domain/feed_rules.dart';
import '../../domain/repositories/bookmarks_repository.dart';
import '../../domain/search_query.dart';
import '../feed_host.dart';
import '../state/search_state.dart';
import 'home_feed_view_model.dart';

/// Search screen. Starts inside whatever home is showing (list, tag,
/// favorites…) with home's archive filter; both can be changed here.
class SearchViewModel extends Notifier<SearchState> with BookmarkFeedHost {
  static const debounce = Duration(milliseconds: 350);

  Timer? _debounce;
  var _generation = 0;

  BookmarksRepository get _repo => ref.read(bookmarksRepositoryProvider);

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    final home = ref.read(homeFeedViewModelProvider);
    return SearchState(
      within: home.scope is AllScope ? null : home.scope,
      includeArchived: home.showArchived,
    );
  }

  // ── BookmarkFeedHost ──────────────────────────────────────────────────

  @override
  List<Bookmark> get items => state.results;

  @override
  set items(List<Bookmark> value) => state = state.copyWith(results: value);

  @override
  bool get isActive => ref.mounted;

  @override
  bool get canLoadMore => state.hasMore;

  @override
  bool keeps(Bookmark bookmark) => belongsInFeed(
        bookmark,
        state.within,
        includeArchived: state.includeArchived,
      );

  // ── Query ─────────────────────────────────────────────────────────────

  /// Typing: search after a short pause.
  void textChanged(String text) {
    state = state.copyWith(text: text);
    _debounce?.cancel();
    _debounce = Timer(debounce, search);
  }

  /// Keyboard "search" or a filter change: search now.
  Future<void> search() async {
    _debounce?.cancel();
    final generation = ++_generation;
    if (state.text.trim().isEmpty) {
      state = state.copyWith(
        status: SearchStatus.idle,
        results: const [],
        nextCursor: () => null,
        error: () => null,
      );
      return;
    }
    state = state.copyWith(status: SearchStatus.loading, error: () => null);
    try {
      final page = await _repo.search(_query());
      if (!_current(generation)) return;
      state = state.copyWith(
        status: SearchStatus.ready,
        results: page.bookmarks,
        nextCursor: () => page.nextCursor,
        loadingMore: false,
      );
    } on Failure catch (f) {
      if (!_current(generation)) return;
      state = state.copyWith(status: SearchStatus.error, error: () => f.message);
    }
  }

  @override
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore) return;
    if (state.status != SearchStatus.ready) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.search(_query(), cursor: cursor);
      if (!_current(generation)) return;
      state = state.copyWith(
        results: [...state.results, ...page.bookmarks],
        nextCursor: () => page.nextCursor,
        loadingMore: false,
      );
    } on Failure {
      if (!_current(generation)) return;
      // Stop paging; the results so far stay.
      state = state.copyWith(loadingMore: false, nextCursor: () => null);
    }
  }

  /// Drop the scope filter and search everywhere.
  Future<void> clearScope() {
    state = state.copyWith(within: () => null);
    return search();
  }

  Future<void> setIncludeArchived(bool value) {
    state = state.copyWith(includeArchived: value);
    return search();
  }

  /// Adds a query-language token (e.g. `is:fav`) from the help chips.
  void insertToken(String token) {
    final text = state.text.trimRight();
    textChanged(text.isEmpty ? '$token ' : '$text $token ');
  }

  String _query() => buildSearchQuery(
        state.text,
        within: state.within,
        includeArchived: state.includeArchived,
      );

  bool _current(int generation) => ref.mounted && generation == _generation;
}

final searchViewModelProvider =
    NotifierProvider.autoDispose<SearchViewModel, SearchState>(
  SearchViewModel.new,
);
