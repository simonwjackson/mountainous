# Zao direct-disk drain

This repair does not change disks, filesystems, pool membership, exports or mergerfs inode policy. Do not run Disko or the deploy installer.

## Safety boundary

`copy` never removes a source. `protect` runs the existing removal/update threshold checks, a SnapRAID sync, an authoritative SnapRAID content listing, and a full **data and parity** read check. `release` is a separate, explicit operation. A copied receipt, a successful timer, or an earlier sync is not release authority.

Every command checks the exact cache subvolume and every data/parity mount against configured block-device identity, filesystem type and UUID. Zao's five USB by-id names include the serials. Its Btrfs cache must have UUID `b11bc61f-1632-4809-8c94-efbf39614f22` and filesystem root `/@cache`. A directory at a missing mount is not accepted. Symlink traversal, nested mounts, hardlinks and a union destination are refused. Open writers break kernel read leases; there is no fallback on filesystems without leases.

Source files must keep the same device, inode, size, ownership, mode, mtime, ctime, link count, xattrs and SHA-256 between copy and release. Publication is a non-replacing rename followed by directory fsync. New files preserve owner, mode, atime, mtime and xattrs. New directories preserve owner, mode, times and xattrs; existing destination directories are not rewritten. Identical destinations are adopted only when file metadata and the access timestamp also match. Conflicts abort, including the same name on multiple data disks.

SnapRAID receives inherited backing-root descriptors through a private in-memory configuration, so even its path-based I/O cannot fall back to a detached mountpoint directory. All commands use `/run/lock/disk-array-towada.lock`. The sync and scrub services call the same CLI. **Do not run raw SnapRAID maintenance concurrently.** Before sync writes anything, it durably replaces the protection generation. Interrupted sync invalidates all earlier protection receipts. Release also checks the content-file hashes and parity/content file identities and timestamps. A failed/partial diff, missing count, duplicate count or exceeded threshold aborts; no force option exists.

Hidden paths, SnapRAID exclusions, links and internal SnapRAID files are retained and reported. The content listing is an additional positive membership check, not an inference from exclusion patterns. Do not claim the whole cache is protected. The coordinator's 2026-10-19 inventory found 1,366 regular files, including 21 hidden files (26,698 apparent bytes). That inventory is advisory, not a live receipt.

## Coordinator-only one-time procedure

Keep containment in place until the reviewed build is active. These commands are a runbook, not permission for a worker to execute them on a host.

1. Pause writer workloads on Zao and remote clients. Pause normalization, cleaners, ingest, downloaders, tiering, cache-mover and SnapRAID timers for this controlled operation. Stop Jellyfin and other consumers. On Unzen, stop consumers and bindfs views, then unmount the NFS view normally. Stop Zao's NFS exporter after clients have unmounted. Do not use lazy/forced unmount. Preserve existing administrative holds.
2. Confirm all five disk identities, cache identity, SMART evidence, recovery space, and available target capacity. Do not delete firmware, hidden files or failed temporary copies to make room.
3. Use a new batch name. Save plan output privately. Default limit is 256 files; `--limit 2000` covers the reported initial inventory, not an assumed future total.

   ```sh
   sudo towada-storage admit
   sudo towada-storage plan --limit 2000
   sudo towada-storage copy --batch e8dad9-drain --limit 2000
   # Optional: --target 00 (or 01 / 04); never pass a filesystem path.
   sudo towada-storage resume --batch e8dad9-drain
   sudo towada-storage protect --batch e8dad9-drain
   # Only after reviewing the successful protection receipt and keeping writers paused:
   sudo towada-storage release --quiesced --batch e8dad9-drain
   sudo towada-storage plan --limit 2000
   ```

   `resume` resumes copy only. It never silently protects or releases. `protect` is expensive: it reads the full array and parity, not just the batch. Do not raise diff thresholds to make a failed check pass. Investigate differences first. A later sync requires protection again before release.
4. Inspect residual files and receipts. Never remove source directories: the implementation preserves **all** cache directories, including empty media/tv and media/movies roots.
5. If exporter remount is needed, keep clients unmounted. Stop range helpers/mounts before the lake. Restart the lake with admission, then readiness/ranges and the exporter. Mount client NFS, then recreate bindfs views, then check actual directory iteration and file reads. Resume only services that the coordinator intentionally paused, after their fresh-admission guards pass. No automatic clearing of fleet fault latches.
6. Remove both run-specific containment drop-ins only after review: `/etc/systemd/system.control/towada-cache-mover.service.d/90-storage-repair-containment.conf` and its `/run/systemd/system/...` counterpart. The coordinator owns this action and timer restoration.

