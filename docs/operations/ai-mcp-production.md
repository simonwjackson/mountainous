# Path-prefixed MCP on the production AI front door

Stage 2 of the MCP rollout. Prepared, **not deployed**. Stage 1 put the router
on `ai-staging` only (see `ai-mcp-staging.md`). This stage moves production
`ai` onto the same router with one row, `/mcp/sparkyfitness`, for flakey only.
SparkyFitness stays on Rakku; this is a new route, not a controlled move.

## Contract

| Part | Value |
| --- | --- |
| Front door | `ai` (`tsnet-proxy-ai`, backend `127.0.0.1:8430`) runs `packages.ai-mcp-tsnet-proxy` |
| Table | `/etc/tsnet-proxy-ai-mcp.json`, one row |
| Row | `/mcp/sparkyfitness` → `http://127.0.0.1:3010/mcp` (`services.sparkyfitness.port`) |
| Callers | flakey only: stable node ID `nbQJZMcewG11CNTRL` (`lib/tailnet-nodes.nix`, `claw-simon`) |
| Tools | the 23 names in `lib/openclaw-sparkyfitness-tools.nix` |
| Upstream credential | `LoadCredential=mcp-sparkyfitness:/run/secrets/sparkyfitness-openclaw-api-key`, default `SetCredential=mcp-sparkyfitness:unavailable credential` |
| Secret | sops `sparkyfitness-openclaw-api-key` in `secrets/hosts/rakku.yaml`, root `0400`, `restartUnits = [ "tsnet-proxy-ai.service" ]` |
| OpenClaw | flakey only: server `sparkyfitness`, `https://ai.hummingbird-lake.ts.net/mcp/sparkyfitness`, `streamable-http`, `toolFilter.include` = the same 23; tool permissions `sparkyfitness__<tool>`; skill `nutrition-fitness`; the wind-down skill and the morning brief read food, training, sleep and body data from it, read-only |

- `/v1` and every path outside `/mcp/` go to the same `proxyHandler` as
  before, unwrapped and unchanged. `checks.ai-mcp-proxy` compares the
  production unit with the stage-1 fixture: only the binary path, the
  `-mcp-table` argument, `ExecReload`, `X-Reload-Triggers`, the one
  `LoadCredential` line and its `SetCredential` default may differ. Every
  other flag stays.
- Nothing MCP-related can stop the front door. A missing, malformed or
  stage-1 table, or a missing, empty or invalid key, makes the proxy log
  `initial MCP table rejected; serving no MCP rows until a valid reload` and
  start with no rows (`/mcp/sparkyfitness` 404); `/v1` serves as usual. A
  good start logs `MCP table loaded`. A missing sops file would normally stop
  the unit (`LoadCredential` exit 243). systemd.exec: with a `SetCredential`
  default for the same ID, a missing source "is not considered fatal". The
  default holds a space, so the router refuses it as a Bearer. An empty
  default does not work: a unit file with `ID:` is "Invalid syntax" and still
  fails. After fixing the table, `systemctl reload` publishes it; after
  fixing the key, restart the unit (credentials load at start).
- SIGHUP is caught from the start of `main`, before the tailnet start (up
  to 90 s). A reload during startup waits and applies once the table loads.
- Caller identity is the stable node ID from tsnet WhoIs. Node names, Host,
  forwarded headers and user profiles never grant access. Laure's `claw`
  (`nkT3Yhzyy121CNTRL`), Zao and every other node get HTTP 403.
- The proxy strips caller `Authorization`, cookies and other headers and sends
  only the server-held Bearer key upstream. OpenClaw holds no key: the server
  entry has no header, environment or credential. The caller lock and the
  server-held key are the only authentication.
- Caller or tool edits change only the table: NixOS reloads the unit (SIGHUP),
  production does not restart. A new or rotated key restarts `tsnet-proxy-ai`
  once (systemd copies credentials at start).
- Laure's gateway (container `openclaw`, person `laure`) does not change. Its
  container system, gateway config and units evaluate byte-identical.

### Limits

- The filter allows or refuses whole tools, not actions. `sparky_manage_food`
  can still `delete_entry` or `delete_food`; other manage tools also write and
  delete. The skill tells flakey not to delete unless Simon asks. That is an
  instruction, not a boundary.
- The key is a full-scope owner key (flakey must write). Anyone with the Rakku
  credential bypasses the tool filter. Keep the sops value and the systemd
  credential private.
- The key expires one year after creation: **2027-11-14 04:13 UTC**. Rotate
  before then (see the key section).
- Upstream calls time out after 60 s and bodies are capped at 4 MiB (the
  shared MCP filter). Model streams on `/v1` keep their old timeouts.
- `tsnet-proxy-ai` restarts once at deployment. Expect `/v1` to be unavailable
  for about 20 s (stage 1 measured 22 s for staging), for every agent. The
  idle gate covers only the two OpenClaw gateways, not Pi agents, assistant,
  Storia, Korri or voice.

