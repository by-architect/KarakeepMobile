# 0003 — Application ID `com.byarchitect.linkstow`

**Status:** accepted · 2026-09-26 · supersedes the IDs in [0002](0002-name-license-app-id.md)

## Context

0002 derived the IDs from the GitHub account (`io.github.by_architect.linkstow`
on Android, `io.github.by-architect.linkstow` on iOS). They differed per
platform, since Android forbids hyphens and iOS forbids underscores. Nothing
had been published yet, so the ID could still change for free.

## Decision

One ID on every platform: **`com.byarchitect.linkstow`** — Android
`applicationId` and `namespace`, the Kotlin package of `MainActivity`, and the
iOS bundle ID (`com.byarchitect.linkstow.RunnerTests` for the test target).

## Consequences

- Permanent from the first store release (F-Droid, Google Play, App Store).
- A `com.` ID conventionally means its owner holds the matching domain
  (`byarchitect.com`); no store checks this, but registering the domain avoids
  anyone else claiming the namespace.
- Test installs made with the old ID are separate apps; uninstall them.