## Receipts, interruptions and costs

Private receipts and SnapRAID logs live in `/var/lib/disk-array/towada/receipts` (0700). Each batch stores candidate paths, source/destination identity, file metadata, hashes, per-file state and protection evidence. Keep them as audit evidence.

Release first records `releasing`, then atomically quarantines the source under `/srv/cache/towada/.cache-mover-release/<batch>-<index>`. It verifies the quarantined inode, metadata and hash under a read lease before unlinking it. This closes the final pathname-replacement race. An interrupted or failed release can leave original bytes in this private quarantine; it does not discard them. Rerun the same release command after admission and protection review. If both source and quarantine are absent but the receipt still says `releasing`, the tool refuses to guess. Review that file manually. Never delete quarantine or receipt state to silence an error.

Release is per-file, not an all-or-nothing batch transaction. A later failure does not undo earlier files that were already safely released. Copy failures can leave `.cache-mover-*` destination files; they remain hidden and unprotected for operator inspection. No automatic cleanup is provided. Receipts and temporary copies consume space. The mechanism is not a backup and cannot protect against arbitrary privileged out-of-band writes or simultaneous hardware loss.

## Scheduled operation and NFS limitation

The hourly service stages at most one bounded batch of files older than 24 hours, regardless of the shared Btrfs filesystem percentage. It resumes that batch until the operator releases it; it does not rehash the same 1.4 TB every hour. Scheduled operation is **copy only**, not a completed automatic drain: cache bytes remain occupied and still require guarded protection and explicit release.

Online release is deliberately not implemented. `--quiesced` is an operator acknowledgement, not an automatic proof that every remote writer is stopped. Kernel read leases and final identity/hash checks remain mandatory even with that acknowledgement.

The installed mergerfs 2.41.1 source documents `hybrid-hash` as the default: directories use path hashes, files use backing-branch/inode hashes. Its `use_ino` option was removed in 2.35. Source release can therefore change file identity. Source `mkdocs/docs/remote_filesystems.md` recommends `inodecalc=path-hash`, `never-forget-nodes=true` (or a bounded `remember-nodes`), and no lazy unmount for NFS exports. Keeping nodes costs memory; path hashing hides hardlink identity and still does not promise persistent FUSE node handles across daemon restart. This repair does **not** change those options. A separate exporter rollout requires its own handle-lifetime test and coordinated client remount. Retaining directories alone is not proof that online release is safe.

## Public status contract

`/var/lib/disk-array/towada/status.json` is root-owned, mode 0644, in a traversable 0755 directory. It contains no names, paths, hashes or secrets:

```json
{"schemaVersion":1,"observedAt":1792445000,"phase":"copy-complete","pendingFiles":null,"pendingBytes":null,"protectedFiles":null,"releasedFiles":0,"lastError":null}
```

- `observedAt`: epoch seconds when this summary was written. It is not a parity freshness guarantee.
- `phase`: command name while running; `<command>-complete` after success; `failed` after refusal. Scheduled success is `scheduled-complete`.
- `pendingFiles`, `pendingBytes`: always null. No live backlog measurement is claimed.
- `protectedFiles`, `releasedFiles`: last processed batch counts, or null when not known. Protected counts describe the receipt, not a current array-wide protection assertion. Later external changes can invalidate evidence.
- `lastError`: null or `operation-refused`. Details remain in the private journal/receipts.

Read-only `plan` and `admit`, and lock-contention failures, do not rewrite the summary. A stale or absent summary is unknown, not healthy.

## nsncd

The observed failure was five clean resolver-triggered restarts in six seconds, not a daemon crash (`NRestarts=0`). NixOS openresolv calls `systemctl try-restart --no-block nscd.service` to invalidate libc nscd's cache. Zao runs **nsncd**, which does not cache. The host override sets `libc_restart=':'` only for nsncd; glibc reloads resolv.conf without restarting the proxy. The start limiter remains unchanged. The exact network interface event sources were not identified; suppressing this unnecessary invalidation removes their restart amplification without an unlimited restart loop.