### Node rename (next stage)

The stable ID survives a rename of `claw-simon` to `flakey`: no row changes.
Rename only the key in `lib/tailnet-nodes.nix`. If the node registers again
instead, it gets a new ID: put the new ID in `lib/tailnet-nodes.nix` and in
the literal in `checks.ai-mcp-proxy`. Until then the row returns 403 to it.

## The key

Created 2026-11-14 04:13:35 UTC: SparkyFitness owner `simon.jackson@gmail.com`,
name `openclaw-flakey`, id `a0b68849-d6e7-4e86-a42c-7013d3938ced`, scope
`full`, default one-year expiry. No other API key existed. Stored with
`sops set`; its hash matches the created value. The value was never printed
and is not in the Nix store; the flake holds only the encrypted file.

Procedure, for rotation. Both scripts carry a Nix shebang. On Zao:

```sh
scp -F /dev/null /tmp/claw/sparky-openclaw-key.sh root@rakku:/tmp/claw/
umask 077
# One sign-in (rate limited). Refuses if a key with the name exists.
# stdout is the key as one JSON string; stderr is value-free.
ssh -F /dev/null root@rakku /tmp/claw/sparky-openclaw-key.sh \
  > /run/user/1000/sparky-openclaw-flakey.json
# sops set --value-stdin with the master key converted in memory, then a
# hash comparison, then the private copy is deleted.
/tmp/claw/sparky-openclaw-key-store.sh "$PWD" /run/user/1000/sparky-openclaw-flakey.json
# Read-only proof on Rakku loopback: initialize and tools/list with the stored
# key; all 23 allowlisted tools exist upstream. The key travels by SSH stdin.
/tmp/claw/sparky-key-verify.sh "$PWD"
```

For a rotation, give the new key another name (the script refuses an existing
name), deploy it (one production restart), check the row, then delete the old
key in SparkyFitness. Do not rerun the creation after a later local failure:
keep the private file and finish the sops step.

## Verification before approval

On Zao, sequentially. Never run the aggregate flake check. Rakku never builds.

```sh
nix build --no-link .#checks.x86_64-linux.ai-mcp-proxy .#checks.x86_64-linux.tailnet-names
nix build --no-link .#checks.x86_64-linux.ai-gateway-staging .#checks.x86_64-linux.ai-gateway
nix build --no-link .#checks.x86_64-linux.openclaw .#checks.x86_64-linux.claw-tools
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.yari.config.system.build.toplevel.drvPath
/tmp/claw/ai-mcp-go-check.sh "$PWD"   # gofmt, go test, go vet, race
/tmp/claw/sparky-setcredential-unitfile-check.sh   # the credential fallback, real unit file (Zao user manager)
/tmp/claw/sparky-prod-identity.sh "$PWD" after   # unit and Laure identities
/tmp/claw/sparky-prod-negative.py "$PWD"         # guards fail on wrong configs
/tmp/claw/sparky-key-leak-check.sh "$PWD" origin/cairn   # no plaintext key anywhere
```

`checks.ai-mcp-proxy` builds the proxy with its Go tests and `go vet`. It
proves the production table exactly (row, ID, 23 tools, credential name),
the unit difference above, a caller/tool edit is reload-only, and an empty
caller list, a node name or a DNS name fails evaluation. The 16 other Rakku
proxy units must still equal the stage-1 fixture.

### Prepared evidence (2026-11-14, base `e8bd3b4f`)

| Item | Before (`e8bd3b4f`) | After (this branch) |
| --- | --- | --- |
| Rakku toplevel drv | `skf9ya1x0gsdc20nxadjyhcxpm6byn96` | `mgqr767f0x4jd7wivch1j6m3wm3hdnb6` |
| Yari toplevel drv | `9v26wzdb25ras84nwplk122w2sfkz7jb` | `gl111w2j1xq3hw1h5hcawl9hm0g9g98y` |
| Rakku units that differ (of 181) | | `tsnet-proxy-ai`, `tsnet-proxy-ai-staging` |
| Yari host units that differ (of 107) | | `container@claw-simon` |
| Laure container toplevel drv | `2af2h9vgb1yid13d27f1wy24sg32ar94` | same |
| Laure container system | `z4mglka9jzbr1yssdkjnxwy0ipgylhw2` | same |
| Laure gateway JSON file | `3g17ic2wfing166zb8qzq0x8cr3l1vzy-openclaw.json` | same |
| Laure gateway config SHA256 | `00c26526…3a3ac9` | same |
| Laure `openclaw-gateway.service` SHA256 | `32e7c942…6d4382` | same |
| Host `container@openclaw.service` SHA256 | `ac5290d7…e39727` | same |
| Laure container conf | `h2xmbng8c1aa6azgnig7f8jwc87bnbji` | same |

