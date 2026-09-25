/// Everything that can go wrong, expressed in terms the UI can show.
///
/// Pure Dart on purpose: the domain layer throws and catches these without
/// knowing about HTTP.
sealed class Failure implements Exception {
  const Failure(this.message);

  /// User-facing, already phrased for display.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Device offline, DNS failure, connection refused, timeout.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'Couldn’t reach the server. Check the address and your connection.',
  ]);
}

/// TLS handshake failed — usually a self-signed or expired certificate.
final class CertificateFailure extends Failure {
  const CertificateFailure([
    super.message =
        'The server’s certificate isn’t trusted. If it’s self-signed, install '
        'your CA on this device.',
  ]);
}

/// Something answered, but it is not a Karakeep server (or a proxy is in the
/// way and returned its own page).
final class NotKarakeepFailure extends Failure {
  const NotKarakeepFailure([
    super.message =
        'This doesn’t look like a Karakeep server. If it sits behind an auth '
        'proxy, add the required headers under Advanced.',
  ]);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'You’re not signed in.']);
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
    super.message = 'The server refused this request.',
  ]);
}

final class RateLimitedFailure extends Failure {
  const RateLimitedFailure([
    super.message = 'Too many attempts. Wait a few minutes and try again.',
  ]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
