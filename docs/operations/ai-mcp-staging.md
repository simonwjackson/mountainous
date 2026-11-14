# Path-prefixed MCP on the staging AI front door

Deployed to `ai-staging` only on 2026-11-14 UTC (Rakku generation 157); see
the deployment record below. Production `ai`, its backend, client keys and
other proxy units are out of scope and did not change.

**Stage 5** (see `ai-mcp-production.md`) widens the row contract: a row has a
loopback `backend` or a native `scryer` account (the proxy serves that Scryer
account itself; its password is the row's `mcp-<row>` credential), and a
loopback row may list exact `ui://` views (`mcpResources`). `routing.patch`
now also patches `scryer.go`; regenerate it when the shared `main.go`,
`mcp-filter.go` or `scryer.go` changes. The staging row and its table do not
change; staging restarts once for the new binary.

**Stage 2** (prepared, see `ai-mcp-production.md`) changes two things here.
Rows now match callers by stable Tailscale node ID, not node name, and the
staging row moves to IDs. Production `ai` also runs this router, with one
row. The deployment record below describes stage 1 as it ran.

## Contract and cost

- Stage 1: `ai-staging` alone uses `packages.ai-mcp-tsnet-proxy`. That package overlays
  `routing.patch` and `routes*.go` on the unchanged shared proxy source. The
  shared `media-tsnet-proxy` derivation does not change. The patch reuses the
  credential injection from local commit `8cf57067`; no personal-data route or
  separate SparkyFitness node is included. `routing.patch` carries three lines
  of context per hunk, so a later shared-source change makes `patch` fail
  instead of inserting at a stale line number. Regenerate it with a three-way
  merge when the shared `main.go` or `mcp-filter.go` changes.
- Everything outside `/mcp/` calls the existing `proxyHandler` directly. The
  front-door authorization, headers, streaming and server timeouts stay intact.
  `/mcp` itself is outside `/mcp/` and still goes to the front door.
- The one row is `/mcp/echo`, backend `http://127.0.0.1:8422/mcp`, tool `echo`,
  allowed callers `claw-simon` (`nbQJZMcewG11CNTRL`; renamed `flakey` on
  2026-11-14, same ID) and `zao`
  (`nto5J2nGb311CNTRL`). The backend always returns `ok`; it does not echo
  input, read files or call services. No credential is needed for this row.
  `zao` stays on this harmless staging row permanently. The Tailscale policy
  lets `tag:claw` reach only the production `ai` front door, so `claw-simon`
  cannot reach `ai-staging`; Zao proves the allowed-caller path instead.
- Caller lists are `mountainous.tailnetNames.<name>.mcpRoutes.<row>.callerNodeIds`
  options: stable node IDs from `lib/tailnet-nodes.nix`, the source of truth.
  WhoIs's `Node.StableID` is the identity. Stage 1 matched the node name, and a
  removed node's name can be registered again by another node. A rename keeps
  the ID, so the claw-simon to flakey rename needs no row change. Caller
  headers cannot grant access. An empty list, a node name or a DNS name fails
  evaluation (the type is `n[a-zA-Z0-9]+CNTRL`), and the router refuses such
  a table and a stage-1 table with `callers`.
- MCP requests use the existing stateless `mcpTools` filter, with separate
  allowlists per row. Caller auth headers and cookies never reach MCP backends.
  MCP has its existing bounded bodies and 60-second upstream timeout; normal
  model streams do not gain that timeout. Upstreams are fixed loopback HTTP URLs.
- Optional `bearerCredentialFile` must be a runtime `/run/` secret source, never
  a store path or literal token. The module adds `LoadCredential=mcp-<row>:<source>`.
  JSON contains only `bearerCredential: "mcp-<row>"`. The router reads this basename
  from systemd's `CREDENTIALS_DIRECTORY`; it cannot take a path from callers.
  Since stage 2 the module also adds `SetCredential=mcp-<row>:unavailable credential`,
  so a missing source no longer stops the unit; the router refuses that value.
- `/etc/tsnet-proxy-ai-staging-mcp.json` is the stable table path. NixOS updates
  its link, then `reloadTriggers` causes `ExecReload=kill -HUP $MAINPID`. Reload
  validates the entire table and publishes an atomic snapshot. Invalid reloads
  retain the previous table and log a value-free error. Since stage 2 an invalid
  initial table no longer stops the proxy: it starts with no rows and logs it,
  and SIGHUP is caught before the tailnet start. In-flight requests retain
  their old handler. Changes to callers, backends or tools do not change
  `ExecStart`, `LoadCredential` or `restartTriggers`. Removing the last row also
  reloads: the explicit `mcpRouting.enable` remains true with an empty table.
- Initial installation changes the staging executable and restarts staging once.
  Adding/rotating a systemd credential is **not** a table-only change: systemd
  loads credentials at service start, so this needs a separate reviewed staging
  restart. SIGHUP is asynchronous; inspect the reload log and test the row after reload.
- The check freezes the other Rakku proxy units (16 since stage 2, 11 since stage 5 retired five) to
  the before-change evaluated fixture, including store paths. A later fleet
  package/input upgrade must deliberately retire or update this temporary guard.
  Do not regenerate the fixture just to make an unexpected production diff pass.

## Verification before approval

Run on Zao, sequentially and from this checkout. Do not run the aggregate flake
check command. Rakku must never build.

```sh
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
nix build --no-link -L .#checks.x86_64-linux.ai-mcp-proxy \
  .#checks.x86_64-linux.tailnet-names .#checks.x86_64-linux.ai-gateway-staging
```

`checks.ai-mcp-proxy` builds the actual staging proxy with its Go tests and
`go vet ./...`, then exercises the real Python no-op backend over loopback HTTP.
It checks callers and LoadCredential wiring on every configured
row, freezes the other Rakku units (16 since stage 2, 11 since stage 5 retired five), and compares changed-caller and empty-table
variants: only `X-Reload-Triggers` may change in their rendered units.

For a local Go run against the same assembled source:

```sh
work=$(mktemp -d /tmp/ai-mcp-go.XXXXXX)
cp -a packages/media-tsnet-proxy/. "$work/"
patch -d "$work" -p1 < packages/ai-mcp-tsnet-proxy/routing.patch
cp packages/ai-mcp-tsnet-proxy/routes*.go "$work/"
(cd "$work" && CGO_ENABLED=0 go test -v ./... && CGO_ENABLED=0 go vet ./...)
# With a compiler available, also run: go test -race -run TestMCPRoutes ./...
```

The before fixture is `tests/ai-mcp-proxy-units-before.json`, re-evaluated from
cairn `89ccdd6b` without this change. Its 18 entries include rendered unit text, ExecStart,
restartTriggers and reloadTriggers. Re-evaluate the same projection to compare:

```sh
nix eval --json .#nixosConfigurations.rakku.config --apply 'c:
  builtins.mapAttrs (n: s: {
    inherit (s) restartTriggers reloadTriggers;
    inherit (s.serviceConfig) ExecStart;
    text = c.systemd.units."${n}.service".text;
  }) (builtins.removeAttrs c.systemd.services (builtins.filter
    (n: builtins.match "tsnet-proxy-.*" n == null)
    (builtins.attrNames c.systemd.services)))' > /tmp/ai-mcp-units-after.json
```

## Prepared evidence

Re-verified after the rebase onto `89ccdd6b`: 38 top-level Go tests pass,
`go vet` passes, all tests pass with `-race`, and the seven route groups pass
600 race runs under four-process contention. The three focused checks pass.
The 18-unit fixture matches; only `tsnet-proxy-ai-staging` differs. The
items below are the original preparation on `ea3a20b0`.

- Go: 36 top-level tests pass, including seven route test groups. The seven
  route groups also pass with `-race`; `go vet ./...` passes.
- Focused checks: `ai-mcp-proxy`, `tailnet-names`, `ai-gateway-staging` pass.
  Negative evaluations reject empty callers, a store-path credential, an
  unbound LoadCredential and a production proxy backend change.
- Before/after: 17 Rakku proxy units compared; only `tsnet-proxy-ai-staging`
  differs. `restartTriggers = []`, one table in `reloadTriggers`, fixed
  `/etc` argument in ExecStart. The check also proves caller changes and
  deletion of the last row change only the reload trigger.
- A read-only SSH read of all 17 installed Rakku proxy unit files matches the
  evaluated before fixture exactly. Home Assistant, Z-Wave, both front-door
  proxies and the staging gateway were active. Staging had PID 985413 and zero
  restarts at inspection. Port 8422 was unused on Rakku.
- Zao's current identity is `zao.hummingbird-lake.ts.net.`; Tailscale lists
  `claw-simon.hummingbird-lake.ts.net.`. Existing staging `/v1/models` returned
  the 401 baseline below. No new MCP route was installed or tested on Rakku.

## Approved staging deployment only

The 2026-11-14 deployment ran this sequence through copied Nix-shebang
scripts, not inline SSH (see the deployment record).

First review the committed diff and get separate deployment approval. Pin the
approved full commit SHA. Do not substitute another branch tip. On Zao:

```sh
cd /home/simonwjackson/.cache/clones/simonwjackson/mountainous/work/ai-mcp-proxy
EXPECTED_SOURCE_SHA=<approved-full-commit-sha>
test "$(git rev-parse HEAD)" = "$EXPECTED_SOURCE_SHA"
test -z "$(git status --porcelain)"
export NIX_SSHOPTS='-F /dev/null'
OLD=$(ssh -F /dev/null simonwjackson@rakku 'readlink /run/current-system')
printf '%s\n' "$OLD" > /tmp/ai-mcp-rakku-rollback-system
ssh -F /dev/null simonwjackson@rakku \
  'systemctl show tsnet-proxy-ai -p MainPID -p InvocationID -p NRestarts; systemctl is-active home-assistant zwave-js'
DRV=$(nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath)
nix copy --derivation --to ssh-ng://root@unzen "$DRV"
SYSTEM=$(ssh -F /dev/null root@unzen \
  "nix build --no-link --print-out-paths '$DRV^*'")
nix copy --no-check-sigs --from ssh-ng://root@unzen --to ssh-ng://root@rakku "$SYSTEM"
# Compare the built units with the running generation before switching.
# Abort if any non-staging proxy differs, including earlier unapplied changes.
ssh -F /dev/null simonwjackson@rakku bash -s -- "$SYSTEM" <<'SH'
set -eu
for unit in "$1"/etc/systemd/system/tsnet-proxy-*.service; do
  name=${unit##*/}
  [ "$name" = tsnet-proxy-ai-staging.service ] && continue
  cmp "$unit" "/etc/systemd/system/$name"
done
SH
ssh -F /dev/null simonwjackson@rakku "sudo nix-env --profile /nix/var/nix/profiles/system --set '$SYSTEM'"
ssh -F /dev/null simonwjackson@rakku "sudo '$SYSTEM/bin/switch-to-configuration' switch"
ssh -F /dev/null simonwjackson@rakku \
  'curl -fsS --max-time 10 -o /dev/null http://127.0.0.1:8123/; ss -ltn | grep 127.0.0.1:3000; readlink /run/current-system; systemctl is-active tsnet-proxy-ai-staging ai-staging-mcp-echo ai-gateway-staging home-assistant zwave-js; systemctl show tsnet-proxy-ai -p MainPID -p InvocationID -p NRestarts; journalctl -u tsnet-proxy-ai-staging -n 15 --no-pager; journalctl -u zwave-js -n 20 --no-pager'
```

Unzen builds. Rakku receives the closure only. Compare production's PID,
InvocationID and NRestarts with the saved before values. Check Home Assistant's
HTTP health and the existing Z-Wave integration/controller status, not only unit
activation. Do not reboot. Stop and roll back if those services regress or if
any other proxy is scheduled to restart. A full system switch can include earlier
unapplied cairn changes: the evaluated before/after proof is not a live-generation
diff. Inspect those live unit differences separately before this switch.

## Post-deploy acceptance

1. From a node that is not an allowed caller (Rakku or Unzen; Zao before it
   joined the row):

   ```sh
   base=https://ai-staging.hummingbird-lake.ts.net
   curl -sS -i --max-time 15 "$base/mcp/echo" -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   # Required: HTTP 403, even with forged Authorization or X-Forwarded-For.
   curl -sS -i --max-time 15 "$base/mcp/missing" -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   # Required: HTTP 404.
   curl -sS -i --max-time 15 "$base/v1/models"
   # Before-change baseline on Zao: HTTP 401,
   # {"error":{"code":"unauthorized","message":"valid gateway key required"}}
   ```

2. From the **claw-simon container** on Yari, not a host identity, use its existing
   curl: `ssh -F /dev/null root@yari 'nixos-container run claw-simon -- runuser -u openclaw -- curl ...'`.
   This needs a tailnet policy grant from `tag:claw` to `ai-staging:443`, which
   does not exist (see the deployment record below). From Zao, an allowed caller,
   POST the same `tools/list` request to `/mcp/echo`: exactly one `echo` tool.
   POST `tools/call` with `params: {"name":"echo"}`: text `ok`.
   Call an unlisted tool: JSON-RPC `-32601`, no backend call. No key is needed.
3. Use an existing staging client key through a private credential/header file,
   not a command-line token or this document, to call `/v1/models`. Compare the
   result with the pre-deploy capture. Use the same approved streaming `/v1`
   request before and after: status, headers, key enforcement and chunks must
   match. Do not make paid provider calls merely for this test without approval.
4. Capture `MainPID`, `InvocationID` and `NRestarts` for `tsnet-proxy-ai-staging`.
   `sudo systemctl reload tsnet-proxy-ai-staging` must log `MCP table reloaded`
   with the same values. Keep a model stream open during this reload.
5. For a real table-change proof, prepare a second staging-only revision changing
   only the row's tool allowlist (e.g. temporarily `[ "echo-denied" ]`). Re-run
   focused evaluation/checks, get approval for that revision, and use the same
   build/copy/switch sequence. The unit may differ only in `X-Reload-Triggers`.
   Its PID and InvocationID must stay the same; `tools/list` becomes empty and
   calling `echo` returns `-32601`. Restore `[ "echo" ]` with the same approved
   procedure. Do not edit the immutable `/etc` symlink target or production.

## Deployment record — 2026-11-14 UTC

Simon approved stage 1. Commits on cairn: `953f823e` (this change, rebased onto
`89ccdd6b`) and `b4c0e502` (adds `zao` as a caller). Rakku was evaluated on
Zao, built on Unzen and copied Unzen → Rakku with `--no-check-sigs`.

| Generation | System | Change |
| --- | --- | --- |
| 155 | `/nix/store/r56yg127y7a4p5mkd44y73x23wldbj49-nixos-system-rakku-26.11.20260923.4975466` | before; rollback target |
| 156 | `/nix/store/jw6dbfjas0rsngdar70drx6fcmjkv02s-nixos-system-rakku-26.11.20260923.4975466` | `953f823e`: staging proxy restarted once (about 22 s), echo backend started |
| 157 | `/nix/store/hj78p74d5jgjxb9ica4bwimw9g1x2k11-nixos-system-rakku-26.11.20260923.4975466` | `b4c0e502`: table only, staging proxy **reloaded** |

- Closure diff 155 → 156: only new paths `ai-mcp-tsnet-proxy` (23.7 MiB),
  `ai-mcp-echo.py`, the MCP table, the staging reload trigger, two units,
  `system-units` and `etc`. No other session's work was pending on Rakku.
  156 → 157: the table, the reload trigger, the staging unit (only its
  `X-Reload-Triggers` line), `system-units` and `etc`.
- Production `tsnet-proxy-ai` kept MainPID 1148002 and InvocationID
  `aac522588f3d4f8ea474030583cd29c1` through both switches. `ai-gateway`,
  `home-assistant` and `zwave-js` also kept their identities. Of 18 proxies,
  only `tsnet-proxy-ai-staging` got a new identity, once. Home Assistant HTTP
  200, Z-Wave server handshake (driver 15.15.0, server 3.4.0), no failed units.
- Generation 157 reloaded the staging proxy: MainPID 1152269 and InvocationID
  `8dfcd5b25f2f43a9a2a3e91eb072cc0b` unchanged, `MCP table reloaded` logged.
  Two manual `systemctl reload` runs also kept them. A Zao keep-alive HTTPS
  socket served requests before and after a reload.
- From Zao before `zao` joined the row: `/mcp/echo` 403, also with forged
  `Authorization` and `X-Forwarded-For`; `/mcp/missing` 404; `/mcp` and
  `/v1/models` unchanged (404 front door and 401). Rakku and Unzen hosts still
  get 403 on `/mcp/echo`.
- From Zao as an allowed caller: initialize returns `ai-staging-echo`,
  `tools/list` is exactly `[echo]`, the `echo` call returns `ok`, an unlisted
  tool returns `-32601 tool not allowed` from the proxy, forged caller headers
  change nothing.
- Keyed `/v1/models` from Rakku through the new binary: `ai-staging-test-a`
  200 (11 models), `ai-staging-test-b` 403 `dialect_not_allowed`. No keyed
  capture was taken before the switch, and no paid streaming call was made.
- **claw-simon positive path: blocked by design.** From `claw-simon` (as
  `openclaw`), TCP to `ai-staging:443` times out while production `ai` returns
  401. The `tag:claw` policy reaches only the production `ai` front door. The
  policy was not changed. The next stage makes the first claw-simon check on
  production `ai`.
- Laure's `container@openclaw` was not touched (active since 2026-11-12 04:38 UTC).

Scripts and logs: `/tmp/claw/ai-mcp-*` on Zao; copied scripts in `/tmp/claw`
on Rakku and Yari.

## Rollback

Rollback target: generation 155,
`/nix/store/r56yg127y7a4p5mkd44y73x23wldbj49-nixos-system-rakku-26.11.20260923.4975466`
(also saved on Zao in `/tmp/ai-mcp-rakku-rollback-system`). No build, state
deletion or tailnet reenrollment is needed. The copied guarded script refuses
when a later deployment replaced generation 156/157 (use a forward revert then),
waits for another switch, switches and prints production identities and health:

```sh
ssh -F /dev/null root@rakku /tmp/claw/ai-mcp-rakku-rollback.py
```

If `/tmp/claw` is gone, copy `/tmp/claw/ai-mcp-rakku-rollback.py` from Zao to
Rakku and run it the same way. The rollback has not been executed.

Repeat front-door, Home Assistant and Z-Wave health checks. Keep all tsnet state
and gateway state directories. Rollback restores the old staging binary and
removes the no-op backend; it must not reenroll either front-door identity.
