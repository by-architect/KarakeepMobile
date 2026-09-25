/// App-wide constants. Anything that differs per flavor belongs here too.
abstract final class AppConfig {
  /// Karakeep's name and logo aren't licensed to us, and "Keeper" is a
  /// registered trademark of Keeper Security, so the app has its own name and
  /// presents itself as a client *for* Karakeep (docs/adr/0002).
  static const appName = 'Linkstow';

  static const sourceCodeUrl = 'https://github.com/by-architect/KarakeepMobile';
  static const license = 'GPL-3.0';

  static const defaultServerUrl = 'https://cloud.karakeep.app';

  /// Prefix of the API key name created on the server by a password sign-in,
  /// so users can recognise (and revoke) it under Settings → API Keys.
  static const apiKeyNamePrefix = 'Linkstow mobile';

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);
}
