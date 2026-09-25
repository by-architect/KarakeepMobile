enum ListKind { manual, smart }

/// A Karakeep list. Smart lists are saved searches.
class BookmarkList {
  const BookmarkList({
    required this.id,
    required this.name,
    required this.icon,
    this.parentId,
    this.kind = ListKind.manual,
  });

  final String id;
  final String name;

  /// An emoji.
  final String icon;
  final String? parentId;
  final ListKind kind;
}

/// `unarchived / total`, as shown in the list picker. [unarchived] is null
/// while it's still being counted.
class ItemCount {
  const ItemCount({required this.total, this.unarchived});

  final int total;
  final int? unarchived;
}
