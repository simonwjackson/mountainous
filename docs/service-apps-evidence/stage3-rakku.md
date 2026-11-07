# Stage 3: Rakku migration results

**Four apps accepted:** Knowledge, Meetings, Storia and Synth. Pace rolled back safely. Storybook and voice-gateway remain on Zao with concrete blockers. Irori sync is retired. All source data, definition links, stopped snapshots and unaccepted profile generations remain available.

Unit names below mean `.service` unless `.timer` is shown explicitly. Source sidecars are named `*-proxy`, not the `*-tsnet` names in the initial brief.

| App | Result and address | Source state size | Old Zao user units | New Rakku system units |
|---|---|---|---|---|
| knowledge | Accepted after an authorized retry; https://knowledge.hummingbird-lake.ts.net | 72 KiB data; 32 KiB tsnet | `knowledge`, `knowledge-proxy`: inactive, disabled | `knowledge`, `knowledge-tsnet`: active |
| meetings | Accepted; https://meetings.hummingbird-lake.ts.net | 3.8 MiB data; 13 MiB rollbacks | `meetings`, `meetings-proxy`: inactive, disabled | `meetings`, `meetings-tsnet`: active |
| storia | Accepted; https://storia.hummingbird-lake.ts.net | 88 KiB stopped SQLite state (152 KiB while running); 28 KiB tsnet at inventory | `storia`, `storia-proxy`: inactive, linked, not enabled | `storia`, `storia-tsnet`: active |
| storybook | Blocked; untouched at https://storybook.hummingbird-lake.ts.net | 56 MiB data; 32 KiB tsnet | `storybook`, `storybook-proxy`: active | None |
| synth | Accepted, native one-process service; https://synth.hummingbird-lake.ts.net | 32 KiB tsnet; documents remain in browser storage | `synth`: inactive, linked, not enabled | `synth`: active; no sidecar |
| voice-gateway | Blocked on GPU/STT dependencies; https://voice.hummingbird-lake.ts.net | 20 KiB configuration; 28 KiB tsnet | `voice-gateway`, `voice-tsnet`: active, unchanged | None |
| pace | Cutover rejected; Zao restored at https://pace.hummingbird-lake.ts.net | 30 MiB finance data; 28 KiB tsnet at inventory | `pace`, `pace-proxy`, `pace-sync.timer`: active; `pace-sync` retains its existing failure | `pace`, `pace-tsnet`: stopped; profile quarantined; `pace-sync.timer` provisioned but gated closed |
| irori-sync | Retired, not moved | 4 KiB data and 28 KiB tsnet retained | `irori-sync`, `irori-sync-proxy`: inactive, linked, not enabled | None |

Accepted apps' updater gates are opened only after their declarations/results are pushed to `origin/cairn`. Pace's updater and sync gates remain closed. Neither canary has an appUpdates entry or gate. Do not start the old sidecars while Rakku serves their identities.

## App checks and failures

### Knowledge

The package build passed 67 tests in 13 files and both TypeScript checks. The compiled server tree is byte-identical to the installed Zao server. The first signed deployment (`1794076854535476991.json`) failed before backend startup: the settings bind created root-owned `.pi/agent`, so ExecStartPre could not install the SOPS credential. The guard stopped the destination and quarantined its profile before restoring Zao.

The supervisor authorized a retry after the batch. The old unaccepted data/tsnet directories were **renamed, not deleted**, under `.migration/before-authorized-retry-*`. Scoped tmpfiles creation verified service-owned 0700 Pi parents. The portable Pi configuration also retains the source thinking, compaction and retry policy. Signed retry receipt: `1794083472380872380.json`. Before and after acceptance, the real API returned the same two cards, two chat records and empty vocabulary; a real Pi inference request completed. The original source and both migration snapshots remain intact.

### Meetings

A packaging-only adapter maps the platform's loopback argv to the unchanged `meetings serve --listen 127.0.0.1:8179`. Tests stayed enabled. proseQL stays at `5f83bdb238d21415c484e98c79d4500dd23bbc3b`; only its transport and advertised ref changed. The old commit initially failed remote fetch, so an exact source-pin branch was added before any outage. Signed receipt: `1794077972243823147.json`.

An existing meeting's read-only CLI export on the new host retained SHA256 `d187bb0f8cf1ed4abef63dccc196faa7bb84d50f93d2556a404a0313a4180407`. Rollback archives and tsnet state were copied and retained.

### Storia

Both AI gateway credentials moved to SOPS. The old `storia.service.d/ai-gateway.conf` URLs remain in the app environment. Native build passed typecheck, lint and 100 tests. Signed receipt: `1794078782817192483.json`. The campaign and practice were read through their actual GetGame RPCs before/after cutover; both response hashes match. Source SQLite files and backups remain on Zao.

### Storybook blocker

