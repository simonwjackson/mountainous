---
id: 01M17ARNM21C0EW0TBGNS1A597
slug: reject-stale-device-owner-provisioning-artifacts
title: Reject stale Device Owner provisioning artifacts
origin: parked
status: To Do
priority: high
labels:
  - android
  - device-owner
  - provisioning
  - release
created: 2026-08-29
source: se-debug
context:
  cwd: /home/simonwjackson/code/sandbox/irori
  branch: main
  commit: 781f46d
  repo: irori
---

# Reject stale Device Owner provisioning artifacts

## Why it matters

Both the stale provisioning APK and the current dirty build report versionCode 3 and versionName 0.3.0. The ignored build/device-owner directory can therefore serve an old APK with no Git or Android version signal that it is stale, which caused this device to receive a build 163 commits behind current source.

## Acceptance Criteria

- [ ] The provisioning command builds the selected source state before publishing an APK.
- [ ] The command regenerates the payload checksum and QR from that exact APK.
- [ ] Provisioning refuses an APK whose source revision or build timestamp does not match the selected source state.
- [ ] Each installable build has an observable identity that distinguishes it from prior APKs.
- [ ] A test covers stale ignored artifacts and fails before publication.

## Related

- `build/device-owner/`
- `app/build.gradle.kts`
- `scripts/install-tablet.sh`
