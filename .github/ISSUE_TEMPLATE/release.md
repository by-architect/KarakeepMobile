---
name: Release
about: One issue per release. The tier-3 checklist — items no script can verify.
title: 'Release <version>'
labels: release
---

**Version:** <!-- 1.4.0 (build 140) -->
**Release owner:** <!-- @you -->
**Branch cut:** <!-- date -->

Tiers 1 and 2 are machine-verified in CI. Everything below needs a human.
Do not tick an item you did not personally check. See `docs/release/README.md`.

## Gate — numbers, not vibes

Submission is blocked unless all of these hold:

- [ ] Tier 1 green on the release branch
- [ ] Tier 2 green (device matrix, signed build, upgrade test)
- [ ] Zero open release-blocking bugs
- [ ] Crash-free sessions ≥ **99.5%** on the beta build
- [ ] ANR rate < **0.47%** (Play's bad-behaviour threshold)
- [ ] User-perceived crash rate < **1.09%** (Play's bad-behaviour threshold)
- [ ] No test currently quarantined for a path in this release

## Release build — verified on the signed artifact

- [ ] Signed release build installs and the core journey works with R8 enabled
- [ ] Installed via `bundletool` split install, not the universal APK
- [ ] **Upgrade test:** current store version installed → upgraded → data intact
- [ ] A forced test crash appeared in the crash dashboard, de-obfuscated
- [ ] Deep links / App Links open the right screen
- [ ] Push notifications arrive
- [ ] Billing verified on a closed track (if applicable)

## Compatibility

- [ ] Min SDK device and target SDK device
- [ ] Phone + tablet/foldable
- [ ] Dark mode
- [ ] RTL locale and the longest-translation locale
- [ ] 200% font scale
- [ ] Fresh install: permission grant **and** every denial path
- [ ] 16 KB page size support (required for apps targeting Android 15+)
- [ ] Offline / airplane mode / slow network

## Accessibility

- [ ] TalkBack pass on the main journey
- [ ] Accessibility Scanner clean
- [ ] Touch targets ≥ 48dp, contrast ratios pass

## Store & policy

- [ ] Data Safety form matches what the app actually sends
- [ ] Privacy policy live and reachable
- [ ] Target-API requirement met
- [ ] Release notes written and localized
- [ ] Play pre-launch report reviewed (internal track upload)

## Rollout

- [ ] Internal track → closed track → staged rollout
- [ ] Staged rollout started at **1–10%**
- [ ] Vitals watched for 24h before widening
- [ ] Every new feature has a working kill switch
- [ ] **Halt condition agreed:** crash-free < 99.5% → pause rollout, flip the flag

## Post-release

- [ ] Rollout at 100%
- [ ] Release branch merged back / tagged
- [ ] Flags for fully-shipped features scheduled for removal
