---
date: 2026-03-15
topic: shared-machine-profiles-modules
---

# Shared Machine Profiles vs Modules

## What We're Building
A cleaner structure for configuration that applies across multiple machines, not just `fuji` and `yari`.

The goal is to reduce duplication by moving repeated host configuration into reusable building blocks. The likely building blocks are NixOS modules for individual concerns and profiles for curated bundles of those concerns. Host files then become composition points that describe what each machine is, rather than re-declaring the same settings repeatedly.

## Why This Approach
The main approaches considered were:

1. Put everything into one shared host base file.
2. Break repeated concerns into reusable modules only.
3. Use modules for individual features and profiles for higher-level machine roles.

The recommended approach is option 3. It keeps low-level logic reusable while still giving each machine a readable, role-oriented shape. It also fits the repository's existing structure around `modules/`, `features/`, and `nix/profiles/`.

## Key Decisions
- Use **modules** for single concerns: user defaults, Syncthing folder generation, Tailscale server hardening, common firewall/fail2ban settings.
- Use **profiles** for machine-wide bundles: workstation, laptop, personal server, media server, automation server.
- Keep **host files thin**: hardware, disks, hostname, host-specific secrets, and a short list of imported profiles/modules.
- Prefer **data options over copy-pasted config** when the same pattern appears on multiple hosts.
- Start with **cross-machine shared pieces first**, before refactoring app-specific services like OpenClaw or tsnsrv.

## Open Questions
None yet.

## Next Steps
→ `/forgerie:spec` for implementation details
