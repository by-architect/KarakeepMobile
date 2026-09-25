import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../auth/auth_providers.dart';
import 'data/datasources/local/home_preferences_local_data_source.dart';
import 'data/datasources/remote/bookmarks_remote_data_source.dart';
import 'data/repositories/bookmarks_repository_impl.dart';
import 'domain/repositories/bookmarks_repository.dart';
import 'domain/repositories/home_preferences_repository.dart';

/// Composition root for the bookmarks feature.
final bookmarksRepositoryProvider = Provider<BookmarksRepository>((ref) {
  return BookmarksRepositoryImpl(
    BookmarksRemoteDataSource(ref.watch(apiClientProvider)),
  );
});

final homePreferencesProvider = Provider<HomePreferencesRepository>((ref) {
  return HomePreferencesLocalDataSource(ref.watch(sharedPreferencesProvider));
});

/// Scopes per-account preferences and caches: same user on another server
/// is a different account.
final accountKeyProvider = Provider<String>((ref) {
  final session = ref.watch(currentSessionProvider);
  return '${session.server.baseUrl}|${session.user.id}';
});
