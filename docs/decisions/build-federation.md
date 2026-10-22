# Build federation and memory guard

Decided 2026-10-22. Code: `modules/build-federation.nix`,
`modules/nix-builder-gate.py`, `modules/memory-guard.nix`. Test:
`tests/build-federation-vm.nix`.

## Problem

Zao locked up when many builds or one large evaluation ran: `nix flake check`
reached 14.8 GiB RAM plus 9.1 GiB zram before the kernel killed it, and SSH
was unusable until then. Meanwhile Unzen (62 GiB) and Aka sat idle, and only
Zao sent work anywhere (to Fuji and Yari, by a hand-written list).

## Decision

**Memory guard, every host.** sshd (64M) and tailscaled (256M) keep their
memory, and `system.slice` reserves 512M so those reserves work. No
`OOMScoreAdjust`: every SSH login is a child of sshd or tailscaled and would
inherit it. systemd-oomd watches `system.slice` (80% pressure for 30 s) and,
except on desktops, the user slices. nix-daemon has `MemoryHigh` 75% and
`MemoryMax` 85% (lower on builders), and builds unpack in
`/nix/var/nix/builds`, not the tmpfs `/tmp`. `checks.baseline` enforces it.

Desktops keep oomd off their user slices: Hyprland and every terminal it
starts share one session scope, so oomd would end the whole session.

**Federation.** A host file declares `fleet.builders.<name>` and
`fleet.hostKeys.<name>`. Every client gets one `nix.buildMachines` entry per
other builder and signs in with its own SSH host key; every builder lets
those keys run `nix-builder-gate serve` and nothing else, at idle CPU and IO
priority. Nix does the scheduling: per derivation it picks the fitting builder
with the lowest running jobs / speedFactor (from its own jobs only), builds
locally when all are full, and after a failed connection skips that builder
for the rest of that `nix build` (Nix 2.34.1, `build-remote.cc`).

| Builder | speedFactor | Notes |
|---|---|---|
| unzen | 4 | MemoryMax 70% |
| aka (unified) | 4 | MemoryMax 60%; games run in user slices, oomd off there |
| zao (unified) | 3 | also a client; 32 GiB swapfile behind zram |
| myoko | 1 | gate `home`, OpenSSH on 2222 (Tailscale SSH owns 22) |
| fuji, yari | 1 | aarch64 only |

Rakku and Tate never build. Ibuki is a Korri device; Korri locks
`max-jobs = 0` and `distributedBuilds = false`. Hiyori sends builds and never
builds (`max-jobs = 0`): a build with no builder reachable fails.

**Myoko's gate.** It accepts at home on mains power. Home means the default
route's gateway has a MAC in `fleet.homeMacs`; subnet and SSID are shared by
too many other networks. A manual choice from the bar (`nix-builder-gate set
on|off`) wins, and clears when a different router is seen. Losing the network,
switching between wired and Wi-Fi, or plugging in clears nothing. A refusal
looks to Nix like a failed connection, so it moves to the next builder.

## Costs

- oomd kills whole cgroups: all running builds with nix-daemon, or a whole
  SSH session that runs a heavy evaluation.
- A build that needs more than a builder's MemoryMax fails instead of
  finishing slowly.
- Zao and Aka run `unified`, which keeps a copy of this registry in
  `features/nix-builders/fleet.json`. A change here must be copied there.
- Myoko's gate trusts the router MAC: a new router stops Myoko building until
  `fleet.homeMacs` is updated.
