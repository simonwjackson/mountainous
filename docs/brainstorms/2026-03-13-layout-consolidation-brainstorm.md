---
date: 2026-03-13
topic: layout-consolidation
---

# Layout Consolidation

## What We're Building
A cleanup of the repository structure so there is one clear place for host-facing configuration and one clear place for reusable Nix implementation code. This work is coupled to profile removal: once profiles are eliminated, the remaining question is whether reusable pieces should stay under `nix/` or be lifted to top-level roots.

The current tree mixes both approaches. Host-facing roots like `hosts/`, `home/`, and `secrets/` already live at the top level, but reusable implementation code is split between `nix/modules`, `nix/packages`, `nix/features`, `nix/lib` and legacy top-level roots like `modules/`, `pkgs/`, and `profiles/`. That makes it hard to know where new code belongs and causes migrations like the `systems -> hosts` change to leave stale parallel structures behind.

## Why This Approach
Three structural directions were considered. First, lift more of `nix/*` to the repo root so everything becomes `modules/`, `packages/`, `lib/`, `features/`, etc. This makes paths shorter but increases the number of top-level concepts and weakens the distinction between domain configuration and implementation machinery. Second, keep the mixed structure and clean up only profiles. That has the lowest short-term cost but preserves the ambiguity that created the current drift. Third, standardize on top-level roots only for domain-facing configuration (`hosts`, `home`, `secrets`, `docs`) and keep reusable Nix implementation under `nix/`. The third option is the cleanest long-term model.

Recommended structure:
- **Top level = primary domain/config roots**: `hosts/`, `home/`, `secrets/`, `docs/`, `overlays/`.
- **`nix/` = reusable implementation**: `nix/modules/`, `nix/features/`, `nix/packages/`, `nix/lib/`.
- **Delete legacy parallel roots**: `profiles/`, `nix/profiles/`, top-level `modules/`, top-level `pkgs/` after migration.

This keeps the repo easy to navigate: if a file describes a real machine or user, it lives at top level; if it is a reusable Nix abstraction, it lives under `nix/`.

## Key Decisions
- **Do not lift `nix/modules`, `nix/packages`, or `nix/lib` to the repo root**: that would create more parallel top-level roots without improving the conceptual model.
- **Move legacy top-level Nix implementation downward instead**: `modules/*` should migrate into `nix/modules/nixos/*` and `pkgs/*` should migrate into `nix/packages/*`.
- **Eliminate profiles rather than relocating them**: `profiles/server` and `nix/profiles/*` should be replaced with normal modules or explicit host config, not moved elsewhere.
- **Keep top-level roots for domain objects only**: `hosts`, `home`, `secrets`, and docs remain top-level because they represent first-class repo entities, not reusable implementation internals.
- **Keep `nix/features` for now**: features already model cross-cutting bundles (some spanning NixOS and Home Manager) and do not need a second migration until the profile cleanup is complete.
- **Treat `overlays/` as optional to migrate later**: it can stay top-level for now since it is flake-facing and already singular; moving it under `nix/` is lower priority than removing the active duplication in `modules/`, `pkgs/`, and `profiles/`.

## Resolved Questions
- **Should reusable Nix code be lifted out of `nix/`?** No. The better direction is to consolidate legacy top-level Nix code into `nix/`.
- **Should profiles be relocated?** No. Profiles should be dissolved into modules/features/host config.
- **Should `hosts/` and `home/` move under `nix/`?** No. They are primary configuration roots and are clearer at top level.

## Open Questions
None at this stage.

## Next Steps
→ Proceed with implementation in this order:
1. Remove dead profiles and replace live profiles with normal modules.
2. Migrate top-level `modules/*` into `nix/modules/nixos/*`.
3. Migrate top-level `pkgs/*` into `nix/packages/*` and update overlays.
4. Update imports, docs, and scaffold logic to match the new layout.
5. Rebuild active hosts after each migration stage to catch path regressions early.