- Checks passed: `ai-mcp-proxy`, `tailnet-names`, `ai-gateway-staging`,
  `ai-gateway`, `openclaw`, `claw-tools`, `openclaw-people`. Each commit of
  the branch also evaluates on its own.
- Go: 42 top-level tests (four new: ID matching, the WhoIs mapping, six bad
  starts that keep the front door, a SIGHUP during startup), `go vet`, gofmt,
  all tests with `-race`, and the route tests 100 times with `-race`.
  Mutations fail the new tests: matching names or ID prefixes, a `log.Fatal`
  on a bad table, no early `signal.Notify`.
- Ten wrong configurations fail evaluation: Zao on the production row, no
  callers, `claw-simon`, `zao`, `flakey`, a 24th tool, a changed `/v1` tag,
  a credential row without its `SetCredential` default, an empty default,
  and production without the table.
- systemd fallback: real unit files (Zao, systemd 259) and systemd-run
  (Rakku, systemd 261). Missing source plus the default: the unit starts
  and gets the default. Missing source, no default: exit 243. Empty default:
  "Invalid syntax", exit 243. Present source: the file wins.
- Dry runs that change nothing: the Rakku preflight under systemd-run (the
  exit code reaches the caller); `rehearse-gate` (2.4 s from `ready` to `go`,
  both gateways idle); Yari `check` and `check-rollback` under systemd-run;
  the OpenClaw CLI probe against `claw-maps` and `claw-scryer-simon`.
- Key: initialize with the stored key returns `sparkyfitness-mcp-server`
  1.12.1; upstream lists 56 tools and all 23 allowlisted ones exist. The
  plaintext key is in no tracked file, branch diff or `/tmp/claw` file.
- Before deployment: keyed `/v1/models` returns 200 and five models from both
  containers; `/mcp/sparkyfitness` returns the front door's 404 from both
  containers and Zao; `/v1/models` without a key returns 401.

## Deploy

Approval first. Pin the approved full commit. `sparky-prod-build.sh` and the
forward and acceptance steps of `sparky-prod-deploy.sh` refuse another HEAD,
a dirty tree, or a recorded build from another commit. The rollback steps do
not check the checkout: they need only the recorded system paths, so a moved
checkout cannot block them. Rakku first, then Yari. On Zao, from the checkout:

```sh
EXPECTED_SOURCE_SHA=<approved-full-commit-sha>
# Records both running systems and the commit. Rakku: evaluate here, build on
# Unzen, copy Unzen -> Rakku through Zao with --no-check-sigs. Yari: build
# natively, remote builders off, only while both gateways are idle (Unzen
# has no aarch64 emulation).
/tmp/claw/sparky-prod-build.sh "$PWD" "$EXPECTED_SOURCE_SHA"
# Optional rehearsal of the Rakku idle gate and ready/go handshake; changes nothing.
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rehearse-gate
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rakku
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-rakku
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-yari
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" yari
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-yari
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-rollback-yari
```

- **Every switch and rollback runs on its host under `systemd-run --wait
  --collect`** (`sparky-prod-launch.sh`), with output in the journal. A
  dropped SSH session cannot stop a switch or its automatic rollback; read
  `journalctl -u sparky-prod-<step> -o cat` afterwards. Unit names are fixed
  per step (`sparky-prod-rakku-switch`, `sparky-prod-rakku-rollback`,
  `sparky-prod-yari-switch`, `sparky-prod-yari-rollback`), so systemd-run
  refuses a second run of a step while the first is active.
- **Rakku** (`rakku`): preflight (the built unit files differ from the live
  ones in exactly `tsnet-proxy-ai` and `tsnet-proxy-ai-staging`; a keyed
  `/v1/models` baseline). Then it waits until Laure's and flakey's gateways
  have no unfinished run. The switch starts under systemd-run, takes every
  service's identity, writes `ready` with a random nonce and waits for a
  `go` that holds the same nonce, so no other unit and no stale `go` can
  trigger it. Zao checks idle again and only then writes `go`; activation
  follows within a second (the
  rehearsal measured 2.4 s from `ready` to `go`, the idle check included). A
  busy gateway writes `abort`; no `go` in 120 s also changes nothing.
  Production ai restarts once. If `ai-gateway`, SparkyFitness, Home
  Assistant or Z-Wave changes identity or fails, a protected unit is not
  active, or `/v1` stops matching the baseline, the same unit switches back
  at once. The Rakku host is not a caller, so its probe of
  `/mcp/sparkyfitness` must return 403. Any other status except 404,
  including 200 (a broken caller lock), also rolls back at once. Only 404
  (the row is not served: fail-closed, `/v1` healthy) exits 5 and stays
  deployed: fix forward with one restart instead of two outages.