`/home/simonwjackson/code/sandbox/storybook` has 115 dirty/untracked entries across server, browser code, family content and assets. Its installed source is a dirty `path:` snapshot with narHash `sha256-YnRu+C3Giu5uvOJVyXwqLkAedzjIfl33zKYweJk7qNA=`. Main cannot be assumed to reproduce that live build. The user must commit or stash the work so main builds the version that runs; then the normal service-app move applies. No source was reconstructed and the dirty checkout was not changed.

### Synth

Synth keeps its existing integrated `synth-serve` binary and tsnet identity. Only a tested version wrapper was added upstream. Its full asset tree matches the installed build. The behavior harness passed in Nix and in the commit hook. Signed receipt: `1794081055483702329.json`. Public root, manifest, service worker and main-module bytes, cache headers and security policy match before/after migration. No interactive audio verification is claimed. The unchanged HTTPS origin preserves browser-held documents.

The platform's opt-in single-process mode, default compatibility proof and isolated live rollback proof are documented in [stage3-single-process.md](stage3-single-process.md). The permanent single-process canary uses loopback 4400 and measured 14.3 MiB after recovery. The existing paired canary and Groceries profiles were not changed.

### Voice blocker and Vela check

The actual installed source is `voice-gateway`, branch `rust-port`, revision `cf59efc4e87f4e1a33030bd09aa2df3663adee0a`, not the TypeScript main branch. Its startup sequence unconditionally loads Silero and Smart Turn, starts Kokoro's CUDA worker and synthesizes fillers, then calls Zao's local Whisper before binding 127.0.0.1:8792. `dictation-backend.service` is active on Zao, using whisper-server on 127.0.0.1:8178. Rakku cannot supply those NVIDIA GPU/local-STT dependencies unchanged. Both voice units remain running on Zao. The brief's OpenAI-key description was out of date: cloud co-driver speech now reads an AI gateway key.

Read-only verification: `/health` (not `/healthz`) returned status `ok` with completed model/Kokoro/Whisper startup phases; `/v1/models` returned `simon`, `laure`, `assistant`, `whisper-1` and `tts-1`. Rakku's actual `/etc/vela/config.json` and the served Vela `/config.json` both select `https://voice.hummingbird-lake.ts.net` and `talkModel: simon`. No microphone/audio conversation was started. Move or redesign these dependencies before a voice cutover; that work is outside this migration.

### Pace: two separate failures

1. **Existing sync failure, not fixed:** Zao's `pace-sync` exits 1 with “SimpleFIN reported incomplete data. Automatic allocation remains paused until a complete sync.” Its original six-hour calendar and five-minute boot trigger remain declared unchanged. The new periodic-command gate stays closed because the app cutover was rejected.
2. **Migration failure:** signed receipt `1794082909971514688.json` rejected activation during the five-second stability window when a three-second loopback smoke request timed out. The backend was CPU-active during startup; its recorded peak was 316.9 MiB. The guard stopped/confirmed both Rakku units, quarantined the canonical profile and restored only the previously active Zao server, proxy and timer. It did not restart the already-failed oneshot. All 4,629 ledger rows and the current-month snapshot match their pre-cutover hashes. No second attempt was made in this batch. An isolated startup/performance investigation is needed before another cutover; do not remove stability checks to force acceptance.

An earlier Unzen package rebuild timed out in the existing browser overflow gate. The identical closure had passed its enabled tests and all browser gates on Zao. That tested closure was copied to Unzen; the installed updater's subsequent check-only passed (`1794082802419463568.json`). No tests were disabled and no application behavior changed. The package's underlying server/sync output stayed `/nix/store/4gqry6wmrxdsvyqxpsyzfn6mn2426ic6-pace-server-0.1.0`.

SimpleFIN configuration, TypeSafe key and embedded-Pi gateway configuration are in SOPS. The one legacy `~/finance/sync-simplefin.mjs` convenience symlink points to the canonical source script; it was explicitly excluded from copying and remains on Zao. All regular finance state was copied and verified. The generic migration now snapshots/stops optional source jobs/timers and restores only those originally active. Unit manifests remain the authority for long-running destination readiness.

## Every platform switch: closure, unit and complete etc-content loss check

Store prefixes abbreviate `nixos-system-<host>-26.11.20260923.4975466` paths. Full comparisons and unit inventories are in `/tmp/rakku-stage3` on Zao. No removed file or unit was accepted.

