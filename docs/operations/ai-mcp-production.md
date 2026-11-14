# Path-prefixed MCP on the production AI front door

Stage 2 of the MCP rollout. **Deployed 2026-11-14 UTC** from cairn `f67a0cf7`:
Rakku generation 158, Yari generation 52 (see the deployment record). Stage 1 put the router
on `ai-staging` only (see `ai-mcp-staging.md`). This stage moves production
`ai` onto the same router with one row, `/mcp/sparkyfitness`, for flakey only.
SparkyFitness stays on Rakku; this is a new route, not a controlled move.

**Stage 5** (section "Stage 5: Simon's own tools on /mcp rows" below) adds
five rows for Simon's own tools and retires their per-tool tailnet nodes.
**Stage 7** (section "Stage 7: Laure's and the shared tools on /mcp rows")
adds four more, two of them for Laure's gateway and two for both gateways,
and retires the last per-tool nodes. The stage-2 sections describe the router
and the sparkyfitness row as deployed then; where they say "one row", read
"ten rows" since stage 7, and where they say "flakey only", read "the row's
callers in `lib/ai-mcp-rows.nix`".

## Contract

| Part | Value |
| --- | --- |
| Front door | `ai` (`tsnet-proxy-ai`, backend `127.0.0.1:8430`) runs `packages.ai-mcp-tsnet-proxy` |
| Table | `/etc/tsnet-proxy-ai-mcp.json`, one row |
| Row | `/mcp/sparkyfitness` → `http://127.0.0.1:3010/mcp` (`services.sparkyfitness.port`) |
| Callers | flakey only: stable node ID `nbQJZMcewG11CNTRL` (`lib/tailnet-nodes.nix`, key `flakey`; the node was `claw-simon` until 2026-11-14) |
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

### Node rename (stage 3, 2026-11-14)

The node was renamed in place from `claw-simon` to `flakey`
(`openclaw-yari.md`, "Rename to flakey"). The stable ID survives a rename:
no row changed, only the key in `lib/tailnet-nodes.nix`, and Rakku's system
did not change. If the node ever registers again instead, it gets a new ID:
put the new ID in `lib/tailnet-nodes.nix` and in the literal in
`checks.ai-mcp-proxy`. Until then the row returns 403 to it.

## Stage 5: Simon's own tools on /mcp rows

Simon's own assistant tools move from their per-tool tailnet nodes to rows on
this front door. Each row admits flakey's stable node ID `nbQJZMcewG11CNTRL`
only and keeps the backend, tools and server-side key of the node it replaces.
flakey keeps every MCP server name, so tool names (`<server>__<tool>`),
permissions, the mail agent, main's `claw-gmail__*` deny, the agent-to-agent
rules, the wind-down and morning-brief skills and the approval modes do not
change. Only the URLs move. OpenClaw holds no key.

| Row | flakey server (unchanged name) | Backend | Tools | Server-side key | Old node (retired) |
| --- | --- | --- | --- | --- | --- |
| `/mcp/calendar` | `claw-calendar` | Google app `127.0.0.1:3171/mcp` | `calendar_busy` | none (loopback) | `claw-calendar` |
| `/mcp/gmail` | `claw-gmail` | Google app | the 7 mail tools, no `mail_send` | none | `claw-gmail` |
| `/mcp/family-calendar` | `claw-family-calendar-simon` | Google app | events, add, remove | none | `claw-family-calendar-simon` |
| `/mcp/ebay` | `claw-ebay-simon` | `ebay-server` `127.0.0.1:3191/mcp` | the 14 eBay tools, plus the 7 `ui://ebay/*.html` views | none | `claw-ebay-simon` |
| `/mcp/scryer` | `claw-scryer-simon` | native: `https://scryer.hummingbird-lake.ts.net/graphql` as `simon` | the 5 Scryer tools, plus `ui://scryer/media.html` | sops `scryer-password-simon` as `mcp-scryer` | `claw-scryer-simon` |
| `/mcp/sparkyfitness` | `sparkyfitness` | unchanged (stage 2) | 23 | `mcp-sparkyfitness` | none |

The dead, offline node `claw-scryer` (`nWonQ4d7xB11CNTRL`, not in Nix since
the per-account split) is deleted with the five. Shared and Laure-owned nodes
stay: `claw-maps`, `claw-websearch`, `claw-family-calendar` and
`claw-scryer-laure`. Laure's servers do not move.

### How the rows work

- `lib/ai-mcp-rows.nix` names every production row, its tools and the flakey
  server that uses it. It is the one allowlist for the row and for flakey's
  `toolFilter`. Each feature adds its own row: `claw-tools` (the three Google
  rows), `claw-ebay`, `claw-scryer`; `ai-gateway` keeps sparkyfitness.
- `lib/openclaw-people.nix` gives each moved server `row = "<row>"`;
  `lib/openclaw-container.nix` then writes
  `https://ai.hummingbird-lake.ts.net/mcp/<row>`. A server without `row` keeps
  `https://<name>.hummingbird-lake.ts.net/mcp`, so Laure's entries are
  byte-identical.
