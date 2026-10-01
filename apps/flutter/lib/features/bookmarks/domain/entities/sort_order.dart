import 'bookmark.dart';

/// Order of a page from the server by when the items were saved — the only
/// order Karakeep can sort by itself.
enum SortOrder { newestFirst, oldestFirst }

/// What a feed is sorted by.
enum SortField { dateAdded, title, website }

/// How the home feed is sorted: a field, and whether it's turned around.
/// Not reversed means newest first for dates and A→Z for text.
class FeedSort {
  const FeedSort({this.field = SortField.dateAdded, this.reversed = false});

  final SortField field;
  final bool reversed;

  bool get isDefault => field == SortField.dateAdded && !reversed;

  /// Whether the server can sort this way. Otherwise the whole feed is
  /// loaded and sorted here.
  bool get byServer => field == SortField.dateAdded;

  /// The server order to ask for: the sort itself for dates, newest first
  /// (a stable start before sorting here) for the rest.
  SortOrder get serverOrder => byServer && reversed
      ? SortOrder.oldestFirst
      : SortOrder.newestFirst;

  FeedSort copyWith({SortField? field, bool? reversed}) => FeedSort(
        field: field ?? this.field,
        reversed: reversed ?? this.reversed,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedSort && other.field == field && other.reversed == reversed;

  @override
  int get hashCode => Object.hash(field, reversed);
}

/// [bookmarks] sorted by [sort]'s field when the server couldn't do it.
/// Items without a website (notes, uploads) go last; ties keep date order.
List<Bookmark> sortLocally(List<Bookmark> bookmarks, FeedSort sort) {
  if (sort.byServer) return bookmarks;
  String? key(Bookmark b) => switch (sort.field) {
        SortField.title => b.displayTitle.trim().toLowerCase(),
        SortField.website => switch (b.content) {
            LinkContent(:final domain) => domain.toLowerCase(),
            _ => null,
          },
        SortField.dateAdded => null,
      };
  final indexed = [
    for (final (i, b) in bookmarks.indexed) (i: i, key: key(b), b: b),
  ];
  indexed.sort((x, y) {
    final a = x.key, b = y.key;
    if (a == null || b == null) {
      if (a == b) return x.i.compareTo(y.i);
      return a == null ? 1 : -1;
    }
    final c = sort.reversed ? b.compareTo(a) : a.compareTo(b);
    return c != 0 ? c : x.i.compareTo(y.i);
  });
  return [for (final e in indexed) e.b];
}
