# NZBFAST cutover and rollback

Unzen now selects `usenet = "nzbfast"`, `nzbfast.held = false`, and global
`processing = "enabled"`. On its next approved activation, NZBFAST starts
unheld: preStart removes the saved paused/offline keys. This commit does not
deploy or change host state.

The operator reported the held trial passed 38/38 leak-audit checks and 33/33
API/permission checks. Sonarr and Radarr SABnzbd client Test returned 200 against
`10.200.200.2:6790`. These host results were supplied by the operator, not
re-run while preparing this configuration.

The feature's default remains `"nzbget"`; Unzen explicitly selects `"nzbfast"`.
That selection disables the NZBGet unit without deleting `/var/lib/nzbget`,
`/var/lib/media-migration/ready/nzbget`, or any NZBGet payload. Unzen's NZBFAST
state is already provisioned: do not provision it again for this cutover.

NZBFAST uses UID 391, group `media` (390), `/var/lib/nzbfast`, and
`/srv/basin/downloads/usenet/nzbfast/{Series,Movies}`. It listens on
`10.200.200.2:6790` from the host through the VPN namespace. No firewall port or
new tsnet identity is opened. Port 6789 remains free for NZBGet rollback.

## Proxy decision: disabled in NZBFAST-only mode

Do not repoint `usenet.hummingbird-lake.ts.net` to NZBFAST. Its API protection
does not protect its dashboard. The pinned source serves `/` and `/index.html`
unless optional browser login is enabled (`crates/nzbfast/src/serve/http.rs:1440-1466`).
Login requires both saved web credentials (`crates/nzbfast-daemon/src/websession.rs:205-215`),
which default to absent (`crates/nzbfast/src/serve/startup.rs:1421-1422`).
With login off, `/login` redirects back to the open dashboard
(`crates/nzbfast/src/serve/http.rs:827-842`). The VM verifies unauthenticated
200 responses for both dashboard paths, a 302 for `/login`, and a 403 for
`/api?mode=queue`.

`stream_secret` is not browser authentication. It seeds a private persistent
playback secret (`crates/nzbfast-daemon/src/settings_restore.rs:1379-1406`),
used to derive per-job stream capabilities (`daemon.rs:2511-2518`).
The served shell inputs contain only page/locale/index/login settings, not an
API key or stream secret (`crates/nzbfast-api/src/webasset.rs:117-183`). API
key/session authorization is separate (`crates/nzbfast/src/serve/http.rs:1105-1170,1238-1310`).
The nonsensitive `mode=version` health probe remains public (`http.rs:1190-1203`).

The existing `tsnet-proxy-nzbget` unit is therefore absent in NZBFAST-only mode.
Its saved identity state is not removed. No replacement identity or credential
is created.

## Single-switch rollback

Change only Unzen's `usenet` to `"both"` or `"nzbget"`. Either restores NZBGet
and its existing `usenet` proxy at `10.200.200.2:6789`, gated on `ready/nzbget`.
`"both"` leaves NZBFAST unheld too; use `"nzbget"` if it must stop. Neither
selection removes NZBFAST state or changes its port.

Run `nix eval --impure --expr 'import ./tests/media-nzbfast-rollback-contract.nix'`
to compare NZBGet ExecStart/unitConfig and the complete generated proxy unit
text with Cairn `02f89d053ac484302562e3b81e7880f721c5134e`. Both rollback modes
must match. The comparison requires that revision in the local Git history.

## First start for a new held trial (not the admitted Unzen state)

First select `usenet = "both"` and `nzbfast.held = true` for that trial.
Run as root only after an approved activation. This change does not execute
these commands on a host.

1. Keep `/var/lib/media-migration/ready/nzbfast` absent.
2. Run `scripts/media-nzbfast-provision.py --check`.
3. Run `scripts/media-nzbfast-provision.py`. It copies only Server1 from the
   saved NZBGet file, with fallback host/port/TLS/connections from the module.
   It does not modify NZBGet. The output is atomic, owned by `nzbfast:media`,
   mode 0600. An existing config requires an explicit `--force`.
4. Review the redacted summary. Create the gate with
   `touch /var/lib/media-migration/ready/nzbfast`, then
   `systemctl start nzbfast.service`.
5. Read the API key privately from `settings.json` for a future client setup.
   Do not paste settings or provider credentials into logs or Nix configuration.
   Do not enable ARR integration or release the processing hold for this trial.

Pre-seeding settings **suppresses upstream API-key generation**. The service
therefore generates a random API key in its private settings file before its
first launch. It preserves that key on restart. Established spool state without
an API key fails closed instead of becoming an open API. This avoids a first
unheld launch just to obtain a key. No credential enters the Nix store.

`preStart` validates servers, atomically applies service policy, then lets the
upstream module synchronize bind/output/port. Malformed settings stop startup.
While held, a non-empty `schedule` or a non-null `pause_until_unix` also stops
startup without writing settings. The operator must explicitly remove those
standing rules before retrying; the service does not silently delete them.
Policy refusals name the field and the repair commands without printing values.
Malformed state keeps the generic refusal message.

NZBFAST permits at most five starts in 60 seconds. With upstream's five-second
restart delay, a permanent preStart refusal stops after about 25 seconds with
`start-limit-hit`. Five starts leave room for an initial launch, a daemon
restart, and short VPN recovery sequences. The VM proves two consecutive VPN
restarts recover active, held NZBFAST after valid state and `reset-failed`.
More rapid tunnel flaps can hit the same limit; after fixing the cause, run
`systemctl reset-failed nzbfast` and `systemctl start nzbfast`.
Upstream creates the output root as 2770; a non-recursive tmpfiles `z` rule sets
2775/root/media without changing payload ownership. Category directories use
ordinary `d` rules with 2775/root/media. `.spool` is under the state directory;
no extra writable sandbox path is needed.

