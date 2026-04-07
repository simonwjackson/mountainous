# Media Tiering Migration Report — 2026-04-07

## Overview

Renamed the entire storage namespace across `zao` and `yari` and introduced
cross-host media tiering with mergerfs unions. Both hosts are switched and
live. Jellyfin on `zao` serves content through the merged range view. ARR
services on `yari` import locally and see a unified library through mergerfs.

## Architecture

### Naming Tiers

| Tier | Purpose | zao path | yari path |
|------|---------|----------|-----------|
| **Shores** | Individual physical disks | `/srv/shores/towada/{00..04}` | — |
| **Lake** | mergerfs union of shores + NVMe cache | `/srv/lakes/towada` | — |
| **Basin** | This host's media contribution (identity layer) | ⚠️ NOT YET IMPLEMENTED | `/srv/basin/media` |
| **Range** | App-visible merged view (local + remote) | `/srv/range/media/{movies,tv}` | `/srv/range/media/{movies,tv}` |
| **Network** | Cross-host NFS mounts | `/net/mountainous/yari/media` | `/net/mountainous/zao/media` |

### Data Flow

```
yari:                                         zao:
  ARR imports → /srv/basin/media/{movies,tv}
                    ↓ (local branch)
  /srv/range/media/{movies,tv}                /srv/range/media/{movies,tv}
    = mergerfs:                                 = mergerfs:
      /srv/basin/media/* (local, rw)              /srv/lakes/towada/media/* (local, rw)
      /net/mountainous/zao/media/* (NFS, rw)      /net/mountainous/yari/media/* (NFS, rw)
                                                        ↑
  mover →→→ /net/mountainous/zao/media/*        Jellyfin reads from /srv/range/media/*
         (rsync + verify + delete source)
```

### NFS Exports

| Host | Export path | Mode | Filesystem |
|------|-----------|------|------------|
| zao | `/srv/lakes/towada/media` | rw | FUSE (mergerfs) |
| yari | `/srv/basin/media` | rw | XFS (root disk) |

Both use `all_squash,anonuid=0,anongid=0` (maps all NFS clients to root:root).
Client CIDR: `100.64.0.0/10` (Tailscale).

### Mergerfs Mounts

| Host | Mountpoint | Branches | Create policy |
|------|-----------|----------|---------------|
| zao | `/srv/lakes/towada` | cache + shores 00,01,04 | `ff` (cache first) |
| zao | `/srv/range/media/movies` | `lakes/towada/media/movies` + `yari NFS/movies` | `ff` |
| zao | `/srv/range/media/tv` | `lakes/towada/media/tv` + `yari NFS/tv` | `ff` |
| yari | `/srv/range/media/movies` | `basin/media/movies` + `zao NFS/movies` | `ff` |
| yari | `/srv/range/media/tv` | `basin/media/tv` + `zao NFS/tv` | `ff` |

### Mover (yari only, role=source)

