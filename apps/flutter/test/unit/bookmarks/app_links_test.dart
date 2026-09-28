import 'package:flutter_test/flutter_test.dart';
import 'package:linkstow/features/bookmarks/presentation/widgets/bookmark_page_views.dart';

void main() {
  test('web pages load in the web view; app links don’t', () {
    for (final url in [
      'https://m.facebook.com/story.php?id=1',
      'http://example.com',
      'about:blank',
      'data:text/html,hi',
    ]) {
      expect(opensInWebView(Uri.parse(url)), isTrue, reason: url);
    }
    for (final url in [
      'fb://profile/100064860875397',
      'intent://profile/1#Intent;scheme=fb;end',
      'mailto:ada@example.com',
      'market://details?id=com.facebook.katana',
    ]) {
      expect(opensInWebView(Uri.parse(url)), isFalse, reason: url);
    }
  });

  test('intent:// links turn into the app’s own link', () {
    expect(
      appLinkTarget(
        Uri.parse(
          'intent://profile/100064860875397#Intent;scheme=fb;'
          'package=com.facebook.katana;'
          'S.browser_fallback_url=https%3A%2F%2Fm.facebook.com%2F;end',
        ),
      ),
      Uri.parse('fb://profile/100064860875397'),
    );
    // Without a scheme there's nothing to open.
    expect(
      appLinkTarget(Uri.parse('intent://x#Intent;package=com.a;end')),
      isNull,
    );
    expect(appLinkTarget(Uri.parse('fb://page/1')), Uri.parse('fb://page/1'));
  });
}