- A row has a loopback `backend` or a native `scryer` account, never both. The
  old `claw-scryer-<user>` endpoint was native code in the proxy (no loopback
  MCP server exists), so a Scryer row serves the same handler (`scryer.go`)
  against the same GraphQL URL, limited to the row's tools. The password is
  the row's credential: `LoadCredential=mcp-scryer:/run/secrets/scryer-password-simon`
  with the `SetCredential=mcp-scryer:unavailable credential` default. The router
  strips only the final newline (as the endpoint mode does) and refuses an
  empty value, a line break or the systemd default.
- A loopback row may list exact `ui://` views (`mcpResources`): eBay's MCP App
  cards need `resources/list` and `resources/read`. Other resources, and
  resource methods on rows without views, return `-32601`.
- `routing.patch` now also patches `scryer.go` (an allowlist parameter;
  `scryerHandler` keeps the endpoint mode). The shared `media-tsnet-proxy`
  source and derivation still do not change, so no other proxy restarts.
- Guards, each proved by `/tmp/claw/simon-tools-negative.py` (12 cases): a row
  with no callers or a node name fails the table's type; a row or tool not in
  `lib/ai-mcp-rows.nix` (for example `mail_send`, `scryer_delete`, a 15th eBay
  tool, an unnamed row) and a Scryer row that also has a backend fail the
  system's assertions; an extra caller fails `checks.ai-mcp-proxy` (exact
  table); a Laure server on a row, or a moved flakey server left on its node,
  fails `checks.openclaw`. The router itself refuses unknown Scryer tools,
  non-`ui://` views and the credential cases above (Go tests).
- The whole table loads or none of it does: a bad Scryer password, like a bad
  SparkyFitness key, leaves every row at 404 and `/v1` up.
- The new credential restarts production `ai` once (about 22 s of `/v1`
  downtime for every agent). Later caller or tool edits only reload the table.
  `scryer-password-simon` restarts `tsnet-proxy-ai` when its value changes.
- The Tailscale policy does not change: flakey already reaches `ai`, and the
  Scryer request leaves Rakku's host network exactly as the old node's did.

### Verification before approval

On Zao, one at a time. Never the aggregate flake check; Rakku never builds.

```sh
/tmp/claw/ai-mcp-go-check.sh "$PWD"   # gofmt, go test (46), go vet, race
for c in ai-mcp-proxy tailnet-names ai-gateway ai-gateway-staging openclaw \
         openclaw-people openclaw-in-place claw-tools claw-ebay claw-scryer claw-websearch; do
  nix build --no-link .#checks.x86_64-linux.$c
done
/tmp/claw/simon-tools-identity.sh "$PWD" after   # then simon-tools-identity-compare.py BEFORE AFTER
/tmp/claw/simon-tools-negative.py "$PWD"
# The real router, real table and real credentials on Rakku, as user
# tsnet-proxy under systemd-run, on loopback; never joins the tailnet.
/tmp/claw/simon-tools-rehearse-build.sh "$PWD"   # then run simon-tools-rehearse-rakku.sh on Rakku
```

The identity comparison must show Laure's container system, gateway JSON,
gateway unit, `claw-tailnet` unit, host `container@openclaw` unit and
container conf unchanged; on Rakku only `tsnet-proxy-ai` and
`tsnet-proxy-ai-staging` differ; on Yari only `container@claw-simon`.

### Deploy

Rakku first, then Yari, then acceptance. Pin the approved commit. Same
machinery as stage 2: build on Unzen and copy through Zao with
`--no-check-sigs`; every switch and rollback runs under `systemd-run` with a
fixed unit name (`simon-tools-<step>`); the Rakku switch waits for both
gateways to be idle and for a `go` holding its nonce; automatic rollback in
the same unit.

```sh
EXPECTED_SOURCE_SHA=<approved-full-commit-sha>
/tmp/claw/simon-tools-build.sh rows "$PWD" "$EXPECTED_SOURCE_SHA"   # also builds aarch64 openclaw-config on Yari
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rehearse-gate
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rakku
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-rakku
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-yari
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" yari
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-yari
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" mail-agent
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-rollback-yari
```

- `rakku`: preflight (exactly the two proxy units differ; keyed `/v1/models`
  baseline), idle gate, ready/go. Afterwards only the two proxies may change
  identity. `ai-gateway`, SparkyFitness, `ebay-server`, the Google and Maps
  apps, Laure's tool proxies, the five old nodes (still running), Home
  Assistant and Z-Wave must keep theirs; keyed `/v1/models` must match the
  baseline; all six rows must answer this host (not a caller) with 403. Any
  problem rolls back at once. All six 404 (table rejected, `/v1` healthy)
  exits 5: fix forward with one restart. `ai-mcp-rakku-health.py` then checks
  Home Assistant and the Z-Wave server handshake.
- `yari`: the stage-2 guards: Laure byte-identical, both gateways healthy and
  idle, checked again right before activation; flakey restarts onto the new
  config, Laure's gateway keeps its InvocationID.

### Acceptance

All read-only. No email sent, no eBay change, no calendar edit, no Scryer change.

1. From inside flakey as `openclaw` (`accept-rakku`): every row answers
   initialize and `tools/list` with exactly its allowlist; an unlisted tool
   returns `-32601`; a forged `Authorization` changes nothing; eBay lists
   exactly its 7 views and Scryer its one.
2. Laure's container and Zao (also with forged headers) get 403 on every row;
   `/mcp/missing` and `/mcp` 404; `/v1/models` without a key 401; keyed
   `/v1/models` 200 from both containers.
