# Storage repair: 2026-10-19

Scope: repair the current topology. No reinstall, partition change, pool membership
change, KIOXIA reactivation, application reset, identity enrollment, or processing
resumption is authorized by this document. The coordinator owns live operations.

## Evidence and limits

The coordinator captured `unzen-survey.txt`, `unzen-details.txt`,
`replica-policy.txt`, `myoko-survey.txt`, and `zao-survey.txt` under the private
`/tmp/storage-repair-e8dad9` run directory. These are observations from this run,
not ongoing health guarantees. Do not publish private receipts or file lists.

| Observation | Meaning | Not established |
| --- | --- | --- |
| Direct NFS root, `tv`, and `movies` stat succeeds. Both bindfs views return errno 116. Range roots stat succeeds. | The failed seam is the mapped view, not a missing NFS export. A union root check can conceal a failed branch. | Which exporter event first invalidated the retained handle. |
| bindfs 1.18.1 `src/bindfs.c` opens `mntsrc_fd`, calls `fchdir(mntsrc_fd)` in `bindfs_init`, and resolves root as `.` in `process_path`. | The daemon retains the source directory identity rather than resolving the full source pathname on every request. | That remounting a healthy NFS mount is necessary. |
| `tests/media-storage-health.nix` removes/recreates an empty exported directory over real NFS. Direct and union stat succeed; bindfs stat raises ESTALE. | A reproducible stale pinned-source mechanism. The test then exercises the shipped health guard, quiescence, and ordinary remount recovery. | Transparent cache-to-array migration or exporter reboot. These need the Zao integration fixture. |
| `/srv/basin/media` contains zero bytes in the survey. Downloads contain about 537,173,295,104 bytes. | Do not drain or delete downloader staging as if it were imported library data. | That a pending handoff exists on Unzen now. |

A successful `systemctl is-active media-storage-ready` was a cached oneshot result.
It was not ongoing filesystem health. The new guard reads each branch with stat
and one directory-read batch, before the range. It does not scan the library.
It runs on admission and once per minute while readiness is active. A failing
monitor stops itself, mover timers, readiness, and the selected local storage
consumers. The gate `/run/media-storage-blocked` prevents accidental restart.
`/run/media-storage-failure.units` retains their observed states. No identity,
database, queue, application processing flag, or saved hold is rewritten.

The probe has a 20-second userspace deadline. Systemd also bounds the monitor at
30 seconds with a five-second stop timeout. A kernel task stuck in uninterruptible
I/O can exceed userspace deadlines. Never interpret timeout as successful cleanup.
The latch is runtime state: **do not reboot as a recovery shortcut**. A maintenance
window that spans reboot needs separately preserved service containment.

### Exporter contract

Zao's safe fallback is scheduled copy-only operation, retaining source directories.
Source release needs a coordinator-approved window with consumers quiesced and
views remounted. This does not finish automatic space reclamation. Until online
identity stability is proven, the cache can still fill. The Unzen guard detects a
fault; it is not permission to make handle-changing releases online.

## Bounded Unzen view recovery

Use one maintenance window and one attempt per step. Stop on any failed command,
remaining mount, unexpected writer, or I/O timeout. No `umount -l`, `umount -f`,
FUSE abort, process killing to force unmount, or blind restart loop.

1. Capture loaded units and their `ActiveState`, `SubState`, `UnitFileState`, and
   conditions in a root-only receipt. Include Scryer, Transmission, NZBFAST,
   NZBGet, the mover instances/timers, readiness, and health timer. Select actual
   loaded units; do not assume Sonarr/Radarr are running. Preserve application
   state, credentials, tsnet identities, ready files, and processing holds.
   If the guard already fired, copy its state receipt before changing anything.
