/// App-wide constants. Anything that differs per flavor belongs here too.
abstract final class AppConfig {
  /// Working title — the final name is not decided yet. Karakeep's name and
  /// logo are not licensed to us, so the app presents itself as a client
  /// *for* Karakeep (see docs/research/karakeep-server.md §1).
  static const appName = 'Keeper';

  static const defaultServerUrl = 'https://cloud.karakeep.app';

  /// Prefix of the API key name created on the server by a password sign-in,
  /// so users can recognise (and revoke) it under Settings → API Keys.
  static const apiKeyNamePrefix = 'Keeper mobile';

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);
}
