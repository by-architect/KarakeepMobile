import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/viewmodels/session_controller.dart';
import '../domain/settings_repository.dart';
import '../settings_providers.dart';

class SettingsState {
  const SettingsState({
    required this.linkOpenMode,
    required this.viewerMode,
    required this.swipeRight,
    required this.swipeLeft,
    this.clearingCache = false,
  });

  final LinkOpenMode linkOpenMode;
  final ViewerMode viewerMode;
  final SwipeAction swipeRight;
  final SwipeAction swipeLeft;
  final bool clearingCache;

  SettingsState copyWith({
    LinkOpenMode? linkOpenMode,
    ViewerMode? viewerMode,
    SwipeAction? swipeRight,
    SwipeAction? swipeLeft,
    bool? clearingCache,
  }) =>
      SettingsState(
        linkOpenMode: linkOpenMode ?? this.linkOpenMode,
        viewerMode: viewerMode ?? this.viewerMode,
        swipeRight: swipeRight ?? this.swipeRight,
        swipeLeft: swipeLeft ?? this.swipeLeft,
        clearingCache: clearingCache ?? this.clearingCache,
      );
}

/// Device settings. "Show archived" isn't here: it belongs to the home feed
/// view model, which the settings screen drives directly so both stay in sync.
///
/// Kept alive: the feed (swipe actions) and viewer read it all the time.
class SettingsViewModel extends Notifier<SettingsState> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  SettingsState build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return SettingsState(
      linkOpenMode: repo.linkOpenMode,
      viewerMode: repo.viewerMode,
      swipeRight: repo.swipeRight,
      swipeLeft: repo.swipeLeft,
    );
  }

  Future<void> setLinkOpenMode(LinkOpenMode mode) async {
    state = state.copyWith(linkOpenMode: mode);
    await _repo.setLinkOpenMode(mode);
  }

  Future<void> setViewerMode(ViewerMode mode) async {
    state = state.copyWith(viewerMode: mode);
    await _repo.setViewerMode(mode);
  }

  Future<void> setSwipeRight(SwipeAction action) async {
    state = state.copyWith(swipeRight: action);
    await _repo.setSwipeRight(action);
  }

  Future<void> setSwipeLeft(SwipeAction action) async {
    state = state.copyWith(swipeLeft: action);
    await _repo.setSwipeLeft(action);
  }

  /// Completes when done, so the screen can confirm with a snackbar.
  Future<void> clearCache() async {
    if (state.clearingCache) return;
    state = state.copyWith(clearingCache: true);
    try {
      await ref.read(cacheCleanerProvider).clear();
    } finally {
      if (ref.mounted) state = state.copyWith(clearingCache: false);
    }
  }

  Future<void> signOut() =>
      ref.read(sessionControllerProvider.notifier).signOut();
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsState>(SettingsViewModel.new);
