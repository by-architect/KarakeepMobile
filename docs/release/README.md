# Release process

Two ideas carry the whole process, and both come from one fact: **a shipped
binary cannot be rolled back.** Store review and update lag mean a bad release
lives on user devices for days.

1. **The train leaves on schedule.** A fixed cadence, branch cut on a fixed day.
   Features that are not ready wait for the next train. This is what Monzo,
   Spotify and Squarespace all converged on.
2. **Merge is decoupled from release.** Everything risky ships dark behind a
   flag, so "broken" means "flip a switch", not "submit a hotfix". See
   `../architecture/feature-flags.md` — this matters more than any test tier.

## The three tiers

Every check belongs to exactly one tier, chosen by **who can verify it**.
Putting an item in the wrong tier is how a checklist rots.

| Tier | Verifier | Mechanism | Runs |
|---|---|---|---|
| 1 | machine, fast | `scripts/verify.sh fast` → `.github/workflows/pr.yml` | every push, blocks merge |
| 2 | machine, slow | `scripts/verify.sh release` → `release.yml`, `nightly.yml` | release branch + nightly |
| 3 | human judgment | `.github/ISSUE_TEMPLATE/release.md` | once per release |

**Tier 1** (target: under 5 minutes) — format, lint/detekt, unit tests, DB
migration tests, screenshot tests. JVM only. Anything slower gets bypassed.

**Tier 2** — device matrix, E2E journeys, macrobenchmarks, baseline profile,
signed release build, `bundletool` split install, and the upgrade test. These
run against the **release artifact**, not a debug build: R8 breaks reflection
and serialization constantly, and the upgrade path is the most common way to
break existing users.

**Tier 3** — TalkBack, RTL, store policy, rollout judgment. Opened as one issue
per release so it is assignable, timestamped, and leaves an audit trail of who
verified what. When the manual suite outgrows an issue template, move it to a
test-case management tool (TestRail, Xray) rather than a longer markdown file.

## Blocking vs warning

Be deliberate, or people learn to ignore the whole signal.

- **Block:** compile, lint errors, unit tests, migration tests.
- **Warn:** coverage, benchmark deltas, bundle size.

Use a **coverage ratchet** — "must not drop below today's number" — not an
absolute target. A percentage mandate produces tests written for the metric.

## The rollout gate

Expressed as numbers, in `.github/ISSUE_TEMPLATE/release.md`:
crash-free sessions ≥ 99.5%, ANR < 0.47%, user-perceived crashes < 1.09%.
Start the staged rollout at 1–10%, watch Vitals for 24h, then widen.
Below threshold → pause the rollout and flip the flag. Do not debate it live.

## One entry point

CI never contains build logic. `scripts/verify.sh` is a thin dispatcher: it
picks the stack and delegates to that stack's fastlane lanes (or Gradle/Flutter
as a fallback). Workflows call the same command you call on your laptop, so
local and CI cannot drift into "works on my machine".

## Roles

Rotate a **release owner** per train. They cut the branch, shepherd the
candidate, own the tier-3 issue, and make the halt call. Rotating it spreads
the knowledge and stops the process depending on one person.
