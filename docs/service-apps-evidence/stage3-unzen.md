# Stage 3 — Unzen — 2026-11-07

YouTube, Ossicle and Pyxis run on Unzen. Reader/comics remains on Zao because
its installed narration worker requires CUDA and explicitly forbids CPU fallback.
No source data, source unit definition or tsnet identity was deleted.

## Results

Sizes below are apparent data-tree bytes, excluding tsnet state and retained
migration archives. The original `du -sh` readings were 3.1 MiB, 5.4 GiB and 52 GiB.

| Service | Result and address | Data bytes | Zao user units | Unzen system units |
| --- | --- | ---: | --- | --- |
| reader | Blocked; `https://reader.hummingbird-lake.ts.net` still serves from Zao | Shared comics state plus 10,963 bytes of reader tsnet state | `reader-proxy.service` remains active | None |
| comics | Same backend as reader, `127.0.0.1:4288` on Zao; blocked with reader | 443,937,973, excluding the library mirror | `comics.service` and `comics-library-sync.timer` remain active; sync service remains on Zao | None |
| youtube | Accepted; `https://youtube.hummingbird-lake.ts.net` | 3,224,729 | `youtube.service`, `youtube-tsnet.service`, `youtube-ytdlp-update.timer` stopped and disabled | `youtube.service`, `youtube-tsnet.service`, `youtube-ytdlp-update.timer` |
| ossicle | Accepted; `https://podcasts.hummingbird-lake.ts.net` | 5,772,391,196 | `ossicle.service`, `ossicle-proxy.service`, `ossicle-ytdlp-update.timer` stopped and disabled | `ossicle.service`, `ossicle-tsnet.service`, `ossicle-ytdlp-update.timer` |
| pyxis | Accepted; `https://pyxis.hummingbird-lake.ts.net` | 55,006,425,376 | `pyxis.service`, `pyxis-tsnet.service`, `pyxis-ytdlp-update.timer` stopped and disabled | `pyxis.service`, `pyxis-tsnet.service`, `pyxis-ytdlp-update.timer` |

Each migrated timer also has its corresponding `*-ytdlp-update.service` on Unzen.
All original definition links remain on Zao, reporting `linked` rather than
`enabled`. All three `enabled-<app>` updater gates are open, root-owned 0600.
The unrelated `pyxis-prototypes.service` was not changed.

Reader's server half is `comics-server`, from `comics-tts`. It is not a second
backend. `services/tts/kokoro_worker.py:81–82` raises
`CUDA is unavailable; CPU fallback is forbidden`. Unzen has no `/dev/nvidia0`.
Neither narration nor the library mirror was silently removed. No comics state
or `~/.local/share/comics*` directory was changed by this migration. A later
reader/comics move needs to preserve narration, use one writer, and bind Unzen's
`/srv/lakes/towada/comics` read-only. The source mirror timer must then be stopped
and disabled with the shared backend. That cutover was not performed here.

## Committed source provenance

Before Pyxis and the final YouTube cutovers, and retrospectively for Ossicle,
evaluating the original app at the following full Git revisions reproduced the
**exact original Zao package store paths**, not only their versions:

| App | Original committed revision | Original Zao package |
| --- | --- | --- |
| Pyxis 2.0.0 | `e2e863d3a326242f415dd6f51a4110b0c69c9aad` | `3q482zfmh5rp5ndhhnizh6w8jlk401mp-pyxis-2.0.0` |
| YouTube 0.1.0 | `1b761c413048bc5f0197d16f26f1b43f34c54f44` | `qnzijqzdcxvz6j6va01bfd2qcv85aazj-youtube-0.1.0` |
| Ossicle 0.1.0 | `62ef195474117fbaf7442d234a974bc83b019657` | `9251kkccl0xmvl21bgml8vlzhc8nbb15-ossicle-0.1.0` |
| comics-tts 0.1.0 | `20bc6ee2f67d57116cbff6640972afa1cb83dca8` | `23fjdhz0q4jx9ylvh658ckgy76rykc6q-comics-tts-0.1.0` |

The first three original repositories are clean. Comics' live package is older
than current `master`, but it is fully reproducible from the commit above. Its
exact filtered web source is `98zsizgb3yj8mkzrqf9bgb1a1ds1402i-source`, NAR hash
`sha256-2meG+TZn8etWmHYmrUiNLyvZhyLRM6o4hizQ+Hfx4Hk=`. This is a filtered
web-source hash, **not** a claimed full dirty-tree flake hash. The current comics
checkout has uncommitted `.gitignore`, archived work-document deletions and an
untracked `progress.md`; none was committed, copied into a deployment, or removed.

