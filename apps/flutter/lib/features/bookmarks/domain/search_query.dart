import 'entities/bookmark_scope.dart';

/// Builds a Karakeep search query (packages/shared/searchQueryParser.ts)
/// from free text plus the screen's filters.
///
/// [within] narrows to a scope; [includeArchived] false adds `-is:archived`
/// (ignored when searching the archive itself).
String buildSearchQuery(
  String text, {
  BookmarkScope? within,
  bool includeArchived = true,
}) {
  final parts = <String>[
    if (text.trim().isNotEmpty) text.trim(),
    ?switch (within) {
      FavouritesScope() => 'is:fav',
      ArchivedScope() => 'is:archived',
      ListScope(:final name) => 'list:${_quote(name)}',
      TagScope(:final name) => '#${_quote(name)}',
      AllScope() || null => null,
    },
    if (!includeArchived && within is! ArchivedScope) '-is:archived',
  ];
  return parts.join(' ');
}

/// Quotes values with spaces or specials. The parser has no escape for `"`,
/// so any are dropped.
String _quote(String value) {
  final clean = value.replaceAll('"', '');
  return RegExp(r'^[\w\-.]+$').hasMatch(clean) ? clean : '"$clean"';
}
