import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/relative_time.dart';
import '../../domain/entities/bookmark.dart';
import 'bookmark_image.dart';

/// A bookmark as a link-preview card: banner, title, description, source and
/// tags — the layout Karakeep's own clients use.
class BookmarkCard extends StatelessWidget {
  const BookmarkCard({super.key, required this.bookmark, this.onTap});

  static const _maxTags = 4;

  final Bookmark bookmark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = bookmark.previewImage;
    final content = bookmark.content;
    final description = switch (content) {
      LinkContent(:final description) => description,
      TextContent(:final text) => text,
      _ => null,
    };
    final isTextNote = content is TextContent;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              AspectRatio(
                aspectRatio: 1.91, // Open Graph image ratio
                child: BookmarkImage(image: image),
              )
            else if (content case AssetContent(assetType: AssetKind.pdf))
              const _PdfBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isTextNote)
                    Text(
                      bookmark.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  if (description != null && description.trim().isNotEmpty) ...[
                    if (!isTextNote) const SizedBox(height: 4),
                    Text(
                      description.trim(),
                      maxLines: isTextNote ? 6 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTextNote ? 15 : 14,
                        height: 1.35,
                        color: isTextNote
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                  if (bookmark.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _Tags(tags: bookmark.tags, max: _maxTags),
                  ],
                  const SizedBox(height: 10),
                  _MetaRow(bookmark: bookmark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context) {
    final content = bookmark.content;
    final (Widget leading, String source) = switch (content) {
      LinkContent(:final favicon, :final domain) => (
          _Favicon(url: favicon),
          domain,
        ),
      TextContent() => (const _MetaIcon(Icons.notes_rounded), 'Note'),
      AssetContent(assetType: AssetKind.pdf) => (
          const _MetaIcon(Icons.picture_as_pdf_outlined),
          'PDF',
        ),
      AssetContent() => (const _MetaIcon(Icons.image_outlined), 'Image'),
      UnknownContent() => (const _MetaIcon(Icons.bookmark_outline), ''),
    };
    const meta = TextStyle(fontSize: 13, color: AppColors.muted);

    return Row(
      children: [
        leading,
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                ),
              ),
              Text(' · ${relativeTime(bookmark.createdAt)}', style: meta),
            ],
          ),
        ),
        if (bookmark.archived)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.archive_outlined,
              size: 16,
              color: AppColors.muted,
              semanticLabel: 'Archived',
            ),
          ),
        if (bookmark.favourited)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.star_rounded,
              size: 17,
              color: AppColors.favourite,
              semanticLabel: 'Favourite',
            ),
          ),
      ],
    );
  }
}

class _Favicon extends StatelessWidget {
  const _Favicon({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = _MetaIcon(Icons.public_rounded);
    final url = this.url;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox.square(
        dimension: 16,
        child: BookmarkImage(
          image: ExternalImage(url),
          fit: BoxFit.contain,
          fallback: fallback,
        ),
      ),
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 16, color: AppColors.muted);
}

class _Tags extends StatelessWidget {
  const _Tags({required this.tags, required this.max});

  final List<BookmarkTag> tags;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = tags.take(max).toList();
    final hidden = tags.length - shown.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in shown) _Chip('#${tag.name}'),
        if (hidden > 0) _Chip('+$hidden'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.popover,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
      ),
    );
  }
}

class _PdfBanner extends StatelessWidget {
  const _PdfBanner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 96,
      child: ColoredBox(
        color: AppColors.popover,
        child: Center(
          child: Icon(
            Icons.picture_as_pdf_outlined,
            size: 36,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
