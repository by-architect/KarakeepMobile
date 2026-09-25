/// Which bookmarks the home feed shows.
sealed class BookmarkScope {
  const BookmarkScope();

  /// Stable key for storage and for identifying counts.
  String get key;

  static BookmarkScope? fromKey(String key, {String? name, String? icon}) {
    return switch (key) {
      AllScope.keyValue => const AllScope(),
      FavouritesScope.keyValue => const FavouritesScope(),
      ArchivedScope.keyValue => const ArchivedScope(),
      _ when key.startsWith(ListScope.prefix) => ListScope(
          id: key.substring(ListScope.prefix.length),
          name: name ?? 'List',
          icon: icon ?? '📋',
        ),
      _ when key.startsWith(TagScope.prefix) => TagScope(
          id: key.substring(TagScope.prefix.length),
          name: name ?? 'tag',
        ),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BookmarkScope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

final class AllScope extends BookmarkScope {
  const AllScope();
  static const keyValue = 'all';
  @override
  String get key => keyValue;
}

final class FavouritesScope extends BookmarkScope {
  const FavouritesScope();
  static const keyValue = 'favourites';
  @override
  String get key => keyValue;
}

/// Only archived items, so "show archived" doesn't apply here.
final class ArchivedScope extends BookmarkScope {
  const ArchivedScope();
  static const keyValue = 'archived';
  @override
  String get key => keyValue;
}

final class ListScope extends BookmarkScope {
  const ListScope({required this.id, required this.name, required this.icon});

  static const prefix = 'list:';

  final String id;

  /// Kept with the scope so the title shows before lists have loaded.
  final String name;
  final String icon;

  @override
  String get key => '$prefix$id';
}

final class TagScope extends BookmarkScope {
  const TagScope({required this.id, required this.name});

  static const prefix = 'tag:';

  final String id;

  /// Kept with the scope so the title shows before tags have loaded.
  final String name;

  @override
  String get key => '$prefix$id';
}
