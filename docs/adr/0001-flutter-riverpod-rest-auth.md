# 0001 — Flutter + Riverpod, REST-first API, API-key sessions

**Status:** accepted · 2026-09-25

## Context

We are building a third-party mobile client for self-hosted Karakeep servers
(research: `docs/research/karakeep-server.md`). The base allows Cubit or
Riverpod. Karakeep exposes a stable REST API (`/api/v1`, OpenAPI) and an
internal tRPC API that the official app uses for almost everything. Sign-in
by password exists only as tRPC `apiKeys.exchange`; SSO users can only use API
keys created on the web.

## Decision

- **Flutter, MVVM with Riverpod.** `Notifier`s are the view models; one
  immutable state class per screen. Repositories are exposed via providers so
  tests override them. No code generation for now.
- **REST first.** tRPC is only used where REST has no equivalent: today
  `apiKeys.exchange` and `config.clientConfig`, through a small helper
  (`core/network/trpc.dart`).
- **The session is an API key.** Password sign-in exchanges credentials for a
  key named `Keeper mobile (<rand>)`; the password is never stored. Pasting a
  key is a first-class path (SSO). The session — server URL, custom headers,
  key — lives in platform secure storage.
- **Routing follows the session.** go_router redirects on
  `sessionControllerProvider`; screens never navigate after sign-in/out.
- **Self-hosted networking.** Android allows cleartext and user-installed CAs;
  iOS allows arbitrary loads. Custom headers go on every request.

## Consequences

- Karakeep rejects key revocation made with an API key, so sign-out only
  forgets the key locally; users revoke it on the web. We say so in the UI.
- tRPC calls have no contract and may break across server versions; keep them
  few and isolated, and feature-detect via `/api/version`.
- Cleartext/user-CA trust is app-wide. A per-server "allow insecure" toggle
  may replace it later.
- One account at a time for now; `SessionJson` is versioned so multi-account
  storage can migrate from it.