| Switch | Old → new system prefix | Allowed differences |
|---|---|---|
| Rakku / Knowledge | `d3pdihrd` → `bjm0h0yp` | Knowledge additions and derived path/trigger changes |
| Unzen / Knowledge updater | `f7csfm4w` → `l2nfzjw3` | Knowledge updater plus already-pushed YouTube additions |
| Rakku / Meetings | `bjm0h0yp` → `gz04m34s` | Meetings resources; four unit/wants additions |
| Unzen / Meetings comparison only | `47bk1l2x` → same | Exact same toplevel; no redundant switch |
| Rakku / Storia | `gz04m34s` → `lylhzywb` | Storia resources and shared-module secret-parent additions; four unit/wants additions |
| Unzen / Storia updater | `47bk1l2x` → `b7fqwqb8` | Storia updater and derived updater-config paths; three additions |
| Rakku / single-process canary | `lylhzywb` → `3gscgzm2` | New isolated canary and authoritative unit manifests; two additions |
| Rakku / Synth | `3gscgzm2` → `wz9nqn3q` | Synth resources/manifest; two additions |
| Unzen / Synth updater | `jccq5jzx` → `g8a1nicd` | Synth updater, unit manifests and derived config paths; three additions |
| Rakku / Pace | `wz9nqn3q` → `hw54y9j9` | Pace resources, gated sync and manifest; seven additions |
| Rakku / Pace key bind | `hw54y9j9` → `6zky5w3b` | Only Pace's bind source: ready SOPS file before ExecStartPre |
| Unzen / Pace updater | `g8a1nicd` → `9x8wk4ll` | Pace updater and derived config paths; three additions |
| Rakku / Pi runtime policy | `6zky5w3b` → `bnc7k06j` | Only Knowledge/Pace settings-bind paths to preserve source policy |

Every actual switch passed `systemctl is-system-running`, zero failed units and the host's core checks. Rakku checks covered Home Assistant, Z-Wave, all three assistants, Beszel, CLIProxyAPI, Groceries and Logbook. Unzen checks included Jellyfin, Scryer, Prowlarr, Transmission, NZBFAST, VPN and Beszel. Unzen's pre-existing failed `cliproxyapi-update` was observed before work and was no longer failed after the first switch; this worker did not modify that service.

A 30-second MemAvailable watcher ran throughout. No sample crossed the 2 GiB stop threshold. Later shared-checkout operations held `stage3-migration.lock` across pin/preflight/deploy/result. An Unzen switch took `unzen-switch.lock` inside it. All native builds used two jobs and empty builders.

## Canonical private source branches added

| Repository on Zao | Branch | Commits / retained revision |
|---|---|---|
| `code/sandbox/knowledge` | `service-app-version` | `4a4807682f3a95e2826f320b5169e0b94266c9f9` |
| `code/sandbox/meetings` | `service-app-rakku` | `e019146`, `5128f21`, `442444b` |
| `code/github/simonwjackson/proseql` | `meetings-source-pin` | Existing `5f83bdb238d21415c484e98c79d4500dd23bbc3b`, unchanged |
| `code/sandbox/no-evil` (Storia) | `service-app-rakku` | `6c108b1` |
| `code/sandbox/synth` | `service-app-rakku` | `d84e30a` |
| `code/sandbox/pace` | `service-app-rakku` | `3e247be` |

These are canonical Zao Git refs, not new public remotes. The updater's existing read-only Git-upload allowlist was extended for these repositories. Zao remains an update-source availability dependency for moved apps, not their runtime host. Storybook and voice-gateway received no source branch or code change.

Mountainous work used branch `c-012cce184a9a45028af9658a1f5c508ceb9450b33fe372ffdd0a61f6e3fb8675`. Every input change has its own commit. Pushed code commits from this worker:

- Knowledge: `62bc05f8`, `4b715509`.
- Concurrent lock repair: `9c189c5c`. Metadata before/bad/after proved pyxamp keeps nixpkgs `3ec636362e1816bc2f0888fa0fa2c69f1bc9e504`; YouTube keeps its intended input `0b3d69c1d6f00a1ad234b84a9598656f24ef61cb` and nixpkgs `9fbb54b33e91ee4ca368e35a78e0613c720600b3`.
- Meetings: `3ce5c06f`, `69f1f0c4`, `e092f00b`.
- Storia: `823d7e5f`, `981a64c5`.
- Single-process support/proof: `e712d639`, `26a8f7f2`.
- Synth: `e58a9e55`, `0464c4a4`.
- Safe periodic jobs/timers and explicit legacy-link retention: `dd429045`, `08542962`.
- Shared Pi runtime: `d12ccc85`, `85ef5581`.
- Pace: `b21fdd4a`, `2c7112c6`, `9aa7b4b4`.
- Earlier result/evidence commits: `c66763ea`, `a87afa8f`, `65943cd5`. The final report commit is identified in the agent's handoff.

All listed commits are ancestors of `origin/cairn`; push hooks passed. No aggregate flake check was run. Private plans, unit inventories, data digests and full logs remain under `/tmp/rakku-stage3`; signed receipts remain under `/var/lib/app-updater/receipts` on Unzen. Do not publish private inventories without auditing them.
