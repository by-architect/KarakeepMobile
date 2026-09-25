/// A saved item. Mirrors Karakeep's bookmark with only what the app shows.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.createdAt,
    required this.content,
    this.title,
    this.archived = false,
    this.favourited = false,
    this.note,
    this.summary,
    this.tags = const [],
  });

  final String id;

  /// When it was last saved (Karakeep moves re-saved links to the top).
  final DateTime createdAt;

  /// User-set title; overrides the crawled one.
  final String? title;
  final bool archived;
  final bool favourited;
  final String? note;
  final String? summary;
  final List<BookmarkTag> tags;
  final BookmarkContent content;

  String get displayTitle {
    final own = title?.trim();
    if (own != null && own.isNotEmpty) return own;
    return switch (content) {
      LinkContent(:final title, :final url) =>
        (title?.trim().isNotEmpty ?? false) ? title!.trim() : url,
      TextContent(:final text) => text.trim().split('\n').first,
      AssetContent(:final fileName, :final assetType) =>
        fileName ?? (assetType == AssetKind.pdf ? 'PDF' : 'Image'),
      UnknownContent() => 'Untitled',
    };
  }

  /// Picture for the card, following Karakeep's own priority:
  /// stored banner → screenshot → the page's image URL.
  ImageRef? get previewImage => switch (content) {
        LinkContent(:final imageAssetId?) => ServerImage(imageAssetId),
        LinkContent(:final screenshotAssetId?) =>
          ServerImage(screenshotAssetId),
        LinkContent(:final imageUrl?) => ExternalImage(imageUrl),
        AssetContent(assetType: AssetKind.image, :final assetId) =>
          ServerImage(assetId),
        _ => null,
      };
}

class BookmarkTag {
  const BookmarkTag({required this.id, required this.name});

  final String id;
  final String name;
}

sealed class BookmarkContent {
  const BookmarkContent();
}

final class LinkContent extends BookmarkContent {
  const LinkContent({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.imageAssetId,
    this.screenshotAssetId,
    this.favicon,
    this.publisher,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? imageAssetId;
  final String? screenshotAssetId;
  final String? favicon;
  final String? publisher;

  /// `www.example.com` → `example.com`; falls back to the raw URL.
  String get domain {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return url;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

final class TextContent extends BookmarkContent {
  const TextContent({required this.text, this.sourceUrl});

  final String text;
  final String? sourceUrl;
}

enum AssetKind { image, pdf }

final class AssetContent extends BookmarkContent {
  const AssetContent({
    required this.assetType,
    required this.assetId,
    this.fileName,
    this.sourceUrl,
  });

  final AssetKind assetType;
  final String assetId;
  final String? fileName;
  final String? sourceUrl;
}

/// A type this app doesn't know yet (newer server).
final class UnknownContent extends BookmarkContent {
  const UnknownContent();
}

/// Where a picture comes from. Server images need the session's headers;
/// external ones must never get them.
sealed class ImageRef {
  const ImageRef();
}

final class ServerImage extends ImageRef {
  const ServerImage(this.assetId);
  final String assetId;
}

final class ExternalImage extends ImageRef {
  const ExternalImage(this.url);
  final String url;
}
