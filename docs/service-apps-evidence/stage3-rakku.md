# Stage 3: Rakku migrations

All source data and definition links remain on Zao. No rollback probe targeted a production application. The updater gates stay closed for failed migrations.

## Results so far

| App | Result | Address | Source data | Zao user units | Rakku system units |
|---|---|---|---|---|---|
| knowledge | Cutover rejected; source restored and verified | https://knowledge.hummingbird-lake.ts.net | 72 KiB (`~/knowledge`), 12 KiB tsnet | `knowledge`, `knowledge-proxy`: active, enabled | `knowledge`, `knowledge-tsnet`: stopped; unaccepted profile quarantined |
| meetings | Signed deployment accepted; existing transcript export identical | https://meetings.hummingbird-lake.ts.net | 3.8 MiB data, 13 MiB rollbacks; tsnet retained | `meetings`, `meetings-proxy`: inactive, disabled | `meetings`, `meetings-tsnet`: active |
| irori-sync | Retired, not moved | No replacement | 4 KiB data, 28 KiB tsnet retained | `irori-sync`, `irori-sync-proxy`: inactive, linked, not enabled; definitions retained | None |

Knowledge's package build passed 67 tests in 13 files, plus both TypeScript checks. Its compiled server tree is byte-identical to the installed Zao server. Its existing two cards, two chat records and empty vocabulary were checked through the public API; Pi inference succeeded on Zao before and after recovery. Signed deployment receipt `1794076854535476991.json` rejected startup: the settings bind created root-owned `.pi/agent`, so ExecStartPre could not copy the SOPS credential. The generic cutover stopped the destination and quarantined its canonical profile before restoring Zao. Only the failed destination unit's failure marker was cleared. No retry was attempted.

Meetings uses a packaging-only adapter from `--host 127.0.0.1 --port PORT` to the unchanged `meetings serve --listen 127.0.0.1:PORT`. The package tests stayed enabled. Its existing proseQL dependency revision `5f83bdb238d21415c484e98c79d4500dd23bbc3b` is unchanged; the Git transport now uses SSH and an advertised source-pin branch. The first remote check failed because that old commit was not fetchable through the advertised main ref; adding the exact existing pin as a branch fixed it before any outage. Signed deployment receipt: `1794077972243823147.json`. The existing meeting's read-only export SHA256 stayed `d187bb0f8cf1ed4abef63dccc196faa7bb84d50f93d2556a404a0313a4180407`.

## Loss checks and host health

| Switch | Old system prefix | New system prefix | Loss check |
|---|---|---|---|
| Rakku / knowledge | `d3pdihrd` | `bjm0h0yp` | On-host closure and complete etc contents: only Knowledge additions and derived path/trigger changes; no missing files or units |
| Unzen / knowledge updater | `f7csfm4w` | `l2nfzjw3` | Only Knowledge updater and already-pushed YouTube additions; no removals |
| Rakku / meetings | `bjm0h0yp` | `gz04m34s` | Only Meetings additions; explicit unit inventory: four unit/wants entries added, zero removed |
| Unzen / meetings updater | `47bk1l2x` | same | Other worker had already provisioned the newest pushed tree. Exact same toplevel; empty closure/etc/unit diff; no redundant switch |

Every actual switch passed `systemctl is-system-running`, zero failed units, and the host's core-unit checks. Rakku checks included Home Assistant, Z-Wave, all three assistants, Beszel, CLIProxyAPI, Groceries and Logbook. Unzen checks included Jellyfin, Scryer, Prowlarr, Transmission, NZBFAST, the VPN and Beszel. Unzen's pre-existing failed `cliproxyapi-update` was observed before work; it was no longer failed after the switch. This worker did not change it.

A 30-second SSH MemAvailable watcher runs during migrations; no sample has crossed the 2 GiB stop threshold.

## Source branches

- Knowledge: `service-app-version`, commit `4a4807682f3a95e2826f320b5169e0b94266c9f9` (version wrapper and install check).
- Meetings: `service-app-rakku`, commits `e019146`, `5128f21`, `442444b` (SSH transport, versioned loopback adapter, advertised unchanged dependency pin).
- proseQL: `meetings-source-pin` points to the unchanged existing dependency commit `5f83bdb238d21415c484e98c79d4500dd23bbc3b`.

These branches are in their canonical Zao repositories. No private source was published to a new external service.

## Concurrent lock repair

Commit `9c189c5c507bb48a150ae49ff63b762b728c1682` repairs the duplicate `nixpkgs_8` JSON key introduced by the concurrent YouTube input merge. `nix flake metadata --json` before the merge, after the bad merge, and after repair proved that pyxamp's original nixpkgs revision `3ec636362e1816bc2f0888fa0fa2c69f1bc9e504` is restored. YouTube retains `0b3d69c1d6f00a1ad234b84a9598656f24ef61cb` and its nixpkgs revision `9fbb54b33e91ee4ca368e35a78e0613c720600b3`. Every earlier locked node retains its complete identity.

Meetings' pin/preflight/cutover/result sequence held Unzen's `stage3-migration.lock` throughout. Further shared updater operations must hold that lock, and acquire `unzen-switch.lock` inside it when switching Unzen.

## Focused checks

- `bash scripts/check-flake-inputs.sh`: passed, including each push hook.
- `nix eval .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath --raw --max-jobs 2 --option builders ''`: passed.
- `python3 -m unittest tests/test_service_apps.py`: eight passed.
- `checks.x86_64-linux.app-knowledge`: built successfully.
- Installed updater check-only for Knowledge and Meetings: passed, builders disabled.
- Native package/system builds used two jobs and empty builders. No aggregate flake check was run.

Detailed private migration plans, complete comparison logs, public-data digests, unit inventories and receipts are retained under `/tmp/rakku-stage3` on Zao and `/var/lib/app-updater/receipts` on Unzen. Private unit inventories contain environment metadata and must not be published without audit.
