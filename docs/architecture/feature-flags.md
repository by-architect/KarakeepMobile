# Feature flags

The load-bearing piece of the release process. Trunk-based development only
works on mobile because **merging is decoupled from releasing**: code lands on
`main` continuously, but users see it only when a flag says so.

This inverts the risk model. You are not trying to certify that a release is
perfect — you are ensuring anything broken can be switched off without a store
submission. A release train without flags is just a slower deadline.

Uber ships every feature as a plugin behind an A/B test, giving a remote kill
switch for every feature in the app. Spotify gates by market and percentage
from the backend.

## Where it lives

| Stack | Path |
|---|---|
| Android | `apps/android-kotlin/core/featureflag/` |
| Flutter | `apps/flutter/lib/core/featureflag/` |

It is a `core` module because every feature depends on it and it depends on no
feature. Features read flags; they never reach for the flag *provider*
directly.

## The seam

Three pieces, whatever the stack:

- **A flag registry** — every flag declared in one place with a key, a default,
  an owner and a removal date. Flags invented inline at call sites are how you
  end up with 200 of them.
- **A provider interface** in `domain` terms: `isEnabled(flag): Boolean`. The
  implementation may be local, remote-config-backed, or an experiment platform;
  callers must not be able to tell which.
- **A local override surface** — a debug screen that forces any flag on or off
  on-device. Without it, QA cannot test a dark-shipped feature, and the flag
  system silently stops being used.

## Rules

1. **Default off.** A flag that defaults on is not a kill switch.
2. **Read a flag in one place per feature**, usually the ViewModel. Flags
   scattered through the UI layer make behaviour impossible to reason about.
3. **Never branch on a flag inside `domain/`.** Business rules should not know
   about rollout state.
4. **Every flag has a removal date.** Ship it to 100%, delete the flag and the
   dead branch. An unremoved flag is permanent conditional complexity.
5. **Flag state must survive offline.** Cache the last known values; never let
   a failed config fetch turn features off for everyone.
6. **Kill switches are separate from experiments.** An experiment can be lost
   to a bad network call; a kill switch cannot.
7. **A flag is not a permission check.** Never gate anything security-relevant
   client-side.

## Related

`../release/README.md` — how flags gate the staged rollout and the halt call.
