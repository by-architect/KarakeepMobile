import '../entities/bookmark_list.dart';
import '../entities/bookmark_scope.dart';

/// What the home screen remembers on this device between launches.
/// Reads are synchronous so the first frame already reflects them.
abstract interface class HomePreferencesRepository {
  bool get showArchived;
  Future<void> setShowArchived(bool value);

  /// Last selected scope for the account, or null.
  BookmarkScope? lastScope(String accountKey);
  Future<void> setLastScope(String accountKey, BookmarkScope scope);

  /// Last known counts per scope key, shown instantly while fresh counts load.
  Map<String, ItemCount> cachedCounts(String accountKey);
  Future<void> setCachedCounts(String accountKey, Map<String, ItemCount> counts);
}
