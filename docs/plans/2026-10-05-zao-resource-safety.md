# Zao workload resource safety recommendation

Status: proposed. No configuration, service, or workload changed.

## Recommendation

Put Nix builds and agent workers under persistent systemd cgroup limits on Zao.
Use aggregate budgets across concurrent jobs, not a fresh allowance per job.
Keep SSH, tailnet proxies, and `forgerie-web.service` outside the worker budgets.
Do not cap the whole `user-1000.slice`, which also contains unrelated applications.

Start with the budgets below. They are conservative policy choices, not measured
optimal values. Get approval before activation, service restarts, or load tests.
Heavy builds and software-rendered game probes remain paused.

## Verified baseline

Read-only inspection on 2026-10-05 found:

| Area | Observed state |
| --- | --- |
| Hardware | Intel i9-11900H, 8 physical cores, 16 logical CPUs, about 31 GiB RAM. |
| Software | Nix 2.34.1 and systemd 259. |
| Nix scheduling | `/etc/nix/nix.conf` has `cores = 0` and `max-jobs = auto`. |
| Nix daemon | `/system.slice/nix-daemon.service`, `Delegate=yes`, no CPU quota or memory/swap cap, `TasksMax=1048576`. |
| User services | `forgerie-sessiond.service`, `forgerie-web.service`, and `pi-assistant-foundation.service` have no CPU quota or memory cap. |
| Paperclip | Active system service at `/system.slice/paperclip.service`, with no CPU quota or memory cap. |
| Swap | About 15 GiB of swap is available. Zao declares zstd zram with `memoryPercent = 50`. |
| Storage | `/nix/store` is on Btrfs. Both NVMe devices use the `none` I/O scheduler. |
| Cgroup controllers | The root exposes `cpu`, `cpuset`, `memory`, `io`, and `pids`, among other controllers. |

The inspected source revision was `f72d9709` on `unified`.
[Zao configuration](../../hosts/zao/default.nix) declares Paperclip, zram, the Fuji
builder, media services, and the Korri host.
[Zao commitments](../../hosts/zao/commitments.nix) require the existing zram policy.
[Disk configuration](../../hosts/zao/disko.nix) declares Btrfs data RAID0 across
both NVMe devices. I/O device discovery from a filesystem path is not sufficient
for this topology.

This verifies configuration and current service placement. It does not prove
containment of future build or agent subprocesses. The earlier host lockout's
cause remains unproven.

## Proposed initial budgets

| Control | All local Nix builds | Forgerie session daemon and Foundation together | Paperclip and its descendants |
| --- | --- | --- | --- |
| `CPUQuota` | `400%` | `200%` | `100%` |
| `CPUWeight` | `20` | `20` | `20` |
| `MemoryHigh` | `12G` | `4G` | `1G` |
| `MemoryMax` | `14G` | `6G` | `2G` |
| `MemorySwapMax` | `1G` | `512M` | `256M` |
| `TasksMax` | `2048` | `1024` | `512` |
| Read bandwidth, per NVMe device | `100M` | `50M` | `25M` |
| Write bandwidth, per NVMe device | `50M` | `25M` | `10M` |

`CPUQuota=400%` permits four logical CPUs' worth of CPU time in total, not four
CPUs per child and not 400% of the machine. These pools sum to seven logical CPUs'
worth of CPU time. Quotas do not reserve physical cores or cap unrelated kernel work.

Their memory caps sum to 22 GiB, leaving about 9 GiB outside these pools.
That is budget headroom, not a memory reservation or a guarantee for other services.
Check unrelated service use before adopting it. `MemoryHigh` applies memory
pressure; `MemoryMax` is the last defense and can trigger a cgroup-local OOM kill.

Use `IOReadBandwidthMax` and `IOWriteBandwidthMax` on both physical NVMe devices,
identified by the stable disk IDs already declared in `disko.nix`.
The table gives limits per device, not per logical Btrfs volume.
Do not rely on `IOWeight` alone with the current schedulers.
Buffered writes and filesystem kernel work need separate attribution checks;
these caps do not bound every source of disk activity.

