# fastlane (android-kotlin)

`scripts/verify.sh` calls fastlane when `Fastfile` exists here, and falls back
to raw Gradle tasks when it does not. Add the `Fastfile` per fork.

Lanes the dispatcher expects:

| Lane | Tier | Should cover |
|---|---|---|
| `verify_fast` | 1 | lint/detekt, unit tests, migration tests, screenshot tests |
| `verify_release` | 2 | instrumented tests, signed bundle, bundletool install, upgrade test |

Useful additional lanes: `beta` (internal track upload), `deploy` (staged
rollout), `screenshots`.

Signing material comes from environment variables in CI — never commit a
keystore or `release.properties`. See `.github/workflows/release.yml` for the
expected secret names.