- **Yari** (`yari`): refuses unless Laure's unit, container conf, container
  system and live config are byte-identical in the candidate, both gateways
  are healthy, and neither has an unfinished run, checked again immediately
  before activation. It rolls back to the previous system at once, in the
  same unit, if the switch exits other than 0 or 4, health does not return in
  180 s, Laure's gateway or container restarted, or her config changed. Her
  session, device and job inventory are reported, not rollback causes. If
  flakey did not restart onto the new config, it exits 3 and names the one
  command that restarts only flakey.
- Every script exits, never waits, when another `switch-to-configuration`
  runs, so an idle check is never consumed by a wait. Rerun the whole step.

Before this branch, Rakku ran generation 157
(`hj78p74d5jgjxb9ica4bwimw9g1x2k11`) and Yari ran
`l5ijg6gxxxwm55c9qasq8vyavr0gcq7w`; both equal the evaluation of the base
commit, so the switch carries only this change. If either host or `cairn`
moved since, re-run the identity comparison before deploying.

## Acceptance

`accept-rakku` and `accept-yari` run these. All are read-only. No test data
goes into Simon's diary.

1. From inside claw-simon, as `openclaw`: MCP initialize, then `tools/list`
   returns exactly the 23 allowlisted tools. One `sparky_get_food_diary` for
   today (America/Denver) succeeds; only its size is printed. An unlisted tool
   returns `-32601` at the proxy. A forged `Authorization` changes nothing.
2. From Laure's container (`openclaw`): `/mcp/sparkyfitness` returns 403.
3. From Zao: `/mcp/sparkyfitness` returns 403, also with forged headers;
   `/mcp/missing` 404; bare `/mcp` 404 from the front door; `/v1/models`
   without a key 401.

   A non-403 for Laure or Zao in `accept-rakku` means run `rollback-rakku`
   now.
4. `/v1/models` with the gateways' own key returns 200 and the same five
   models from both containers (baseline before deployment: 200, five models).
5. On Rakku (switch script): only the two proxies restarted; Home Assistant
   HTTP 200; Z-Wave active; no new failed units.
6. After Yari: `openclaw-admin mcp list` in claw-simon lists `sparkyfitness`;
   OpenClaw's own CLI `mcp probe` of the deployed config, with throwaway
   state, finds exactly the 23 `sparkyfitness__` tools; the live config entry
   has no credential. Laure's gateway InvocationID is unchanged.

Then ask Simon to log one real meal through flakey and check it once in the
diary. Do not create synthetic entries.

## Rollback

Yari first, then Rakku. Both refuse when a later deployment replaced the
deployed system (use a forward revert then). Both keep Laure's guards
(byte-identity, health, no unfinished run) and drop every flakey
precondition: a broken, crash-looping or stuck flakey cannot block them.

```sh
# Under systemd-run on Yari. Laure must stay byte-identical; never flips back.
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rollback-yari
# Waits until Laure's gateway is idle, then the same ready/idle/go gate. Under
# systemd-run on Rakku: production ai and ai-staging restart once on the
# stage-1 binary and table; the row disappears. Polls /v1 for up to 120 s.
/tmp/claw/sparky-prod-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rollback-rakku
```

If `/tmp/claw` is gone, set the pinned previous system. Do not use
`nixos-rebuild switch --rollback`: a rollback or a failed attempt adds a
generation, so "previous" can be the wrong one. Run these on the host as
root, one command at a time, while Laure's gateway is idle:

```sh
# Rakku: generation 157, the system before stage 2.
nix-env -p /nix/var/nix/profiles/system --set /nix/store/hj78p74d5jgjxb9ica4bwimw9g1x2k11-nixos-system-rakku-26.11.20260923.4975466
systemd-run --wait --collect --unit sparky-manual-rollback /nix/store/hj78p74d5jgjxb9ica4bwimw9g1x2k11-nixos-system-rakku-26.11.20260923.4975466/bin/switch-to-configuration switch
# Yari: the system before stage 2.
nix-env -p /nix/var/nix/profiles/system --set /nix/store/l5ijg6gxxxwm55c9qasq8vyavr0gcq7w-nixos-system-yari-26.11.20260923.4975466
systemd-run --wait --collect --unit sparky-manual-rollback /nix/store/l5ijg6gxxxwm55c9qasq8vyavr0gcq7w-nixos-system-yari-26.11.20260923.4975466/bin/switch-to-configuration switch
```

If either host or `cairn` moves before the deployment, `sparky-prod-build.sh`
records the new previous systems; use those paths instead. Rolling back keeps
all tsnet and gateway state, the sops value and the SparkyFitness key. To close the route at once
without a deployment, delete `openclaw-flakey` in SparkyFitness: upstream
then refuses the key and the proxy answers `-32603`. Removing the row in Nix
also removes its credential, so that restarts production `ai` once.
