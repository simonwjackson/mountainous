# Unzen configuration

Unzen is a headless server on the `cairn` branch. Its host declaration is
`modules/hosts/unzen.nix`, and its initial Disko layout is `disks/unzen.nix`.
The operator selected an unencrypted bcachefs pool shared by NixOS and data.
Some future drives are not connected yet. This configuration is prepared and
tested on virtual disks; it is not installed on the physical machine.

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

## Initial storage configuration

Missing future drives do not prevent installing onto the approved initial
drives. The final pool cannot be fully validated until its intended drives are
present. The current layout contains only the two installed NVMe devices.

The host imports Disko's upstream module and `disks/unzen.nix` directly. It does
not import the shared `disk` layer, which formats btrfs. The standard NixOS
bcachefs module supplies the driver and tools.

| Drive | Partition | Format and use |
|---|---|---|
| Kioxia | 1 GiB ESP | FAT32, mounted at `/boot`; GRUB, kernel, and initrd boot copies. |
| Kioxia | All remaining capacity | Member of the shared bcachefs filesystem. |
| SN770 | 1 GiB ESP | FAT32, mounted at `/boot-secondary`; independent GRUB, kernel, and initrd copies. |
| SN770 | All remaining capacity | Member of the same bcachefs filesystem. |

The filesystem UUID is Disko's deterministic UUID for `unzen`:
`e5f61013-d6f5-260d-9883-4dda26b2c293`. Mounted subvolumes hold `/`, `/home`,
`/nix`, and `/srv`. All four mounts refer to that UUID. No OS/data subvolume has
a fixed size. Five retained GRUB generations bound ESP usage. Monthly
scrub runs once for the shared filesystem through the standard NixOS service.

The full NixOS system, generated format program, and mount program now build.
Those builds do not format hardware or apply the 95 W power service. The
installation needs separate approval and identity enrollment before execution.

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

The initial format sets `data_replicas=2` and `metadata_replicas=2`. Erasure
coding stays off. The two members have separate failure domains,
`onboard.kioxia` and `onboard.sn770`. No settings have been applied to the live
NVMe drives. Copies live on different eligible devices, not fixed mirror pairs.
Two fully populated copies protect against losing one device; replica health
must be checked after faults, policy changes, and expansion.
With the two roughly 1 TB initial SSDs, usable capacity is roughly 1 TB before
filesystem and boot overhead.

The three card-mounted drives share a failure point. The pinned 1.39.6 code
supports a `failure_domain` device option that can group them together.
Replication placement across domains is a preference, not a hard requirement:
if other domains fill, copies can land in the same domain. The
`bcachefs fs failure-domains` report checks what losing each domain would cost.
Changing a domain does not itself rewrite existing data. Ordinary device copies
do not imply protection against losing the whole card. Keep capacity headroom,
check placement, and keep off-machine backups.

### Boot and installation boundaries

The operator selected mirrored EFI boot. The configuration uses standard NixOS
`boot.loader.grub.mirroredBoots` for `/boot` and `/boot-secondary` and disables
systemd-boot. GRUB copies kernels and initrds to both FAT32 ESPs, so it does not
need to read bcachefs. Each ESP gets `EFI/BOOT/BOOTX64.EFI` through
`efiInstallAsRemovable=true`; `canTouchEfiVariables=false` avoids NVRAM writes
and lets firmware use the standard fallback path on either device. Actual
firmware boot order and discovery still need physical validation.

Both ESP mounts use `nofail`. OS/data mounts use `degraded=yes`, which permits
reduced redundancy without enabling the separate `degraded=very` data-loss
override. The pinned driver sets only `BCH_FORCE_IF_DEGRADED` for `yes`, not
`BCH_FORCE_IF_LOST`. The built-in missing-device wait is 30 seconds. Boot from
one drive leaves only one copy available, and new writes can lack redundancy
until repair. Replace failed devices promptly and check actual replica health.
No external failure-alert delivery is configured.

Mirror updates assume both ESPs are present and mounted. Do not rebuild or
install bootloaders against an absent ESP: an unmounted boot directory is then
part of the root filesystem, not the intended FAT32 target. Restore or replace
the failed drive before bootloader updates. The recovery USB remains unchanged.
Missing-drive tests use independent snapshots of a shut-down healthy pair;
degraded writes from the two tests are never recombined.

The recovery system currently lacks `/sys/firmware/efi`. Before physical
installation, confirm the UEFI boot path and the approved installation method.
No boot-mode change, NVRAM write, or remote installation has run.

