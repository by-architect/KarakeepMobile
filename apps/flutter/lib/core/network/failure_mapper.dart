import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'trpc.dart';

/// Translates transport errors into [Failure]s.
///
/// Callers pass the wording that fits their context for 401/403, e.g. a
/// sign-in screen says "wrong password" rather than "not signed in".
Failure mapDioException(
  DioException e, {
  String? unauthorizedMessage,
  String? forbiddenMessage,
}) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkFailure(
        'The server took too long to respond. Try again.',
      );
    case DioExceptionType.badCertificate:
      return const CertificateFailure();
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      final cause = e.error;
      if (cause is HandshakeException || cause is TlsException) {
        return const CertificateFailure();
      }
      if (cause is FormatException) return const NotKarakeepFailure();
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const UnknownFailure('Request cancelled.');
    case DioExceptionType.badResponse:
      return _fromResponse(
        e.response,
        unauthorizedMessage: unauthorizedMessage,
        forbiddenMessage: forbiddenMessage,
      );
  }
}

Failure _fromResponse(
  Response<Object?>? response, {
  String? unauthorizedMessage,
  String? forbiddenMessage,
}) {
  final status = response?.statusCode;
  final serverMessage = parseTrpcError(response?.data).message;
  return switch (status) {
    401 => unauthorizedMessage != null
        ? UnauthorizedFailure(unauthorizedMessage)
        : const UnauthorizedFailure(),
    // Prefer the server's reason: "password auth disabled", "verify your
    // email", "demo mode" all arrive as 403.
    403 => ForbiddenFailure(
        serverMessage ?? forbiddenMessage ?? const ForbiddenFailure().message,
      ),
    404 || 405 => const NotKarakeepFailure(),
    429 => const RateLimitedFailure(),
    _ => UnknownFailure(
        serverMessage ?? 'The server returned an error (${status ?? '?'}).',
      ),
  };
}
