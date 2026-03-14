---
date: 2026-03-13
topic: layout-consolidation
status: superseded-by-implementation
---

# Layout Consolidation

## Historical Note
This brainstorm captured an earlier decision point while the repository still had multiple overlapping implementation roots.

## Outcome
The repository now uses a clearer top-level layout:

- `hosts/`, `home/`, `secrets/`, and `docs/` for primary configuration data
- `modules/`, `features/`, and `packages/` for reusable Nix building blocks
- `overlays/` for flake-facing package extensions
- `nix/lib/` for shared helper code that still makes sense as library support

The duplicate legacy package roots discussed here have been removed, and package sources now live under the canonical `packages/` tree.

## Final Takeaway
The useful part of the original brainstorm was the goal: reduce parallel directory structures and make it obvious where new code belongs. The exact proposed intermediate migration path is no longer current, but the cleanup objective has now been implemented.
