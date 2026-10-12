# NZBFAST held trial

Unzen runs NZBGet and NZBFAST when `media-applications.usenet = "both"`.
The default is `"nzbget"`. `"nzbfast"` disables the NZBGet unit but does not
remove its state. NZBFAST remains offline and paused unless global `processing`
is `"enabled"` **and** `nzbfast.held = false`.

NZBFAST uses UID 391, group `media` (390), `/var/lib/nzbfast`, and
`/srv/basin/downloads/usenet/nzbfast/{Series,Movies}`. It listens on
`10.200.200.2:6790` from the host through the VPN namespace. No firewall port or
new tsnet identity is opened. `usenet` still proxies NZBGet on 6789.

## First start (operator only, after an approved activation)

Run as root on Unzen. This change does not execute these commands on a host.

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
| `pause_until_unix`, `paused_by_offline` | removed to avoid an old timed pause | `crates/nzbfast-daemon/src/daemon_shutdown.rs:861-870` |
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

## Limits

No deployment, production credentials, provider connections, or host leak audit
are part of this change. VM checks use a reserved `.invalid` server and offline
mode. NZBFAST output is separate local trial staging; this change does not add
remote NFS exports or a second ARR download-client configuration for it.
The hold applies at startup, not as an API authorization rule: an operator with
the API key can change runtime pause/offline settings until the next restart.