2. Stop the health timer and mover timers first. Stop any active mover and active
   storage consumers, including Scryer and Transmission. Preserve previously
   inactive services as inactive. Keep the existing Zao mover containment.
   Explicitly stop readiness. Confirm each stopped process is gone. Capture
   `systemctl list-jobs`; do not proceed with pending stop jobs.
3. Inspect process holds on the affected mounts with `fuser -vm` and the known
   consumers' `/proc/<pid>/mountinfo`. Check for other NFS clients through the
   coordinator. A service sandbox can retain a mount after the host view changes.
   Do not stop tsnet identities or the VPN just to repair a filesystem view.
4. Stop the **range mount units first**, then the **bindfs view mount units**.
   Obtain exact escaped names with `systemd-escape --path --suffix=mount PATH`.
   The four paths, in order, are:
   `/srv/range/media/movies`, `/srv/range/media/tv`,
   `/srv/media-library-view/movies`, `/srv/media-library-view/tv`.
   Use ordinary `systemctl stop UNIT`. After each stop, verify mount absence in
   `/proc/self/mountinfo`. If busy, stop and investigate. Do not force it.
5. Direct NFS root/`tv`/`movies` must still pass stat and directory reads. Leave
   `/net/mountainous/zao/media` mounted when it is healthy. An NFS recovery is a
   separate escalation, not part of this view repair.
6. Start the two view mount units, then the two range units. Run
   `media-storage-health` directly. It ignores the processing latch and performs
   the real read-only checks. Verify ownership mappings and representative
   existing file reads as the intended service users. Do not create media or
   alter ownership to make admission pass.
7. Drain any queued `OnFailure` job before removing its latch. In this already
   quiesced window, run `systemctl start media-storage-failed.service` and then
   `systemctl stop media-storage-ready.service`. The first command waits for the
   failure handler; the second waits for its readiness stop job. Inspect
   `systemctl list-jobs` again. Never clear the latch while a failure handler can
   still recreate it. Only after all checks pass, archive the guard receipt and remove
   `/run/media-storage-blocked`. Start `media-storage-ready.service`. This must
   not start Scryer, Transmission, or mover timers. Clear only the inspected
   failed health/readiness/mover status after saving the failure evidence.
8. Start **only** the previously active, separately approved consumers. Do not
   restore all enabled units indiscriminately. Check their existing holds,
   queues, identities, and private mount namespaces. Restart the health timer.
   Keep mover timers stopped until the exporter fix and controlled drain have
   passed coordinator acceptance. Starting a mount alone never resumes Scryer.

Normal `nixos-rebuild` is not Disko formatting. The proposed Unzen closure adds
health/admission and stop ordering only. It does not change disk topology or
replica options. The proposed Myoko closure changes the existing bar collector
and state handling; it adds no notification channel.

## Replica policy audit

| Verified evidence | Conclusion |
| --- | --- |
| Initial install verification and 2026-10-11 expansion record data and metadata defaults of two. | The default policy is two copies. |
| The live `/srv/basin/downloads` xattr explicitly sets `bcachefs.data_replicas=1`; descendants inherit effective one. | Downloads are a configured one-copy exception. Do not change it without intent and capacity review. |
| Other probed roots have no replica override; pool options remain two. | Missing effective xattrs are not proof of one-copy policy. |
| About 537 GB of downloads versus about 447 G in physical one-copy accounting. | The exception is consistent with much of the one-copy data. Apparent/path and physical/compressed accounting are not interchangeable. This does not assign every vulnerable extent to downloads. |
| Three RW devices, zero reported device I/O errors, zero pending reconciliation, but nonzero failure-domain loss exposure. | Idle reconciliation does not prove redundancy or operator intent. Shared-card failure exposure remains real. |

The repository's install/expansion reports, `disks/unzen.nix`, local-staging ADR,
and available commit history contain no rationale for the download exception.
The local-staging decision says where downloads live, not their replica count.
The current rationale is **unknown**. Older journal excerpts mentioning journal
and Prowlarr database read errors omitted timestamps. They do not establish a
current error or authorize cleanup of retired application state.