Also set Zao's Nix defaults to `max-jobs = 1` and `cores = 4`.
These reduce build concurrency but do not enforce a CPU or memory ceiling.
Client-side Nix evaluation belongs to the caller's pool, not the daemon's pool.
Keep Fuji's builder configuration and private signing/cache policy unchanged.

## Where enforcement belongs

Keep the initial policy Zao-specific in `hosts/zao/default.nix`.
Use native NixOS/systemd options, without a new general-purpose feature interface.

Apply the build budget to `nix-daemon.service`, retaining its existing delegation.
Verify actual build cgroup ancestry before claiming that it contains all builds.

Put `forgerie-sessiond.service` and `pi-assistant-foundation.service` in one bounded
user-manager slice. A system-manager slice and a user-manager slice cannot serve
as the same parent pool. Paperclip therefore gets its own system-manager budget.

The current Forgerie and Foundation units live in `~/.config/systemd/user`, outside
this repository. Manage native drop-ins declaratively and check their effective
precedence. Do not assume that writing a NixOS definition replaces these files.
Confirm which services actually spawn each agent and command. This proposal does
not cover direct terminal launches, containers, or other job launchers unless
their placement is explicitly verified.

The first version caps worker services as a whole. An OOM kill can terminate
sessions or the service itself. Foundation's own interface can also be affected.
Keeping the Forgerie web service outside this pool preserves its separate process,
not session-daemon availability. Per-job failure isolation needs a separate change.

Keep the existing zram settings. `memoryPercent = 50` sets logical swap capacity;
it does not reserve physical RAM or impose a CPU ceiling for compression.
Do not add broad user-level OOM killing that can terminate unrelated applications.

## Approval and verification gates

1. Approve the budgets and a maintenance window. Check running jobs before
   changing daemon limits or restarting worker services.
2. Before the first candidate evaluation/build, approve and apply temporary
   containment. The policy cannot protect the build that creates it until limits
   are already effective. Do not restart an unrestricted build to install safety.
3. Build and review the candidate using [direct Nix commands](../nix-commands.md).
   Do not run `nix run .#deploy`; it is a destructive fresh-install tool.
4. Test containment with short, bounded subprocesses. Inspect `/proc/<pid>/cgroup`
   for a real Nix builder, an agent command, and a detached child. Verify ancestor
   limits, `cpu.max`, `memory.high`, `memory.max`, `memory.swap.max`, and `pids.max`.
5. Verify `io.max` and observed I/O accounting on both NVMe devices. Use disposable
   files and bounded actual disk I/O, not cached reads or an unrestricted disk test.
6. Test two worker jobs together. Confirm they share one budget. In a smaller
   disposable test cgroup, verify memory-limit failure without stressing the host.
7. During the tests, verify a fresh SSH login, tailnet access, and the Forgerie web
   endpoint. Check throttling/OOM counters and service logs. Stop on a kernel warning
   or loss of access. Do not reproduce the previous lockup deliberately.
8. Extend the existing commitment assertions and runtime verifier with these
   containment gates. Only then persist the configuration. Retain the previous
   system generation and a working rollback session outside the worker pools.

Do not grant agents permission to remove limits or move jobs into unrestricted
units. Root or privileged launch paths can defeat this policy. Exceptional large
jobs need explicit approval and a revised combined budget, or a different host.

## Costs and limits

Builds and probes will take longer. Memory caps can kill legitimate work.
The source records a previous Nix evaluation at about 15.2 GiB RSS; it will not fit
inside the proposed worker memory budget. Large evaluations need a separately
approved route. No performance or containment test for these proposed limits has
run yet.

Cgroups reduce resource exhaustion risk. They cannot guarantee SSH availability
or fix a kernel, filesystem, GPU driver, or hardware lockup. The system still needs
separate incident diagnosis. Do not describe this recommendation as a proven fix.

## Primary references

- [systemd 259 resource controls](https://github.com/systemd/systemd/blob/v259/man/systemd.resource-control.xml)
  define CPU quotas, memory pressure and caps, swap caps, task caps, and per-device I/O limits.
- [Nix 2.34 settings](https://nix.dev/manual/nix/2.34/command-ref/conf-file.html)
  describe `cores`, `max-jobs`, and build cgroup support.
- [Linux cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)
  describes hierarchical enforcement and I/O/writeback limitations.
