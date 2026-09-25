# AndroidBase

Stack-agnostic starting point for new mobile apps. Fork it, delete the stack you
are not using, and build inside the layers that are already laid out.

```
docs/
  architecture/   the layering contract + feature-flag seam   (shared)
  release/        the three test tiers, flaky-test policy     (shared)
  adr/            decision records                            (shared)
  conventions/    naming, branching, logging                  (shared)
design/           design tokens and source assets             (shared)
scripts/verify.sh single entry point for all verification     (shared)
.github/          CI workflows, PR + release templates        (shared)
apps/
  android-kotlin/   native Android (Gradle, Compose, MVVM)
  flutter/          Flutter (MVVM via Cubit / Riverpod)
```

Every stack under `apps/` follows the same three layers — `data`, `domain`,
`presentation` — so the architecture travels with you even when the language
does not. See [`docs/architecture/README.md`](docs/architecture/README.md).

## Verification

One entry point, called identically by CI and by you:

```sh
./scripts/verify.sh fast      # tier 1 — blocks merge, minutes
./scripts/verify.sh release   # tier 2 — release pipeline, slow
./scripts/verify.sh all
```

It detects the stack and delegates to that stack's fastlane lanes, falling back
to Gradle or Flutter commands. It exits cleanly while a stack has no build files
yet. Tier 3 — the checks only a human can do — lives in
[`.github/ISSUE_TEMPLATE/release.md`](.github/ISSUE_TEMPLATE/release.md), opened
once per release. The reasoning is in
[`docs/release/README.md`](docs/release/README.md).

## Using this base

1. Fork / clone, rename the repo.
2. Delete the `apps/*` directory you do not need.
3. Copy `feature/_template` (or `features/_template`) once per screen or feature.
4. Add the build files for your stack (`build.gradle.kts`, `pubspec.yaml`,
   `fastlane/Fastfile`, a `.gitignore`) — this base ships structure only.
5. Fill in `docs/conventions/` and set your release cadence.

## Adding another stack

Create `apps/<stack>/` (e.g. `react-native`, `kmp`), reproduce the same
`data / domain / presentation` split, and add a branch to `scripts/verify.sh`.
Nothing else in the repo needs to change.
