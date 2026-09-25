import '../../domain/entities/bookmark_list.dart';

/// A list placed in the tree: children follow their parent, indented.
class ListEntry {
  const ListEntry({required this.list, required this.depth});

  final BookmarkList list;
  final int depth;
}

enum ListsStatus { loading, ready, error }

class ListsNavState {
  const ListsNavState({
    this.status = ListsStatus.loading,
    this.lists = const [],
    this.tags = const [],
    this.tagsLoaded = false,
    this.tagsError,
    this.showAllTags = false,
    this.counts = const {},
    this.counting = false,
    this.error,
  });

  final ListsStatus status;
  final List<ListEntry> lists;

  /// Most used first.
  final List<TagSummary> tags;
  final bool tagsLoaded;

  /// Tags load on their own; a failure here doesn't hide the lists.
  final String? tagsError;

  /// The drawer shows the top tags until the user expands them.
  final bool showAllTags;

  /// By scope key (`all`, `favourites`, `archived`, `list:<id>`).
  final Map<String, ItemCount> counts;

  /// Unarchived counts are still being computed.
  final bool counting;
  final String? error;

  ListsNavState copyWith({
    ListsStatus? status,
    List<ListEntry>? lists,
    List<TagSummary>? tags,
    bool? tagsLoaded,
    String? Function()? tagsError,
    bool? showAllTags,
    Map<String, ItemCount>? counts,
    bool? counting,
    String? Function()? error,
  }) {
    return ListsNavState(
      status: status ?? this.status,
      lists: lists ?? this.lists,
      tags: tags ?? this.tags,
      tagsLoaded: tagsLoaded ?? this.tagsLoaded,
      tagsError: tagsError != null ? tagsError() : this.tagsError,
      showAllTags: showAllTags ?? this.showAllTags,
      counts: counts ?? this.counts,
      counting: counting ?? this.counting,
      error: error != null ? error() : this.error,
    );
  }
}