3. `accept-yari`: the above, plus `flakey-mcp.py accept` (every flakey server:
   initialize, exact list, one read: `calendar_busy`, `mail_list` limit 1,
   `family_calendar_events`, `ebay_listings` limit 1, `scryer_search`,
   `sparky_get_food_diary`, and the shared servers), OpenClaw's own CLI probe
   lists every server with no diagnostics, the live entries hold the row URL
   and no credential, Laure's own four servers answer her container, her
   gateway InvocationID is `5dbd700ddc1f4214b772e5a0522652ff`, and no unit has
   failed on Yari or in either container.
4. `mail-agent`: one real delegation from a disposable main session to a
   disposable reader session ("how many unread in the last 24 hours", mail_list
   only). The reader's `claw-gmail__mail_list` succeeds through `/mcp/gmail`;
   no write tool runs; main calls no Gmail tool; `tools.effective` gives the
   reader exactly the 7 Gmail tools and `session_status`, and main none. Both
   sessions are deleted with `sessions.delete`.

### Retire the old nodes

Only after acceptance passes on every new path. A second commit removes the
five old tailnet names from Nix (`lib/claw-tools.nix`, `claw-ebay`,
`claw-scryer`); Yari does not change and production `ai` does not restart.

```sh
EXPECTED_SOURCE_SHA=<retire-commit-sha>
/tmp/claw/simon-tools-build.sh retire "$PWD" "$EXPECTED_SOURCE_SHA"   # refuses if Yari would change
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" retire-rakku
/tmp/claw/simon-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-retire
# Then delete the six nodes from the tailnet (OAuth client, device scope).
/tmp/claw/simon-tools-delete-nodes.sh dry-run
/tmp/claw/simon-tools-delete-nodes.sh delete
```

`simon-tools-delete-nodes.sh` first checks, on Yari, that neither gateway's
live config names any of the six hosts (exact `<name>.hummingbird-lake.ts.net`),
then on Rakku lists the tailnet's devices through the fleet OAuth client and
deletes a device only if exactly one device has that exact name, its node ID
is the recorded one, it carries only `tag:claw-tools`, and it is not
connected. Anything else stops the run before that device.

| Node | Node ID |
| --- | --- |
| `claw-calendar` | `nfm68HkCdg11CNTRL` |
| `claw-gmail` | `njBnm9PE4S11CNTRL` |
| `claw-ebay-simon` | `nwHWf8RDwt11CNTRL` |
| `claw-scryer-simon` | `nANYvp9y2X11CNTRL` |
| `claw-family-calendar-simon` | `nCziJXC7GY11CNTRL` |
| `claw-scryer` (dead since 2026-11-11) | `nWonQ4d7xB11CNTRL` |

The old nodes' tsnet state stays on Rakku under
`/tundra/permafrost/var/lib/tsnet-proxy-<name>`; nothing deletes it.

### Rollback (stage 5)

A deleted tailnet node cannot come back with its identity. After the
deletion, the rollback is a redeploy of the old units, which registers new
nodes with new IDs.

- Undo the `claw-google-auth` step first if it is deployed: `rollback-auth`
  (dbus-broker reloads; nothing restarts).
- Before the retire step: `rollback-yari`, then `rollback-rakku` (production
  `ai` restarts once onto the stage-2 binary and table; the old nodes still
  run). Both are `simon-tools-deploy.sh` steps with Laure's guards only.
- After the retire step, before the deletion: `rollback-retire` brings the
  old units back on their saved identities.
- After the deletion: move each old node's state aside on Rakku, as root,
  `mv /tundra/permafrost/var/lib/tsnet-proxy-<name> /tundra/permafrost/var/lib/tsnet-proxy-<name>.deleted`
  (a saved identity of a deleted node never joins again), then
  `rollback-retire` (or revert the retire commit and deploy). Each unit
  enrolls a new node through the OAuth client. `claw-family-calendar-simon`
  still admits only flakey's ID. Then `rollback-yari` and `rollback-rakku` if
  the rows must go too.
- Without `/tmp/claw`, use the pinned systems from the deployment record with
  `nix-env -p /nix/var/nix/profiles/system --set <system>` and
  `systemd-run --wait --collect --unit simon-tools-manual-rollback <system>/bin/switch-to-configuration switch`,
  while Laure's gateway is idle. Do not use `nixos-rebuild switch --rollback`.

### Stage 5 deployment record — 2026-11-14 UTC

