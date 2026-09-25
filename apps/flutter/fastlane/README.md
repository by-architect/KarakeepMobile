# fastlane (flutter)

`scripts/verify.sh` calls fastlane when `Fastfile` exists here, and falls back
to raw flutter commands when it does not. Add the `Fastfile` per fork.

Lanes the dispatcher expects:

| Lane | Tier | Should cover |
|---|---|---|
| `verify_fast` | 1 | flutter analyze, unit + widget tests, golden tests |
| `verify_release` | 2 | integration_test, signed appbundle, install + upgrade test |

Useful additional lanes: `beta` (internal track upload), `deploy` (staged
rollout), `screenshots`.

Signing material comes from environment variables in CI — never commit a
keystore or signing properties. See `.github/workflows/release.yml` for the
expected secret names.
