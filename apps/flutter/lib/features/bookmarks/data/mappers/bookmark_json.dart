import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_list.dart';

/// JSON → entities. REST and tRPC return the same bookmark shape
/// (packages/shared/types/bookmarks.ts `zBookmarkSchema`).
abstract final class BookmarkJson {
  static Bookmark bookmark(Map<String, Object?> json) {
    final tags = json['tags'];
    return Bookmark(
      id: json['id']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      title: json['title'] as String?,
      archived: json['archived'] == true,
      favourited: json['favourited'] == true,
      note: json['note'] as String?,
      summary: json['summary'] as String?,
      tags: tags is List
          ? [
              for (final t in tags.whereType<Map<String, Object?>>())
                BookmarkTag(id: t['id']! as String, name: t['name']! as String),
            ]
          : const [],
      content: _content(json['content']),
    );
  }

  static BookmarkContent _content(Object? json) {
    if (json is! Map<String, Object?>) return const UnknownContent();
    switch (json['type']) {
      case 'link':
        return LinkContent(
          url: json['url']! as String,
          title: json['title'] as String?,
          description: json['description'] as String?,
          imageUrl: json['imageUrl'] as String?,
          imageAssetId: json['imageAssetId'] as String?,
          screenshotAssetId: json['screenshotAssetId'] as String?,
          favicon: json['favicon'] as String?,
          publisher: json['publisher'] as String?,
        );
      case 'text':
        return TextContent(
          text: json['text'] as String? ?? '',
          sourceUrl: json['sourceUrl'] as String?,
        );
      case 'asset':
        return AssetContent(
          assetType:
              json['assetType'] == 'pdf' ? AssetKind.pdf : AssetKind.image,
          assetId: json['assetId']! as String,
          fileName: json['fileName'] as String?,
          sourceUrl: json['sourceUrl'] as String?,
        );
      default:
        return const UnknownContent();
    }
  }

  static BookmarkList list(Map<String, Object?> json) => BookmarkList(
        id: json['id']! as String,
        name: json['name']! as String,
        icon: json['icon'] as String? ?? '📋',
        parentId: json['parentId'] as String?,
        kind: json['type'] == 'smart' ? ListKind.smart : ListKind.manual,
      );
}
