/// Turns whatever the user typed into a server base URL.
///
/// Lenient on input: a bare host gets `https://`, and pasted API or page URLs
/// (`…/api/v1`, `…/signin`, `…/dashboard/…`) are cut back to the base. Keeps
/// a sub-path so servers hosted under e.g. `/karakeep` still work.
sealed class ServerUrlResult {
  const ServerUrlResult();
}

final class ValidServerUrl extends ServerUrlResult {
  const ValidServerUrl(this.url);
  final String url;
}

final class InvalidServerUrl extends ServerUrlResult {
  const InvalidServerUrl(this.message);
  final String message;
}

const _appRoutes = {'api', 'signin', 'signup', 'dashboard', 'settings', 'admin'};

ServerUrlResult normalizeServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) {
    return const InvalidServerUrl('Enter your server address.');
  }
  if (text.contains(RegExp(r'\s'))) {
    return const InvalidServerUrl('The address can’t contain spaces.');
  }

  final schemeMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://').firstMatch(text);
  if (schemeMatch == null) {
    text = 'https://$text';
  } else {
    final scheme = schemeMatch.group(1)!.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return const InvalidServerUrl(
        'The address must start with http:// or https://.',
      );
    }
  }

  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    return const InvalidServerUrl('That doesn’t look like a web address.');
  }

  final segments = <String>[];
  for (final segment in uri.pathSegments) {
    if (segment.isEmpty) continue;
    if (_appRoutes.contains(segment.toLowerCase())) break;
    segments.add(segment);
  }

  final normalized = Uri(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    pathSegments: segments,
  );
  final url = normalized.toString();
  return ValidServerUrl(url.endsWith('/') ? url.substring(0, url.length - 1) : url);
}
