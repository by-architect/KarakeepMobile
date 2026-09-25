## What and why

<!-- One or two lines. Link the issue. -->

## Definition of done

- [ ] Tier 1 passes locally (`./scripts/verify.sh fast`)
- [ ] Tests added or updated for the changed behaviour
- [ ] Layer boundaries respected — `domain/` gained no framework imports
- [ ] Risky or incomplete behaviour sits behind a feature flag
- [ ] Any new flag is registered with a default and an owner
- [ ] DB schema change ships with a migration **and** a migration test
- [ ] User-facing strings are localized
- [ ] No secrets, keystores or tokens in the diff

## Flag / rollout

<!-- Flag name and default, or "none". -->
