/// Where a Karakeep server lives and how to get through to it.
class ServerConnection {
  const ServerConnection({required this.baseUrl, this.headers = const {}});

  /// Normalised, no trailing slash, e.g. `https://keep.example.com`.
  final String baseUrl;

  /// Extra headers sent on every request (auth proxies, Cloudflare Access).
  final Map<String, String> headers;

  @override
  bool operator ==(Object other) =>
      other is ServerConnection &&
      other.baseUrl == baseUrl &&
      _mapEquals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
        baseUrl,
        Object.hashAllUnordered(
          headers.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
