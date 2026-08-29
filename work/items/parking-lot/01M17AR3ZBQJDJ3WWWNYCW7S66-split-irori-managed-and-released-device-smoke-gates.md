---
id: 01M17AR3ZBQJDJ3WWWNYCW7S66
slug: split-irori-managed-and-released-device-smoke-gates
title: Split Irori managed and released device smoke gates
origin: parked
status: To Do
priority: medium
labels:
  - android
  - device-owner
  - testing
  - verification
created: 2026-08-29
source: se-debug
context:
  cwd: /home/simonwjackson/code/sandbox/irori
  branch: main
  commit: 781f46d
  repo: irori
---

# Split Irori managed and released device smoke gates

## Why it matters

The current post-install documentation points to device-irori-coexistence-smoke.sh, which requires Samsung Launcher as Home. A newly provisioned managed device correctly uses IroriHomeAlias and lock task, so the smoke reports a false failure and can send an operator toward the wrong recovery action.

## Acceptance Criteria

- [ ] A managed-device smoke verifies Device Owner, IroriHomeAlias, active lock task, and the installed APK version.
- [ ] A released-device smoke verifies Samsung Launcher, inactive lock task, and the persisted recovery flag.
- [ ] The cutover and provisioning docs name the correct smoke for each device state.
- [ ] Each smoke states its required starting state before it changes or checks the device.

## Related

- `scripts/device-irori-coexistence-smoke.sh`
- `scripts/verify-boot.sh`
- `scripts/device-recover.sh`
- `docs/irori-coexistence-cutover.md`
