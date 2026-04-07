---
date: 2026-04-07
topic: media-tiering permissions and ownership
source_report: docs/reports/2026-04-07-media-tiering-migration.md
---

# Media Tiering Permissions and Ownership Brief

## Chosen Thing
Shape a reusable, declarative fix for cross-host media ownership and permissions in the shared `media` + `media-tiering` model, centered on a shared `media` group identity across hosts rather than per-service UID parity.

## Users and Context
- Primary environment: the current `yari` ↔ `zao` media-tiering deployment.
- Primary users: Jellyfin, Radarr, Sonarr, downloaders/mover automation, and `simonwjackson`.
- Current problem: NFS `all_squash` writes land as `root:root`, which works in some paths only because mergerfs is running as root, but leaves ownership semantics inconsistent and fragile.
- Desired context: a repo-wide pattern that can be reused on future hosts without host-specific permission hacks.

## Goals
- Make cross-host media writes and deletes behave consistently under NFS + mergerfs.
- Ensure the design is reusable as a standard repo pattern, not a one-off for one host pair.
- Preserve the simpler, safer `all_squash` NFS model rather than requiring full cross-host UID parity.
- Allow Jellyfin, Radarr, Sonarr, downloaders, mover automation, and `simonwjackson` to manage media when needed.
- Include a way to normalize existing on-disk ownership/mode drift, not only future writes.

## Non-Goals
- Redesign the basin/lake/range storage model.
- Resolve whether `zao` should gain a dedicated basin mergerfs.
- Change mover scheduling, cache-tier behavior, or stale-data cleanup beyond what is necessary for permission correctness.
- Optimize for zero-downtime rollout at all costs.

## Constraints
- Must fit the existing NixOS module structure and be expressed declaratively.
- Must remain compatible with NFS `all_squash` semantics.
- Must avoid depending on dynamic service UIDs matching across hosts.
- Should favor simplicity and reliability, even if rollout may need a small maintenance window.
- Should work as a reusable repo-wide pattern while being validated first on `yari` and `zao`.

## Success Criteria
- New media created or moved across hosts no longer drifts to unusable `root:root` semantics.
- Existing media can be reconciled into the chosen ownership/mode model without recurring manual repair.
- Jellyfin and the ARR/downloader stack can modify/delete media through the supported paths when intended.
- `simonwjackson` can administer media without ad hoc root-only fixes for normal operations.
- The permission model is understandable from configuration alone and does not rely on accidental behavior from mergerfs/root.
- The design can be applied to additional hosts without introducing per-service static UID management.

## Candidate Shapes
1. **Shared media group model**
   - Standardize a fixed `media` GID across participating hosts.
   - Map NFS `all_squash` writes into that group.
   - Require media to be group-writable and services/admin users to participate in the `media` group.
   - Add a normalization path for existing files.

2. **Per-service identity parity**
   - Assign fixed UIDs/GIDs to Jellyfin, Radarr, Sonarr, downloaders, etc. across hosts.
   - Let NFS preserve real identities instead of collapsing to a shared group model.
   - More invasive and harder to scale operationally.

3. **Status quo with narrow patches**
   - Keep `root:root` behavior and rely on root/mergerfs-mediated access.
   - Use occasional manual `chown`/`chmod` repair.
   - Lowest effort, but not reusable or robust.

## Chosen Shape
Adopt the **shared media group model** as the repo-wide pattern for cross-host media ownership.

In scope for the shaped work:
- a declarative shared-group identity for media access,
- NFS behavior that preserves that shared-group contract under `all_squash`,
- a consistent expectation that managed media is group-writable,
- and a defined normalization path for existing media so the system converges on the new model instead of only fixing future writes.

## Key Decisions
- Choose **group-based cross-host access** over per-service UID parity.
- Keep **NFS `all_squash`** as the safety baseline.
- Treat **media services plus `simonwjackson`** as legitimate writers/admins for the managed media surface.
- Include **existing-file normalization** as part of the shaped work, not as an out-of-band manual cleanup.
- Favor a **clean, reusable design** over minimizing every moment of service disruption.
- Defer the exact numeric GID choice to planning/implementation so long as it becomes fixed and shared across participating hosts.

## Open Questions
None currently blocking for planning.

## Next Step
Plan the smallest declarative change set that establishes a shared `media` group identity, makes NFS/group-write semantics explicit, and defines how existing media permissions are normalized and verified on `yari` and `zao` first.