Simon approved the whole stage. Landed on cairn by fast-forward:
`13bc4b78` (rows), `9c80497b` (flakey's URLs), `1c0587c5` (runbook) from
`6685b6e8`; then `59f1d6c2` (retire) and `8b48fc83` (`claw-google-auth
--verify`). Rakku: evaluated on Zao, built on Unzen, copied through Zao with
`--no-check-sigs`. Yari: built natively, with the aarch64 `openclaw-config`
check (`openclaw config validate`, both people).

| Host | Step | Generation and system |
| --- | --- | --- |
| Rakku | before | 158 `/nix/store/11a2g7zh8zmb286903b35js57znqrmi2-nixos-system-rakku-26.11.20260923.4975466` |
| Rakku | rows (`1c0587c5`) | 159 `/nix/store/pp9xl85kqsm4zyq0msbnhy6sz4138pbl-nixos-system-rakku-26.11.20260923.4975466` |
| Rakku | retire (`59f1d6c2`) | 160 `/nix/store/z2hdr8a06p84b612m3xhl7zly0x728x8-nixos-system-rakku-26.11.20260923.4975466` |
| Rakku | auth (`8b48fc83`) | 161 `/nix/store/jpv87gsdpii270c23xxh4cwyfqcca464-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | before | 53 `/nix/store/rfvqx5amjsyd6qcjf22fnv75nzap42a2-nixos-system-yari-26.11.20260923.4975466` |
| Yari | flakey's URLs (`1c0587c5`) | 54 `/nix/store/vpq1hk8ffc2bxdkwjadxn01w3hd6n8q4-nixos-system-yari-26.11.20260923.4975466` (unchanged by the later steps) |

- Before deploying: both running systems equalled the evaluation of
  `6685b6e8`. Identity comparison: Laure's container system, gateway JSON
  (`3g17ic2w…-openclaw.json`, SHA256 `00c26526…3a3ac9`), gateway unit,
  `claw-tailnet` unit, host `container@openclaw` unit and container conf
  byte-identical at every commit; Rakku differed in exactly
  `tsnet-proxy-ai` and `tsnet-proxy-ai-staging` (rows), then exactly the five
  retired proxies (retire); Yari only in `container@claw-simon`. Negative
  cases 12/12 on both trees. Go: 46 tests, vet, race. The real router with
  the real table and credentials, under systemd-run on Rakku as
  `tsnet-proxy`: all six rows exactly their tools, Laure's ID 403, Scryer
  signed in. Baseline from flakey on the old nodes: 30/30 and a clean CLI probe.
- Rakku rows: both gateways idle (1.4 s rehearsal from ready to go). Switch
  rc 0 in 24.1 s. `tsnet-proxy-ai` stopped at 15:31:44.729 and logged
  `MCP table loaded` and `proxy ready` at 15:32:07.786: **`/v1` was down
  23.1 s**, started once (NRestarts 0). Only the two proxies restarted; Home
  Assistant HTTP 200; Z-Wave handshake (driver 15.15.0, server 3.4.0); no
  failed units; all six rows 403 to the Rakku host.
- `accept-rakku` 34/34 from the containers and 15/15 from Zao. Laure's `/v1`
  (keyed `/v1/models`, five models) worked after the restart.
- Yari: Laure byte-identical, both gateways idle and healthy. Switch rc 0.
  Laure unhealthy 0 s, gateway InvocationID `5dbd700ddc1f4214b772e5a0522652ff`
  unchanged; flakey restarted onto the new config (about 20 s).
- `accept-yari` 49/49 (with `flakey-mcp.py` 30/30: one read on each server,
  nothing written; CLI probe: every server, no diagnostics; Laure's four
  servers answer her) and 15/15 from Zao. `mail-agent` 6/6: the reader's
  `claw-gmail__mail_list` succeeded through `/mcp/gmail`, no write tool ran,
  main called no Gmail tool and its warm `tools.effective` holds none; both
  disposable sessions deleted.
- Retire: only the five old proxies stopped (and their bind mounts);
  `tsnet-proxy-ai` was not restarted (`/v1` had no downtime). `accept-retire`
  49/49 and 15/15.
- Deleted from the tailnet (fleet OAuth client, scope `devices:core
  auth_keys`), each checked first: exact name, recorded ID, only
  `tag:claw-tools`, not connected, named by neither gateway's live config.
  Each DELETE returned HTTP 200; 92 devices became 86; none is in
  `tailscale status`.

  | Node | Node ID | Last seen |
  | --- | --- | --- |
  | `claw-calendar` | `nfm68HkCdg11CNTRL` | 2026-11-14 15:49:13 UTC |
  | `claw-gmail` | `njBnm9PE4S11CNTRL` | 2026-11-14 15:49:13 UTC |
  | `claw-ebay-simon` | `nwHWf8RDwt11CNTRL` | 2026-11-14 15:49:13 UTC |
  | `claw-scryer-simon` | `nANYvp9y2X11CNTRL` | 2026-11-14 15:49:13 UTC |
  | `claw-family-calendar-simon` | `nCziJXC7GY11CNTRL` | 2026-11-14 15:49:13 UTC |
  | `claw-scryer` | `nWonQ4d7xB11CNTRL` | 2026-11-11 08:37:50 UTC |

- `claw-google-auth --verify` compared the loopback app with the
  `claw-calendar` node, which no longer exists, so it now reads the loopback
  app only. Its Rakku switch (161) only reloaded dbus-broker; `--check` passes.
  The switch script now also compares drop-in files (`*.service.d/`).
- Final `accept-auth`: 49/49 and 15/15; no failed units on Rakku, Yari or in
  either container. Scripts and logs: `/tmp/claw/simon-tools-*` on Zao.

## Stage 7: Laure's and the shared tools on /mcp rows

The last per-tool tailnet nodes move to rows on this front door. Each row
keeps the backend, tools and server-side key of the node it replaces and
admits only the stable node IDs its callers have in `lib/tailnet-nodes.nix`.
Both gateways keep every MCP server name, so tool names (`<server>__<tool>`),
permissions, skills, `dispatch_action` IDs and the morning briefs do not
change. Only the URLs move. OpenClaw holds no key.

| Row | Callers (stable ID) | Server (unchanged name) | Backend | Tools | Server-side key | Old node (retired) |
| --- | --- | --- | --- | --- | --- | --- |
| `/mcp/family-calendar-laure` | Laure's `claw` `nkT3Yhzyy121CNTRL` | `claw-family-calendar` (Laure) | Google app `127.0.0.1:3171/mcp` | `family_calendar_events` | none (loopback) | `claw-family-calendar` `nw4DmtiXHN11CNTRL` |
| `/mcp/scryer-laure` | `claw` | `claw-scryer-laure` (Laure) | native: `https://scryer.hummingbird-lake.ts.net/graphql` as `laure` | the 5 Scryer tools, plus `ui://scryer/media.html` | sops `scryer-password-laure` as `mcp-scryer-laure` | `claw-scryer-laure` `nn4JrFbREK11CNTRL` |
| `/mcp/maps` | `flakey` `nbQJZMcewG11CNTRL` and `claw` | `claw-maps` (both) | Maps app `127.0.0.1:3172/mcp` | `travel_time` | none (loopback) | `claw-maps` `naQB5pjsTM11CNTRL` |
| `/mcp/websearch` | `flakey` and `claw` | `claw-websearch` (both) | native: `http://127.0.0.1:8430/v1/responses`, model `gpt-6.1-sol` | `web_search` | sops `ai-gateway-key-openclaw-yari` (the gateways' own `openclaw@yari` key) as `mcp-websearch` | `claw-websearch` `nut8ipE3di11CNTRL` |

Afterwards `tailscale status` shows `ai`, `ai-staging`, `flakey` and `claw`
for this feature, and no `claw-*` tool node. (Laure's node was later renamed
in place to `snowy`, same ID: `lib/tailnet-nodes.nix` and the row callers use
the key `snowy`; the table did not change. See `openclaw-yari.md`, "Rename
Laure's gateway to snowy".) No node changes its tags; the
tailnet policy does not change (both gateways already reach `ai`, and every
row's backend is on Rakku's loopback or leaves Rakku's host network exactly as
the old node's request did).

### What changed

- `lib/ai-mcp-rows.nix` names each row's `callers` as keys of
  `lib/tailnet-nodes.nix` (now with `claw`). Every row module reads its
  callers, tools and server from it. `ai`'s assertion now also refuses a row
  whose caller IDs differ from that list, as it refuses an unknown row or tool.
- The router gains a native **web search** row kind beside loopback and
  Scryer rows. It runs the same `websearch.go` handler as the `claw-websearch`
  endpoint: only `web_search`, only the fixed loopback front-door Responses URL
  (checked by the table's type and by the router), a granted model, and the key
  as the row's credential. The router refuses an empty, multi-line or default
  key, as for the other credentials. A row has exactly one of a backend, a
  Scryer account or web search.
- `tsnet-proxy-ai` loads two new credentials, `mcp-scryer-laure` and
  `mcp-websearch`, each with its `SetCredential=…:unavailable credential`
  default. Both arrive in one Rakku switch: `ai` restarts once (and
  `ai-staging` for the new binary). Either secret's new value restarts `ai`.
- Both gateways' servers have a `row`; `lib/openclaw-container.nix` writes
  `https://ai.hummingbird-lake.ts.net/mcp/<row>` for every tool server and
  fails evaluation for a server without one. The shared `claw-maps` and
  `claw-websearch` come from one place there.
- The gateway unit restarts when its config changes
  (`restartTriggers = [ <openclaw.json> ]`). Laure's container switches in
  place, which restarts only changed units; without the trigger her new URLs
  would wait for OpenClaw's file watcher (hot reload, up to five minutes).
  With it, the switch stops her gateway before `/etc` changes and starts it
  once on the new file. Her container, tailnet node, sessions, pairings and
  memory stay. flakey's container still restarts on change.

### Guards

`/tmp/claw/laure-tools-negative.py CHECKOUT` proves 17 wrong configurations
fail evaluation: a row with no callers (Laure's two), a node name as a
caller, Zao added to a shared row, flakey added to Laure's Scryer row in its
module, an unknown tool on Laure's calendar or Scryer row, `web_fetch` on the
web search row even when listed, a web search row with a backend too, web
search to another port, an unnamed row, Laure's calendar server on Simon's
row, flakey's Scryer server on Laure's row, flakey added to Laure's row in
the allowlist without a server, a Laure or shared server without a row, and
a gateway unit without the config restart trigger.
`tests/openclaw-people.nix` requires each gateway's URL servers to be exactly
the rows that admit its node, with the row's tools and no credential. The Go
tests (49) cover the web search row: both callers served, others 403 without
reaching the front door, only the row's key upstream, 19 invalid rows, and a
default key that leaves `/v1` up with every row at 404.

### Verification before approval

On Zao, one at a time. Never the aggregate flake check; Rakku never builds.

```sh
/tmp/claw/ai-mcp-go-check.sh "$PWD"           # gofmt, go test (49), go vet, race
/tmp/claw/laure-tools-checks.sh "$PWD"        # ai-mcp-proxy tailnet-names ai-gateway ai-gateway-staging
                                              # claw-tools claw-scryer claw-websearch claw-ebay
                                              # openclaw openclaw-people openclaw-in-place
/tmp/claw/laure-tools-identity.sh "$PWD" LABEL   # then laure-tools-identity-compare.py BEFORE AFTER EXPECT.json
/tmp/claw/laure-tools-negative.py "$PWD"
```

Expected differences from `cfb5bd31`: rows commit, on Rakku exactly
`tsnet-proxy-ai` and `tsnet-proxy-ai-staging`, and the four new rows in the
table; Yari byte-identical. Gateway commit: on Yari exactly
`container@openclaw` (reloads in place) and `container@claw-simon`; in each
container only `openclaw-gateway.service`; in Laure's config only the URLs of
her four servers, in flakey's only those of `claw-maps` and `claw-websearch`;
Rakku byte-identical. Retire commit: on Rakku exactly the four old proxy
units; Yari byte-identical.

### Deploy

Rakku first, then Yari, then acceptance; retire and delete only after every
gateway works on the new paths. Same machinery as stage 5 (scripts
`/tmp/claw/laure-tools-*` on Zao, each with a Nix shebang): Rakku built on
Unzen and copied through Zao with `--no-check-sigs`; Yari built natively with
the aarch64 `openclaw-config` and `openclaw-in-place-config` checks; every
switch and rollback under `systemd-run` with a fixed unit name
(`laure-tools-<step>`); the Rakku switch waits for both gateways to be idle and
for a `go` holding its nonce; automatic rollback in the same unit.

```sh
EXPECTED_SOURCE_SHA=<landed gateway or runbook commit>
/tmp/claw/laure-tools-build.sh rows "$PWD" "$EXPECTED_SOURCE_SHA"
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rehearse-gate
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rakku
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-rakku
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-yari
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" yari
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-yari
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-rollback-yari
```

- `rakku`: preflight (exactly the two proxy units differ; keyed `/v1/models`
  baseline), idle gate, ready/go. Only the two proxies may change identity;
  `ai-gateway`, SparkyFitness, `ebay-server`, the Google and Maps apps,
  Laure's Pi assistant, the four old proxies (still running), Home Assistant
  and Z-Wave keep theirs; keyed `/v1/models` matches the baseline; all ten
  rows answer the Rakku host with 403. Any problem rolls back at once; all
  ten 404 (table rejected, `/v1` healthy) exits 5: fix forward.
  `ai-mcp-rakku-health.py` then checks Home Assistant and the Z-Wave
  handshake.
- `yari` (`laure-tools-yari-switch.py forward`): refuses unless the target's
  `container@openclaw` carries `X-ReloadIfChanged=true`, only
  `openclaw-gateway.service` differs in her container, her config differs
  only in her four server URLs (all row URLs), both gateways are healthy and
  idle (checked again right before activation). It rolls back at once if the
  switch fails, health does not return in 180 s, her container restarted, her
  gateway did not restart exactly once (one new InvocationID, NRestarts 0),
  her container or flakey's does not run the target, or her live config is
  not the target's. A lost session or paired device is an alert (exit 6),
  not a rollback: a rollback cannot restore state.

### Acceptance

All read-only. No calendar edit, no Scryer change.

1. `accept-rakku`: from each container as `openclaw`, every row that admits
   that gateway answers initialize and `tools/list` with exactly its
   allowlist, refuses an unlisted tool (`-32601`), ignores a forged
   `Authorization`, and lists exactly its views; every other row returns 403
   to it (Laure's rows to flakey, Simon's to Laure). From Zao every row 403,
   also with forged headers; `/mcp/missing` and `/mcp` 404; `/v1/models`
   without a key 401. Keyed `/v1/models` 200 from both containers.
2. `accept-yari`: the above, plus both gateways' live configs (every URL
   server is its row, no credential, no per-tool host), `laure-tools-mcp.py`
   for both gateways (initialize, exact list, one read each:
   `family_calendar_events`, `scryer_search`, `travel_time` between two public
   city centres, one `web_search`, and on flakey all of its stage-5 reads),
   OpenClaw's own CLI `mcp probe` for both gateways with no diagnostics,
   Session Share both ways (`flakey-share.py`), Laure's gateway InvocationID
   is the one the switch recorded, and no failed units on Yari or in either
   container.

### Retire the old nodes

Only after acceptance passes. The retire commit removes the four tailnet
names (`lib/claw-tools.nix` goes, `claw-scryer-laure` from `claw-scryer`,
the endpoint from `claw-websearch`); Yari does not change and production `ai`
does not restart.

```sh
EXPECTED_SOURCE_SHA=<retire commit>
/tmp/claw/laure-tools-build.sh retire "$PWD" "$EXPECTED_SOURCE_SHA"   # refuses if Yari would change
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" retire-rakku
/tmp/claw/laure-tools-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept-retire
/tmp/claw/laure-tools-delete-nodes.sh dry-run
/tmp/claw/laure-tools-delete-nodes.sh delete
```

`laure-tools-delete-nodes.sh` checks that neither gateway's live config names
any of the four hosts, that the old units are gone from Rakku, and then, per
device through the fleet OAuth client: exactly one device with that exact
name, the recorded node ID, only `tag:claw-tools`, not connected. Anything
else stops the run before that device.

### Rollback (stage 7)

- Before the retire step: `rollback-yari` (Laure's gateway restarts once more
  onto the old URLs, in place; flakey restarts), then `rollback-rakku`
  (production `ai` restarts once onto the stage-5 binary and six rows; the
  old nodes still run). Both are `laure-tools-deploy.sh` steps with Laure's
  guards only.
- After the retire step, before the deletion: `rollback-retire` brings the
  old units back on their saved identities.
- After the deletion: move each old node's state aside on Rakku, as root,
  `mv /tundra/permafrost/var/lib/tsnet-proxy-<name> /tundra/permafrost/var/lib/tsnet-proxy-<name>.deleted`,
  then `rollback-retire`; each unit enrolls a new node with a new ID through
  the OAuth client. Then `rollback-yari` and `rollback-rakku` if the rows must
  go too.
- Without `/tmp/claw`, use the pinned systems from the deployment record with
  `nix-env -p /nix/var/nix/profiles/system --set <system>` and
  `systemd-run --wait --collect --unit laure-tools-manual-rollback <system>/bin/switch-to-configuration switch`,
  while Laure's gateway is idle. Do not use `nixos-rebuild switch --rollback`.

### Stage 7 deployment record — 2026-11-14 UTC

Simon approved the stage. Landed on cairn by fast-forward: `ed245f12`
(rows), `9da3d232` (gateway URLs), `f89930bd` (runbook) from `cfb5bd31`; then
`fd513eca` (retire). Rakku: evaluated on Zao, built on Unzen, copied through
Zao with `--no-check-sigs`. Yari: built natively, with the aarch64
`openclaw-config` and `openclaw-in-place-config` checks.

| Host | Step | Generation and system |
| --- | --- | --- |
| Rakku | before | 161 `/nix/store/jpv87gsdpii270c23xxh4cwyfqcca464-nixos-system-rakku-26.11.20260923.4975466` |
| Rakku | rows (`f89930bd`) | 162 `/nix/store/p8wfzq83rlq7npmfhn7pq93agwyfvpp0-nixos-system-rakku-26.11.20260923.4975466` |
| Rakku | retire (`fd513eca`) | 163 `/nix/store/kisiwq6lw147f80kl7bb5k88j5bq4zn9-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | before | 54 `/nix/store/vpq1hk8ffc2bxdkwjadxn01w3hd6n8q4-nixos-system-yari-26.11.20260923.4975466` |
| Yari | gateway URLs (`f89930bd`) | 55 `/nix/store/1qj23dd6k82kp8q9r6fwnbxaygkyrk8z-nixos-system-yari-26.11.20260923.4975466` (unchanged by retire) |

- Before deploying: both running systems equalled the evaluation of
  `cfb5bd31`. Identity comparison: rows changed on Rakku exactly
  `tsnet-proxy-ai` and `tsnet-proxy-ai-staging`; the gateway commit changed
  on Yari exactly `container@openclaw` and `container@claw-simon`, in each
  container only `openclaw-gateway.service`, in Laure's config only her four
  server URLs; retire changed on Rakku exactly the four old proxies. Checks:
  `ai-mcp-proxy`, `tailnet-names`, `ai-gateway`, `ai-gateway-staging`,
  `claw-tools`, `claw-scryer`, `claw-websearch`, `claw-ebay`, `openclaw`,
  `openclaw-people`, `openclaw-in-place`, and on Yari the two aarch64 checks.
  Negative cases 17/17. Go: 49 tests, vet, race. The real router with the
  real table and credentials on Rakku (systemd-run, user `tsnet-proxy`, never
  on the tailnet): all ten rows exactly their tools for their callers, every
  non-caller 403, Scryer signed in as `simon` and as `laure`. Baseline: Laure's
  four servers on the old nodes 12/12 with one read each and a clean CLI probe.
- Rakku rows: rehearsal 1.8 s from ready to go, both gateways idle. The first
  preflight stopped before any change: the stage-5 drop-in comparison also
  compared `multi-user.target.wants/` links, which resolve to the changed
  unit files. The script now compares contents only in `*.d/` directories.
  Switch rc 0 in 23.1 s. `tsnet-proxy-ai` stopped at 16:51:49.026 and logged
  `MCP table loaded` and `proxy ready` at 16:52:11.358: **`/v1` was down
  22.3 s**, started once (NRestarts 0). Only the two proxies restarted; the
  four old proxies, `ai-gateway`, SparkyFitness, `ebay-server`, the Google
  and Maps apps and Laure's Pi assistant kept their identities. Home Assistant
  HTTP 200; Z-Wave handshake (driver 15.15.0, server 3.4.0); no failed units;
  all ten rows 403 to the Rakku host.
- `accept-rakku` 61/61 from the containers and 23/23 from Zao: Laure's rows
  answer her and 403 to flakey, the shared rows answer both, Simon's rows 403
  to her; keyed `/v1/models` 200 with five models from both containers.
- Yari: both gateways idle and healthy; Laure's container reloaded in place
  (`container@openclaw` InvocationID `16c35f6d…` kept). **Her gateway
  restarted once**: stopped 16:54:00.146, started 16:54:01.418, healthy again
  after 12.7 s; InvocationID `5dbd700ddc1f4214b772e5a0522652ff` →
  `5487dfcd79464e2cbb182e4db83a4abe`, NRestarts 0. Her 8 sessions, 4 paired
  devices and 2 jobs are unchanged; her Session Share source kept its process.
  flakey's container restarted (unhealthy 61.4 s), as in stage 5.
- `accept-yari` 84/84 and 23/23 from Zao: both live configs hold only row
  URLs and no credential; one read on every server (flakey 30/30, sparkyfitness
  included; Laure 12/12: `family_calendar_events`, `travel_time`,
  `scryer_search`, one `web_search`), nothing written; OpenClaw's CLI probe on
  both gateways lists every server with its filter's tool count and no
  diagnostics; Session Share both ways (each side's source connected, one
  `sessions.list` each); no failed units on Yari or in either container.
  `check-rollback-yari` passes after the deploy.
- Retire: only the four old proxies stopped (and their bind mounts);
  `tsnet-proxy-ai` was not restarted. `accept-retire` 84/84 and 23/23.
- Deleted from the tailnet (fleet OAuth client, scope `devices:core
  auth_keys`), each checked first: exact name, recorded ID, only
  `tag:claw-tools`, not connected, named by neither gateway's live config.
  Each DELETE returned HTTP 200; 86 devices became 82. `tailscale status` on
  Zao now shows `ai`, `ai-staging`, `flakey` and `claw` and no `claw-*` tool
  node. No node changed its tags.

  | Node | Node ID | Last seen |
  | --- | --- | --- |
  | `claw-family-calendar` | `nw4DmtiXHN11CNTRL` | 2026-11-14 16:59:45 UTC |
  | `claw-maps` | `naQB5pjsTM11CNTRL` | 2026-11-14 16:59:45 UTC |
  | `claw-scryer-laure` | `nn4JrFbREK11CNTRL` | 2026-11-14 16:59:45 UTC |
  | `claw-websearch` | `nut8ipE3di11CNTRL` | 2026-11-14 16:59:45 UTC |

- Scripts and logs: `/tmp/claw/laure-tools-*` on Zao; copies in `/tmp/claw`
  on Rakku and Yari.

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
proxy units must still equal the stage-1 fixture (11 since stage 5, 7 since
stage 7: the nine retired per-tool proxies must be absent).

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

## Deployment record — 2026-11-14 UTC

Simon approved. Landed on cairn as `dfd9fe32`..`f67a0cf7` (fast-forward from
`e8bd3b4f`). Rakku: evaluated on Zao, built on Unzen, copied Unzen → Rakku
through Zao with `--no-check-sigs`. Yari: built natively.

| Host | Before | After |
| --- | --- | --- |
| Rakku | 157 `/nix/store/hj78p74d5jgjxb9ica4bwimw9g1x2k11-nixos-system-rakku-26.11.20260923.4975466` | 158 `/nix/store/11a2g7zh8zmb286903b35js57znqrmi2-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | 51 `/nix/store/l5ijg6gxxxwm55c9qasq8vyavr0gcq7w-nixos-system-yari-26.11.20260923.4975466` | 52 `/nix/store/hxkrg1n16j4zds2py72j6w5nx09pw7cw-nixos-system-yari-26.11.20260923.4975466` |

- Rakku: preflight OK (exactly the two proxy units differ). Both gateways
  idle; the idle check ran again before `go`. Switch rc 0 in 24.9 s.
  `tsnet-proxy-ai` stopped at 06:06:12.04 and logged `MCP table loaded` and
  `proxy ready` at 06:06:34.59: **`/v1` was down 22.5 s**, started once
  (NRestarts 0). `tsnet-proxy-ai-staging` restarted once. `ai-gateway`,
  `ai-gateway-staging`, SparkyFitness, Home Assistant and Z-Wave kept their
  identities. Only activation oneshots (hjem, linger, tailscale-join and
  similar, inactive before and after) got new invocations. Keyed `/v1/models`
  matched the baseline. Home Assistant HTTP 200; Z-Wave server handshake
  (driver 15.15.0, server 3.4.0); no failed units.
- `accept-rakku` 13/13: initialize (`sparkyfitness-mcp-server` 1.12.1);
  `tools/list` exactly the 23; `sparky_get_food_diary` for 2026-11-13 read
  (842 characters, not shown); an unlisted tool `-32601`; a forged
  `Authorization` changes nothing; Laure's container 403; from Zao 403 (also
  forged), `/mcp/missing` 404, `/mcp` 404, `/v1/models` 401; keyed
  `/v1/models` 200 with five models from both containers.
- Yari: Laure byte-identical, both gateways healthy and idle. Switch rc 0.
  Laure unhealthy 0 s; flakey unhealthy about 20 s while it restarted onto
  the new config. Laure's gateway InvocationID `5dbd700d…` and container
  InvocationID `16c35f6d…` unchanged (active since 2026-11-12 04:38:53 UTC).
  The brief and wind-down reconcilers failed once while the gateway started
  and succeeded on their automatic retry. The morning-brief job now holds
  the new text. No failed units on Yari or in either container.
- `accept-yari` 16/16: the above, plus `openclaw-admin mcp list` lists
  `sparkyfitness`, the OpenClaw CLI probe of the deployed config finds
  exactly 23 `sparkyfitness__` tools with no diagnostics, and the live config
  entry has no credential. `check-rollback-yari` passes after the deploy.
- No data was written to SparkyFitness. Scripts and logs: `/tmp/claw/sparky-prod-*`
  on Zao; copies in `/tmp/claw` on Rakku and Yari.

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
