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

The operator chose one bcachefs filesystem for NixOS and data, with only the
firmware boot partition outside it. Disko's pinned native bcachefs types support
multi-device filesystems and mounted subvolumes, including root, home, and nix.
This support was checked in the upstream example and test source; Unzen's
complete layout and boot behavior have not been tested yet.

The OS and data subvolumes will share free capacity without a fixed-size OS
partition. The earlier 128 GiB OS example described a separate-pool alternative,
not this selected layout. Only the EFI boot partition needs a separate fixed
allocation. Shared capacity avoids stranded free space, but data and snapshots
can fill the pool and block OS writes. Monitor free space and bound retention.

The operator said the disks will be wiped. The initial plan uses these two
currently installed devices and leaves the USB recovery drive unchanged:

| Initial device | Existing filesystems |
|---|---|
| `/dev/disk/by-id/nvme-KXG60ZNV1T02_NVMe_KIOXIA_1024GB_81UFC0UWF8T3` | FAT and btrfs |
| `/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_22135C800678` | f2fs |

The operator selected an unencrypted pool after the automatic-unlock
investigation. TPM availability no longer blocks preparing the storage layout.
No formatting, partition change, or installation has run.

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

### Future devices and redundancy

The operator's photo shows a Samsung 970 EVO Plus 1 TB, a WD_BLACK SN770 1 TB,
and a Sabrent Rocket 2230 512 GB on a four-socket PCIe card. These are planned
additions, not enumerated device identities. Record their actual serials and
stable paths when connected. Do not add absent devices to the initial Disko
format plan or assume the pictured SN770 is distinct from the installed one
without checking its serial. The operator confirmed bifurcation works.

The recommendation is `data_replicas=2` and `metadata_replicas=2`, with erasure
coding off for the initial two-device root pool. Those settings are not applied
by the current scaffold. Copies live on different eligible devices, not fixed
mirror pairs. Two fully populated copies protect against losing one device;
replica health must be checked after faults, policy changes, and expansion.
With the two roughly 1 TB initial SSDs, usable capacity is roughly 1 TB before
filesystem and boot overhead.

The three card-mounted drives share a failure point. The pinned 1.39.6 code
supports a `failure_domain` device option that can group them together.
Replication placement across domains is a preference, not a hard requirement:
if other domains fill, copies can land in the same domain. The
`bcachefs fs failure-domains` report checks what losing each domain would cost.
Changing a domain does not itself rewrite existing data. Ordinary device copies
do not imply protection against losing the whole card. Keep capacity headroom,
check placement, and keep off-machine backups. EFI boot redundancy also needs
separate configuration and a boot-failure test.

Source: [pinned failure-domain allocation documentation](https://github.com/koverstreet/bcachefs-tools/blob/v1.39.6/fs/alloc/disk_groups.c#L3-L58)
and [replica options](https://github.com/koverstreet/bcachefs-tools/blob/v1.39.6/fs/opts.h#L161-L170).

### Encryption decision and previous TPM investigation

The operator explicitly accepted unencrypted storage for Unzen. Do not add
native filesystem encryption, LUKS, Clevis, or a TPM unlocking requirement to
the initial layout. This permits unattended boot without an unlock secret.
Physical access to the disks exposes file contents and stored SSH host keys;
those keys also permit decryption of the host's enrolled fleet secrets.
Unencrypted storage does not remove the fleet identity-enrollment requirement.

The operator previously requested investigation of automatic encrypted boot.
The findings below are retained as evidence, not pending installation work.

The pinned NixOS modules support native encrypted bcachefs with Clevis in the
initrd. `boot.initrd.clevis.devices.<device>.secretFile` supplies a sealed JWE
secret; the bcachefs module decrypts it and unlocks the filesystem. Clevis
supports TPM2 and network Tang policies, with interactive fallback. The
passphrase must not be embedded in plaintext in the Nix store or boot files.

A read-only live probe found no `/sys/class/tpm` device, no `/dev/tpm*` node,
and no visible TPM ACPI table. Kernel logs explicitly report `No TPM chip
found`. The current recovery system also booted without `/sys/firmware/efi`.
This proves no usable TPM is exposed now, not that the board lacks TPM support.
The board manual documents `Intel(R) Platform Trust Technology` under Security
and `Security Device Support` under Trusted Computing. Their firmware settings
have not been read. Intel PTT being disabled is an inference, not a verified
cause. No driver, firmware setting, TPM state, or encryption key was changed.

If encryption is revisited, the local-TPM path needs firmware and kernel
visibility checked before sealing and testing a key. Tang is a supported
alternative but adds early-boot network and server availability dependencies.
TPM presence alone does not establish a secure boot policy. Protecting a removed
disk differs from protecting a stolen whole machine or a changed boot image.
An encrypted-boot design needs an explicit measured boot policy, an offline
recovery passphrase, and tested recovery after firmware or boot changes.
No working unattended unlock has been demonstrated on Unzen. No TPM enrollment
or firmware change is planned for the selected unencrypted layout.

Relevant pinned sources: `nixos/modules/system/boot/clevis.nix`, its
`clevis.md`, and `nixos/modules/tasks/filesystems/bcachefs.nix` in the nixpkgs
input. Temporary read-only probe: `/home/simon/unzen-tpm-readonly.py`.

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