Keep KIOXIA excluded. Cooling is an intentional constraint in the current repair
scope. This work must not turn an inventory observation into reactivation,
repartitioning, or membership work.

## Boot and recovery audit

`modules/hosts/unzen.nix` overrides `/boot` to the SN770 ESP, disables
`/boot-secondary`, and restricts GRUB mirrored boots to `/boot`.
`checks.unzen-boot` asserts this runtime configuration. `disks/unzen.nix` remains
the historical **initial install** plan. Never run Disko on this system and do
not rewrite that plan as a supposed repair for ordinary activation.

The survey records SN770 serial `22135C800678` as the current `/boot` device and
an existing `BOOT/BOOTX64.EFI` file. This is not a physical boot test. Samsung and
Sabrent whole-disk pool members do not provide alternate ESPs.

Recovery routes, with console access and separate reboot approval:

- If SN770 is readable, select its existing UEFI fallback loader in firmware.
  Do not format or recreate its ESP. Verify retained GRUB/kernel/initrd files
  before attempting bootloader repair.
- The retained Hiyori recovery USB was preserved during the original install
  and later removed. Its current availability/connection is **not verified**.
  Reconnect that existing media if available. The old USB kernel did not include
  bcachefs; the already documented pinned Unzen RAM installer provides matching
  tools/driver. Use its boot-only recovery route, never installation/Disko phases.
  Re-establish trusted SSH after checking the actual DHCP address.
- From recovery, first inspect the existing UUID and members read-only and
  locate the existing SN770 ESP. If the boot disk is lost, assess one-copy and
  shared-card exposure and independent backups before any repair. No formatting,
  `fsck --repair`, member addition, or ESP creation is part of this runbook.

Historical sources: [initial install](../research/unzen-hardware.md),
[expansion](../hardware/unzen-pool-expansion-2026-10-11/README.md). Their October 8
and October 11 membership tables are not the current October 19 inventory.

## Monitoring semantics and offline preview

The SSH protocol requires successful exit, valid rows, and a final timestamped
completion record. Partial/malformed/failed output is unknown, never green.
Clock differences over two minutes are unknown. The UI marks a retained sample
stale after ten minutes, including when a refresh hangs. Missing configuration,
expected mount paths/identities, sysfs data, or successful scrub history remain
visible failures or unknowns. Sync age is limited to 36 hours; scrub age to 14 days.

`df` measures the filesystem shared by cache, root, snapshots, and other data.
Warnings start at 80%, critical at 90%. These thresholds do not claim cache
occupancy or parity protection. The bar reads only the bounded public
`/var/lib/disk-array/towada/status.json` summary, schema version 1. Its counts are
**last-batch** observations; null backlog is unknown, not zero. It never reads
private per-file receipts and does not run recurring recursive `du`/`find` scans.
Missing/stale summaries remain warnings. Source-release containment remains a
warning even after a controlled drain because scheduled copies do not free space.

Offline fixture preview on a graphical test session (no SSH):

```sh
preview=$(mktemp -d)
cp modules/quickshell/{StorageHealthPreview.qml,StorageHealth.qml,Theme.qml,storage-health.js} "$preview/"
PATH="$PWD/tests/fixtures/storage-health-bin:$PATH" \
  STORAGE_HEALTH_ENABLED=1 STORAGE_HEALTH_PREVIEW=issues \
  quickshell -p "$preview/StorageHealthPreview.qml"
```

The isolated directory prevents Quickshell from scanning unrelated bar modules.
Use `healthy`, `stale`, `partial`, or `error` in place of `issues` to check other
states. Capture with the session's existing screenshot tool, for example
`grim /tmp/storage-health-fixture.png`. The real collector remains unchanged by
this fixture PATH. Coordinator screenshots after Myoko deployment are still
required; this source-only work does not assert live visual acceptance.
