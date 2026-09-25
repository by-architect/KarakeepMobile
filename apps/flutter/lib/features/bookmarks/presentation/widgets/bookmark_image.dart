import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/bookmark.dart';

/// Loads an [ImageRef], disk-cached. Server images carry the session's
/// headers; external images get none, so the API key never leaves the server.
class BookmarkImage extends ConsumerWidget {
  const BookmarkImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  final ImageRef image;
  final BoxFit fit;

  /// Shown when the image fails. Defaults to a plain placeholder.
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (url, headers) = switch (image) {
      ServerImage(:final assetId) => (
          ref.watch(apiClientProvider).assetUrl(assetId),
          ref.watch(apiClientProvider).serverHeaders,
        ),
      ExternalImage(:final url) => (url, null),
    };
    final placeholder = fallback ?? const ColoredBox(color: AppColors.popover);
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => const ColoredBox(color: AppColors.popover),
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
