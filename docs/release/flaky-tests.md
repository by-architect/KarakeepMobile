# Flaky test policy

Write this down before the first flake, not after the tenth. Google measures
~1.5% of test runs as flaky at scale; Slack built automatic detection and
suppression for the same reason. A flaky blocking gate teaches people to ignore
the gate — which costs more than the bug the gate would have caught.

## Definition

A test is flaky if it produces different results on the same commit. Not
"sometimes fails because the code is broken" — that is a failing test.

## Rules

1. **Retry only failures, never the whole suite.** Re-running everything hides
   which test was unstable.
2. **A test may fail the build only if it fails 3 times in a row.** Below that
   it is reported as flaky, not as a failure.
3. **Above the flakiness threshold, quarantine it.** Pull it off the critical
   path so it stops blocking merges.
4. **Quarantine always opens a ticket** with an owner and a due date. A
   quarantine with no ticket is a deleted test with extra steps.
5. **Quarantined tests keep running** on the nightly job, so a fix is noticed.
6. **A quarantined test covering a path in the current release blocks that
   release.** That item is on the tier-3 checklist deliberately — quarantine
   buys merge velocity, never release confidence.
7. **Expiry.** A test quarantined longer than two release trains is either
   fixed or deleted. Nothing sits in limbo.

## Common causes, in rough order

Real waits replaced by sleeps · shared mutable state between tests · dependence
on test execution order · real clock or timezone · real network · animations
not disabled · under-resourced CI emulators.

## Metric to watch

Flake rate per suite, trended per week. A rising trend is an infrastructure
problem, not a collection of individual test bugs — fix it as one.
