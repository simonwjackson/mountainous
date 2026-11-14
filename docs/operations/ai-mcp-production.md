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
| Upstream credential | `LoadCredential=mcp-sparkyfitness:/run/secrets/sparkyfitness-openclaw-api-key` |
| Secret | sops `sparkyfitness-openclaw-api-key` in `secrets/hosts/rakku.yaml`, root `0400`, `restartUnits = [ "tsnet-proxy-ai.service" ]` |
| OpenClaw | flakey only: server `sparkyfitness`, `https://ai.hummingbird-lake.ts.net/mcp/sparkyfitness`, `streamable-http`, `toolFilter.include` = the same 23; tool permissions `sparkyfitness__<tool>`; skill `nutrition-fitness` |

- `/v1` and every path outside `/mcp/` go to the same `proxyHandler` as
  before, unwrapped and unchanged. `checks.ai-mcp-proxy` compares the
  production unit with the stage-1 fixture: only the binary path, the
  `-mcp-table` argument, `ExecReload`, `X-Reload-Triggers` and the one
  `LoadCredential` line may differ. Every other flag stays.
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
  for about 20 s (stage 1 measured 22 s for staging), for every agent.

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
| Rakku toplevel drv | `skf9ya1x0gsdc20nxadjyhcxpm6byn96` | `y1mxbf140wsklsk76af3lcb6xkhb3hjl` |
| Yari toplevel drv | `9v26wzdb25ras84nwplk122w2sfkz7jb` | `0k1prdz4q2k57xpdmgm47ra9ckycqcqs` |
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
- Go: 40 top-level tests (two new: ID matching and the WhoIs mapping), `go vet`,
  gofmt, all tests with `-race`, and the route tests 100 times with `-race`.
  Mutations that match names or ID prefixes fail the new tests.
- Eight wrong configurations fail evaluation: Zao on the production row, no
  callers, `claw-simon`, `zao`, `flakey`, a 24th tool, a changed `/v1` tag,
  and production without the table.
- Key: initialize with the stored key returns `sparkyfitness-mcp-server`
  1.12.1; upstream lists 56 tools and all 23 allowlisted ones exist. The
  plaintext key is in no tracked file, branch diff or `/tmp/claw` file.
- Before deployment: keyed `/v1/models` returns 200 and five models from both
  containers; `/mcp/sparkyfitness` returns the front door's 404 from both
  containers and Zao; `/v1/models` without a key returns 401.

## Deploy

Approval first. Pin the approved full commit; the scripts refuse another HEAD
or a dirty tree. Rakku first, then Yari. On Zao, from the checkout:

```sh
EXPECTED_SOURCE_SHA=<approved-full-commit-sha>
test "$(git rev-parse HEAD)" = "$EXPECTED_SOURCE_SHA"
# Records both running systems for rollback. Rakku: evaluate here, build on
# Unzen, copy Unzen -> Rakku through Zao with --no-check-sigs. Yari: build
# natively, remote builders off, only while both gateways are idle.
/tmp/claw/sparky-prod-build.sh "$PWD" "$EXPECTED_SOURCE_SHA"
# Preflight: the built unit files differ from the live ones in exactly
# tsnet-proxy-ai and tsnet-proxy-ai-staging; keyed /v1/models baseline.
# Then wait until Laure's and flakey's gateways have no unfinished run, and
# switch at once. Production ai restarts once. ai-gateway, SparkyFitness,
# Home Assistant and Z-Wave must keep their identities, keyed /v1/models must
# match the baseline, else the script switches back at once.
/tmp/claw/sparky-prod-deploy.sh "$PWD" rakku
/tmp/claw/sparky-prod-deploy.sh "$PWD" accept-rakku
# Refuses unless Laure's unit, container conf, container system and live
# config are byte-identical in the candidate; checks Laure's sessions,
# devices, cron jobs and gateway InvocationID before and after; flakey restarts.
/tmp/claw/sparky-prod-deploy.sh "$PWD" yari
/tmp/claw/sparky-prod-deploy.sh "$PWD" accept-yari
```

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
deployed system (use a forward revert then).

```sh
# Guarded like the deploy: Laure must stay byte-identical; flakey restarts.
/tmp/claw/sparky-prod-deploy.sh "$PWD" rollback-yari
# Waits until both gateways are idle; production ai and ai-staging restart
# once on the stage-1 binary and table; the row disappears.
/tmp/claw/sparky-prod-deploy.sh "$PWD" rollback-rakku
```

If `/tmp/claw` is gone, `nixos-rebuild switch --rollback` on each host selects
the previous generation (Rakku 157). Rolling back keeps all tsnet and gateway
state, the sops value and the SparkyFitness key. To close the route at once
without a deployment, delete `openclaw-flakey` in SparkyFitness: upstream
then refuses the key and the proxy answers `-32603`. Removing the row in Nix
also removes its credential, so that restarts production `ai` once.
