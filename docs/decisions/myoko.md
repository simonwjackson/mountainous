# Host Definition: Myoko (Internal Disk Laptop)

## Purpose
Pre-provisioned host definition for the primary laptop before the physical hardware arrives. It evaluates and builds to verify desktop layers, with installation intentionally blocked until disk hardware IDs are populated.

## Principles
- Shares `base`, `desktop`, and `disk` layers with `hiyori` (the portable USB host).
- Excludes `portable.nix`: `base` defaults to `systemd-boot` with `canTouchEfiVariables = true`, appropriate for internal non-removable drives.
- Disk specification uses an intentional unresolvable placeholder (`/dev/disk/by-id/REPLACE_WITH_REAL_DISK_ID`) so disko aborts rather than writing to an unintended device during initial bring-up.