The signed nix-extras cache uses its own nixpkgs pin. Following this flake's
nixpkgs changes the NZBFAST output path and loses that cache entry.

## Upstream contract, v1.7.1 (`370da775361e29a9fb0d490f4750df899ea56c92`)

Paths below are relative to the NZBFAST source, not this repository.

| Key | Service policy | Source |
| --- | --- | --- |
| `auto_rename` | false | `crates/nzbfast-daemon/src/settings.rs:593-595` |
| `spot_enabled` | false | `crates/nzbfast-daemon/src/settings.rs:690-692` |
| `index_enabled` | false | `crates/nzbfast-daemon/src/settings.rs:685-687` |
| `identity_lookup` | false | `crates/nzbfast-daemon/src/settings.rs:596-598` |
| `update_checks` | false | `crates/nzbfast-daemon/src/settings.rs:1172-1174` |
| `delete_to_trash` | false | `crates/nzbfast-daemon/src/settings.rs:371-374` |
| `categories` | `"Series, Movies"` | `crates/nzbfast-daemon/src/settings.rs:357` |
| `cat_meta` | relative dirs `Series` / `Movies` | `crates/nzbfast-daemon/src/settings.rs:364`; `settings_restore.rs:198-203` |
| `out_umask` | octal string `"002"` | `crates/nzbfast-daemon/src/settings.rs:449-457`; `bootstrap.rs:1263-1270` |
| `paused`, `offline` | true when held; removed when released | `crates/nzbfast-daemon/src/daemon_shutdown.rs:842-870` |
| `schedule` | refuse non-empty schedules while held; preserve empty schedules | `crates/nzbfast-tasks/src/tasks.rs:76-108` |
| `pause_until_unix` | refuse non-null deadlines while held; remove when releasing | `crates/nzbfast-daemon/src/daemon_shutdown.rs:860-887` |
| `paused_by_offline` | remove old pause ownership bookkeeping | `crates/nzbfast-daemon/src/daemon_shutdown.rs:851-855` |
| `apikey` | private random key only on fresh state | `crates/nzbfast-daemon/src/settings.rs:1191-1197`; `bootstrap.rs:616-725` |
| `bind`, `port`, `out_dir` | upstream module owns these | `crates/nzbfast-daemon/src/settings.rs:306-323` |

The fresh-install exclusion is `bootstrap.rs:673`, and `.spool` resolution is
`bootstrap.rs:151-154`. `ServerConfig` uses `host`, `port`, `tls`, `username`,
`password`, `connections` (`crates/nzbkit-base/src/config.rs:75-116`) and
`enabled` (`config.rs:194-197`), inside `servers` (`config.rs:60`).
Upstream restores `categories` by adding names to its native defaults, not by
replacing them (`settings_restore.rs:686-693`). The trial's two ARR names and
relative destinations are present, but the API also lists native categories.
The SAB queue exposes `paused` and `offline` in
`crates/nzbfast-api/src/sabcompat.rs:1428-1435`.

## Startup hold review

The pinned source restores pause state before spawning tasks
(`crates/nzbfast/src/serve/startup.rs:63-65,484`). The schedule replays after
that restore and can resume a paused queue. Its accepted actions are only
pause, resume, speedlimit, server enable/disable, and quota reset; it has no
online action (`crates/nzbfast-daemon/src/sched.rs:138-171`). All non-empty
schedules are refused while held, including JSON strings and raw arrays.

Another unsafe saved startup path is `pause_until_unix`: an expired deadline
starts resumed, and a future deadline arms the worker that later clears pause
(`crates/nzbfast-daemon/src/daemon_shutdown.rs:876-887,668-672`). Held admission
now refuses either without writes. The VM covers both deadlines and the resume
schedule, then starts the real pinned daemon with an empty schedule and checks
`paused=true, offline=true` through its API.

I found no further saved startup path that clears global pause/offline in this
pin. The other production writers are authenticated resume/online API actions
(`crates/nzbfast-api/src/api/queue.rs:144,1795-1798`; `sabcompat.rs:2894`) and
slow-storage recovery. Slow-storage recovery stands down while offline
(`crates/nzbfast-daemon/src/slowstore.rs:917-929`). RSS and watch folders enqueue
jobs, but do not clear the global flags
(`crates/nzbfast-tasks/src/tasks.rs:1370-1385`; `tasks/watchfolder.rs:638-654`;
`crates/nzbfast-daemon/src/daemon_enqueue.rs:395-398`). They therefore need no
additional pause admission rule. Configured RSS feeds can still poll HTTP
sources; the startup hold is not a prohibition on every background HTTP task.

## VPN leak audit selection

`media-runtime` writes `/etc/media-vpn-leak-audit.json` from the same active
mode/placement predicate that attaches services to the namespace. Run
`scripts/media-vpn-leak-audit.py --list-services` to read its expectations
without running a host audit. Rollback to `usenet = "nzbget"` removes NZBFAST
from membership, DNS, and BindsTo checks. An expected inactive service remains
a failure. Missing or invalid declarations refuse the audit. Any failed audit
check now gives a non-zero exit status.

## Limits

No deployment, production credentials, provider connections, or host leak audit
are part of this change. VM checks use a reserved `.invalid` server and offline
mode. NZBFAST output is separate local trial staging; this change does not add
remote NFS exports or a second ARR download-client configuration for it.
The hold applies at startup, not as an API authorization rule: an operator with
the API key can change runtime pause/offline settings until the next restart.