The new app branches preserve those app versions. Changes are packaging only:
YouTube's bind/version adapter and server alias; Ossicle's CLI version metadata;
and Pyxis' Nix tests. No existing test was disabled.

“Complete source” in the successful Pyxis build means its Nix test source now
includes the SDK reference-plugin fixture and generated contracts. Its Bun
shebang is patched for the Nix sandbox. The original core package had
`doCheck = false`; the new package runs all 244 Rust tests and a CLI version check.
This phrase does not mean any uncommitted application work was adopted.

## Branches and commits

The source branches are served read-only over the tailnet from the original
repositories on Zao. Their original working checkouts were not switched.

| Repository | Branch | New commits / selected tip |
| --- | --- | --- |
| `code/sandbox/youtube` | `service-apps-unzen` | `0b3d69c` |
| `code/sandbox/ossicle` | `service-apps-unzen` | `cfda55d`, `4c112f7` |
| `code/github/simonwjackson/pyxis` | `service-apps-unzen` | `a601c0d`, `f988faf`, `1970a27`, `112c9dd` |
| `code/github/simonwjackson/proseql` | `service-apps-unzen` | existing `0f9c9cc46fe2a1219dc4efccaa75092518dd7724` |
| same | `service-apps-pinned-meetings` | existing `5f83bdb238d21415c484e98c79d4500dd23bbc3b`, advertised so pinned fetches succeed |

Mountainous work branch:
`c-822b77bd3d4718747f9689b5d2c22b55ce437dc3f4851f451f12961bb1ee0470`.
Its functional commits are `c6b44a01`, `4b122d8b`, `6fc69f11`, `42c6fbb7`,
`1a04810e`, `28da98c1`, `85708ffc`, `88e64d1a`, and `963a921e`.
They are on `origin/cairn`. Every push fetched and rebased first; no force-push
was used. Concurrent input conflicts were regenerated with `nix flake update`.
The initial YouTube input auto-merge produced duplicate lock keys; the parent's
`9c189c5c` repaired the lock before any deployment from that tree. The pending
switch was cancelled. Later checks also verified the YouTube and pyxamp pins.

## Switch loss checks

Both switches below built the newest pushed `origin/cairn` on Zao with
`--max-jobs 2 --cores 4 --option builders ''`. The Unzen flock covered each
build/compare/switch. After the shared-checkout race was found, the outer
`stage3-migration.lock` covered pinning through cutover and result checks; the
switch lock was always acquired inside it.

| Switch source | Running system → candidate | Reviewed comparison SHA256 | Result |
| --- | --- | --- | --- |
| `85708ffc364929a533b19763db3308c5f466f9c9` | `l2nfzjw3…` → `47bk1l2x…` | `c624407a602490d0f6797bdc4a91537d525a1cf27b61699e680654f7b4e3c721` | No removed units, closure entries or `/etc` files. Adds Ossicle, the other worker's meetings updater, and private secret-parent provisioning. |
| `963a921e51aa38478350cfdff9b6b32c0202e613` | `b7fqwqb8…` → `jccq5jzx…` | `a3cfdd8853da9359f979303001ab9491690d5e919f8a9d157572f8e06fe08228` | No removals. Adds Pyxis and LAN TCP 9000 on `bond0` only; preserves the other worker's Storia updater. Nightly refresh clocks retain Zao's America/Denver wall time. |

The comparisons used on-host `nix store diff-closures`, complete `/etc` content
comparison and explicit old/new system-unit lists. The firewall script diff was
also inspected: its only rule addition permits TCP 9000 on `bond0`.
After each switch and cutover, the target reported `running`, zero failed units,
and active Jellyfin, Scryer, Prowlarr, Transmission, media VPN, Beszel, media
sidecars, storage-health timer and all installed app-update timers.

## Data and acceptance

Ossicle's 5,772,391,196-byte and Pyxis' 55,006,425,376-byte initial rsyncs completed
while their Zao services were active. The guarded cutover copied stopped tsnet
state. Its reviewed deploy command then confirmed both sides stopped, stopped
the source refresh timer, performed a short final data rsync, verified it with a
checksum dry-run, and only then ran signed activation. Existing destination
copies replaced during final sync were backed up. Source data remains on Zao.
The final Pyxis pass transferred one 17,588,552-byte database file, using matching
rsync blocks; it did not transfer the 55 GB library during the outage.

Acceptance used the old public addresses and existing state:

- Ossicle: all 11 podcast IDs, exact positions/queue/settings, a cached MP3 HTTP
  byte range, and Vela CORS.
- Pyxis: an existing bearer token, unchanged albums/bookmarks/playlists, account
  and contract identity, retained plugins, and Vela CORS. No device was claimed
  and no physical Sonos playback or command was issued.
