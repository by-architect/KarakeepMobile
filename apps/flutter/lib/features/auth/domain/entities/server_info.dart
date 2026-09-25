/// What a server told us about itself before sign-in.
class ServerInfo {
  const ServerInfo({
    this.version,
    this.passwordAuthDisabled = false,
    this.signupsDisabled = false,
    this.demoMode = false,
  });

  /// e.g. `0.33.0`, `nightly`, or null when the server didn't say.
  final String? version;

  /// SSO-only server: sign-in has to go through an API key.
  final bool passwordAuthDisabled;
  final bool signupsDisabled;
  final bool demoMode;
}
