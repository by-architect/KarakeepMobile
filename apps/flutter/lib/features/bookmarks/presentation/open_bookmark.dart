import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/presentation/settings_view_model.dart';
import '../domain/entities/bookmark.dart';
import 'feed_host.dart';

/// Opens a bookmark the way Settings says: the in-app viewer (with actions
/// and swiping through [source]'s feed) or the phone's browser app.
/// Notes and uploads always open in the viewer — there's no page to visit.
Future<void> openBookmark(
  BuildContext context,
  WidgetRef ref,
  Bookmark bookmark, {
  required FeedSource source,
}) async {
  final mode = ref.read(settingsViewModelProvider).linkOpenMode;
  if (bookmark.content case LinkContent(:final url)
      when mode == LinkOpenMode.externalBrowser) {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn’t open this link.')),
      );
    }
    return;
  }
  await context.push(Routes.viewer(bookmark.id, from: source.name));
}
