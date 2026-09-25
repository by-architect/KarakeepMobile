import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/settings_repository.dart';
import '../../bookmarks_providers.dart';
import '../../domain/entities/bookmark.dart';
import 'bookmark_image.dart';

/// Builds the body of one viewer page. Swapped in tests, where platform
/// web views don't exist.
typedef BookmarkPageBuilder = Widget Function(Bookmark bookmark, ViewerMode mode);

final bookmarkPageBuilderProvider = Provider<BookmarkPageBuilder>(
  (ref) => (bookmark, mode) => BookmarkPageView(bookmark: bookmark, mode: mode),
);

/// Reader-view HTML for a bookmark, loaded once per page.
final readerHtmlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, id) {
  return ref.read(bookmarksRepositoryProvider).getReaderHtml(id);
});

/// One bookmark's content: the page (browser or reader) for links, the text
/// for notes, the image or a PDF opener for uploads.
class BookmarkPageView extends StatelessWidget {
  const BookmarkPageView({
    super.key,
    required this.bookmark,
    required this.mode,
  });

  final Bookmark bookmark;
  final ViewerMode mode;

  @override
  Widget build(BuildContext context) {
    return switch (bookmark.content) {
      LinkContent(:final url) => switch (mode) {
          ViewerMode.browser => _LivePage(url: url),
          ViewerMode.reader => _ReaderPage(bookmark: bookmark, url: url),
        },
      TextContent(:final text) => _TextPage(text: text),
      AssetContent(assetType: AssetKind.image, :final assetId) =>
        InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: BookmarkImage(
              image: ServerImage(assetId),
              fit: BoxFit.contain,
            ),
          ),
        ),
      AssetContent(:final assetId, :final fileName) =>
        _PdfPage(assetId: assetId, fileName: fileName),
      UnknownContent() => const _Notice(
          icon: Icons.help_outline_rounded,
          text: 'This kind of bookmark can’t be shown yet.',
        ),
    };
  }
}

/// The live website.
class _LivePage extends StatefulWidget {
  const _LivePage({required this.url});

  final String url;

  @override
  State<_LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<_LivePage> {
  late final WebViewController _controller;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // No gesture recognizers: horizontal drags stay with the page view
        // (next/previous bookmark), vertical ones scroll the site.
        WebViewWidget(controller: _controller),
        if (_progress < 100)
          LinearProgressIndicator(
            value: _progress / 100,
            minHeight: 2,
            color: AppColors.primary,
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }
}

/// Karakeep's saved article, styled for the black theme. Links inside open
/// in the browser app.
class _ReaderPage extends ConsumerStatefulWidget {
  const _ReaderPage({required this.bookmark, required this.url});

  final Bookmark bookmark;
  final String url;

  @override
  ConsumerState<_ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<_ReaderPage> {
  WebViewController? _controller;

  WebViewController _build(String html) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('http')) {
              launchUrl(
                Uri.parse(request.url),
                mode: LaunchMode.externalApplication,
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(
        readerDocument(widget.bookmark.displayTitle, widget.url, html),
        baseUrl: widget.url,
      );
  }

  @override
  Widget build(BuildContext context) {
    final html = ref.watch(readerHtmlProvider(widget.bookmark.id));
    return html.when(
      loading: () => const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => _Notice(
        icon: Icons.cloud_off_rounded,
        text: e is Failure ? e.message : 'Couldn’t load the article.',
      ),
      data: (content) {
        if (content == null) {
          return const _Notice(
            icon: Icons.chrome_reader_mode_outlined,
            text: 'No reader view for this page yet. Karakeep may still be '
                'crawling it — switch to Browser from the title menu.',
          );
        }
        return WebViewWidget(controller: _controller ??= _build(content));
      },
    );
  }
}

/// Wraps Karakeep's article HTML in a black, readable page.
String readerDocument(String title, String url, String body) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  final host = Uri.tryParse(url)?.host ?? '';
  return '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
html,body{background:#000;color:#e6e6ea;margin:0}
body{font:18px/1.65 -apple-system,Roboto,"Segoe UI",sans-serif;padding:20px 18px 96px;word-wrap:break-word}
h1{font-size:1.55em;line-height:1.25;color:#fff;margin:.2em 0 .3em}
.src{color:#707073;font-size:.8em;margin-bottom:1.6em}
h2,h3,h4{color:#fff;line-height:1.3}
a{color:#3b9dff}
img,video,iframe,figure{max-width:100%;height:auto}
figure{margin:1em 0}
figcaption{color:#a1a1a6;font-size:.85em}
pre,code{background:#151518;border-radius:6px;font-size:.88em}
pre{padding:12px;overflow-x:auto}
code{padding:2px 4px}
blockquote{border-left:3px solid #333;margin:1em 0;padding-left:14px;color:#a1a1a6}
table{border-collapse:collapse;display:block;overflow-x:auto}
td,th{border:1px solid #282828;padding:6px}
hr{border:0;border-top:1px solid #282828}
</style></head><body>
<h1>${esc(title)}</h1><div class="src">${esc(host)}</div>
$body
</body></html>''';
}

class _TextPage extends StatelessWidget {
  const _TextPage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 17, height: 1.6),
      ),
    );
  }
}

class _PdfPage extends ConsumerWidget {
  const _PdfPage({required this.assetId, this.fileName});

  final String assetId;
  final String? fileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 56,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(fileName ?? 'PDF', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final url = await ref
                      .read(bookmarksRepositoryProvider)
                      .openableAssetUrl(assetId);
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } on Failure catch (f) {
                  messenger.showSnackBar(SnackBar(content: Text(f.message)));
                }
              },
              child: const Text('Open PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}