Do not run `scripts/install-remote` yet. Unzen still needs its own enrolled host
key, final target checks, and explicit approval to erase the two named NVMe
drives. Later expansion uses `bcachefs device add`, not Disko formatting. M.2
hardware changes need a shutdown on this machine.

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

From the `cairn` worktree, run:

```sh
./scripts/test-unzen-install-plan
nix build --no-link -L .#checks.x86_64-linux.unzen-storage
nix build --no-link .#nixosConfigurations.unzen.config.system.build.toplevel
```

The install-plan test evaluates the real host. It checks both stable disk IDs,
partition sizes, shared UUID mounts, two-copy format arguments, separate failure
domains, no encryption, mirrored GRUB EFI paths and kernel copies, `nofail` ESP
mounts, safe degraded mount policy, monthly scrub, and the headless upstream 95 W
policy. It also verifies unchanged Hiyori recovery mounts and its disabled power
service. Full-system evaluation must now succeed, rather than fail for a missing
root. The test never executes the formatter or starts the power service.

The VM test imports the same `disks/unzen.nix` through Disko's upstream test
library. It formats disposable virtual disks, checks idempotent format/mount,
installs EFI loaders on both drives, and cold-boots the bcachefs root without a
passphrase. The harness replaces its top-level boot attrset while remapping
disks, so the test passes the actual layout's boot policy separately through
`extraSystemConfig`. It does not silently test the harness's default bootloader.
It checks all four subvolume mounts, both ESP boot payloads, two member labels
and failure domains, two-copy policy readbacks, and the scrub timer. The healthy
failure-domain JSON report must show no offline member, nonzero stored data,
and no separation violation.

From a shut-down healthy pair, the test independently clones the Kioxia and
SN770 images. Each clone cold-boots with the other drive physically absent from
QEMU. The test checks `multi-user.target`, OS/data mounts, the surviving ESP,
retained marker data, one offline member, and successful degraded writes. It
then resumes the untouched healthy pair and verifies that no degraded-test
marker leaked into it. Finally, it adds a third virtual disk, verifies increased
capacity and retained data, and changes data/metadata replica policies to three
online. That last readback verifies policy acceptance, not completion of
three-copy reconciliation.
The VM uses the upstream test library's shared 9p Nix store; it does not test a
physical Nix-store write workload, the real MSR service, actual motherboard
firmware failover, or recovery after both drives fail.

During the VM addition, udev's redundant `device online` attempts logged EBUSY
against the already mounted new member. The explicit add returned success;
member count, capacity, and existing-data assertions passed. Physical expansion
has not been tested. Do not treat the VM result as proof of hardware behavior.

The full system, format program, and mount program built successfully with
bcachefs 1.39.6 for Linux 6.18.53. Nix formatting, ShellCheck, and Git whitespace
checks passed. Hardware installation, live power service verification,
closed-case/card-installed cooling, and physical boot failover remain separate
work.

### Host identity enrollment

The operator approved a separate Unzen identity and fleet-secret access. Its
ed25519 key lives outside Git at
`~/.local/share/mountainous/hostkeys/unzen/ssh_host_ed25519_key`. The key has mode
`0600`; its directory has mode `0700`. The SSH fingerprint is
`SHA256:VP6I/dDbuKVFEPdYz4rCIDphMFT/Bzf+Dh1Vs9bQPD4`.

`.sops.yaml` and `secrets/fleet.yaml` now include Unzen's public age recipient.
All five previous recipients remain. `scripts/test-unzen-identity` verified the
key pair and decrypted the actual encrypted fleet file to `/dev/null` using
only Unzen's identity, with an empty HOME and no operator credential environment.
The operator's master identity also passed a separate decryption check.
A pre-enrollment baseline also verified unchanged encrypted secret fields,
unchanged unrelated creation rules, and byte-identical unrelated secret files.
No secret values or private key contents were printed or committed.

Keep a secure backup of the local keystore. The existing install helper stages
this key at `/etc/ssh/ssh_host_ed25519_key` with mode `0600` through
`--extra-files`, before first activation. The key has not been sent to the
physical machine.

Physical installation has not run. It still needs fresh device-identity checks,
backup/erasure approval, and a verified bcachefs-capable installer. Actual
firmware boot order and UEFI fallback discovery also need physical validation.
The current `scripts/install-remote` disables SSH host-key checking. Verify and
preserve SSH peer trust before sending the new private host key; do not treat
that helper's unchecked connection as a trusted enrollment channel.
