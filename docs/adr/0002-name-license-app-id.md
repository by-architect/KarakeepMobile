# 0002 — Name "Linkstow", GPL-3.0, permanent app IDs

**Status:** accepted · 2026-09-25

## Context

The app shipped under the working title "Keeper". Before publishing:

- "Karakeep" belongs to Localhost Labs Ltd; its terms grant no right to use
  the name or logo. Names built on it ("Karakeep Pro", "Karakeeper") read as
  official, and "karakeeper" is already an unrelated App Store client.
- "Keeper" is a registered trademark of Keeper Security for their password
  manager apps on the same stores.
- Store application IDs can never change after the first release.

## Decision

- **Name:** Linkstow (no existing app found under it). Presented as "a client
  for Karakeep", with an explicit not-affiliated note. Own icon, drawn by
  `apps/flutter/tool/generate_app_icon.py`.
- **License:** GPL-3.0 (`LICENSE`). Settings → About links the source code.
- **IDs**, derived from the GitHub account `by-architect`:
  - Android `applicationId`: `io.github.by_architect.linkstow` (Java package
    rules: no hyphens)
  - iOS bundle ID: `io.github.by-architect.linkstow` (no underscores)
  - Dart package: `linkstow`
- ADR 0001's API-key name `Keeper mobile (<rand>)` becomes
  `Linkstow mobile (<rand>)`.

## Consequences

- Keys created by earlier test builds are still named "Keeper mobile (…)" on
  the server; revoke them on the web if unused.
- Installing this build does not update an earlier test install (different
  application ID); uninstall the old one.
- Moving the repo to another owner does not require changing the IDs.