- **Nightly timer**: `*-*-* 03:00:00 America/Denver` — moves all eligible media
- **Low-space timer**: every 5 minutes — drains when local FS ≤ 20% free
- **Safety**: skips files < 60 minutes old, skips busy files (lsof), flock serialization
- **Workflow**: rsync to temp → cmp verify → mv into place → rm source → prune empty dirs
- **Post-move**: authenticates to Jellyfin on zao, triggers library refresh
- **Source**: `/srv/basin/media/{movies,tv}` (local backing)
- **Destination**: `/net/mountainous/zao/media/{movies,tv}` (NFS into zao's lake mergerfs)

### App Paths

| App | Host | Library dirs | Download dirs |
|-----|------|-------------|---------------|
| Radarr | yari | `/srv/range/media/movies` | `/srv/basin/downloads/usenet/completed`, `/srv/basin/downloads/torrents/completed` |
| Sonarr | yari | `/srv/range/media/tv` | (same) |
| Jellyfin | zao | `/srv/range/media/movies`, `/srv/range/media/tv` | — |

### Key NFS Lesson Learned

NFS cannot traverse FUSE sub-mounts under a non-FUSE export. Specifically:
- Exporting `/srv/basin/media` (btrfs) with bind-mounted FUSE children → **fails**
- Exporting `/srv/lakes/towada/media` (the FUSE mount itself) → **works**

The export root must BE the FUSE mount, not a real FS with FUSE mounted inside.
This is why zao exports from inside the lake mergerfs directly, and why the
original plan to use `/srv/basin` as the NFS export on zao didn't work.

---

## Open Issues

### Issue 1: Basin Does Not Exist on zao

**Problem**: The naming convention defines three tiers (lake → basin → range),
but on zao `media.root = "/srv/lakes/towada"` so the lake serves double duty
as both lake and basin. There is no `/srv/basin` directory on zao. If a second
lake is added, there's no aggregation layer.

**Impact**: Conceptual inconsistency. Downloads on zao would go to
`/srv/lakes/towada/downloads/...` which puts downloader work on USB spinning
disks. Not currently a problem since zao doesn't run downloaders.

**Proposed fix**: Set `media.root = "/srv/basin"` on zao. Create a dedicated
mergerfs at `/srv/basin/media` that directly unions the shore media directories
(`shore00/media + shore01/media + shore04/media`), bypassing the lake and its
cache tier. Export this basin mergerfs via NFS. The lake continues to exist for
non-media uses (books, gaming, code, etc.). The range mergerfs then unions
basin + yari NFS, same as on yari.

This requires:
- A new mergerfs mount definition (possibly via the media-tiering module or a
  new basin-specific config)
- Updating `media.root` on zao from `/srv/lakes/towada` to `/srv/basin`
- Verifying NFS export works from the new basin mergerfs
- The lake mergerfs still handles snapraid, cache mover, etc.

**Alternatively**: Accept that on hosts with a lake, the lake IS the basin.
Document this as intentional. The naming is aspirational for multi-lake hosts.

### Issue 2: NFS Ownership Drift (root:root)

**Problem**: Both NFS exports use `all_squash,anonuid=0,anongid=0`. All NFS
operations appear as `root:root` on the remote host. When the mover writes
files from yari to zao over NFS, they land as `root:root`. When Jellyfin
(uid=991 on zao) tries to manage these files locally, it relies on the
mergerfs running as root. Direct filesystem access by non-root services will
fail. Any manual `chown` fix gets overwritten by the next mover run.

**Impact**: Jellyfin currently works because mergerfs FUSE runs as root and
handles file operations. But if Jellyfin or any future service accesses the
backing path directly (not through mergerfs), permission denied. Also, the
Jellyfin delete-via-NFS path sends the delete as root (squashed), which works
but is overly permissive.

**Proposed fix**:
1. Assign a **static GID** to the `media` group on both hosts:
   ```nix
   users.groups.media.gid = 993;  # or any fixed number
   ```
2. Set NFS exports to use `anongid=<media-gid>`:
   ```
   all_squash,anonuid=0,anongid=993
   ```
   Files created over NFS will be `root:media`.
3. Ensure all media files are **group-writable** (`g+w`).
4. Ensure `jellyfin`, `sonarr`, `radarr`, and `simonwjackson` are in the
   `media` group on their respective hosts.
5. The mover script should `chmod g+w` after transfer, or use rsync options
   to preserve group-writable permissions.

With this, NFS writes create `root:media` files with group write permission.
Any service in the `media` group can manage them. Root-squash is maintained
for safety.

**Alternative**: Use `no_all_squash` and let real UIDs pass through. But UIDs
are dynamically assigned by NixOS and differ between hosts (jellyfin is 991 on
zao, doesn't exist on yari). This would require static UIDs for all media
service users across all hosts — more invasive.

### Issue 3: Split Directory Creation Responsibility

**Problem**: When media-tiering is enabled, `moviesDir` and `tvDir` point to
range paths (`/srv/range/media/movies`). The media module's tmpfiles creates
these range dirs. The tiering module's tmpfiles creates the basin-level backing
dirs (`/srv/basin/media/movies`, `//srv/basin/media/tv`). This split caused
`/srv/basin/media/tv` to be missing on yari after switch — we had to create it
manually.

**Impact**: Fragile boot — if tmpfiles ordering is wrong or the tiering module
fails to create backing dirs, mergerfs mounts will fail.

**Proposed fix**: The media module should always create dirs under `mediaRoot`
(the basin physical layer) regardless of whether `moviesDir`/`tvDir` point to
range. Add these to the media module's tmpfiles:
```nix
cfg.mediaRoot            # /srv/basin/media
"${cfg.mediaRoot}/movies"
"${cfg.mediaRoot}/tv"
```

This way the physical backing dirs always exist. The tiering module creates
the range dirs and mergerfs mounts on top. Clear ownership: media module owns
basin dirs, tiering module owns range dirs.

### Issue 4: Mover Writes Through Cache (Double-Hop)

**Problem**: On zao, the NFS export is from the lake mergerfs. The lake's
`category.create=ff` policy puts the NVMe cache first. When the mover on yari
writes a file to `/net/mountainous/zao/media/movies/Foo`, the write goes:

```
yari → NFS → zao lake mergerfs → NVMe cache (/srv/cache/towada)
                                       ↓ (hourly cache mover)
                                  backing shore (XFS)
```

Files sit in the NVMe cache until the cache mover evacuates them. If the cache
fills up during a large mover batch, the `moveonenospc` mergerfs policy kicks
in, but there's a window where writes might fail.

**Impact**: Not broken, but:
- Files aren't "settled" on spinning disks until the cache mover runs
- A large batch transfer could fill the NVMe cache
- SnapRAID doesn't see files until they reach the shores

**Proposed fix options**:
1. **Accept it** — the cache tier is designed for exactly this: absorb burst
   writes, drain to slow storage. The hourly mover handles drainage.
2. **Create a basin mergerfs without the cache tier** (see Issue 1) and export
   that instead. Mover writes go directly to shores, bypassing cache.
3. **Run the cache mover immediately after mover batches** — add a
   `systemctl start towada-cache-mover` to the mover's post-transfer hook.

Option 3 is the least invasive.

### Issue 5: Stale Data on Disk

**Enola Holmes duplicate in cache**:
- Exists at `/srv/cache/towada/media/movies/Enola Holmes (2020)/`
- Also exists at `/srv/basin/media/movies/Enola Holmes (2020)/` on yari
- Likely written to cache during earlier testing when content was pushed to
  the old `/srv/pool/tank0/media/movies` path which included the cache branch
- **Fix**: Delete from zao cache: `sudo rm -rf /srv/cache/towada/media/movies/Enola\ Holmes\ \(2020\)/`
  then trigger a Jellyfin library refresh.

**Legacy empty directories on shores**:
- `/srv/shores/towada/{00,01,04}/movies/` — empty after mv to `media/movies/`
- `/srv/shores/towada/{00,01,04}/series/` — empty after mv to `media/tv/`
- **Fix**: `sudo rmdir /srv/shores/towada/*/movies /srv/shores/towada/*/series`

**Old yari media at /srv/storage**:
- `/srv/storage/` may still exist on yari with residual content
- The rename from `/srv/storage` to `/srv/basin` was done via partial `mv`
  operations; completeness was not verified for all subdirectories
- **Fix**: Audit `ssh yari 'du -sh /srv/storage/*'` and either move remaining
  content or clean up.

---

## Current Host State (as of 2026-04-07 ~12:00 MDT)

### zao (switched, persistent)

- **Config**: `hosts/zao/default.nix`
- **media.root**: `/srv/lakes/towada`
- **media-tiering**: role=sink, peerHost=yari
- **Disk array**: 5 USB disks (shores 00-04), mergerfs lake at `/srv/lakes/towada`
- **Cache**: NVMe btrfs at `/srv/cache/towada`
- **NFS export**: `/srv/lakes/towada/media` (rw, fsid=0)
- **NFS mount**: `yari:/` at `/net/mountainous/yari/media` (rw, automount)
- **Range mergerfs**: `/srv/range/media/{movies,tv}`
- **Jellyfin**: running, libraries at `/srv/range/media/{movies,tv}`
- **Jellyfin DB**: cleaned of old `/srv/pool/tank0` and `/net/yari` paths
- **Jellyfin counts**: 9 movies, 4 series, 39 episodes
- **SnapRAID conf**: `/etc/snapraid-towada.conf` (shores/towada paths)
- **All services**: green

### yari (switched, exit code 4 from systemd-run wrapper but config applied)

- **Config**: `hosts/yari/default.nix`
- **media.root**: `/srv/basin`
- **media-tiering**: role=source, peerHost=zao, mover enabled
- **NFS export**: `/srv/basin/media` (rw, fsid=0)
- **NFS mount**: `zao:/` at `/net/mountainous/zao/media` (rw, automount)
- **Range mergerfs**: `/srv/range/media/{movies,tv}`
- **Mover timers**: active (nightly + low-space)
- **Source-migrate stamp**: present at `/var/lib/media-tiering/source-migrated`
- **Basin content**: `/srv/basin/media/movies/Enola Holmes (2020)/`
- **Basin tv**: empty (content was on the old `/srv/storage/media/tv/` path,
  may need manual migration)
- **Sonarr/Radarr**: using range paths for library dirs, basin paths for downloads

### Git State

- Branch: `unified`
- Latest commit: `2501cc1` — "fix: NFS export from mergerfs lake, drop localSources bind mounts"
- Pushed to origin

---

## Files Modified in This Migration

### Feature modules
- `features/disk-array/pool-options.nix` — mountBase `/srv/shores/`, mergedPath `/srv/lakes/`
- `features/disk-array/nixos.nix` — tmpfiles parent dirs
- `features/media/default.nix` — root default `/srv/basin`, added rangeRoot/rangeMoviesDir/rangeTvDir
- `features/media/nixos.nix` — unchanged (tmpfiles derive from options)
- `features/media-tiering/default.nix` — localBackingRoot default `${media.root}/media`, peerMountRoot `/net/mountainous/${peer}/media`, added nfs.anonuid/anongid options
- `features/media-tiering/nixos.nix` — mergerfs targets range paths, both export/mount modes rw, range tmpfiles
- `features/syncthing/default.nix` — example path updated
- `features/transmission/default.nix` — example path updated
- `features/jellyfin/nixos.nix` — unchanged (bootstrap paths come from host config)
- `features/sonarr/default.nix` — Jellyfin notification options (from earlier work)
- `features/sonarr/nixos.nix` — Jellyfin notification seeding (from earlier work)
- `features/radarr/default.nix` — same
- `features/radarr/nixos.nix` — same

### Host configs
- `hosts/zao/default.nix` — pools.towada, media.root=/srv/lakes/towada, Jellyfin libs at /srv/range, media-tiering sink
- `hosts/zao/disko.nix` — cache mountpoint /srv/cache/towada
- `hosts/yari/default.nix` — media.root=/srv/basin, media-tiering source with mover

### Packages (from earlier Jellyswarrm work, included in same commits)
- `packages/jellyswarrm/default.nix` — new
- `features/jellyswarrm/default.nix` — new
- `features/jellyswarrm/nixos.nix` — new
- `flake.nix` — jellyswarrm input
- `flake.lock` — updated

---

## Manual Operations Performed on Live Systems

### zao
1. Moved media from legacy dirs to canonical layout on each shore:
   ```
   shore/{00,01,04}/movies/* → shore/{00,01,04}/media/movies/
   shore/{00,01,04}/series/* → shore/{00,01,04}/media/tv/
   ```
2. `chown -R jellyfin:media` on `/srv/lakes/towada/movies` and `series` (old
   paths, pre-move — may need to be re-done on the new `media/movies` paths)
3. Cleaned Jellyfin DB of stale paths (`/srv/pool/tank0/*`, `/net/yari/*`,
   `/net/mountainous/yari/*`)
4. Removed stale Jellyfin library locations via API (kept only `/srv/range/...`)
5. Triggered multiple Jellyfin library refreshes

### yari
1. Moved media from `/srv/storage/media/movies` to `/srv/basin/media/movies`
   (partial — tv content may still be at old location)
2. Created `/srv/basin/media/tv` manually

---

## Deployment Notes

- `just switch zao` works (local switch)
- `just switch yari` fails with the remote sudo wrapper issue — use:
  ```bash
  ssh -F /dev/null yari 'cd ~/code/mountainous && git pull && sudo nixos-rebuild switch --flake ".#yari"'
  ```
- The `systemd-run` wrapper on NixOS 26.05 returns exit code 4 even when the
  switch succeeds. The config IS applied despite the error.

---

## Recommended Next Steps

1. **Fix Issue 2 (ownership)**: Set static `media` GID, update NFS anongid,
   ensure group-writable permissions across all media dirs.
2. **Fix Issue 3 (tmpfiles)**: Add basin-level media subdirs to the media
   module's tmpfiles so they always exist.
3. **Fix Issue 1 (basin on zao)**: Either accept lake-as-basin or create a
   dedicated basin mergerfs on zao from shore media dirs.
4. **Clean stale data (Issue 5)**: Remove Enola Holmes from zao cache, remove
   legacy empty dirs from shores, audit `/srv/storage` on yari.
5. **Fix Issue 4 (cache hop)**: Either accept it or trigger cache mover after
   media-tiering mover runs.
6. **Test Jellyfin delete flow**: Delete a title from Jellyfin UI that lives
   on each branch (local zao, remote yari via NFS) to confirm both work.
7. **Test mover end-to-end**: Import something on yari via Sonarr, wait for
   nightly mover or trigger manually, verify it appears on zao and Jellyfin
   sees it at the same path.
