#!/usr/bin/env sh
#
# Single entry point for verification. CI and humans call the same thing, so
# they cannot drift. This script only dispatches -- it never reimplements a
# build. Per-stack logic belongs in fastlane lanes or Gradle tasks.
#
#   scripts/verify.sh fast      tier 1: blocks merge, must stay minutes
#   scripts/verify.sh release   tier 2: release pipeline, slow and expensive
#   scripts/verify.sh all       both tiers
#
# Optional second argument limits the run to one stack:
#   scripts/verify.sh fast android-kotlin
#
set -eu

TIER="${1:-fast}"
ONLY="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS=0
RAN=0

log()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
skip() { printf '    \033[2mskip: %s\033[0m\n' "$*"; }

run() {
  _label="$1"; shift
  printf '    run: %s\n' "$*"
  if ( cd "$_dir" && "$@" ); then
    printf '    \033[32mpass\033[0m %s\n' "$_label"
  else
    printf '    \033[31mFAIL\033[0m %s\n' "$_label"
    STATUS=1
  fi
  RAN=$((RAN + 1))
}

has_fastlane() { [ -f "$_dir/fastlane/Fastfile" ]; }

# ---------------------------------------------------------------- android ----
verify_android() {
  _dir="$ROOT/apps/android-kotlin"
  [ -d "$_dir" ] || return 0
  log "android-kotlin :: $TIER"

  if has_fastlane; then
    run "fastlane verify_$TIER" bundle exec fastlane verify_"$TIER"
    return 0
  fi

  if [ ! -x "$_dir/gradlew" ]; then
    skip "no fastlane/Fastfile and no gradlew -- stack not initialized yet"
    return 0
  fi

  case "$TIER" in
    fast)
      run "static analysis" ./gradlew --no-daemon lintDebug
      run "unit tests"      ./gradlew --no-daemon testDebugUnitTest
      ;;
    release)
      run "instrumented tests" ./gradlew --no-daemon connectedDebugAndroidTest
      run "release bundle"     ./gradlew --no-daemon bundleRelease
      ;;
  esac
}

# ---------------------------------------------------------------- flutter ----
verify_flutter() {
  _dir="$ROOT/apps/flutter"
  [ -d "$_dir" ] || return 0
  log "flutter :: $TIER"

  if has_fastlane; then
    run "fastlane verify_$TIER" bundle exec fastlane verify_"$TIER"
    return 0
  fi

  if [ ! -f "$_dir/pubspec.yaml" ]; then
    skip "no fastlane/Fastfile and no pubspec.yaml -- stack not initialized yet"
    return 0
  fi

  case "$TIER" in
    fast)
      run "analyze"    flutter analyze
      run "unit tests" flutter test
      ;;
    release)
      run "integration tests" flutter test integration_test
      run "release bundle"    flutter build appbundle --release
      ;;
  esac
}

# ------------------------------------------------------------------- main ----
case "$TIER" in
  fast|release) ;;
  all)
    "$0" fast    "$ONLY"
    "$0" release "$ONLY"
    exit $?
    ;;
  *)
    printf 'usage: %s <fast|release|all> [android-kotlin|flutter]\n' "$0" >&2
    exit 2
    ;;
esac

if [ -z "$ONLY" ] || [ "$ONLY" = "android-kotlin" ]; then verify_android; fi
if [ -z "$ONLY" ] || [ "$ONLY" = "flutter" ];        then verify_flutter; fi

if [ "$RAN" -eq 0 ]; then
  printf '\n\033[33mnothing ran.\033[0m No stack is initialized yet -- add build files first.\n'
  exit 0
fi

if [ "$STATUS" -eq 0 ]; then
  printf '\n\033[32m%s tier passed.\033[0m\n' "$TIER"
else
  printf '\n\033[31m%s tier failed.\033[0m\n' "$TIER"
fi
exit "$STATUS"