- YouTube: all stable database rows, one user, one site, two credentials, both
  generated encryption identities, HTTP health, unauthenticated admin refusal
  and successful authenticated access with the existing admin credentials.
  Upstream re-salts the env admin's bcrypt hash on startup and updates
  `last_login` on authenticated reads; those two generated fields were checked
  by the working credential, not by byte equality.

Signed successful receipts under `/var/lib/app-updater/receipts/` on Unzen:

| App | Receipt | Accepted executable profile |
| --- | --- | --- |
| Ossicle | `1794078316603424174.json` | `179sxljb96q0x4y3pl6yp3gsdx34bx55-activatable-ossicle-0.1.0` |
| Pyxis | `1794079698511185035.json` | `681kynmkiw0zgqk4dnqb7b4hi2laqm2m-activatable-pyxis-2.0.0` |
| YouTube | `1794079795992739812.json` | `2c5gs3lys9yka7d49zrv5kpmp4vwi0i7-activatable-youtube-0.1.0` |

Failed attempts returned to Zao before proceeding: YouTube's first attempt
exposed missing `.config` parents, now covered by the Nix contract; a later
attempt exposed an operator probe error (unauthenticated `/admin` correctly
returns 401, not 200). Ossicle's first attempt rejected a concurrently changed
updater checkout after the final sync. The migration flock resolves that race.
All unaccepted state and profile generations were retained before retry.
No rollback failure fixture was run against a production app.

## yt-dlp refresh policy

All three keep a small Unzen system timer using their existing packaged updater
binary and private state. The app updater follows its Git input, not the separate
yt-dlp nightly feed, so replacing these timers with app-input updates would stop
nightly refreshes. Refresh calendars retain Zao's original local wall time:
03:30 America/Denver for Ossicle/Pyxis, 04:15 America/Denver for YouTube, each with
45-minute random delay and persistence. Their binaries' existing last-good/floor
behavior is unchanged. Their app-profile update gates are separate.

## Checks

- `bash scripts/check-flake-inputs.sh`: pass, including the pre-push hook.
- Unzen toplevel single-attribute evaluation: pass.
- `python3 -m unittest tests/test_service_apps.py`: 9 passing tests.
- Combined focused `tests/test_app_update.py` and service-app tests: 18 passing.
- Nix `service-apps` contract, `service-app-tools` package, per-app checks and
  deploy schema: individually built with two jobs and empty builders; pass.
- Deploy schema isolation regression: failed with the original implementation
  because it tried to build an intentionally failing unrelated profile; passes
  after removing string context only from schema validation. Real activation
  checks keep their dependencies.
- Upstream Ossicle build: 103 Rust tests and version install check pass.
- Upstream Pyxis build: 244 Rust tests and version install check pass. The initial
  newly enabled SDK test failed because the fixture interpreter/source closure
  was missing; packaging was corrected without disabling tests.
- YouTube package build: shell checks and version/invalid-argument install tests
  pass; live signed activation and account/site checks pass.
- `nixfmt --check`, Python compile checks and `git diff --check`: pass for changed
  platform files. No aggregate flake verification was run.
- Recursive on-host `nix store verify --no-contents --sigs-needed 1` passes for
  all three accepted executable profiles. Jellyfin's HTTP `/health` returns
  `Healthy`; all three public-origin acceptance probes pass again at completion.

## CLIProxyAPI baseline failure

Verified: the last successful nightly before the failure was
2026-11-06 03:01:24 UTC. The first failed run since November 1 was
2026-11-07 03:06:00 UTC, after Unzen's earlier 01:50 system switch. Its error was:
`build ... on 'ssh-ng://simon@nix-builder-aka' failed ... local builds are disabled
(max-jobs = 0)`. Aka's running config had `max-jobs = 0` and empty `builders`;
its system symlink dated 2026-11-06 18:16:38 UTC. The previous successful run used
`simonwjackson@nix-builder-aka`.

Inferred likely cause: the fleet builder/account transition selected an Aka
daemon that cannot build. The failing path is CLIProxyAPI's separate updater,
not `scripts/app-update.py`. The service-app script's native-build flags do not
repair that separate path. These observations do not prove which prior Aka
switch introduced zero build capacity. No CLIProxyAPI path or service was changed
here. The failure flag was gone after the other worker's switch; this is not
proof that its next nightly will succeed. That remains a high-priority follow-up.

Remaining limits: reader/comics has not moved; its mirror timer remains required
on Zao. Sonos physical playback and fresh external-provider extraction were not
exercised. Pyxis's LAN URL uses Unzen's observed `192.168.1.114` lease and needs
that address to remain reserved. App updates follow the new source branches;
future upstream changes must reach those branches or their input refs must be
advanced after integrating the packaging changes.
