# Unzen scaffold

Unzen is a headless server on the `cairn` branch. Its host declaration is
`modules/hosts/unzen.nix`. The operator selected bcachefs and reported that
some drives are not connected yet.

## Hardware and measured power policy

The machine running the recovery host Hiyori has an Intel i7-9700K with eight
cores and eight threads, and an ASRock Z390 Phantom Gaming-ITX/ac board.
The scaffold enables Intel microcode updates through the standard NixOS option.
It does not change Hiyori's recovery-host configuration. Raw thermal recordings
are archived on `mini-itx-nvme-airflow`, commit `c6269c79`, under
`docs/hardware/hiyori-95w-run-2026-10-08/` and
`docs/hardware/hiyori-power-fan-run-2026-10-07/`.

The approved temporary comparison finished at
`2026-10-08T00:59:27.535005+00:00`. Both package limits were 95 W.

| Eight-worker CPU-only result | Unrestricted | Both limits at 95 W |
|---|---:|---:|
| Median RAPL package-power estimate | 115.48 W | 89.14 W |
| Peak reported CPU temperature | 100 degrees Celsius | 86 degrees Celsius |
| Stage duration | 44.91 seconds, stopped at cutoff | 75 seconds, completed |
| Throughput in bogo operations per second | 21602.71 | 19889.35 |

The subsequent 120-second CPU-plus-SSD-read stage completed at a maximum
reported CPU temperature of 91 degrees. No CPU thermal-throttle counter
increased. This measured trade-off costs 7.93% CPU-only throughput in this
integer workload; it is not an application-wide performance prediction.
The test requested the open case with the PCIe card removed. Closed-case
operation remains unverified.

The scaffold uses upstream NixOS options rather than a custom power-cap service:

```nix
services.undervolt = {
  enable = true;
  p1 = { limit = 95; window = 28; };
  p2 = { limit = 95; window = 0.00244; };
};
```

Despite the service name, no voltage offset is configured. Temperature targets
and the turbo override also remain unset. The upstream module loads the MSR
driver and applies the settings at boot and after sleep. The upstream tool
checks the power-register write by reading it back. No polling timer is enabled;
firmware that later replaces the limits would require a separate investigation.

Both a limit and a window are required by the upstream options. A read-only
check of Hiyori found long-term and short-term windows of 27983872 and 2440
microseconds. The configured seconds quantize to the same hardware windows.
This is not Intel's stock turbo profile, which can allow short bursts above
95 W. The standard service's MSR write path has not been tested on this machine;
the successful temporary comparison used the Linux RAPL sysfs interface.

The temporary comparison restored the original limits. Adding this host file
does not apply the cap to the running recovery system.

## Storage is deliberately deferred

Missing future drives do not prevent scaffolding or installation onto the
available drives. We need an approved initial root and boot layout, not every
future pool member. The final pool cannot be fully validated until its intended
drives are present.

`boot.supportedFilesystems = [ "bcachefs" ];` enables the standard NixOS
bcachefs tools and kernel-module integration. No mount, pool, disk device,
replica count, encryption choice, or formatting command is configured.
The shared `disk` layer is not imported because it formats btrfs.

This is not an installable system yet. The root filesystem and boot partition
are unset, so a full NixOS system build fails its missing-root-filesystem check.
Do not run the installation scripts against this scaffold.

Before installation, identify the drives used for the initial install. Collect
their stable `/dev/disk/by-id/` paths, capacities, current filesystems, and data
that must be preserved. Then decide whether bcachefs holds root, a data pool, or
both, and choose initial redundancy and encryption. Pool creation erases the
selected storage and needs a separate approved installation plan.

Bcachefs supports adding devices at runtime, including devices of different
sizes. The pinned 1.39.6 user manual describes `bcachefs device add` against a
mounted filesystem and later adjustment of device labels, targets, and replica
counts. The add command formats the new member. It does not preserve existing
data on that member or require reformatting the existing pool.

Additional capacity does not automatically add replicas. A single-device pool
has no protection against that device failing. Choose replication explicitly
when enough devices are available, and keep backups. Adding a pool member also
does not create an EFI boot partition on that member or make boot redundant.
Do not use degraded mount options as a substitute for an initial storage plan.

Source: [bcachefs-tools 1.39.6 device management manual](https://github.com/koverstreet/bcachefs-tools/blob/v1.39.6/doc/bcachefs.5.rst.tmpl#L70-L120).
The new-member formatting behavior is in
[`src/commands/device.rs`](https://github.com/koverstreet/bcachefs-tools/blob/v1.39.6/src/commands/device.rs).

Unzen also needs its own SSH host identity enrolled in the fleet secret
recipients before an unattended first boot. The scaffold does not generate keys
or change encrypted secrets.

## Checks

Run `./scripts/test-unzen-scaffold` from the `cairn` worktree. It evaluates the
real host, checks the upstream 95 W command and unset voltage/temperature
options, checks bcachefs module and tool inclusion, and verifies that no storage
layout or desktop was added. It also checks that Hiyori keeps its existing
recovery mounts and has no power-limit service enabled.

The test passed, including the expected missing-root-filesystem build refusal.
The bcachefs 1.39.6 module for Linux 6.18.53 was realized from the Nix binary
cache. The generated upstream service unit built and its `ExecStart` contains
only the two power-limit arguments. Nix formatting and ShellCheck passed.

The test does not access disk block devices or start the power service.
Live verification, pool checks, installation, and deployment remain deferred.
