# Per-person OpenClaw on Yari — 2026-11-11 Denver

## Current state and the continuity decision

**Laure stays in place.** Her address remains
`https://claw.hummingbird-lake.ts.net`, container `openclaw`, tailnet node `claw`,
state `/var/lib/nixos-containers/openclaw/var/lib/openclaw`, agent `laure`,
workspace `workspace-laure`, Snowy/avatar, assigned profile role `laure`, and
existing iPad/phone pairings. Do not copy a database into her live state.
Do not retire `claw`, rename it, or re-pair her devices as part of this handoff.

Simon's gateway is `https://flakey.hummingbird-lake.ts.net` (tailnet node
`flakey`, ID `nbQJZMcewG11CNTRL`, IP `100.75.156.21`, only `tag:claw`; container
and state `claw-simon`). The node was `claw-simon` until the in-place rename on
2026-11-14 (see "Rename to flakey" below). His databases are fresh by
his decision. His workspace files, Markdown memory and research runs were
copied and checksum-compared, not deleted from the old gateway. His old
conversations remain in the verified root-only backup, not in the new UI.

The temporary rehearsal container and tailnet node `claw-laure` have been
retired. Its cloned private state and synthetic profile were wiped before the
real handoff. Its old node pairing was removed from Simon's gateway.

Everything new comes from **one** `lib/openclaw-container.nix`.
`lib/openclaw-people.nix` declares person/container/node identity, existing
workspace path, role name, login, personal servers, prompt and brief enablement.
`lib/openclaw-instances.nix` derives the temporary rehearsal names while
`mountainous.features.openclaw.legacy.enable` is true. Setting it false switches
Laure's **existing** container to the same shared definition, not a new placement.
Simon's role is default `person`; sign-in accepts only his login. Laure keeps the
stored named role `laure`, and sign-in accepts only her login. Both retain
`sessions.others = "write"` for same-agent children and Session Share. Neither
role grants admin. Each has only its own calendar/Scryer servers, plus maps and
MCP web search. Simon alone declares the clock and budget demos as extras.

Shared skills live in `lib/openclaw-skills/shared/`; each loads its own sibling
folder too. Optional lists are `extraSkillFolders`, `extraMcpServers`,
`extraPlugins`, and `extraToolPermissions`. Extra MCP entries use `{ name; value; }`
or the pinned demo descriptor `{ name; bundledDemoTool; }`. Generated JSON drift
checks cover both the rehearsal and final in-place instances. The focused check
also asserts Laure's production login, existing names/role and disabled brief.

Both gateways resolve the same signed app profile
`/nix/var/nix/profiles/apps/openclaw`. The weekly controller restarts/health-checks
both active instances and their sources. Before handoff these are the two new
containers; afterward they are `claw-simon` and `openclaw`. It never restarts the
protected legacy gateway while the legacy flag is true. Shell remains denied;
the unconfigured built-in `web_search` is denied separately, and the shared
`web-search` skill directs plain search requests to the working MCP endpoint.

| Front-door chat model | Native contextWindow | maxTokens | contextTokens cap |
| --- | ---: | ---: | ---: |
| claude-opus-5-5 | 1000000 | 128000 | absent, full window |
| gpt-6.1-sol | 500000 | 128000 | 272000 |
| gemini-3.8-flash-high | 1048576 | 65536 | absent |

Simon approved these values. Separate `openclaw@yari` front-door probes accepted
698431 prompt tokens on Opus with `max_tokens=128000` (HTTP 200), 542301 on Sol,
and 760099 on Gemini. Sol/Gemini windows come from CLIProxyAPI's model list;
these probes establish large-input acceptance, not a measured maximum. Installed
Anthropic/OpenAI docs support Opus's uncapped input and Sol's 272000 budget.
`models list --json` shows context windows/cap; it does not expose `maxTokens`.
The authored output limits also pass real CLI config validation. Laure receives
these in the same single restart as the completed in-place change.

## Gates used for the handoff

Simon explicitly released the no-touch hold after Laure stopped for the evening.
Before that go, no restart, stop or reconfiguration of `openclaw` was allowed.
Reaching 22:00 alone was never permission. The legacy container's system, host config and restart-trigger
store paths remain frozen real dependencies. Before every pre-handoff Yari
switch, rebase on current origin/cairn, build on Yari, check origin and the running
system did not change, and run `scripts/openclaw-safe-switch` on Yari. It compares
unit bytes, container-config bytes **and store path**, the system closure and
config store paths, and the running private config bytes. It refuses differences
and checks legacy process identity and the app profile afterward.

Before **every gateway interruption**, `openclaw-wait-idle CONTAINER` reads only
`audit_events` event types, run ids and timestamps. It waits for each
`agent.run.started` to have a matching terminal receipt. Missing/unreadable
receipts are not proof of idle. The switch guard, app controller and workspace
copy helper use it. It does not inspect message text. Do not cut off a turn.
Never run `nix flake check`; use the focused checks and native ARM validation.

Frozen transitional inputs on a new evaluator (copy, do not build them):

```sh
NIX_SSHOPTS='-F /dev/null' nix copy --from ssh-ng://root@yari --no-check-sigs \
  /nix/store/j5gwnqw7sw5gbs5fbr19dmvrrvalj335-nixos-system-claw-26.11pre-git \
  /nix/store/30qbz85w5qhckyl8dmj9m294ifyv7f07-etc-nixos-containers-openclaw.conf \
  /nix/store/n63mxcv1saygx0b0ypkd01cl6h02nknh-X-Restart-Triggers-container-openclaw
```

## Verified before handoff

Yari generation **39**, system
`/nix/store/kd7ywni4svbyiyvsw7jwcx9y6lvykbwk-nixos-system-yari-26.11.20260923.4975466`.
Legacy container InvocationID `fa8925c4a2924b3eba6947aef0256167` and gateway
InvocationID `0c54eb2fab884081a4a3f22f995d40fc` stayed unchanged through all three
switches and the two-gateway package health controller. Legacy unit SHA256:
`86538792713a66a465a9271aecc03874f04d00eac8c5b69a5bde38f30d192a5a`.
All six legacy claw-tools endpoints and each new gateway's own four endpoints
passed tools/list after every switch. App profile remains generation 1,
`61j8zqks0hykidf3ws2s0k069r13plhm-activatable-openclaw-gateway-2026.11.3`.

A real Simon browser on Zao passed sign-in/pairing, flakey persona, calendar,
Markdown memory recall, ask_user, the exact plain web-search prompt without
naming the MCP tool, both budget/clock cards and interaction, model limits, and
view-only Session Share. Evidence: `/tmp/claw/simon-new/` on Zao.

Simon's brief was initially created before the main conversation existed and
had no immutable creating-conversation binding. The helper removed it and
restarted only `openclaw-morning-brief`. New job
`66d2d1b5-48d2-45a1-b899-ec86179df374` is bound to `agent:main:main`, enabled
07:00 America/Denver, zero stagger, and survived the final restart/reconcile.
One manual run delivered exactly one tagged message into that conversation's
history. Old brief `df3d8216-a284-4086-a127-3890019d5cdb` was removed through the
old gateway API without restart; its declaration is backed up root-only at
`/var/tmp/claw-split-old-simon-brief.json`. No duplicate old Simon brief remains.

Session Share passed **both directions** between the two new gateways: only the
Shared fixture listed; actual user/assistant text opened read-only; unshared and
Draft direct reads failed; moving out revoked a read immediately and removed the
row at refresh. The real non-admin Simon UI also opened `SHARE-PROOF-LAURE`
view-only with its composer disabled. Each source advertises only
`openclaw.sessions.list.v1,openclaw.sessions.read.v1`, capability
`openclaw-sessions`, no worker hosting. Core administrator-minted single-use join
codes pair tagged devices without inventing a human identity or weakening auth.
They approve only the exact bootstrap command surface. Source units use their
own user/state and durable paired token, not an ambient local gateway password.

An online full backup of the live legacy gateway passed `--verify` after an idle
check, without restarting it: **82409441 bytes**, root:root 0600 at
`/permafrost/openclaw-migration-backups/2026-11-12T03-37-18.170+00-00-openclaw-backup.tar.gz`.
SQLite online backups are safe while running; an archive has per-database
consistency, not a single cross-database transaction. The fresh handoff backup also passed verification. Full restore preserves identities/tokens verbatim; a copied
seal triggers full validation, not quarantine unless physical corruption is proven.
No `doctor --fix` or SQL write was used.

The isolated restored clone booted with the exact Laure instance, only rehearsal
node/login overrides: Snowy, matching avatar SHA256
`6b78b03bbadfc2e2b3a608e386011e39f1e8772d115e0b8cc313aec9d3a2a8e8`,
**5 original sessions (4 active, 1 archived)**, original heartbeat id
`be615b2c-0e91-49fd-b561-ea16cea9ce74` and dreaming id
`b930183b-f866-400a-9e30-0a5d0516911b` retained. Both resolve to agent `laure`;
dreaming retains its stored null agentId and isolated target. A new synthetic
profile explicitly assigned `laure` negotiated the four non-admin scopes and
sessionCap write. It saw 0 main sessions under default, configuredAgentsOnly false,
and explicit main selection; it saw 5 Laure sessions before its own test rows.
Its real read tool failed on Simon's USER.md; its sessions_spawn and child run
succeeded. Only audit metadata was inspected, never original conversation content.
With gateway stopped, moving Simon's workspace and agents/main outside the
container to a root-only host archive still booted cleanly with no main sessions.
Initial swap/start to health: **13 s**; archive/restart: **14 s**; cold validation:
**27 s**. Budget **45–60 seconds** for the real container stop/start.

All cloned private state, restored staging, input archive and synthetic profile
were wiped afterward. The original empty test state was restored. The protected
live gateway and its original state were never stopped or altered by this rehearsal.

## Executed in-place handoff — 2026-11-11

Simon gave explicit go after Laure finished for the evening. The previous 22:00
hold no longer applied. Commit `6b0dc15c` set Yari's legacy flag false. Its system
output and derivation matched the native pre-build exactly before activation.

The activation command was run once, successfully. Do not run it again:

```sh
bash /var/tmp/openclaw-activate-in-place --laure-has-stopped
```

`scripts/openclaw-activate-in-place` refuses a changed baseline or concurrent
activation; waits for both gateways to be idle; takes a fresh verified online
backup; archives Simon's original workspace and agent directory; switches to the
pre-built system; checks continuity, models and six MCP endpoints; and only then
pairs both real Session Share sources. Its error trap attempts pinned rollback.
No rollback was needed. Source flag changes require explicit operator action.

### Security correction: paired devices are not all Laure's

The original continuity check incorrectly preserved **all ten** original
pairings. Seven belonged to Simon, and his phone `usu` was connected with both
node and operator roles. A login/role change does **not** revoke an existing
bootstrap-issued device token or remove a phone's node capabilities.

The supervising operator checked ownership against tailnet addresses and removed
all seven through `openclaw-admin devices remove`. Laure's devices were not
changed. No claim is made about what the phone may have read before removal.

| Simon device | Verified tailnet IP | Revoked device prefixes |
| --- | --- | --- |
| usu | 100.110.243.2 | 9a68bc5f, bcb55518 |
| Zao | 100.114.19.92 | 5c6fbc6b, 2f61d437, f976f084 |
| Myoko | 100.117.218.54 | 3b42fc03, 715d39a4 |

The activation script now includes this explicit step **after backup and before
its retained-device baseline and gateway stop**:

1. Inventory `devices list --json` and `nodes list --json`. Verify ownership
   against tailnet addresses, not display names. Reconfirm the address list
   before another use of this handoff script.
2. Remove the other person's paired devices **and nodes** through supported
   `devices remove`; reject their matching pending requests. The script uses the
   verified addresses above and asserts that both APIs have no leftovers or
   `usu` row. Do not remove the approved read-only Session Share source.
3. Preserve Laure's iPad, phone browser and local CLI. Only these retained device
   contracts form the continuity baseline, not all former household pairings.
4. Check pending bootstrap/setup and join-code metadata without printing bearer
   values. Revoke a valid unwanted credential only through a supported command;
   never edit SQLite to force revocation.

Actual follow-up checks found **zero** pending device requests, **zero** rows in
`device_bootstrap_tokens`, and **zero** rows in `device_pairing_join_codes`.
No stored valid setup/bootstrap bearer remained to revoke. Setup-completion
receipts are non-secret outcomes, not reusable credentials. `nodes list` on
`openclaw` now shows only the connected read-only source from Simon; no `usu` row.

### Verified result

| Check | Result |
| --- | --- |
| Host | Generation **40**, `/nix/store/7mhvsskivrnnbsaylbww7zvpgrdbalgq-nixos-system-yari-26.11.20260923.4975466` |
| Laure container | `/nix/store/z4mglka9jzbr1yssdkjnxwy0ipgylhw2-nixos-system-claw-26.11pre-git` |
| Gateway outage | **66.9 seconds**: admission closed 04:38:03.934 UTC; ready 04:39:10.879. This exceeded the 45–60 second estimate. Full continuity checks took 93 seconds. |
| Laure sessions | **5 → 5**, four active and one archived, same IDs; original text not opened |
| Old main agent | Absent from roster, listings and physical container workspace/agent paths |
| Profiles | **3 → 3**, original Laure profile and assigned `laure` role unchanged |
| Laure device pairings | iPad `da467e0e` (100.121.89.74) and phone browser `359b918a` (100.84.218.93), unchanged |
| Final device pairings | **4**: Laure's two devices, local CLI `2ee6e6c1`, and read-only Simon source `c6a5517c` |
| Nodes on Laure gateway | Only connected `c6a5517c`; exactly session list/read commands, `sessionHost=false` |
| Jobs | Two unchanged Laure jobs: heartbeat `be615b2c-0e91-49fd-b561-ea16cea9ce74`, dreaming `b930183b-f866-400a-9e30-0a5d0516911b`; effective agent `laure`. Old main heartbeat removed by sole-agent config. No new Laure brief. |
| Identity/avatar | Original Tailscale node and Snowy checksum retained |
| Health | Both gateways healthy; all six MCP endpoints passed `tools/list` from the real Laure container |
| Rehearsal retirement | Exact `claw-laure` machine deleted through Tailscale API; its old `b5ac6741` node pairing removed from Simon's gateway |

Both real Session Share nodes are connected and advertise **only**
`openclaw.sessions.list.v1` and `openclaw.sessions.read.v1`, with
`sessionHost=false`. On real `claw`, direct node invocation listed Simon's
controlled Shared fixture and read the actual `SHARE-PROOF-SIMON` assistant text.
Moving it out of Shared immediately denied read with “Session is no longer
shared.” No fixture was created on Laure's real gateway and none of her original
conversation text was opened. Simon's “OpenClaw sessions” catalog shows her real
node `2ee6e6c1`, connected, and **zero conversations**; she has shared none.
The full non-admin UI/read-only proof passed earlier on the rehearsal pair.
Production Laure-viewer verification is deliberately left for her own login.
No temporary admin identity was created on her production gateway.

One operational limitation appeared: after revoking the fixture, the source
inventory retained a stale selection and list returned the same fail-closed
“no longer shared” error. Restarting **only** Simon's source cleared it; the next
list succeeded with zero rows. Neither gateway restarted. Investigate source
inventory invalidation upstream. If a Shared-group change does not appear, use
this source-only refresh, not a gateway restart:

```sh
nixos-container run claw-simon -- systemctl restart openclaw-session-share
# For Laure's publications, the source container is openclaw instead.
```

### Retained recovery material

Both archives are verified, root:root 0600, beneath a root-owned 0700 directory:

- `/permafrost/openclaw-migration-backups/2026-11-12T03-37-18.170+00-00-openclaw-backup.tar.gz`
  — 82,409,441 bytes.
- `/permafrost/openclaw-migration-backups/handoff-20261112T043737Z/2026-11-12T04-37-38.973+00-00-openclaw-backup.tar.gz`
  — 149,239,598 bytes.

Simon's original directories remain alongside the second archive under
`retired-simon/workspace` and `retired-simon/agents-main`. They are outside Laure's
container. `/permafrost/openclaw-migration-backups/latest-handoff` records the
folder; `/var/lib/openclaw-migration-backups` is only a convenience symlink.

**Keep both full backups, retired files and the pinned rollback until Simon
explicitly authorizes removal, including after tomorrow's successful check.**
The full backups predate device cleanup and contain the old credentials. Never
restore one to a reachable gateway without repeating device cleanup in isolation
first. Do not copy live WAL files or run `doctor --fix` to force a restore.

### Exact pinned rollback

Do not restore an old whole database over newer Laure messages. The installed
helper waits for both gateways to be idle, preserves newly created replacement
directories, restores the retired original directories and switches to the pinned
generation-39 host. It leaves device revocations intact.

```sh
ssh -F /dev/null root@yari \
  '/permafrost/openclaw-migration-backups/rollback-in-place --restore-pinned-legacy'
```

Pinned root: `/nix/var/nix/gcroots/openclaw-before-in-place-handoff` →
`/nix/store/kd7ywni4svbyiyvsw7jwcx9y6lvykbwk-nixos-system-yari-26.11.20260923.4975466`.
Source is `scripts/openclaw-rollback-in-place`. Bash/shell lint passed; a complete
rollback was not executed on production. Independently verify old serving health
and the original count recorded in the handoff folder's `laure-count`. Revert the
source legacy flag to true before ordinary deployment. The pinned configuration
is the old two-agent setup, not the intended steady state. Never restore the
pre-prune pairing database during ordinary configuration rollback.

### Open checks after tonight

- Laure uses **https://claw.hummingbird-lake.ts.net** on her existing iPad and
  phone. Expect Snowy, the same five conversations, normal existing device
  authorization and the `laure` role. Do not send a new QR code. If continuity
  fails, use the pinned rollback and independently verify health and count;
  retain evidence and report the incident.
- **Laure's own view of a conversation Simon shared: verify when she next uses
  it.** Simon puts a controlled conversation in group `Shared`; she selects
  “OpenClaw sessions,” expands the connected source and opens its matching text
  read-only. Continue/archive/terminal must stay unavailable. If absent, check
  connectivity and group spelling, then source-only refresh above. If still
  absent, retain evidence and investigate; do not widen proxy auth, impersonate
  Laure, create temporary administrators or request re-pairing.
- Simon's phone `usu` must pair to **flakey** (container `claw-simon`), not back
  to Laure's gateway. Wait until he is ready before minting the time-limited
  code. Use `openclaw-admin qr --limited` in `claw-simon`; do not hand off admin
  authority. Steps: "Re-pair after the rename" below.
- Fresh-state brief reconcile still needs an immutable creating-conversation
  binding fix. Simon's live job `66d2d1b5-48d2-45a1-b899-ec86179df374` already has
  the correct binding to `agent:main:main` and passed one real manual delivery.
- Heartbeat remains unchanged: interval runs with no channel skip `no-route`;
  event-driven wakes still work. Laure's prepared 07:00 brief stays disabled.
- Upstream view-only UI still exposes voice/import controls; import was not tested.

---

# Historical one-gateway runbook and deployment evidence

The sections below describe the superseded two-agent placement. Do not use their
restart/deploy commands while the live legacy gateway is protected.

# OpenClaw trial on Yari

## Decision: one gateway, two agents (2026-11-11)

Simon and Laure share this one gateway. Each person has an own agent: `main`
(Simon, persona flakey) and `laure` (persona from her own BOOTSTRAP.md
interview). Each person signs in as themselves through Tailscale and has a
non-admin role limited to the own agent, with `sessions.others: "write"`.
Publishing a conversation shares it with the other person. Admin work happens
only on the command line on Yari. OpenClaw 2026.11.3 has no setting that makes
new conversations start as Draft: the New session page always starts as
"normal". The sidebar's default "My sessions" filter only hides the other
person's conversations. It does not block them. Sign-in uses Tailscale Serve
run outside OpenClaw with `trusted-proxy` auth, not OpenClaw-managed Serve,
because managed Serve needs OpenClaw to have write access to the container's
tailscaled.

On 2026-11-11 Simon chose `sessions.others: "write"` for both roles so agent-created sub-agents can start. He accepted cross-person renames and deletion of already archived ordinary sessions. Neither person can run or send messages through the other person's agent, archive or restore the other person's sessions, re-share them, or fork them. Foreign Drafts remain unreadable. The cap also grants membership in foreign Read-only and Suggest sessions. Scopes and allowed agent lists remain unchanged.

Session tools use `tools.sessions.visibility = "agent"` and `tools.agentToAgent.enabled = false`: each agent can access only its own sessions, including same-agent sub-agents.

Both agents share the research skill in `lib/openclaw-skills/research/SKILL.md`, with at most 8 children per parent and a 900-second timeout per researcher or auditor spawn.
Research scope uses short angle-first child labels and stated-versus-assumed constraints after the final direct answer: pre-spawn skill text, yield acknowledgment, an unsupported system-section override, and an injected workspace AGENTS.md instruction all failed to produce scope text in OpenClaw 2026.11.3.

The gateway has `TasksMax=2048`; the former 256-task limit exhausted under session MCP workers and caused `EAGAIN` on 2026-11-11.
Session MCP runtimes use `mcp.sessionIdleTtlMs=600000` to release idle stdio servers and their supervisors after 10 minutes, on the next minute sweep.
Both model provider entries use `timeoutSeconds=600` for the shared model request and idle watchdog; lower explicit run budgets still apply.

## Placement and boundaries

| Service | Placement | State / address |
| --- | --- | --- |
| OpenClaw | Yari, `containers.openclaw` (nspawn) | `/var/lib/nixos-containers/openclaw` persisted under `/permafrost` |
| Claw overlay | Container's own tailscaled, `tag:claw` | `/var/lib/tailscale` inside the container |
| Home exit node | Rakku | `100.88.212.117` |
| Model front door | Existing ai-gateway on Rakku | `https://ai.hummingbird-lake.ts.net/v1` |
| Control UI | Container loopback 18789, Tailscale Serve 443 | `https://claw.hummingbird-lake.ts.net` |
| MCP Apps sandbox | Container loopback 18790, Serve 8443 | `https://claw.hummingbird-lake.ts.net:8443` |

OpenClaw is untrusted execution. Its dedicated user has no capabilities, strict
filesystem protection, private temporary files, an 8 GiB gateway and container memory cap, and write
access only to its state directory. The container has its own private network
and TUN device. Yari itself keeps Oracle egress for builds. Forgerie stays on Zao.

An inet nftables OUTPUT policy permits only loopback, tailscale0, and the
separate trusted tailscaled UID. All other IPv4 and IPv6 output is dropped.
There is no established-connection bypass. DNS uses Tailscale's resolver, not
Yari's resolver. A loopback-only dnsmasq sends tailnet-name queries to Quad100
and public queries to public resolvers **through the exit node**. Only the
trusted overlay UID gets service-private bootstrap DNS and direct egress.
The OpenClaw service cannot access the host Nix daemon socket, overlay socket,
or source credential mounts; LoadCredential supplies only its own two secrets. Losing the exit node or stopping tailscaled cannot expose an
Oracle fallback route to the OpenClaw user. The overlay daemon alone needs
direct internet access to bootstrap the encrypted overlay.

The tailnet policy must auto-approve exit nodes for `tag:mountainous` and let
that tag mint `tag:claw`. Claw must **not** receive `tag:mountainous`. Its ACL
permits `autogroup:internet:*`, `tag:mountainous:443`, and the front door.
It also permits `tag:claw-tools:443`. The fleet OAuth client, owned by
`tag:mountainous`, may mint `tag:claw-tools`; its tagOwners are
`autogroup:admin` and `tag:mountainous`. Members can reach Claw's 443 and 8443. This policy lives in Tailscale's admin
console, outside this repository. Never relax it to make registration work.

OpenClaw 2026.11.3 uses nix-openclaw's locked npm package, patches and Nix-mode
wrapper. nix-openclaw has no aarch64-linux flake package, so
`lib/openclaw-package.nix` supplies the pinned Node 24.22.1 ARM runtime.
All external release files are flake inputs. The official MCP React clock demo
2.0.4 is a pinned, self-contained release, tested offline over stdio. No runtime
npm installation is needed. No marketplace skills, messaging channels or elevated tools are configured.
The managed headless Chromium browser runs inside the same egress boundary. Calendar and maps use the restricted remote endpoints below.

Security review on 2026-11-10 read all 722 published OpenClaw advisories using
GitHub's cursor pagination. The highest published fixed version was 2026.9.3.
The old GHSA-7xr2-q9vf-x4r5 lists no patched version and a vulnerable range
`<= 2026.2.22`; a release version alone does not prove that old report resolved.
Keep treating the service as hostile and keep its boundaries in place.

## Read-only calendar and maps

Rakku retains Simon's existing loopback-only apps and credential plumbing. Its
usual assistant still uses the complete Google MCP API on port 3171 and maps
on 3172. OpenClaw cannot reach those ports or the assistant endpoint.

| Endpoint (HTTPS 443, `/mcp`) | Upstream | Only exposed tool |
| --- | --- | --- |
| `claw-calendar.hummingbird-lake.ts.net` | `127.0.0.1:3171` | `calendar_busy` |
| `claw-maps.hummingbird-lake.ts.net` | `127.0.0.1:3172` | `travel_time` |
| `claw-family-calendar.hummingbird-lake.ts.net` | `127.0.0.1:3171` | `family_calendar_events` |

`family_calendar_events {day}` reads only Simon's "Family" calendar
(`46g7he3srihobgru1lmoegsar8@group.calendar.google.com`, set as
`GOOGLE_FAMILY_CALENDAR_ID` on the Google app in `modules/hosts/rakku.nix`).
The caller cannot name a calendar; extra arguments are ignored. It returns
title, all-day flag, start, end and location for the local Denver day. It never
returns event IDs, descriptions or attendees, and never reads Personal,
Routine, Interviews or Holidays. It uses Simon's existing Google sign-in.

Each identity has only `tag:claw-tools`, enrolls with the existing fleet OAuth
client, and retains its state in `/var/lib/tsnet-proxy-claw-{calendar,maps,family-calendar}`
under Rakku's persistence volume. The `tsnet-proxy-*` units use tsnet's tailnet
TLS listener, not a LAN or public listener. There is no Funnel. Before serving
an MCP request, local-client WhoIs must identify the actual remote peer;
forwarding headers do not establish identity. Tailnet ACLs still decide which
peers can connect. A non-tailnet peer is refused.

`packages/media-tsnet-proxy/mcp-filter.go` enforces the boundary independently
of OpenClaw. Only POST `/mcp` is accepted. `initialize` advertises only tools;
`notifications/initialized` is acknowledged locally. `tools/list` returns only
allowed descriptors and no pagination cursor. `tools/call` requires an exact
allowed name. Other methods, unknown tools, mail tools, writes, batch requests,
and requests without an ID receive JSON-RPC errors before contacting the app.
The filter canonicalizes requests, strips caller headers and metadata, fixes
the upstream Host header to the app's accepted loopback host, disables redirects,
and limits request/response bodies to 4 MiB and upstream requests to 60 seconds.
Stateless upstream JSON and SSE replies are converted to JSON. These two apps
currently register no views, so **all resources/read and ui:// reads are denied**.
This filter does not support general stateful or streaming MCP servers.

`lib/claw-tools.nix` is the single tool policy used by both endpoints and
OpenClaw's `transport = "streamable-http"` / `toolFilter.include` configuration.
To add a tool, review its real implementation for reads and data exposure first,
then edit that policy and update `checks.claw-tools` and its HTTP boundary tests.
A restricted endpoint must have a nonempty allowlist; an empty list is a type
error. To retire one endpoint, remove its complete policy entry and update the
focused check, rather than clearing its tools.
Do not add a write or mail tool to the calendar endpoint. A future view needs an
explicit exact-URI resource policy and tests; do not allow all `ui://` resources.
Run the focused check, evaluate Rakku and Yari, build Rakku on Unzen, deploy
Rakku first, and prove registration uses only `tag:claw-tools` and Claw can
reach it before deploying Yari. OpenClaw's allowlist is defense in depth, not
the authorization boundary.

To remove these tools, remove Rakku's `claw-tools` layer and the imported remote
servers in `lib/openclaw-container.nix`, retire `modules/claw-tools.nix` (including
its check) and the unused policy, then deploy Yari and Rakku. This stops
the endpoints without changing Simon's assistant or deleting its Google auth.
Retain proxy identity state for rollback. Removing saved identities or tailnet
registrations is separate from stopping the services. Once no endpoint remains,
Simon can remove `tag:claw-tools` from the console ACL. Roll back a failed host
switch with `nixos-rebuild switch --rollback`; do not reboot Rakku.

## Model-native web search MCP

`https://claw-websearch.hummingbird-lake.ts.net/mcp` runs on Rakku with
exactly one tool: `web_search {query: string, max_results?: integer}`. Both
agents can use it through the global streamable-HTTP server and its exact
`toolFilter.include = [ "web_search" ]`. No plugin or outside search vendor
is added. OpenClaw's own native-search custom-base-URL restriction is unchanged.

`modules/claw-websearch.nix` declares this placement using the existing
`media-tsnet-proxy` package. The identity has only `tag:claw-tools`, serves
HTTPS 443, verifies the actual peer with WhoIs, and has no LAN listener or
Funnel. Its saved identity is `/var/lib/tsnet-proxy-claw-websearch/tailnet`
on Rakku's persistence volume. Only MCP initialization, notification of
initialization, tool listing and the exact tool call are supported. Resources,
prompts, unknown tools and batches fail closed.

`packages/media-tsnet-proxy/websearch.go` copies pi-web-access's `openai`
Responses request shape: user `input_text`, `web_search`, required tool choice,
parallel tool calls, `include=["web_search_call.action.sources"]`, `store=false`,
`stream=true`, and `OpenAI-Beta: responses=experimental`. It calls
`http://127.0.0.1:8430/v1/responses` with **gpt-6.1-sol**, the existing
OpenClaw-granted model already verified to run native search. It reuses
`ai-gateway-key-openclaw-yari` as systemd credential `websearch-key`; the key
is not in the store, process arguments or environment. Rotation restarts the
endpoint too. Cost: this credential has the broader existing OpenClaw grant,
not a separate search-only grant; the endpoint fixes both destination and model
and never forwards arbitrary caller headers or Responses fields.

Each search has a **60-second** deadline, no redirects, and a **4 MiB**
request/upstream response limit. Query length is 1–2000 characters;
`max_results` defaults to 5 and accepts integers 1–10. The result is
`{answer, results:[{title,url,snippet}]}`, also supplied as MCP structured
content. Answer length is capped at 16,000 characters, titles at 512, source
URLs at 4096 bytes, and snippets at 300 characters. Sources come only from URL
citation annotations, use HTTP(S), and are deduplicated after removal of
`utm_source=openai`. Snippets are the nearby cited answer text, **not fetched
page excerpts**. The agent can use `web_fetch` for page text. A successful
search without citations returns an empty list, not invented sources.

JSON and completed SSE Responses are accepted. A missing search call,
incomplete/failed response, timeout, excessive response or transport failure
returns a bounded typed tool error. HTTP errors return only their status, not
an upstream body. Any decoded answer or citation containing the credential is
withheld. The adapter does not log requests, responses or upstream errors.
Native search can still return wrong or stale information; citations are
untrusted external content, not an authority boundary.

Run focused `claw-websearch`, `claw-tools`, `openclaw` and `tailnet-names`
checks, evaluate Rakku and Yari, and build the ARM `openclaw-config` check on
Yari. The search check uses a local configurable Responses server for JSON/SSE
citations, no citations, upstream errors, timeout, invalid/oversized responses,
credential reflection and denied arguments/methods. Rebase on the latest
origin/cairn before **every build**. Build Rakku on Unzen, relay its closure
through Zao as root (or signed), and switch only when no other switch runs.
Deploy Rakku first, check every claw-tools endpoint and Laure's agent entry,
then deploy Yari and repeat those checks. Verify a search with sources in a
**new** conversation, never Simon's main one, and compare security audit IDs.

To remove only search, remove Rakku's `claw-websearch` layer and Yari's MCP
server entry, update their focused assertions, then build/deploy Yari and
Rakku. Keep the saved tsnet identity for rollback. Do not delete identity or
conversation state. A failed host switch can use
`nixos-rebuild switch --rollback`; do not reboot Rakku. The reused gateway
key remains required by OpenClaw and must not be removed with this endpoint.

### Web search deployment and verification (2026-11-11 UTC)

- Implementation **`98311bc3`**, runbook **`90a51de9`**, gateway-disable
  regression fix **`a19fb38a`**, all landed on `cairn`. The extra gateway
  check first found that the search rotation hook declared a secret even when
  the gateway was disabled; the fix makes this placement follow gateway
  enablement. The production endpoint and grant do not change with that fix.
- This run deployed Rakku generation **137**, built on **Unzen** and copied
  through **Zao** to root on Rakku:
  `/nix/store/5d1kb6c732z4s207axipy4splfcs3p1w-nixos-system-rakku-26.11.20260923.4975466`.
  A later concurrent Scryer deployment advanced Rakku to **138**
  (`xam6hxw79y3s4gcva57kiwmsz6lcy15b`); search was rechecked afterward.
  No build ran on Rakku and no host rebooted. Before activation, a switch lock
  and process check confirmed no other switch was running.
- Yari's update worker deployed the MCP config with generation **23**:
  `/nix/store/in6jmak1fm9v4i8k8mc5cwnx42rvczvi-nixos-system-yari-26.11.20260923.4975466`.
  This run also built that system and the ARM config check on Yari after a
  fresh rebase. **This run made no Yari switch**, as instructed while the
  update worker owned activation. No second activation was needed.
- `claw-websearch` is online at **100.82.48.71**, with exactly
  **`tag:claw-tools`**. TLS-verified requests from the **OpenClaw user**
  initialized, listed only `web_search`, rejected an unknown tool/resource
  and invalid result count, then returned a live NixOS answer with **2 citation
  sources**. The first certificate handshake failed during initial issuance;
  the next probe passed without disabling TLS checks.
- New conversation
  **`agent:main:explicit:websearch-verification-8100eac4-7f02-4e0c-a15f-6f6c21673d05`**,
  not the main conversation, asked for the latest stable NixOS release.
  Its actual SQLite transcript records
  `dispatch_action` → **`mcp:claw-websearch:claw-websearch__web_search`**, a
  successful result with **3 citation sources**, and **3 `web_fetch` calls**.
  The final answer reports NixOS **26.05 “Yarara”** and cites the official
  release announcement, release schedule and Discourse announcement URLs.
  Run **519a7d19-2744-407c-b507-531fa0825714** completed in **38.011 seconds**,
  with **0 tool failures**. The answer also explicitly rejected one search
  claim it could not confirm in the fetched download-page text. This proves
  the real tool path, not just a model's claim that it searched.
- After the Rakku deployment and again after Yari's worker switch, all five
  claw-tools endpoints listed their intended tools. Scryer retained all five
  of its tools. Laure's entry and both heartbeat definitions remained.
  Both agent policies permit search. **Laure's agent was not run** just for
  verification. Home Assistant, Z-Wave, ai-gateway, all three pi-assistant
  units, Google and maps stayed active with their original start times.
  The search unit has **0 automatic restarts**; a root-only comparison found
  the key in neither its journal, unit, environment nor command line.
- Passed: focused **claw-websearch**, **claw-tools**, **openclaw**,
  **tailnet-names**, **claw-scryer**, **ai-gateway**; Rakku/Yari toplevel
  evaluations; ARM **openclaw-config**; the Unzen package/system build
  (**23 package tests**); search HTTP tests under the Go race detector;
  Go vet/gofmt, Nix formatting and whitespace checks. Tests cover JSON/SSE
  citations, no citations, error, timeout, invalid/oversized response, reflected
  key and denied calls. No aggregate flake check ran.
- Security audit changed from **1 critical / 4 warnings / 1 info** to
  **1 critical / 3 warnings / 1 info**, with **no new check IDs**. The prior
  agent-session isolation fix removed the cross-agent-session warning when
  generation 23 deployed; this was not a search change. Trusted-proxy auth
  remains critical; MCP Apps, private-network opt-in and trusted loopback
  remain warnings. No settings were weakened to silence them.
- Evidence on Zao: `/tmp/claw-websearch-transcript-evidence.json`,
  `/tmp/claw-websearch-conversation-result.json`, before/after audit JSON,
  probe output, build/switch logs and host health files under
  `/tmp/claw-websearch-*`. These checks preceded the update worker's separate
  OpenClaw package update. That worker owns its post-update health check.

## Official interactive demos

The container also runs the official `@modelcontextprotocol/server-budget-allocator`
**2.0.4**, matching the React clock release. The system-monitor demo was
removed on 2026-11-10; its verification below is historical. Their exact npm tarballs and content hashes are flake inputs.
`lib/openclaw-demo.nix` packages the self-contained JavaScript and HTML with the
same ARM Node runtime as the clock. No npm installation, outside service,
credentials, mounts, or additional permissions are needed. The servers use
`--stdio` in declarative `mcp.servers`; neither opens an HTTP listener.

In a **new** Control UI session, ask “help me split a $5,000 monthly budget”. The budget example uses business categories and
synthetic history/benchmarks, not personal finance data. Its initial budget is
$100,000; the visible budget dropdown offers only $50k/$100k/$250k/$500k.
Move an allocation slider to try the card. The removed monitor's polling
failure is recorded in the historical verification below.

To remove only the budget demo, remove `interactiveDemos` and its server merge
from `lib/openclaw-container.nix`, its corresponding input from `flake.nix` and
`flake.lock`, and their names from the focused `openclaw` assertions. Keep the
shared package/test for `basic-react`. Run the focused check, evaluate Yari,
build the ARM config check and system on Yari, land on `cairn`, then deploy Yari.
No tailnet registration or saved service state needs removal. Existing chat
cards may no longer reconnect after removal. A Yari generation rollback restores
the former server configuration without deleting conversations.

### Browser verification (2026-11-10 Denver)

- Implementation `b96f2570` landed on `cairn`. Yari generation **15**:
  `/nix/store/6jkmbk87iim28529as6kxk80iw9rp9lg-nixos-system-yari-26.11.20260923.4975466`.
  Final packages and system were built on Yari with remote builders disabled.
  Container and gateway are active; deployed config validation passed.
- Focused `checks.x86_64-linux.openclaw` passed, after first failing without the
  new server configuration. ARM `openclaw-config` passed. All three packaged
  servers passed offline stdio initialization, tool calls, and HTML resource
  reads. Budget data and repeated monitor stats were checked. Nix formatting,
  Ruff lint/format, whitespace and flake-input checks passed.
- Used a newly paired real Chromium browser and new conversation
  `agent:main:dashboard:d12568e1-d298-44ac-8562-61c4b1590dad`, not the main chat.
  “help me split a $5,000 monthly budget” initially produced only a text table.
  An explicit follow-up requesting the official budget app rendered the card.
  Dragging Marketing from **25% to 44%** updated the chart, dollar allocation
  from **$25k to $44k**, and total from **$100k to $119k** with an over-budget
  warning. The model incorrectly suggested typing a custom budget into the
  preset-only dropdown; no upstream UI changes were made.
- “show me system stats” rendered the System Monitor card with **claw**, Linux
  arm64 and four Neoverse-N1 cores, but **live refresh failed**. Repeated app
  polls received JSON-RPC **-32603**, **“The session's current tool policy does
  not allow this operation.”** The card displays **Error**, blank CPU history,
  memory and uptime. The offline server polling test passes; the live browser
  failure is at OpenClaw's app-call policy boundary. No policy or permission
  changes were made to bypass it. This trial is not a working live monitor.
- Screenshots on Zao: `/tmp/claw/demo-budget.png` (after slider interaction),
  `/tmp/claw/demo-monitor.png` (after repeated failed refreshes). Exact browser
  errors: `/tmp/claw/demo-monitor-errors.json`. Screenshots also contain the
  model's surrounding conversation text. No messages were sent to the main
  conversation. Heartbeat, morning brief, persona, calendar/maps and Rakku
  configuration were not changed.

## Daily morning brief

`morning-brief` runs at **07:00 America/Denver**, every day (`0 7 * * *`,
zero stagger, including DST). Each run is isolated and uses the normal default
model and full workspace persona (flakey). It reads today's `calendar_busy` and
returns one short day plan: a plain why line, calendar busy blocks, real travel
between known coordinates, relevant memory, Denver home weather (39.739, -104.985, America/Denver,
unless an event says otherwise) and
calendar-free windows of at least 45 minutes within 08:00–22:00. It uses the
03:00–03:00 Denver day and skips a duplicate plan found in memory. It says once
that Atlas picks/Today, Logbook recovery and training, wind_down_state, groceries
and overnight Mail are unavailable. It assumes an ordinary day, never invents
tasks or recovery data, and makes no substitute dashboard or external writes.

The declaration is `lib/openclaw-morning-brief.nix`; its prompt is
`lib/openclaw-morning-brief.md`. Change the cron expression or zone in the former,
or edit the latter, then run the focused `openclaw` check, evaluate Yari, land,
and deploy Yari as below. Do not edit this job in the UI: deployment restores
the declared definition, including enablement.

OpenClaw persists jobs in gateway SQLite state, not the read-only application
config. The container's `openclaw-morning-brief.service` oneshot uses the root-only
admin wrapper and `gateway call cron.add` to upsert declaration key
`mountainous:morning-brief`, then `cron.update` to converge all authored fields.
OpenClaw 2026.11.3's declaration API alone preserves description and session
routing edits; the second call restores those too. Repeated starts keep the
job ID and history and do not duplicate it. If either call fails, the unit retries.
It starts after the gateway, retries startup failures, and restarts with the
gateway. It does not run the brief during reconciliation.

Delivery is `announce`, bound to `agent:main:main`, with **no external route**.
OpenClaw commits the final response as an assistant message in the main Control
UI conversation; the private execution transcript stays isolated. No messaging
channel or webhook is added. The API captures that conversation's generation.
If Simon explicitly resets/deletes the creating conversation and delivery then
reports a stale binding, remove the job with `cron rm JOB_ID` and restart the
oneshot to bind a replacement to the current main conversation. Normal container
restarts keep the binding and job history.

As root on Yari:

```sh
nixos-container run openclaw -- openclaw-admin cron list --all --json
nixos-container run openclaw -- openclaw-admin cron get JOB_ID
nixos-container run openclaw -- openclaw-admin cron run JOB_ID --wait
nixos-container run openclaw -- openclaw-admin cron runs JOB_ID --limit 1
nixos-container run openclaw -- systemctl restart openclaw-morning-brief
```

To remove only this brief, first remove the `openclaw-morning-brief` unit and
its declaration from `lib/openclaw-container.nix`, remove the unused prompt,
definition and focused test assertions, then deploy Yari. Remove the persisted
job with `nixos-container run openclaw -- openclaw-admin cron rm JOB_ID`.
Removing the job before removing the unit recreates it at the next reconciliation.
This does not delete Simon's conversation or other jobs. For a temporary pause,
`cron disable JOB_ID` works until the next reconciliation; a durable pause sets
`enabled = false` in the declaration and deploys it.

## Morning brief deployment evidence (2026-11-10 Denver)

- Implementation: `24c27a90`, with full-field reconciliation fix `5c530c50`,
  landed on `cairn`. Yari generation **14**:
  `/nix/store/jhpqj619na4dx2xl4zc7whmxi091nkx5-nixos-system-yari-26.11.20260923.4975466`.
  No host reboot. The container gateway and reconciliation unit are active.
- Job ID: `df3d8216-a284-4086-a127-3890019d5cdb`. Exactly one declaration exists,
  enabled, isolated, `0 7 * * *`, `America/Denver`, stagger 0. Next run:
  2026-11-11 07:00 Denver / 14:00 UTC. The delivery preview says
  `announce -> creating conversation`, with no external channel route.
- Manual run at **17:52:44 Denver**, finished in **18.602 seconds**:
  `status: ok`, `completionStatus: succeeded`, `deliveryStatus: delivered`.
  The recorded tool call used `calendar_busy {day:"2026-11-10"}`. No maps call.
  The brief reported **0 busy events today**, **1 calendar-free window,
  08:00–22:00 (14 hours)**, and an open-calendar day. It asked **0 questions**.
  It also noted the **1 next-day event, 12:00–14:00**, incorrectly returned by
  the known calendar boundary bug. The prompt contains no bug workaround.
  Re-run after the separate calendar fix to verify a clean brief.
- `chat.history` for **`agent:main:main`** returned the exact brief as an
  assistant message, model `automation-result`, tagged with this job ID.
  This verifies durable main-session delivery, not just a run-history summary.
- Live drift test: disabled the job and changed its description, execution
  target, schedule and prompt. Restarting the oneshot restored all five,
  retained the same ID, and left exactly one job. This exposed the upstream
  partial-declaration behavior; `cron.update` fixed it.
- Restarted **`container@openclaw`**, then rechecked the same ID, definition,
  one recorded manual run, and active gateway/reconciliation units. Startup
  connection races recovered through the unit's configured retry.
- Checks passed: focused `checks.x86_64-linux.openclaw`, Yari toplevel
  evaluation, ARM `openclaw-config` build on Yari, full Yari system build,
  Nix formatting, whitespace validation and `scripts/check-flake-inputs.sh`.
  `writeShellApplication` also checked the reconciliation shell script during
  the system build. No aggregate flake check ran.
- Roll back the system with `nixos-rebuild switch --rollback` on Yari. Jobs are
  persistent service state: rollback does not remove this job. To stop it too,
  disable/remove its persisted job after the older unit no longer recreates it.

## Credentials

`ai-gateway-key-openclaw-yari` is a random 32-byte hex key with matching encrypted
copies in `secrets/hosts/rakku.yaml` and `secrets/hosts/yari.yaml`. Each file is
readable only by its host and Simon's master key. Yari cannot decrypt Rakku's
other secrets. Rotate both copies together with `sops set` and the converted
master identity (`scripts/secrets` documents conversion). Never print values.

The grant `openclaw@yari` permits chat_completions, responses, models and images,
with claude-opus-5-5 (default), gpt-6.1-sol, gemini-3.8-flash-high,
gemini-3.1-flash-image and gpt-image-2. Its required cap field is
USD 1,000,000,000/month (effectively unlimited); the remote account owns the cap.
Its rate stays 300 requests/minute. The gateway's existing prepaid
provider exemption still applies; these three models use subscription routes.
No Jev, systemone or speech grant exists.

The separate `openclaw-gateway-token` exists only in Yari's encrypted host file.
Systemd passes both secrets through LoadCredential and the launcher exports
runtime environment variables. The Nix store contains only environment variable
references, never values. Host secret files are mounted read-only into the
container and are root-only. The registration OAuth secret is not readable by
OpenClaw. Control UI uses OpenClaw token auth, plus device pairing; Serve does
not bypass auth. Retrieve the token privately as root from
`/run/secrets/openclaw-gateway-token` on Yari, then paste it into the UI's token
field. Approve the browser's pending pairing with
`nixos-container run openclaw -- openclaw-admin devices approve REQUEST_ID`.
`openclaw-admin` is a root-only credential-loading wrapper that runs the real
CLI as the service user. It also supports `devices list` and `security audit`. Do not put tokens in URLs.

## Build and deploy

Use a clean checkout of `cairn`, and `ssh -F /dev/null` for every host. Never run
`nix flake check`. Run the focused checks sequentially:

```sh
nix build .#checks.x86_64-linux.claw-tools --no-link --max-jobs 1 --cores 1
nix build .#checks.x86_64-linux.openclaw --no-link --max-jobs 1 --cores 1
nix build .#checks.x86_64-linux.home-exit-node --no-link --max-jobs 1 --cores 1
nix build .#checks.x86_64-linux.ai-gateway --no-link --max-jobs 1 --cores 1
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
```

Build Yari on Yari, including `checks.aarch64-linux.openclaw-config`. Build
Unzen and Rakku on Unzen. Rakku must never build. `nixos-rebuild switch` with
`--build-host` and `--target-host` can copy evaluated derivations to these hosts.
For subsequent deploys from Zao (Unzen must already be approved):

```sh
export NIX_SSHOPTS='-F /dev/null'
nixos-rebuild switch --flake .#unzen --build-host root@unzen --target-host root@unzen
nixos-rebuild switch --flake .#rakku --build-host root@unzen --target-host root@rakku
nixos-rebuild switch --flake .#yari --build-host root@yari --target-host root@yari
```

Alternatively, copy with `nix copy --derivation --to ssh-ng://root@HOST DRV`,
then use a copied Nix-shebang script on that host to build `DRV^*`, set its
system profile, and run `bin/switch-to-configuration switch`. Keep build/deploy
scripts local, copy them and run them; do not embed multi-step SSH commands.

Switch right after the build. If a switch must wait, check two things before it
runs. `readlink -f /run/current-system` on the host must still print the system
that the build replaced, and `origin/cairn` must not have moved. Another session
can switch the host during the wait, and a system built before that switch
undoes it. On 2026-11-11 Yari generation 34 replaced generation 33 with an
older build for 17 minutes for this reason.

Deploy Rakku first. Confirm Rakku is advertised and approved (ExitNodeOption
true in another node's `tailscale status --json`). Deploy Yari to select Rakku, then deploy Unzen and explicitly clear its saved
exit advertisement with `tailscale set --advertise-exit-node=false`. Root SSH works on these hosts; the simon account on Yari and Unzen needs
a sudo password. Do not reboot Rakku. Confirm Home Assistant, Z-Wave,
ai-gateway and all three pi-assistant units remain active after switching.

## Stop limits

A Yari system switch that changes the container stops
`container@openclaw.service` and starts it again. Three settings decide how
long that stop can take.

| Unit | Setting | Value | Reason |
| --- | --- | --- | --- |
| `openclaw-gateway.service`, in the container | `KillMode` | `mixed` | OpenClaw's `docs/gateway/restart-recovery.md` requires it. Only the gateway gets the stop signal. systemd kills the remaining children when the gateway exits. |
| `openclaw-gateway.service`, in the container | `TimeoutStopSec` | 35 s | The gateway reads this value and sets its own deadline 5 s before it. |
| `container@openclaw.service`, on Yari | `TimeoutStopSec` | 180 s | Must be longer than the container needs to stop itself. |

The gateway divides its limit. At 35 s, active runs get about 20 s to finish,
cleanup gets 10 s, and 5 s stay as margin. That is one full ordinary stop.
OpenClaw documents 330 s for its own units. Do not use that value here. It
pays for a 315 s drain that only a requested restart (`openclaw gateway
restart`) uses, and this deployment restarts the gateway through systemd.

`checks.openclaw` requires the host limit to be at least the gateway limit
plus 90 s. The 90 s is systemd's default for one more unit that stops after
the gateway, such as tailscaled.

A healthy gateway stops in less than 1 second, and the container stops in 2 to
4 seconds. On 2026-11-11 the `plugin-services` close step of OpenClaw 2026.11.3
did not return in two stops that followed a research run with sub-agents. Both
stops ran under the old `KillMode=control-group`, and both gateways had started
the managed browser. The gateway then waits until its deadline, writes a
stability bundle under `/var/lib/openclaw/logs/stability/`, and its watchdog
kills it 2 s later. At a 35 s limit that stop takes about 32 s. Under
`KillMode=mixed` the same conditions stop cleanly: see "Stop after a research
run" below. Which plugin service hung under `control-group` is not proven.

To read how the last stops went, run these on Yari:

```sh
journalctl -u container@openclaw.service --utc -o short-precise \
  --grep 'Stopping Container|Stopped Container|stop-sigterm|unix-export'
grep -E 'shutdown budget|completed cleanly|shutdown deadline reached' \
  /var/lib/nixos-containers/openclaw/var/lib/openclaw/logs/gateway.log | tail
```

`completed cleanly in N ms` is a healthy stop. `shutdown deadline reached`
lists the close steps that did not finish.

If the host limit expires, systemd logs `State 'stop-sigterm' timed out.
Killing.` and kills systemd-nspawn. systemd-nspawn 261 then leaves
`/run/systemd/nspawn/openclaw/unix-export` mounted. The next start fails once
with `Mount point ... exists already, refusing`, and `switch-to-configuration`
returns exit 4. systemd then restarts the unit, and that start succeeds. Before
you treat exit 4 as a failed deploy, run `systemctl is-active
container@openclaw`. If it prints `active`, do not repeat the switch and do not
roll back.

### Stop limits evidence (2026-11-11 UTC)

Implementation: `fc09676d`, landed on `cairn`. Yari has run it since generation
31 (20:28). The final system is generation **35**,
`/nix/store/ip7dx262q4x95d1nvvljgcw4ys4nw1a6-nixos-system-yari-26.11.20260923.4975466`,
the build of `715927bc`.

All times come from `journalctl -u container@openclaw.service` on Yari, the
container's own journal, and the gateway's `gateway.log`.

| Stop | Limits, gateway / host | Gateway | Container stop | Result |
| --- | --- | --- | --- | --- |
| 22 container stops and 28 gateway stops, 10 Nov 20:56 to 11 Nov 18:02 | 90 s / 90 s | `completed cleanly` in 0.15 to 0.55 s | 2.2 to 4.2 s | Normal |
| 18:23:14, after a research run | 90 s / 90 s | `shutdown deadline reached` after its 84.8 s budget, killed by its watchdog 87.3 s into the stop | Host limit expired at 90.18 s | SIGKILL, stale mount, one failed start, switch exit 4. Ready at 18:25:31 |
| 19:07:53, 25 minutes after a research run | 90 s / 90 s | `shutdown deadline reached` after its 84.8 s budget, killed 87.4 s into the stop | 89.75 s | Switch exit 0, with 0.25 s to spare |
| 20:49:35 | 35 s / 180 s | `completed cleanly in 383ms` | 3.07 s | Normal |
| 21:33:17 | 35 s / 180 s | `completed cleanly in 217ms` | 2.92 s | Normal |
| 22:13:39 | 35 s / 180 s | `completed cleanly in 241ms`, with 8 remote MCP sessions open | 6.17 s | Normal |
| 22:31:08 | 35 s / 180 s | `completed cleanly in 295ms` | 3.19 s | Normal |

Both slow stops listed the same pending close steps: `shutdown.gateway-close`,
`restart.close.plugin-services` and `restart.close.cleanup-work`. Both wrote a
`gateway.stop_shutdown_timeout` stability bundle. In the first one the host
limit expired 8 ms after the container logged `Shutting down`.

Since the change the gateway logs this line at each start:
`shutdown budget at startup: drain=20000ms shutdown=30000ms reserve=10000ms
exitMargin=5000ms; source=systemd system openclaw-gateway.service
TimeoutStopUSec=35000ms`. On generation 35, `systemctl show` prints
`TimeoutStopUSec=3min` for the container unit, and `TimeoutStopUSec=35s` and
`KillMode=mixed` for the gateway unit.

**No stop has hung since the change.** The 32 s bound for a hung close step
comes from OpenClaw's code and the systemd limit. No live stop has exercised it.
"Stop after a research run" below tests whether `KillMode=mixed` removes the
hang. Since `2b895b74`,
idle session MCP runtimes close after 10 minutes, so the gateway that stopped at
22:13:13, 28 minutes after its last sub-agent run, had no remote MCP session
open.

The weekly updater restarts only the gateway, through `openclaw-profile-control
restart-and-check`. That uses the same stop. Three runs of the controller on
this day took 25 to 27 s with a healthy stop. A hung close step adds about 32 s,
which is inside the updater's 300 s activation limit.

Checks: `checks.x86_64-linux.openclaw` failed before the change (`attribute
'KillMode' missing`) and passes after it. Yari's system built on Yari with
builders disabled. After generation 35: container and gateway active, no failed
unit on Yari or in the container, `/healthz` and `/` return 200, brief
`df3d8216-a284-4086-a127-3890019d5cdb` unchanged at 07:00 America/Denver, roles
and Laure's entry unchanged, and `tools/list` passes for all six `claw-*`
endpoints.

Generation 34 was a mistake. It was the build of `fc09676d`, switched at 22:13
after a two-hour wait for a quiet gateway, over generation 33 (`715927bc`).
Generation 35 restored the build of `715927bc` at 22:31. No sub-agent ran in
those 17 minutes.

To remove the stop limits, revert `fc09676d` and deploy. Do not use
`nixos-rebuild switch --rollback` from generation 35 for this: generation 34
lacks three later commits, and generation 30 predates all four.

Local evidence on Zao: `/tmp/yari-claw-stop/`.

### Stop after a research run (2026-11-12 UTC)

The hang did not come back under `KillMode=mixed`. Two stops right after a
research run with sub-agents completed cleanly while the managed browser still
ran. One was the weekly updater's gateway restart. The other was a container
restart, which is the stop that a system switch does.

Each test sent one research request to a new test conversation on `main`
(`agent:main:explicit:claw-stop-hang-repro-*`, never `agent:main:main`) with
`openclaw-admin agent`. The request told every researcher to open one source
with the browser tool, because both hung gateways had started the browser. Each
run had three researchers and one auditor and ended with a final answer.

| Stop (UTC) | Command | After the run ended | Chromium processes | Gateway | Container stop |
| --- | --- | --- | --- | --- | --- |
| 00:44:42 | `openclaw-profile-control restart-and-check` | 49 s | 13 | `completed cleanly in 833ms` | Not stopped. The controller took 28.4 s |
| 01:06:39 | `systemctl restart container@openclaw` | 8 s | 14 | `completed cleanly in 531ms` | 3.21 s |

The plugin services stop one after the other, in reverse start order, and
without a deadline: `openai/decisions:openai`,
`memory-core/memory-core-standing-intents`, `memory-core/memory-core-dreaming`,
`memory-core/memory-core-index`, `browser/browser-control`. In both tests the
first four returned in 0 to 9 ms. `browser-control` returned in 225 ms and
159 ms. In the second test the trace shows it closed the `openclaw` browser
profile in 155 ms. One second after SIGTERM the gateway cgroup had no Chromium
process in either test.

`OPENCLAW_GATEWAY_RESTART_TRACE=1` times only whole close steps, so it cannot
name a plugin service. For these tests a temporary preload logged each plugin
service stop. A runtime drop-in under the container's
`/run/systemd/system/openclaw-gateway.service.d/` set
`OPENCLAW_GATEWAY_RESTART_TRACE=1` and
`NODE_OPTIONS=--import=/run/openclaw-diag/stop-trace.mjs`. The preload uses
`registerHooks` from `node:module` to add log calls to the 2026.11.3 chunk files
and writes `/var/lib/openclaw/logs/stop-trace.log`. The container restart
cleared the drop-in and the preload, and the log was moved to Zao. To use the
preload again, take it from `/tmp/claw-hang/stop-trace.mjs` on Zao. Its patches
name hashed chunk files, so a new OpenClaw release needs new patches.

The history in `gateway.log` and the host journal, 10 Nov 20:56 to 12 Nov
01:07, adds these facts:

- Four container stops under `control-group` came from gateways that had
  started the browser. The stops at 05:47:38 and 06:11:40 on 11 Nov were clean.
  The stops at 18:23:14 and 19:07:53 hung. A running browser alone did not
  cause the hang. Why the two earlier stops were clean is not known.
- In both hung stops the stdio MCP servers logged `closed; next request
  reconnects` within 90 ms of SIGTERM. The remote `claw-*` servers logged it
  1.6 to 2.7 s after SIGTERM. Inferred: `control-group` killed the gateway's children at once,
  and the remote connections dropped when the container's network units
  stopped. These lines are an effect of the stop, not its cause. Stops under
  `mixed` log none of them, because the gateway closes its own children.
- Inferred, not proven: `browser-control` was the service that did not return.
  Of the five plugin services, only `browser-control` owned processes in the
  gateway cgroup in these tests (Chromium), and it stops last. Under
  `control-group`, systemd sent SIGTERM to Chromium before `browser-control`
  tried to close it.

No test ran `control-group` again to prove this. That test would hang the live
gateway for about 32 s, and OpenClaw's `docs/gateway/restart-recovery.md`
requires `mixed`. For the same reason no issue went to openclaw/openclaw. Not
tested: a research run that starts the browser without being told to, and a
stop after 10 or more idle minutes.

Before you attach a `gateway.stop_shutdown_timeout` stability bundle to a
public report, remove the session keys. `snapshot.events[].source` holds values
such as `session:agent:main:main` and `session:agent:main:explicit:<name>`. The
19:09 bundle on 2026-11-11 had 24 of them. Its host name is already
`<redacted-hostname>`, and it has no message text, e-mail address or URL.

Local evidence on Zao: `/tmp/claw-hang/`.

## Verify

Use `nixos-container run openclaw -- ...` or `machinectl shell` on Yari. Run
network probes as the OpenClaw user, not the trusted tailscaled UID. Check:

- Rakku and container `curl -4 https://ifconfig.me` return the same home IP;
  Yari's own probe still returns Oracle's IP.
- After stopping the container's tailscaled, an OpenClaw-user curl with a
  known public destination (`--resolve` to avoid a DNS-only failure) fails.
  Restore tailscaled and its `claw-tailnet` unit immediately.
- `/v1/models` returns 401 without a key, and succeeds with the OpenClaw key.
  Make one short completion using the default model.
- TCP to Rakku:22 must fail. Probe HTTPS to a tag:mountainous service; the saved
  policy is intended to allow it. See the current reachability caveat below.
- From Zao, load the Control UI, pair it, send a short chat, and capture a
  screenshot. Call the basic-react clock tool to inspect its MCP App.
- Run `openclaw security audit`, record its warnings and `free -m` on Yari.
  MCP Apps being enabled is an expected upstream security warning.

The application config is declarative and read-only. UI changes to config are
not the source of truth; edit this flake and deploy instead.

## Roll back / remove

For a failed switch, run `nixos-rebuild switch --rollback` on that host. Do not
reboot Rakku. A previous Yari generation stops the new container; a previous
Rakku generation revokes its grant. A previous Rakku generation removes the
unit but the Tailscale advertisement is a saved preference: explicitly run
`tailscale set --advertise-exit-node=false` when rolling it back. Do not clear
Tailscale state or service state during rollback.

To remove the trial completely: remove Yari's `openclaw` layer and its two
secret entries, remove the grant from ai-gateway and the encrypted copies,
build and deploy Yari and Rakku, then remove the unused flake inputs and code.
Disable Rakku's exit advertisement before removing its layer and deploy Rakku.
Remove the Claw node and `tag:claw` policy from Tailscale admin. Retain a backup
of `/permafrost/var/lib/nixos-containers/openclaw` until Simon approves deleting
its conversations and overlay identity. Removing that state is a separate,
irreversible data-deletion decision, not part of a routine rollback.

## Deployment evidence (2026-11-10)

- Initial verified generations: Unzen 54, Rakku 127, Yari 10.
- OpenClaw-user egress and Unzen: `38.175.187.81`; Yari: `129.146.97.70`.
- With the exit selection cleared, and separately with the container overlay
  daemon stopped, a previously successful public HTTPS probe with DNS bypassed
  timed out. Restoring the overlay restored the home IP. Rakku:22 and assistant
  HTTPS both timed out from Claw. Claw's node has only `tag:claw`.
- Front door: unauthenticated models returned 401; authenticated models returned
  exactly the three granted models. A short Opus completion and a Control UI
  chat succeeded. Existing HA, Z-Wave and assistant processes did not restart.
- The official React clock rendered in a double iframe whose outer URL uses
  `:8443/mcp-app-sandbox`. The model incorrectly claimed it could not display
  the app, but the browser did display it; trust the rendered view, not that text.
- Security audit: 0 critical, 1 expected MCP Apps warning, 1 information entry.
  After chat and MCP use: 3,090 MiB host memory used, 20,873 MiB available;
  gateway cgroup 1,938,919,424 bytes, peak 2,131,668,992 bytes, limit 4 GiB,
  zero service restarts. The optional `--deep` audit adds a probe warning:
  `missing scope: operator.read`. The CLI deep probe could not read
  gateway status; do not weaken gateway auth to silence it. Browser device pairing,
  authenticated chat and normal audit were verified separately. Screenshots: `/tmp/claw/control-chat.png` and
  `/tmp/claw/mcp-app.png` on Zao; probes and health logs are beside them.

## Calendar/maps deployment evidence (2026-11-10)

- Implementation: `1567c5b6` on `cairn`. Rakku generation **128**
  (`sjs93jn50sv77ly3yccp6afyc3isgn3h`), built on Unzen; Yari generation **12**
  (`l6pq2sr4qxkb343d1l9a12zsr4xgfr30`), built on Yari. No host reboot.
- `checks.x86_64-linux.claw-tools`: both HTTP boundary tests passed. Denied
  mail/write/unknown tool calls never reached the upstream; listings were
  filtered, batch/resource requests were denied, and an unverified peer with
  spoofed forwarding headers received HTTP 403. The packaged proxy's full
  nine tests passed, including enrollment and saved-identity checks. Focused
  `openclaw` and `tailnet-names` checks passed. ARM `openclaw-config` was
  rechecked on Yari; deployed config also passed real CLI validation.
- Home Assistant, Z-Wave, ai-gateway, all three pi-assistant units, and both
  personal apps remained active with **unchanged start times**. Simon's own
  loopback Google endpoint still listed all 11 original tools. Only tsnet
  proxy processes restarted during Rakku's switch.
- Yari's deployed config contains both remote servers and matching include
  lists. The gateway is active. Security audit: **0 critical, 1 expected MCP
  Apps warning, 1 information**. Rakku `100.88.212.117:22` still timed out from
  the OpenClaw user after deployment.
- The console policy was then saved. Both nodes registered with only
  `tag:claw-tools`: calendar `100.117.142.98`, maps `100.107.76.69`. From the
  **OpenClaw user** in the container, initialize succeeded; tools/list returned
  exactly `calendar_busy` / `travel_time`; mail_list and an unlisted name each
  received JSON-RPC `-32601` on both endpoints. Resource reads also received
  `-32601`. Rakku:22 still timed out after those checks. Initial certificate
  issuance exceeded the first 20-second probe; subsequent verified TLS calls
  succeeded without bypassing certificate validation.
- OpenClaw session `maps-check` called the real
  `mcp:claw-maps:claw-maps__travel_time` through `dispatch_action`, with a
  successful tool result. Answer: **4 minutes, 2.202 km driving**, Denver Union
  Station `(39.75305556, -105)` to Colorado State Capitol
  `(39.7392321, -104.9848677)`. Both coordinates came from Wikipedia's coordinate
  API, not invented places. This is a Valhalla baseline, not live traffic.
- **Calendar remains blocked by missing Google authorization, not the tailnet.**
  OpenClaw session `calendar-check` called the real calendar tool and received
  `not_authorised: Google is not connected.` No busy blocks were invented.
  The Google app's persisted gogcli config has no credential/token files, and
  its pre-change journal already had not_authorised poll failures. The earlier
  Google/maps runbook also states real sign-in was never done. Simon's own
  assistant did not previously have working Google authorization either.
- Keyring credentials, API credentials and permissions are separate: the sops
  keyring password exists, but that alone does not authorize a Google account.
  `gog` 0.11.0 **requires your own Google Cloud Desktop OAuth client JSON**
  (`client_id` and `client_secret`); it does not supply a shared client.
  Verified against the installed 0.11.0 `auth credentials set --help`,
  `auth add --help`, and the upstream
  [v0.11.0 README](https://github.com/openclaw/gogcli/blob/v0.11.0/README.md#1-get-oauth2-credentials).
- **Superseded handoff:** the flake now installs `claw-google-auth`, using
  the SOPS-managed Desktop client. Use the current
  [Google sign-in runbook](assistant-google-maps.md#sign-in-or-sign-in-again),
  not the temporary launcher described below. The remaining notes describe
  the earlier deployment's evidence, before that client was provisioned.
- A prepared one-run browser wizard was installed on Rakku at
  `/var/tmp/claw-google-auth/start` (launcher) and
  `/var/tmp/claw-google-auth/wizard` (unmodified wizard library plus stages).
  **No OAuth step has been run.** Simon runs:

  ```sh
  ssh -F /dev/null -t simonwjackson@rakku sudo /var/tmp/claw-google-auth/start
  ```

  The launcher runs the wizard as `pi-simon`, with HOME set to the Google app
  and WorkingDirectory set to its persisted `.config/gogcli`. Systemd loads
  the same `gog-keyring-password` credential as the app. The browser stages
  enable Calendar API, configure consent/test user, capture Desktop client
  ID/secret, then use `gog auth add --services calendar --readonly --remote`
  steps 1 and 2. Secrets and the full callback URL use hidden input. It asks
  readiness before starting the short-lived authorization URL. No Gmail or
  calendar write scope is requested. External apps left in Testing can have
  seven-day refresh-token expiry; the wizard does not publish the app.

  After browser completion, the launcher restarts only the Google app,
  compares real calendar_busy blocks from loopback and claw-calendar, prints
  only Denver start/end times, and runs `assistant ask` through Simon's normal
  local CLI/RPC. With one stored account, gog auto-selects it, so no
  GOG_ACCOUNT config change is needed. If more accounts are added, select the
  account through mountainous's `apps.google.environment.GOG_ACCOUNT`, not an
  unmanaged systemd override. The existing Gmail poll remains unauthorized
  until Gmail is separately connected; it does not prevent calendar reads.
- Wizard checks: bash syntax passed; shellcheck passed excluding the standard
  unchanged library's unused RED variable warning; Python syntax passed;
  verification helper JSON/SSE/error behavior passed against a real local HTTP
  test endpoint. Rakku's `start --check` passed without starting OAuth. The
  interactive browser flow and post-sign-in real-data checks are prepared but
  **not yet run**. Wizard files are ephemeral; actual OAuth state is persisted.
- Final Rakku service start times still match the baseline. Yari's gateway is
  active with zero automatic restarts and still has only the expected audit
  warning. Local evidence: `/tmp/claw-tools-evidence/` on Zao. Copied scripts
  `/tmp/claw-tools-probe`, `/tmp/claw-yari-health` and `/tmp/claw-session-trace`
  on Yari support repeating network and actual-tool-call checks. No raw mail,
  event titles or credential values are recorded in this runbook.

## Account-scoped Scryer endpoints

Rakku serves `https://claw-scryer-simon.hummingbird-lake.ts.net/mcp` as
`simon` and `https://claw-scryer-laure.hummingbird-lake.ts.net/mcp` as `laure`.
Each exposes `scryer_graphql` and the four MCP App tools described below.
Main denies `claw-scryer-laure__*`; laure denies `claw-scryer-simon__*`.
The exact-name session allowlist contains both sets of app tools, with the
per-agent deny applied on top. No old `claw-scryer` server remains.

`modules/claw-scryer.nix` uses the existing per-person sops secrets.
`modules/tailnet-names.nix` passes them with systemd LoadCredential and `%d`,
never the Nix store or environment. Secret rotation restarts the matching
proxy as well as the existing Pi assistant. Neither proxy loads the admin
password. Simon's Scryer account still has app-wide permissions and can see
Laure's libraries; this change does not alter accounts or grants. The shared
skill forbids acting on the other person's library. Per-agent tool denial is
not network isolation between mutually untrusted agents in one container.

Both new tsnet names enroll with the existing fleet OAuth client and
`tag:claw-tools`; no stored join key or ACL change is needed. Each keeps its
own persisted state. The old admin unit is removed, not its saved identity.
No agent has an admin endpoint or password. Do not delete saved tsnet state
as part of deployment or rollback.

The native adapter defaults `-scryer-username` to `admin` for compatibility;
these two units explicitly select their person. Tokens stay in process memory,
with `persistSession: false`; login response bodies are never returned.
Credential reflections are withheld. Only HTTP 401 retries once; after a
transport error, read state before retrying a mutation. Requests and replies
are bounded to 4 MiB, upstream requests to 30 seconds and tool calls to 60.
Redirects are disabled. HTTPS peer verification, no LAN listener and no Funnel
remain unchanged.

Library choice is read from Scryer, not written into the endpoint: the code
holds no library or person name (a Go test and a view test both check this).
A card offers the libraries the signed-in account holds an explicit
`MANAGE_TITLES` grant on; an account with no grants (a plain admin on a simple
install) gets every library it can manage. So Simon's card offers his own and
the shared libraries, not Laure's, although his account is an app admin.
The card proposes one library, in this order: the one the request named
(`scryer_search {library: "…"}`, words from a library name, which the agent
passes when the person says who it is for), the one named after the account,
Scryer's default for that kind, the only one. So that the agent can name a
library at the first try, `tools/list` appends the account's current library
names to `scryer_search`'s description (read from Scryer, kept for a minute,
left out if Scryer does not answer in 5 seconds). With several libraries, **Add**
and **Monitor** open a panel with the proposal selected, and the confirm
button names the library. With one library (Anime here) the card does not ask.
`scryer_add` takes that `libraryId`; without one it adds only when the answer
is unambiguous, and else refuses and lists the choices. An id the account was
not granted fails without a write. Cards show `libraryName`.
Existing titles are shown in their current library, never moved by an add.
See the Owners section of `docs/media-scryer.md` for routing words.

Validate focused `claw-scryer`, `tailnet-names` and `openclaw` checks, plus
ARM `openclaw-config`. Never run an aggregate flake check. Rakku requires a
system switch. Yari's endpoint, tool policy and skill changes also require a
**system switch**: the independent `openclaw` deploy-rs app profile carries
only the package, not these settings. Retain that profile and verify the
`openclaw-profile-control restart-and-check` health gate after deployment.
Do not replace the signed package profile just to change configuration.

Rollback both affected systems with `nixos-rebuild switch --rollback`, after
checking the previous generation's contents. This re-enables the old admin
endpoint and is a security regression; use only to recover service. Do not
reboot or remove any Scryer, OpenClaw or tsnet state.

### Library choice deployment evidence (2026-11-12 UTC)

- Commits `58b7dcd2` (library choice, `setTitleMonitored` fix, short model
  text) and `3b685dec` (library names in the tool description) on `cairn`.
  Rakku generations **141** (`7r4jii5l`) and **142** (`w3filqik`), built on
  Unzen and copied through Zao; only `media-tsnet-proxy` changed, all tsnet
  proxies restarted, Home Assistant, ai-gateway and the pi-assistants did not.
  Yari generation **36** (`gf7wxfby`, skill text only, no package change), built
  on Yari; `openclaw-profile-control restart-and-check` passed afterwards.
- Passed: Go tests under the race detector, the `claw-scryer` check, the x86
  `openclaw` evaluation, ARM `openclaw-config`, and the view's 14 Node tests.
- Live, read-only, as each account: simon is offered Simon and Family libraries
  (not Laure's, although his account can manage them), laure is offered Laure
  and Family; each gets the own library proposed, `library: "family"` proposes
  Family, a hint that names no library is reported, and Anime has one choice.
- In a new Draft conversation of `main`: "get Paddington 2 for the kids" made
  one `scryer_search` with the family hint. The card's Add panel showed Family
  Movies selected, Simon Movies as the other choice, and the button "Add to
  Family Movies". The button was not pressed: an add is undone only by a
  delete. No title was added and nothing in Scryer changed.
- During the test another session restarted the gateway and then the container.
  After a restart OpenClaw shows old cards as "Send a message to interact
  again"; the next reply draws a working card.

### Account endpoints deployment evidence (2026-11-11 UTC)

- Commit `b0b6f323` on `cairn`. Rakku generation **140**
  (`vzfy3dp1…-nixos-system-rakku`), switched with `nixos-rebuild --target-host`;
  the closure diff was only the three tsnet unit changes. Yari generation
  **24** (`fvlmsysl…-nixos-system-yari`), built on Yari with builders off; the
  closure diff had no package changes. The app profile stayed at generation 1;
  `openclaw-profile-control restart-and-check` passed afterwards.
- Both new nodes enrolled with `tag:claw-tools`. The first TLS handshakes
  timed out while certificates were issued, then passed.
- From Zao and from the container's openclaw user, `{me{username}}` returned
  `simon` and `laure`. `libraries(permission: MANAGE_TITLES)`: simon gets
  Simon, Laure and Family Movies/Series and Anime; laure gets Laure and Family
  Movies/Series and Anime. The old `claw-scryer` name timed out (no listener).
  `scryer_search "Dune"` returned 16 results on each endpoint.
- A new `main` session (`agent:main:explicit:scryer-accounts-check-8c076a39`)
  called `claw-scryer-simon__scryer_search`; its effective tools hold only
  `claw-scryer-simon__*`. Laure's agent was checked by config only (deny
  `claw-scryer-simon__*`), so her first run stays hers.
- No title was added live. Add routing is covered by Go tests and view tests.

The evidence below records historical admin deployments; it does not describe
the current account wiring.

### Scryer deployment evidence (2026-11-10 Denver)

- Implementation **`a57894843a9f1efc56def91315ccf7365b0767da`**, landed on
  `cairn`. Rakku generation **132**:
  `/nix/store/sw8zvxy2x8a50synbnk01s1b0rix53if-nixos-system-rakku-26.11.20260923.4975466`.
  Built on Unzen from the locally evaluated derivation, then copied through Zao
  to `root@rakku` with `--no-check-sigs` for these locally built outputs. No
  build ran on Rakku. No reboot. No OpenClaw config, container, feature module
  or Yari change.
- The node is online at **100.96.57.101**, with exactly **`tag:claw-tools`**.
  From Zao, the TLS-verified MCP client initialized, listed exactly **1 tool**,
  `scryer_graphql`, and received **1 query root**, **1 Dune title** (limit 3),
  and **0 GraphQL errors**. It printed counts, not titles or IDs. Resource
  listing/reads and an unknown tool each returned **-32601**. Two complete
  probes passed. The first TLS handshake timed out during initial certificate
  issuance; the next attempt passed without disabling TLS checks. Tool calls
  used only a read-only query; authentication used the normal admin login.
- Home Assistant, Z-Wave, ai-gateway, all three pi-assistant units, Google and
  maps remained active, with all **8 application start times unchanged**.
  Calendar, maps and the new Scryer proxies are active. Existing tsnet proxies
  restarted because their shared binary changed. The Scryer unit has **0
  automatic restarts**. A root-only check after the live requests found the
  password in neither its journal nor its unit text.
- Passed: focused `claw-scryer`, `claw-tools` and `tailnet-names` Nix checks;
  Rakku toplevel evaluation; Nix formatting; Go formatting and vet; the combined
  HTTP boundary tests under Go's race detector; and all **14 package tests**
  during the Unzen package/system build. No aggregate flake check ran.
- Evidence and the read-only client are on Zao at `/tmp/claw-scryer-probe`,
  `/tmp/claw-scryer-verification.json`, `/tmp/claw-scryer-before.json`,
  `/tmp/claw-scryer-after.json`, and `/tmp/claw-scryer-package-log`.
  At that time the prepared skill was not yet wired into OpenClaw.

## Scryer MCP App (2026-11-11 UTC)

One MCP App view, `ui://scryer/media.html` (`text/html;profile=mcp-app`), is
served by each account-scoped endpoint and draws two card shapes:

- **Search tiles** after `scryer_search {query}`: each result with its poster
  (or the kind in pixel art), kind, year, network or runtime, library badges,
  and **Add** / **Monitor**. With more than one library for the kind, both ask which library first and propose one. A series asks which episodes: all, future,
  missing and future, or chosen seasons.
- **Title card** after `scryer_title {titleId}`: one mark per episode for each
  season (on disk, wanted, upcoming, not monitored), the whole-show scope, and
  **Monitor** / **Unmonitor** per season. Per-episode switches are in the full
  view.

| Tool | Visible to | Scryer operations |
| --- | --- | --- |
| `scryer_search` | model and card | `searchMetadataMulti`, `titlesByExternalIds` |
| `scryer_title` | model and card | `title` |
| `scryer_add` | card only | `libraries` (MANAGE_TITLES), `titlesByExternalIds` (never adds twice), `addTitle` (explicit libraryId), `title` |
| `scryer_monitor` | card only | `setCollectionMonitored` (season), `setEpisodeMonitored` (episodes of the same title only), `updateTitle` + `setTitleMonitored` (whole-show scope), then `title` |

Every write ends with a fresh read of the title, and the card draws only that
read. After a failure, the card reads again (the title, or the search for an
add). There are no delete, file, restore or settings buttons; those stay in
chat with the skill's confirmation rules. Code: `packages/media-tsnet-proxy/scryer_app.go`
(tools) and `packages/media-tsnet-proxy/scryer-view/` (view, committed built page,
harness with a fake endpoint, `README.md` with the data contract).

What makes the buttons work in OpenClaw 2026.11.3:

- **Session tool policy.** OpenClaw checks a card's own tool call by its
  projected name, without plugin metadata, so `bundle-mcp` in `tools.allow`
  does not cover it. This is why the System Monitor card failed with -32603.
  `tools.allow` therefore lists exactly the four exact app-tool names under each of `claw-scryer-simon__` and
  `claw-scryer-laure__`. Nothing else is added.
- **Approval.** No approval mode is set for either Scryer server. OpenClaw then decides
  from tool annotations. The four app tools carry honest hints (reads
  read-only; add and monitor not destructive, idempotent, closed-world), so they
  run without a prompt. `scryer_graphql` has no hints, so a card calling it
  would still be prompted.
- **Posters.** Scryer returns proxied poster paths (`/images/media/…`). The
  endpoint makes them absolute on `https://scryer.hummingbird-lake.ts.net`,
  which needs no login, and declares that origin in the view's CSP
  (`resourceDomains`). They load in the viewer's own browser, so the viewer
  must reach that tailnet name. A poster that fails to load falls back to the
  pixel kind.

Known limits:

- OpenClaw starts an inline card at 160 px and grows it to the reported height,
  up to 1200 px. Longer cards scroll inside the frame.
- **OpenClaw's full screen is broken for MCP Apps in 2026.11.3.** It grants
  full screen, but `<mcp-app-view>` gets an inline `display: block`, which
  defeats its flex layout, so the frame stays at the 150 px iframe default.
  Clearing that style in the browser fixed it in testing. The view detects a
  granted full screen under 320 px, returns to inline and grows in place, with
  **Show less**. When OpenClaw fixes this, full screen works with no change here.
- The first card in a brand-new conversation once showed "MCP App unavailable:
  Session … was not found". A reload rendered it. Buttons on a card drawn
  before a Yari restart can fail with "bundle-mcp server claw-scryer is not
  connected" until the next model turn reconnects the server.
- Many titles have no `monitorType` in Scryer. The card then words the scope
  from the flags ("All episodes monitored", "Some episodes monitored").
- Search results carry no network or end year before a title is added, so
  same-named titles are told apart by year, kind, status and runtime.
- The model does not see the card. The view sends `updateModelContext`;
  OpenClaw shows it as "App context" on the composer.

### Scryer MCP App deployment evidence (2026-11-11 UTC)

- Commits on `cairn`: `98c28e06` (view), `2d5704ed` (tools),
  `65fc597f` (OpenClaw wiring, skill, annotations), `5ac73bbf` and `ca8f80c3`
  (inline growth and the full-screen fallback).
- Rakku generations **135** (`7a97d9b3`, tools), **136** (`cd5s3i7p`,
  annotations) and **138** (`xam6hxw7`, view fixes; also carries another
  session's websearch commits, which that session deployed as 137). Each was
  built on Unzen, copied through Zao as root, and switched. Only
  `media-tsnet-proxy` changed in the closures; all tsnet proxies restarted for a
  few seconds. Home Assistant, ai-gateway and the three pi-assistant units kept
  their start times. No reboot.
- Yari generation **21** (`8kmvm9j9`), built on Yari with remote builders
  disabled. The container restarted once. A later session's generation 23 still
  contains the claw-scryer server, the four allow entries and the skill folder.
- Passed: Go vet and tests (race detector included), the `claw-scryer`,
  `claw-tools` and x86 `openclaw` checks, ARM `openclaw-config` (real CLI
  validation), Rakku and Yari toplevel evaluation, Nix formatting, the view's
  11 Node tests, and a 114-frame review deck of the view against the fake
  endpoint. No aggregate flake check ran.
- From Zao (read-only): 5 tools with the expected visibility, the resource with
  its CSP, unknown resource -32602 and unknown tool -32601. A live search
  returned 12 results, 11 with posters, all from the Scryer origin. A live title
  read returned 13 seasons and 163 episodes.
- OpenClaw: `mcp doctor` reported `claw-scryer: ok`; `skills list` showed
  `scryer` ready for `main` and `laure`. In a new Draft conversation of `main`,
  not the Main Session, the search and title cards rendered with posters, and
  the inline cards grew to their content (747 px for 16 Dune results). The
  full-screen fallback expanded the card in place with Back to results.
- One live write, chosen to be harmless and reversible: Curb Your Enthusiasm
  S3E1 was monitored. The card's switch set it to not monitored. Scryer's read
  agreed (120 → 119 monitored, nothing else changed), and the card showed the
  re-read. The switch then restored it, and a GraphQL read confirmed
  monitored again (120). The test browser was paired for the test and removed
  afterwards.
- Laure's agent was checked by configuration and `skills list` only; no
  conversation ran in her agent.
- Roll back: on Rakku, `nixos-rebuild switch --rollback` (or switch to
  generation 134 for the endpoint before the app). On Yari, roll back to
  generation 20 only after checking what later generations added; another
  session deployed 22 and 23 on top.

## Family calendar deployment evidence (2026-11-11 UTC)

- Apps `d40b848` (local `main` of `assistant/apps`) adds `family_calendar_events`.
  Its tests prove gog receives only the configured Family ID, never `--all`,
  ignores a caller's `calendarId`, and returns `not_configured` without a call
  when the ID is unset. 36 app tests passed. Mountainous `cd68b31d` on `cairn`.
- Application profile changed only `bin/google`; installed without restarting
  other units. Rakku generation **133** runs
  `/nix/store/xb1wkq9i3v5yszy1xvyrpwyk47jj49i9-nixos-system-rakku-26.11.20260923.4975466`,
  built on Unzen and relayed through Zao. Rakku did not build or reboot.
  The switch restarted only `assistant-app-simon-google` and `pi-assistant-simon`
  (its tool list gained the read-only tool) and started the new proxy.
  Home Assistant, Z-Wave, ai-gateway, Laure's and Household's assistants, maps
  and the other claw proxies kept their start times.
- Checks: focused `claw-tools`, `tailnet-names` and `openclaw`; Rakku toplevel.
- Node `claw-family-calendar` (`100.99.2.46`) has only `tag:claw-tools`. From Zao:
  tools/list returns only `family_calendar_events`; `calendar_busy`, `mail_list`
  and `resources/read` return `-32601`. Fourteen days were read, with a
  `calendarId` of the Personal calendar added to every call: every reply was
  `calendar: "Family"`, two days had one event each (one timed, one all-day),
  and replies held only `title`, `allDay`, `start` and `end` keys.
- Roll back: `nixos-rebuild switch --rollback` on Rakku (to generation 132) and
  reinstall the previous application profile generation with `nix-env --profile
  /nix/var/nix/profiles/per-user/pi-assistant/application --rollback`.

## Laure's agent (2026-11-11 UTC)

Display identity is Nix-managed at `agents.entries.laure.identity`: Snowy, ❄️, her interview's theme, and workspace-relative `avatars/avatar.png`; leave her user profile and role unchanged.

`lib/openclaw-container.nix` declares two agents under `agents.entries` with
`agents.ownership = "explicit"`. OpenClaw 2026.11.3 rejects the legacy
`default = true` marker in a multi-agent roster, so the config pins what that
marker meant for `main`: its workspace, `agents.defaults.systemAgent`,
`agents.defaults.sessionStore` and `talk.agentId`, as `openclaw doctor --fix`
would. Both agents set `heartbeat.every = "30m"`: once any agent has a
heartbeat block only those agents run one, and a multi-agent roster without
blocks runs none. MCP servers stay global; each agent's `tools.deny` removes
whole servers by their `<server>__*` names:

| Agent | Workspace | Denied servers | Remaining MCP tools |
| --- | --- | --- | --- |
| `main` | `/var/lib/openclaw/workspace` | `claw-family-calendar` | calendar_busy, travel_time, two demo apps |
| `laure` | `/var/lib/openclaw/workspace-laure` | `claw-calendar`, `basic-react`, `budget-allocator`, `system-monitor` | travel_time, family_calendar_events |

Laure's workspace does not exist until her agent's first run. OpenClaw then
seeds the starter files, including BOOTSTRAP.md, and her setup interview runs
in that first conversation. Do not run her agent before she does.

After a config change, `tools.effective` reports MCP tools only after an agent
run rediscovers the catalog (notice `mcp-stale-catalog`). Check a session that
has run since the restart.

Evidence:

- Mountainous `6a21ffea` on `cairn`. Yari generation **16**:
  `/nix/store/4pxywyv9sfiwfhg20j3jlks2q9np4k6n-nixos-system-yari-26.11.20260923.4975466`,
  built on Yari with remote builders off. The real `openclaw config validate`
  (ARM `openclaw-config` check) passed. Focused `openclaw` check passed.
  The switch restarted only `container@openclaw`.
- `agents list`: `laure` (no identity yet, not default) and `main` (flakey,
  default). Cron: `heartbeat-main` kept its ID; `heartbeat-laure` was added;
  `morning-brief` (df3d8216) unchanged.
- One short run of `main` in new session `agent:main:explicit:laure-setup-check`
  replied OK without tools. That session's effective tools equal the
  pre-change list for `agent:main:main` exactly (15 tools); the Family
  calendar tool is absent. From the OpenClaw user, `claw-family-calendar`
  tools/list returned only `family_calendar_events`.
- Laure's effective tools are checked after her first run (step 5).
- Security audit: 0 critical, 2 warnings, 1 info. New warning
  `security.trust_model.cross_agent_session_access_default`: session tools can
  address other agents' sessions. Only `session_status` is allowed to either
  agent. Not changed.
- Roll back: `nixos-rebuild switch --rollback` on Yari (generation 15). The
  `heartbeat-laure` job and any Laure workspace then remain as state; remove the
  job with `cron rm` if Laure's agent is retired.


## Trial decisions — 2026-11-10 Denver

- Both agents use `tools.profile = "full"`, an explicit allowlist for the
  requested capabilities and `deny = [ "group:runtime" ]`. Code Mode and
  elevated execution stay off. Workspace file tools use `fs.workspaceOnly`.
  Per-agent MCP deny lists and both 30-minute heartbeats stay unchanged.
- Bundled skills are exactly weather, visualize and diagram-maker. ClawHub is
  disabled. Settings remain the Nix-owned, read-only file.
- Simon approved specific plugin exceptions for the requested capabilities:
  browser (managed browser), memory-core (memory search), openai (Images API),
  web-readability (web fetch). All are bundled **2026.11.3** from the pinned
  nix-openclaw package; `plugins.allow` contains only these four IDs. No
  marketplace, search plugin, Brave credential, channel, session-share or
  visitor capability is added.
- All three chat models declare text/image input and reasoning, with thinking
  default medium. Real chat-completions requests with `reasoning_effort=medium`
  returned HTTP 200 for all three. This proves acceptance, not the provider's
  internal reasoning behavior. Explicit limits were approved on 2026-11-11: Opus contextWindow 1,000,000 / maxTokens 128,000, without a contextTokens cap; Sol 500,000 / 128,000 with contextTokens 272,000; Gemini 1,048,576 / 65,536. Separate front-door probes using openclaw@yari accepted 698,431 prompt tokens on Opus with max_tokens=128000 (HTTP 200), 542,301 on Sol, and 760,099 on Gemini. Sol/Gemini native windows come from CLIProxyAPI's model list; the probes establish large-input acceptance, not a maximum-window measurement. Opus's uncapped input and Sol's 272,000 budget follow installed docs/providers/anthropic.md and docs/providers/openai/setup.md. Earlier unconfigured custom-provider defaults were only 128,000 context and 32,768 output.
- Images use `agents.defaults.mediaModels.image`, with
  `openai/gemini-3.1-flash-image` primary and `openai/gpt-image-2` fallback. The
  openai provider points at the same front door's `/v1/images` dialect. The installed
  Images adapter ignores allowedHostnames and overrides the provider request's
  allowPrivateNetwork. It requires the documented shared
  `browser.ssrfPolicy.dangerouslyAllowPrivateNetwork=true` opt-in for this
  tailnet URL. Cost: this also admits private browser destinations; the
  unchanged container OUTPUT policy and tailnet ACL remain the network boundary.
- Memory uses the bundled SQLite/FTS engine (`memory.search.provider=none`),
  not embeddings: the grant has no embeddings dialect. Saves remain workspace
  Markdown. Cost: lexical recall does not provide semantic vector matching.
- The shell-free policy does not remove the risks of browser automation,
  writable workspace instructions, cron or cross-agent session tools. The
  existing per-person roles are unchanged. Do not mistake these tool choices
  for isolation between mutually untrusted users.

### Native web search: upstream limitation and MCP bridge

Simon's latest decision is front-door/model-native search only: no Brave,
Parallel, outside search service, search plugin or new search credential.
A real `/v1/responses` request through `openclaw@yari`, model `gpt-6.1-sol`,
with `tools=[{type:"web_search"}]` completed HTTP 200, with **2 web_search_call
items and 1 citation annotation**. Thus the gateway and CLIProxyAPI forward
native search successfully; no grant change is needed.

OpenClaw 2026.11.3 itself refuses this native-search route. Installed docs
`tools/web.md` (Native OpenAI web search) and the actual
`dist/native-web-search-policy-Cfd1Zg5f.mjs` require **all three**: provider ID
`openai`, API `openai-responses`, and absent/official OpenAI API base URL.
A custom front-door URL fails the last requirement even if the provider is
renamed. Per-model extra_body passthrough is documented only for completions;
there is no supported native-search opt-in for a Responses proxy. Merely
switching `front-door.api` does not enable search. Keep the existing working
chat adapter. `web_fetch` and managed-browser navigation remain available,
but are not claimed as native `web_search`. The approved `claw-websearch` MCP bridge above now supplies this capability
without patching OpenClaw or changing the working chat adapter.

### Weekly package update: signed app profile

OpenClaw's package now has the independent deploy-rs profile
`/nix/var/nix/profiles/apps/openclaw` on Yari only. It contains the
nix-openclaw gateway plus our ARM Node wrapper. The container binds the host's
**apps directory** read-only, not the resolved profile symlink. The gateway
launch and `openclaw-admin` resolve the profile each time they run. Models,
tools, endpoints, permissions and other configuration still require normal
Yari system deployment. A package update does not switch the system or the
container, and does not update these settings.

Unzen runs `app-update-openclaw` each **Sunday at 02:15 America/Denver**.
Its complete job has a four-hour limit, ending by 06:15 before the 07:00 brief.
Missed runs do not catch up after boot, so they cannot overlap the brief. The
timer is gated by `/var/lib/app-updater/enabled-openclaw`,
created only after the first accepted signed deployment. Disable scheduling
with `systemctl stop app-update-openclaw.timer` and move the gate aside.

The updater takes the existing global update lock, requires a clean repository,
fetches `origin/cairn` and fast-forwards its detached checkout before selecting
a candidate. It selects the upstream nix-openclaw revision, not the exact
revision embedded in the original flake URL; it does **not** edit `flake.lock`.
It pins that candidate with `--override-input` throughout checks and deployment.
Version and input timestamps must not decrease relative to the system lock or
last accepted receipt. An unchanged candidate can retry a failed host.

ARM derivations are evaluated on Unzen, copied to Yari, and realized **on Yari**
using the dedicated builder key. Its forced SSH command accepts only Nix store
transport or `app-native-build <store derivation>`. Realization explicitly sets
`max-jobs=2`, `cores=4`, and `builders=""` on the target; remote-store options
alone would not prevent delegation to Fuji. Outputs return to Unzen before
signing. The app, `openclaw`, `openclaw-config` (real CLI config validation) and
deploy-schema checks run sequentially on ARM. Only checked closures receive
the local app-updater signature.

Deploy-rs uses the existing restricted `app-deploy` account, signature checks,
auto rollback and magic rollback. That account can change only app profiles.
The only extra root operation is the fixed `openclaw-profile-control
restart-and-check` controller. It cannot switch systems, restart arbitrary
units or change config. Activation restarts only the container's gateway and
waits up to 120 seconds for `/healthz` to return `ok=true` and the Control UI
root to return **HTTP 200**, then checks five seconds of stable process
identity. The previous profile runs the same hook on rollback.

Manual verification uses the exact configuration path from the running unit:

```sh
# On Unzen, as root; retain the unit's HOME, LOCAL_KEY, NIX_REMOTE,
# NIX_SSHOPTS and GIT_SSH_COMMAND environment (systemctl show -p Environment).
systemctl cat app-update-openclaw.service
app-update --config <app-updates.json-from-ExecStart> --app openclaw --check-only
systemctl start app-update-openclaw.service
```

`--check-only` builds and checks but does not sign, deploy, advance acceptance
or create the gate. Real runs produce private atomic JSON receipts and command
logs under `/var/lib/app-updater/receipts`, including source SHA, selected input
revision/version, ARM activation path and per-host deployment result. Accepted
state is `/var/lib/app-updater/accepted-openclaw.json`. Keys stay under Unzen's
`/var/lib/app-updater`; no system activation key is given to the updater.

Before each manual system build, rebase on the latest origin/cairn. Before a
Yari switch, check for another `switch-to-configuration` process. Bootstrap a
new placement by building and signing the **current locked** activation first,
setting it as the initial app profile as app-deploy, then switching the system
to profile-based launch. Do not switch to a missing profile. After every host
deployment check container/gateway health, Laure's roster entry, the unchanged
07:00 brief, and every claw-tools tools/list endpoint. Do not start Laure's
agent to perform this check.

For package rollback, select a retained generation with `nix-env --profile
/nix/var/nix/profiles/apps/openclaw --switch-generation N` as `app-deploy`, then
run the permitted controller via sudo. Check both health endpoints and the
roster. A system rollback does not roll back this independent package profile;
retain both old closures. Never delete OpenClaw state for a package rollback.


#### Weekly profile deployment evidence — 2026-11-11 UTC

Implementation: `326f4914` (profile/native transport), `856af38e` (quiet-window
limit and this runbook), `121b17bd` (CLI receipt tests), landed on `cairn`.
Rebased on origin/cairn before builds; systems built from `121b17bd`. No host
rebooted. Yari built its ARM system with builders disabled; Unzen built its
x86 system with builders disabled.

| Target | Generation | Running closure |
| --- | --- | --- |
| Yari system | **23** | `/nix/store/in6jmak1fm9v4i8k8mc5cwnx42rvczvi-nixos-system-yari-26.11.20260923.4975466` |
| Unzen system | **56** | `/nix/store/6rhbj10dcc5xff3xc7q782d6ldwbsfda-nixos-system-unzen-26.11.20260923.4975466` |
| Yari OpenClaw app | **1** | `/nix/store/61j8zqks0hykidf3ws2s0k069r13plhm-activatable-openclaw-gateway-2026.11.3` |

The initial app profile contained the current locked version, **2026.11.3**,
with revision `412fc9f978072eac48c4dfe8cc77181e077696a6`. Its closure was signed
on Unzen, then installed as app-deploy before switching Yari to profile-based
launch. The container sees the apps directory read-only. System switch
restarted the container; package deployments restart only the gateway.

Both manual updater runs used source `a19fb38a8e6bb563db8724ed9665f64cc79aeff1`
after the updater refreshed origin/cairn. The dry run passed with no host
activation or acceptance write. The real run selected newer nix-openclaw
**`b04843a59efe524bc01a14aed1d5b977dc811334`**, passed every ARM check, signed
and deployed as app-deploy with both rollbacks and signature checking enabled.
The upstream revision changed packaging metadata, not the selected npm gateway:
it still resolves to **2026.11.3 and the same store closure**. Thus the app
profile correctly stayed at generation 1, while accepted input revision advanced.
Neither updater run changed Yari's system generation.

Receipts on Unzen:

- Dry run: `/var/lib/app-updater/receipts/1794379125984961677.json`.
- Real run: `/var/lib/app-updater/receipts/1794379207815705162.json`.
- The successful signed activation enabled `/var/lib/app-updater/enabled-openclaw`.
  The timer is active; next run is **2026-11-15 02:15 Denver / 09:15 UTC**.

Because the newer input had the same package output, a separate data-free
broken candidate also exercised a real profile change. Its `openclaw` binary
exited 1 without touching state. It was natively built through the actual
forced Yari transport, signed, and deployed with the production activation hook.
The 120-second health gate failed. Deploy-rs returned exit 1 and reported
**"rolled back to previous generation"**. Profile generation 1 and the original
closure were restored automatically, and the old gateway restarted with
**0 automatic restarts**. The broken profile is not deployed. System generation
23 and accepted input revision b04843a remained unchanged.

After **each system deployment, the real package deployment, and the rollback**:
container and gateway active; gateway health and Control UI HTTP 200; Laure's
entry present; original brief ID `df3d8216-a284-4086-a127-3890019d5cdb` still
enabled at 07:00 America/Denver. Tools/list as the container's OpenClaw user
passed for calendar, family calendar, maps and Scryer; after Yari adopted the
concurrent web-search config it also passed for web search. Final tools lists
were 1 / 1 / 1 / 5 / 1 respectively. No Laure agent run was created. Yari's
`sudo -l` for app-deploy lists **only** the fixed OpenClaw controller command;
no system activation or arbitrary systemctl command is permitted.

Passed: **13 Python tests**, including real subprocess dry-run/deployment/failure
receipts; Ruff lint and format; Python compilation; Nix formatting and whitespace;
Yari/Unzen toplevel evaluations and native system builds; focused ARM
`app-openclaw`, `openclaw`, `openclaw-config` and `deploy-schema`; focused x86
`openclaw`, `app-updater-closure` and `deploy-schema`. The broader focused
`app-profiles` contract fails because it still requires Pi enabled on Aka,
which its host explicitly disables. This same failure was reproduced against
pre-change `98311bc3`; it was not changed here. No aggregate flake check ran.
Korri cache HTTP 503 warnings occurred during the first ARM build; it completed
successfully using the available inputs and native builds.

Local evidence: `/tmp/claw-updates-before.json`,
`/tmp/claw-updates-after-unzen.json`, `/tmp/claw-updates-after-yari.json`,
`/tmp/claw-updates-after-update.json`, `/tmp/claw-updates-after-rollback.json`.
The rollback fixture and its signed activation path are under
`/tmp/claw-updates-rollback*` on Unzen. For rollback of this migration, use Yari
system generation **22** (the previous fixed-path launch). Package-only rollback
uses the profile procedure above; retain profile generation 1.


## Trial deployment and verification — 2026-11-10 Denver

Implementation commits on `cairn`: `629df4b5`, `276f46e2`, `d31a4b3d`,
`3c0a27b0`, `55b6935b`. Rebased against current origin/cairn before the builds;
no Laure-session commits were dropped. No auth, roles, sign-in or Laure persona
configuration changed. No secret was added or rotated. No host rebooted.

| Host | Generation | Running system | Build host |
| --- | --- | --- | --- |
| Rakku | 135 (134 deployed by this run) | `7a97d9b3yb9rfb6d1wgwdrmcffp5xv12` | 134 built on Unzen/relayed through Zao; 135 deployed independently |
| Unzen | 55 | `dhqa185nk8asa6mi0smlmlyfffwjb0pg` | Unzen |
| Yari | 20 (first deployment 19) | `mr63j76hr86ib51pxn18np2lcj8j1qbs` | Yari, remote builders disabled |

Source deployed by this run: Rakku/Unzen `3c0a27b0`, Yari `55b6935b`. The final
docs rebase preserved newer independent Scryer commits `98c28e06` and `2d5704ed`.
The supervisor directed no further activation to avoid a deployment race.
During final checks the Scryer session deployed Rakku generation **135**; its
running output matches the current-tip toplevel derivation. Its endpoint now
lists 5 tools (the original scryer_graphql plus its 4 new media tools); all four
endpoints and Laure's entry were rechecked after that independent switch.
Yari generation 20 also matches the current-tip derivation. Unzen generation
55 still predates `98c28e06`/`2d5704ed` and lacks their shared proxy-package
changes; it was not redeployed on the supervisor's direction. All OpenClaw
trial changes are live. Current-tip focused checks/evaluations passed without
another activation.

Focused checks passed: x86 openclaw, home-exit-node, ai-gateway and claw-tools;
all three host toplevel evaluations; ARM openclaw-config (real CLI validation)
and Yari system builds. Nix formatting, Ruff lint/format for the changed Python
test, whitespace and check-flake-inputs passed. The ai-gateway check first
rejected the old expected grant, then passed with the expanded grant assertion.
No aggregate flake check ran. ARM config-check logging reports an unwritable
production log path inside the build sandbox; validation still passes. The
production gateway has zero automatic restarts.

After **each** host deployment, the four claw-tools units on Rakku were active,
container tools/list returned their exact one-tool lists, and the laure entry
and both enabled heartbeats remained present. Rakku's Home Assistant, Z-Wave,
all three pi-assistant units, Google and maps kept their original start times;
only ai-gateway restarted there. Unzen's switch reached generation 55 but
returned exit 4 from a transient `simon` user-manager activation transaction
(`exit.target` already queued). No system units failed. The saved exit-node
advertisement was explicitly cleared afterward. No unrelated user-unit fix was
made.

Network verification as the **openclaw user**:

- Selected exit node is Rakku, `ExitNodeAllowLANAccess=false`; another node sees
  Rakku `ExitNodeOption=true` and Unzen `false`.
- Rakku, container curl and the **managed browser** at api.ipify.org all return
  **38.175.187.81**. Yari itself remains **129.146.97.70**.
- Rakku:22 times out. Stopping container tailscaled blocks a previously working
  public HTTPS request with DNS bypassed (`--resolve ...:1.1.1.1`, curl exit 28).
  Tailscaled and claw-tailnet were restored; the home IP and active units were
  rechecked. Startup can briefly lack the exit peer's netmap entry; the existing
  retry recovers without an Oracle fallback.
- **Reachability caveat:** the tag:mountainous front door returns HTTP **401**
  without a key and **200** with it. However, scryer and traccar HTTPS both time
  out from the container; Scryer returns **200** from Zao. Thus general fleet
  HTTPS reachability under the newly saved policy is **not proven**. The reason
  is not established. No ACL, auth or service changes were made to bypass it.

Browser verification used a newly paired Chromium session, **not the main
conversation**: `agent:main:dashboard:2ee33954-f22c-405e-9038-2b6c88b53915`.

| Requested behavior | Verified result |
| --- | --- |
| ask_user | Structured Cedar/Quartz question rendered; Cedar answer was accepted. The model corrected one malformed first call. |
| Memory save and recall | Workspace note saved; memory_search and memory_get returned the exact marker. Recall passed again after the container restart. The first search had a partial index-repair warning; the final search had none. FTS-only, no embeddings. |
| Native web search | Front-door Responses probe succeeded with 2 search-call items and 1 citation; OpenClaw cannot select native search for a proxy URL. Unavailable in the chat, as explained above. |
| Attached image | Uploaded 64×64 test image; model correctly identified red left and blue right. |
| Image generation | One 1024×1024 paper-crane image generated through the default Gemini Images route and rendered in chat. Initial private-network refusal was reproduced before the documented opt-in fix. |
| Browser and fetch | Managed headless Chromium opened example.com; web_fetch returned HTTP 200. A subsequent managed-browser IP check returned the home IP. |
| Shell absence | tools.effective on the new session excludes exec, process and code_execution with reason deny; terminal is excluded by the allowlist. Same global deny applies to both agents and is asserted in the focused check. No Laure run/session was created just to test her policy. |
| Plugin confinement | Real plugins list loads exactly browser, memory-core, openai and web-readability, all bundled 2026.11.3; no other plugin loads. |

Screenshots on Zao: `/tmp/claw-decisions-ask-user.png`,
`/tmp/claw-decisions-generated.png`, `/tmp/claw-decisions-browser-ip.png`.
They contain the verification chat and Simon's account avatar. The generated
file is named `.png` but its actual first bytes are JPEG (`ff d8 ff e0`); it
renders correctly. This upstream naming mismatch was reported, not patched.

Morning brief retained ID **df3d8216-a284-4086-a127-3890019d5cdb**, exactly one
07:00 America/Denver declaration, stagger 0. The final reconciled prompt contains
the exact Denver home-place sentence from Simon's decision. Manual results
(counts and times only):

| Run (Denver) | Duration | Busy blocks | Calendar-free windows | Weather reads | Questions | Delivery |
| --- | --- | --- | --- | --- | --- | --- |
| 22:44:24 (before home place) | 22.084 s | 0 | 1, 08:00–22:00 | 0 | 1 | delivered |
| 22:49:25 (final home place) | 27.187 s | 0 | 1, 08:00–22:00 | 1 | 1 | delivered |

SOUL.md Growing was updated in place; owner **992:998**, mode **0600** retained.
A same-owner/mode backup sits beside it. Both container and gateway report
MemoryMax **8,589,934,592** bytes.

Final security audit: **1 critical, 4 warnings, 1 info**. The critical is the
unchanged trusted-proxy auth mode. Warnings cover MCP Apps, the required shared
private-network Images opt-in, unchanged trusted loopback proxy, and cross-agent
session access (now meaningful with session tools). These are reported, not
silenced or repaired. Memory Core also created its default 03:00 memory-dreaming
automation when enabled; the two heartbeat jobs and morning brief are unchanged.

| Decision | Status |
| --- | --- |
| 1 Tools | done with a caveat: native search unavailable; Laure policy checked declaratively, without starting her agent |
| 2 Bundled skills | done |
| 3 Plugins | done with a caveat: four specific approved capability exceptions, no general plugins |
| 4 Browser | done with a caveat: shared private-network opt-in required by Images |
| 5 Models/images | done with a caveat: real context/output limits unconfirmed; defaults retained; GPT image fallback catalogued, only primary generation exercised |
| 6 Front-door grant | done |
| 7 Network policy verification | done with a caveat: AI HTTPS succeeds and SSH fails; general fleet HTTPS still times out |
| 8 Rakku exit node | done |
| 9 MemoryMax | done |
| 10 Soul growth | done |
| 11 Morning brief | done, including the Denver home-place follow-up |
| 12 Demo apps | done |
| 13 Weekly updates | superseded by the signed weekly app-profile updater above |
| 14 Yari role | done |
| 15 Preserved boundaries | done; both heartbeats, Nix-owned settings, calendar_busy-only personal endpoint and event-title handling retained |

Rollback: `nixos-rebuild switch --rollback` on the affected host, no reboot.
The first Yari rollback returns generation 19 (before the Images/home-place
fix); generation 18 predates the trial decisions. To restore Unzen egress,
restore its advertisement and select Unzen in the container before withdrawing
Rakku's advertisement. SOUL.md and cron history are persistent state, not system
closure contents; a system rollback does not undo them. Restore only the saved
SOUL.md backup if Simon wants that wording reverted. Do not delete service or
tailnet identity state.

## eBay MCP (2026-11-12)

Simon's read-only eBay product service is placed on Rakku. The flake input
`ebay` pins `1bbffa36ba768e60929892a4bd4e449cc8dca5ba`. No buying, listing
changes, replies, Best Offer responses or buyer data are exposed.

- `ebay-server.service`: `127.0.0.1:3191`, POST `/mcp`. This port was free
  before deployment. DynamicUser, strict filesystem protection, read-only temp
  filesystems, no state directory, restart on failure. Access tokens stay in
  memory. Systemd LoadCredential reuses `ebay-api-env` and `ebay-refresh-token`;
  the server reads `CREDENTIALS_DIRECTORY`. No secret values were changed.
- `tsnet-proxy-claw-ebay-simon.service` serves
  `https://claw-ebay-simon.hummingbird-lake.ts.net/mcp`, enrolled with only
  `tag:claw-tools`. Its saved tsnet identity is retained across restarts.
- The filter permits only `ebay_search`, `ebay_listings`, `initialize`, `ping`,
  `tools/list`, `resources/list`, and `resources/read` for exactly
  `ui://ebay/search.html` and `ui://ebay/listings.html`. It acknowledges
  `notifications/initialized` locally. Lists are filtered; unknown tools,
  methods, URIs, batches and non-tailnet peers fail closed. The proxy uses
  session-less MCP 2025 versions. No general HTTP proxy or write route exists.
- Only `claw-simon` receives the server, the two `toolFilter.include` entries,
  the two exact projected `tools.allow` names, and the Simon-only eBay skill.
  No approval override: the tools' read-only hints apply. Laure's `openclaw`
  container must retain its exact system path, config bytes and start time.

Focused checks: `claw-ebay`, `claw-tools`, `tailnet-names`, `openclaw`,
`openclaw-people`; evaluate both host toplevel drvPaths. Run ARM
`openclaw-config` on Yari. Never run an aggregate flake check. Before each build,
rebase on latest `origin/cairn`, check no target switch is running, and on Yari
check Simon's audit events for unfinished agent runs. Build Rakku on Unzen,
copy the closure through Zao as root, then switch without reboot. Yari builds
itself. Compare Laure's container config and system path before switching.

Verify as the OpenClaw user inside `claw-simon`: initialize, exactly two tools
with read-only hints, resource listing, and reads of both real views (DOCTYPE
first, `<!-- ebay-view source-sha256:` within the first 300 bytes; match its hash
to the pinned committed pages; MIME `text/html;profile=mcp-app`, image
CSP `https://i.ebayimg.com`). One `ebay_listings {limit:3}` call must succeed;
print only its count. Refuse an unknown tool without reaching eBay. Keep live
HTTP attempts within the approved budget; reads/listing of MCP metadata use
no eBay calls. Check the server journal's static client operation events for
an exact HTTP attempt count. Check all other claw endpoints, Home Assistant
and Z-Wave. After Yari switches, check gateway health, `openclaw-admin mcp list`
and its tool catalog; prove Laure's config and container start time unchanged.
The browser UI test is a separate Simon/parent check.

To remove: delete the `claw-ebay` Rakku layer, Simon's server and exact tool
permissions, and his eBay skill; deploy both hosts in the same order. Then
remove the feature and input if unused. Retain the two shared secrets and
saved tsnet identity. For emergency rollback, inspect the previous generation
for concurrent changes before `nixos-rebuild switch --rollback`; do not reboot
Rakku or roll back to a Yari configuration that changes Laure's container.


### eBay deployment evidence (2026-11-12 UTC)

Implementation `a8f8a9f6` landed on `cairn`. Both hosts run it. No secret value
was changed. The eBay repository and signed app profile were unchanged.
No Laure conversation was read.

| Host | Generation | Running system | Built on |
| --- | --- | --- | --- |
| Rakku | **143** | `/nix/store/pnlhssn0lh7kwi5ba03s66yy6xhs0h0y-nixos-system-rakku-26.11.20260923.4975466` | Unzen, closure copied via Zao to root@rakku |
| Yari | **41** | `/nix/store/8bfh03fv7zd7pvhm61dj78zbqal4y7df-nixos-system-yari-26.11.20260923.4975466` | Yari, remote builders disabled |

Rebased on latest `origin/cairn` before builds; checked for concurrent switches
and unfinished Simon agent runs. Rechecked origin and the running systems before
activation. No host rebooted. Only Simon's container stopped on Yari. Rakku's
14 existing tsnet units restarted for the shared proxy binary and returned
active; the new eBay server and proxy are active with zero automatic restarts.
Home Assistant returned HTTP 200; Z-Wave JS completed a WebSocket handshake and
version receipt. Their start times, ai-gateway's and all three Pi assistants'
start times stayed unchanged.

Passed: focused x86 `claw-ebay`, `claw-tools`, `tailnet-names`, `openclaw` and
`openclaw-people` drift checks; both toplevel drvPath evaluations; native ARM
`openclaw-config` (real CLI validation); Nix formatting, Go formatting/vet,
whitespace and existing-lock-node equality. The new boundary test first failed
before implementation, then passed. The proxy package's 29 tests passed during
Unzen's build. No aggregate flake check ran. Initial Yari evaluation needed the
runbook's retained transitional closures copied from Yari; evaluation then passed.

From the real OpenClaw user inside `claw-simon`, with verified TLS:

| Probe | Result |
| --- | --- |
| initialize | HTTP 200, MCP 2025-11-25 success |
| tools/list | HTTP 200, exactly 2, both read-only |
| resources/list | HTTP 200, exactly 2 |
| resources/read, both pages | HTTP 200, real views, MIME and image CSP passed |
| unknown tool | HTTP 200, JSON-RPC -32601 |
| ebay_listings, limit 3 | HTTP 200, success, count **3** |

Both views have `<!DOCTYPE html>` on line 1 and the source stamp on line 2;
the stamp is within the first 300 bytes and matches the pinned committed pages:
`16111f89c67d3ba9eee0331a8f82584e999c38354ecdf951365743a2ae79fb96`.
The first TLS handshake timed out during certificate issuance; the next passed.
No eBay tool ran on those first metadata probes. The service's static client
journal records exactly **2 eBay HTTP attempts**: one OAuth and one Trading,
no retry, buyer-tag audit empty. No search or write call was made. All metadata
probes and all six other claw endpoint tools/list checks passed again after
Yari switched. The node is online at `100.85.21.66`, with only `tag:claw-tools`.

`openclaw-admin mcp list` in `claw-simon` lists `claw-ebay-simon`.
The admin CLI's `mcp probe` requires exclusive offline state and correctly refused
the live state. A real CLI probe with empty throwaway client state and the exact
deployed read-only config discovered exactly `claw-ebay-simon__ebay_listings`
and `claw-ebay-simon__ebay_search`, resources enabled, approval auto, no diagnostics.
The throwaway client state was removed; the serving gateway was not stopped for
this check. The eBay skill is eligible and enabled. Simon's gateway is active,
health `ok=true`, zero automatic restarts; started **21:30:07 UTC**.
The browser card UI is not tested here; Simon/parent will test it.

Before the Yari switch, byte comparisons passed for Laure's live and candidate
container unit, container config, and private gateway config. Their store paths
and container system closure were identical. After the switch, container and
gateway process identities and the signed app profile still matched. Laure's
container remained at **04:38:53 UTC**, MainPID **1462903**, InvocationID
`16c35f6d73314cb798339be98ab5dfad`. Config SHA256 stayed
`00c26526158088baba45a8499389bee708ace3be8194b84778ff3f0b573a3ac9`;
container config SHA256 stayed
`2924b0618f171b3d20cff34c21d502f07ead760f2236083a15baddc0b3edc1ff`.
Her system stayed `/nix/store/z4mglka9jzbr1yssdkjnxwy0ipgylhw2-nixos-system-claw-26.11pre-git`.
No Laure agent run was created.

Rollback: after inspecting for concurrent changes, Rakku generation **142**
removes the eBay service/endpoint, and Yari generation **40** removes Simon's
wiring without changing Laure's config. Prefer reverting the feature and
redeploying if later generations contain unrelated work. Keep both existing
eBay secrets and the saved proxy identity. Evidence and copied Nix-shebang
scripts are under `/tmp/claw-ebay-evidence/` on Zao.


### eBay card polish deployment evidence (2026-11-12 UTC)

Implementation `8134cc4d` pins eBay `1bbffa36ba768e60929892a4bd4e449cc8dca5ba`
and tells Simon's model to answer in one or two sentences without repeating the
card's rows. The cards sort comparable delivered prices with exact integer minor
units, retain requested time sorts, and omit absent Best Offer status. Only the
`ebay` lock node changed; every other lock node is byte-for-byte unchanged.

| Host | Generation | Running system | Built on |
| --- | --- | --- | --- |
| Rakku | **144** | `/nix/store/lgqk9xrd7apz7ck10xisdx69rc68azxf-nixos-system-rakku-26.11.20260923.4975466` | root@unzen, copied through Zao as root |
| Yari | **42** | `/nix/store/63ggdbwsfxpazwkms2x3y6s8xjk2dxh7-nixos-system-yari-26.11.20260923.4975466` | Yari, remote builders disabled |

Rebased on latest origin/cairn and checked target switches before each host
build; Simon had zero unfinished agent runs before Yari builds and activation.
Concurrent `73a8ebf3` arrived after Rakku activation. Rebased before Yari activation
and proved its toplevel drvPath still matched the built candidate. This Rakku
generation does not include that separate Google-auth change. Neither host rebooted.
Rakku restarted only ebay-server; the proxy PID/start time, Home Assistant,
Z-Wave, ai-gateway and three Pi assistants stayed unchanged. All 15 tsnet units
are active. Home Assistant returned HTTP 200; Z-Wave passed handshake/version.
Yari restarted only Simon's container. His gateway is active, health `ok=true`,
zero automatic restarts, started **22:02:45 UTC**. The new skill's deployed text
matches the reply instructions and the skill is eligible and enabled.

Passed: all **27 view tests**, build byte check, JavaScript syntax checks,
Rust fmt/clippy (warnings denied), all **28 Rust tests**, and eBay `nix build`.
Re-shot all six screenshots with the running harness and inspected them; stopped
the harness afterward. The browser harness verified default/price headers,
newest/endingSoonest preservation, and quiet absent Best Offer status.
Passed the five focused x86 checks (`claw-ebay`, `claw-tools`, `tailnet-names`,
`openclaw`, `openclaw-people`), both host evaluations, native ARM
`openclaw-config`, Nix formatting and whitespace checks. No aggregate check ran.

From the real OpenClaw user inside claw-simon, verified TLS: initialize, exactly
**two read-only tools**, exactly two resources, both views' MIME/CSP/stamp and
full content SHA256, unknown-tool refusal, and one listings read (count **3**).
Metadata passed again after Yari switched; all six other claw endpoint tool lists
passed. `openclaw-admin mcp list` includes claw-ebay-simon. The real CLI catalog
probe with empty throwaway client state and exact deployed config discovers
exactly `claw-ebay-simon__ebay_listings` and `claw-ebay-simon__ebay_search`,
resources enabled, no diagnostics. Throwaway state was removed.

The served pages match the pinned committed bytes:

- Source stamp: `344f971094ccfd14a3b301b04089a2f1456b7dacd797dee85add26482aceb80c`.
- Search HTML SHA256: `29106f947144a7de2bb924f1f790c5b1808f0a0460cf83749e21e2d35edd6e3d`.
- Listings HTML SHA256: `0fba3efa761082c4867fdb90587d1da06ccfe292f8383fe5d3aa15fb547f4e74`.

Exactly **2 eBay HTTP attempts**, one OAuth and one Trading, appear in the new
server invocation journal. One read tool call; no retry, no search, no write,
no buyer tags. No other live eBay calls were made by this deployment.

Laure's live/candidate container unit and container config compare byte-identical;
container-config store path, gateway-config store path and system closure are
identical. Before/after evidence files compare byte-identical, including:

- Container PID **1462903**, started **04:38:53 UTC**, InvocationID
  `16c35f6d73314cb798339be98ab5dfad`.
- Gateway PID **391**, started **04:38:53 UTC**, InvocationID
  `5dbd700ddc1f4214b772e5a0522652ff`.
- Unit SHA256 `ac5290d73d6d3d8372a9691f8a43d899d302ba4a9186f1ea54dd8c05abe39727`.
- Container config SHA256 `2924b0618f171b3d20cff34c21d502f07ead760f2236083a15baddc0b3edc1ff`.
- Gateway config SHA256 `00c26526158088baba45a8499389bee708ace3be8194b84778ff3f0b573a3ac9`.
- System `/nix/store/z4mglka9jzbr1yssdkjnxwy0ipgylhw2-nixos-system-claw-26.11pre-git`;
  signed app profile unchanged. No Laure conversation was read or run created.

Evidence and copied Nix-shebang scripts: `/tmp/ebay-polish-evidence/` on Zao.
Live OpenClaw chat rendering and model adherence to the new brevity instruction
were not exercised; the harness and deployed resources were checked directly.
A host that omits tool input cannot preserve a requested time sort; this limit
is documented in the eBay contract and view README.
Rollback, after inspecting concurrent changes: Rakku **143**, Yari **41**.
These restore the previous cards/skill without changing Laure's configuration.

### eBay selling approval deployment evidence (2026-11-12 Denver / 2026-11-13 UTC)

Implementation **726b6a57** pins only the eBay input to
`cdbea4f671f36bccde1b4045c144616a9985ec09`. All other lock nodes compare equal.
The endpoint permits exactly the 14 contract tools and seven exact
`ui://ebay/*.html` resources, not arbitrary URIs. Only Simon receives the expanded
allow policy, server-wide `codex.defaultToolsApprovalMode = "approve"`, skill,
and `ebay-selling` automation. App-only visibility is still the model boundary.

| Host | Generation | System | Builder |
| --- | --- | --- | --- |
| Rakku | **150** | `/nix/store/rhxh6zzjf7h7mjhw9gbmi33jjkqawbi2-nixos-system-rakku-26.11.20260923.4975466` | root@unzen; closure copied through Zao as root |
| Yari | **43** | `/nix/store/i1f8xw0fcgplk8mijm2khndq4y7jgfnr-nixos-system-yari-26.11.20260923.4975466` | Yari, builders disabled |

Fetched/rebased on latest origin/cairn before builds and activation, rechecked
both built drvPaths before activation, checked for target switches and unfinished
Simon agent runs. Neither host rebooted. Rakku's initial guard correctly refused
an outdated baseline: another session had activated generation 149. Compared
its candidate `/etc` tree: only the two eBay units differ from our candidate.
The subsequent switch stopped only ebay-server and its proxy. The combined
source includes others' Gmail read-only/preparation work (`73a8ebf3`, `446bb039`,
`43265e81`); `claw-google-auth`, `claw-tools` and both host evaluations passed.
No other author's commit was edited. Home Assistant, Z-Wave and ai-gateway kept
their start times. Simon's Pi assistant had restarted at 02:43:13 UTC during the
other deployment, before our 02:50:16 activation; it remains active.

Passed six focused x86 checks: `claw-ebay`, `claw-tools`, `tailnet-names`,
`openclaw`, `openclaw-people`, `claw-google-auth`. Passed both host toplevel
evaluations, native ARM `openclaw-config` (real CLI validation), Nix formatting,
whitespace, and lock-node equality. The packaged eBay build ran **52 Rust tests**,
all passed. Shell applications passed their build-time checks. No aggregate
flake check ran. The new boundary assertions cover all names, approval mode,
persistent storage, Simon's cron declaration and absence from Laure.

Verified through TLS as the real OpenClaw user inside `claw-simon`:

- `tools/list`: exactly **14**, with exactly the five app-only descriptors
  carrying `_meta.ui.visibility = ["app"]`.
- All **seven** resource pages: DOCTYPE, source stamp within 300 bytes, correct
  MIME and full SHA256 equal to the pinned committed `view/dist` bytes.
- Unknown-tool refusal; successful local `ebay_drafts {}` (no eBay HTTP).
- Actual serving gateway `tools.effective`, with
  `{"agentId":"main","sessionKey":"agent:main:main"}`: exactly the **nine**
  qualified model-visible eBay tools; **none** of apply/skip/save/put-back/upload.
  This is the effective runtime list, not `tools.catalog` or an offline probe.
- All six other established endpoint tool lists passed. All 17 tsnet services
  are active; Home Assistant returned HTTP 200, Z-Wave passed handshake/version.
- Simon gateway health `ok=true`, zero automatic restarts; started 02:53:45 UTC.

State: `StateDirectory=ebay`, `StateDirectoryMode=0700`,
`EBAY_STATE_DIR=/var/lib/ebay`, `TZ=America/Denver`; hardening retained.
Through the service's idmapped mount the directory is **0700 ebay-server:ebay-server**
(uid/gid 61512 at verification). Host view is deliberately nobody:nogroup under
`/var/lib/private/ebay`, with `/var/lib/ebay` a systemd-managed symlink. An app-user
marker survived an explicit service restart; the marker alone was then removed.
Do not clean this directory during deployment or rollback. It holds private
message-bearing drafts and the append-only write audit, and must be retained
as private application state when backing up or moving the service.

Automation proof: gateway `cron.list` has exactly the enabled declaration
`mountainous:ebay-selling`, ID **819b4130-7f43-478d-9033-acadb60db88d**,
agent `main`, session `agent:main:main`, isolated agentTurn, 300-second timeout,
announce delivery, `0 8 * * *`, America/Denver, no stagger.
Next run **2026-11-13 08:00:00 MST** (1794582000000 ms).
It was **not run**. The oneshot retried once while the gateway was starting,
then reconciled successfully; it is active/exited. The installed OpenClaw
`docs/automation/cron-jobs/delivery.md:117` explicitly documents text-only
`NO_REPLY` suppression for announce agentTurns. The prompt uses it only after
successful checks find nothing needing Simon. Price drafts require a known
no-sale state; the model must not guess absent sale data.

Laure proof: live/candidate unit and container config compare byte-identical;
container system root and gateway-config store path are identical. Full
before/after/final evidence files compare byte-identical, including app profile:
container PID **1462903**, gateway PID **391**, both started **04:38:53 UTC**;
unit SHA `ac5290d73d6d3d8372a9691f8a43d899d302ba4a9186f1ea54dd8c05abe39727`,
container config SHA `2924b0618f171b3d20cff34c21d502f07ead760f2236083a15baddc0b3edc1ff`,
gateway config SHA `00c26526158088baba45a8499389bee708ace3be8194b84778ff3f0b573a3ac9`;
closure `/nix/store/z4mglka9jzbr1yssdkjnxwy0ipgylhw2-nixos-system-claw-26.11pre-git`.
No Laure conversation was read and no Laure agent run was created.

Budget: **zero live eBay HTTP attempts, zero writes**. Only metadata and the
local draft read ran. Static client operation events in the complete post-deploy
server journal also count zero across the persistence restart. New live
message/offer parsing, writes, physical phone card approval and actual scheduled
model behavior remain unverified; no live write/Verify/photo was attempted.
Daily price action can be skipped when no-sale information is unavailable.
Evidence and copied local Nix-shebang scripts: `/tmp/ebay-selling-evidence/` on Zao.

Rollback: retain state and inspect concurrent changes first. Disable the
persisted automation through the gateway API (rolling back Nix alone does not
remove gateway-owned jobs):

```sh
ssh -F /dev/null root@yari 'nixos-container run claw-simon -- openclaw-admin gateway call cron.update --json --params '\''{"id":"819b4130-7f43-478d-9033-acadb60db88d","patch":{"enabled":false}}'\'''
```

Then use the guarded Yari switch procedure with **generation 42**
(`/nix/store/63ggdbwsfxpazwkms2x3y6s8xjk2dxh7-nixos-system-yari-26.11.20260923.4975466`),
which preserves Laure. Rakku **generation 149**
(`/nix/store/sb23bpsbpk5sam2frssd74nfr7dqdnnh-nixos-system-rakku-26.11.20260923.4975466`)
restores its immediate pre-release eBay configuration without undoing other
sessions' earlier deployments. Set the selected system profile then run that
closure's `bin/switch-to-configuration switch`; never build on Rakku. Keep
`/var/lib/private/ebay`, both secrets and proxy identity. Prefer a forward revert
and rebuild if subsequent generations carry unrelated work.
## Personal Gmail reader — step 2 (2026-11-12)

Simon approved only this gateway wiring step. `claw-gmail` on Rakku remains
unchanged. Only Simon's per-person descriptor declares it. The `mail` agent
uses `front-door/claude-opus-5-5`, its own workspace and agent auth directory,
no skills, explicit `tools.exec.mode = "deny"`, and an explicit allowlist of the seven projected Gmail tools plus
`session_status`. Unlisted tools are unavailable. `main` denies `claw-gmail__*`.
Do not add `mail_send`, a general Google endpoint, shell access or a mail poll.

`tools.sessions.visibility` stays `agent`. Simon alone enables agent-to-agent
access with participants `main` and `mail`; `main.tools.agentToAgent.send` is
`["mail"]` and the reader's is `[]`. Use `sessions_send` with `agentId: "mail"`,
not spawn or cross-agent history. The caller receives the reply to that turn.
Laure's outgoing access remains disabled, with only `laure` in her roster and
no Gmail server. Her login, role, conversations, device pairings and jobs do
not change. Never run her agent to test this feature.

The shared definition accepts optional `extraAgents`, `agentTools`,
`agentToAgent` and `extraAgentInstructions` from the person descriptor. Absent
fields preserve Laure's old policy. The drift check validates each actual
personal override before comparing the common generated config. A required
oneshot installs real, read-only instruction files before Simon's gateway:
bootstrap reads reject out-of-workspace symlinks. `mail` treats mail as
untrusted data, reports structured summaries, labels `Not Me` only after a
`not_mine` verdict, and performs no mailbox or draft change without an explicit
request from flakey. Flakey also treats summaries as untrusted. Tool isolation
is not a separate process or a guarantee against prompt injection.

Config authority: the installed **2026.11.3** package's docs on Yari:

- `docs/gateway/config-agents/entries-and-multi-agent.md:29-32,44-48,74-81`:
  name, workspace, agentDir, model, identity and empty skills list.
- `docs/tools/exec.md:140-150`: exec mode `deny` blocks execution at its own
  boundary as well as the tool allowlist. This also prevents the skill/MCP
  host-exec drift warning for the reader.
- `docs/tools/multi-agent-sandbox-tools.md:219-288`: per-agent tool allowlists,
  intersection with global policy and projected `<server>__<tool>` names.
- `docs/gateway/config-tools/sessions-and-subagents.md:25-30,33-97,129-133`:
  participant allowlist, directed send-only access, reply and visibility rules.
- `docs/gateway/security/prompt-injection.md:34-35`: restricted reader and the
  remaining risk of a summary manipulating the privileged recipient.
- `docs/gateway/protocol/operator-methods.md:33-50`: `tools.effective` requires
  a session key and only previews a warm MCP catalog. Run the read-only test
  first; a cold preview alone does not prove MCP confinement.

Validate with `openclaw`, `openclaw-people`, `openclaw-in-place`, native ARM
`openclaw-config` and Yari's toplevel drvPath. Before activation, compare the
running system to the output of the parent cairn commit, reject another active
switch and use `openclaw-wait-idle --check openclaw claw-simon`. Keep a counts-only
Laure baseline: sessions (including archived), paired devices and roster; do
not read her messages. After activation, compare those counts and pairing IDs,
check both health endpoints, run the one approved count/ownership delegation
and inspect tool-call names only. Delete both test sessions through
`sessions.delete` after the runs finish. Summarize the security audit without
changing existing exceptions. Record the generation and measured interruption.
Rollback with the retained pre-step system's `bin/switch-to-configuration switch`
and its profile, after checking for intervening deployments. A rollback does
not remove persistent mail workspace or test transcripts; delete test sessions
through the gateway, never by changing SQLite.

### Gmail reader deployment evidence — 2026-11-13 UTC

Code commits `75f74901` and `c5f656fc` landed fast-forward on `cairn` after
rebasing. Yari built both systems natively with remote builders disabled.
Generation **44** introduced the reader. Generation **45** adds explicit
reader exec mode `deny`; the initial audit had treated an empty skills list as
a host-exec boundary drift despite the tool allowlist. The explicit execution
deny fixes that warning without granting or removing any mail capability.

Final system:
`/nix/store/lxzj3skfjng70vpl11ig6ykbvz9sl05s-nixos-system-yari-26.11.20260923.4975466`.
Before each switch, the running system matched the built output of that commit's
parent on cairn. No other switch was running, and both gateways had zero
unfinished audit runs. Both switches stopped **only** Simon's container.
Health sampling measured **19.4 s** and **60.2 s** between the last healthy
sample and recovery. Laure had **0 s** interruption and did not restart;
sharing a definition did not change her generated closure in this step.
Both gateways' `/healthz` and root returned HTTP 200 afterward, with zero
gateway automatic restarts.

Passed: x86 `openclaw`, `openclaw-people` and `openclaw-in-place` focused checks;
Yari toplevel drvPath evaluation; native ARM `openclaw-config` real CLI validation
for both person configs; both native system builds; Nix formatting and whitespace.
The new roster assertion failed before implementation, then passed. No aggregate
flake check ran. ARM config validation reports its existing unwritable sandbox
log path; configuration validation itself succeeds.

The final real flakey delegation used a disposable `main` session and an
explicit disposable `mail` session (created through `sessions.create`). Its
query was `in:inbox is:unread newer_than:1d`, limit 100. Result: **32 unread**;
newest ownership verdict **unsure** (no approved rule matched). Audit metadata
shows one successful `mail_list` and one successful `mail_not_mine` by `mail`.
No label, archive, draft, discard or send tool ran. `tools.effective` on the warm
reader session shows exactly the seven Gmail tools plus `session_status`;
its core `toolAccess` list and projected `mcp` group must be combined. `main`'s
warm preview has no Gmail tool. Directed send lists and agent-only visibility
match the declared policy. Mail has no scheduled job.

Three disposable conversations (the first probe's parent, and the final probe's
parent/reader) were deleted with `sessions.delete`; zero explicit test sessions
remain. **Cleanup limitation:** direct `agentId: "mail"` on the first probe
selected the protected `agent:mail:main`. OpenClaw refuses main-session deletion.
That test-only context was reset through `sessions.reset`; OpenClaw retains its
reset history. No SQLite state was edited. Future tests must create and target
an explicit reader session key so both sides can be deleted. Private temporary
response dumps were removed; retained evidence contains counts and metadata.

Laure: **6 sessions (1 archived)** and **4 pairings**, unchanged session/device
IDs; zero pending pairings; roster only `laure`; no Gmail server or mail agent;
agent-to-agent disabled; identical private config SHA256 and unchanged container
and gateway invocation IDs. Her two existing jobs remain. No conversation text
was read and no test agent run was made on her gateway. All configured HTTP
MCP endpoints passed `tools/list` as the actual OpenClaw user: six on Simon's
gateway (Gmail exactly seven tools), four on Laure's. Final security audit:
**1 critical, 3 warnings, 1 info**, identical finding IDs to the pre-step audit.
The existing trusted-proxy critical and three existing warnings remain.

Evidence and copied Nix-shebang helpers use `/tmp/claw/mail-reader-*` on Zao and
Yari. Rollback to the pre-step generation **43** output, not 44:
`ssh -F /dev/null root@yari /tmp/claw/mail-reader-rollback.sh`.
The helper refuses a later deployment or an active turn and restores the profile
and system together. It does not erase persistent reader state or reset history.

## Personal Gmail — step 3: hourly filing and morning brief

Simon approved this step on 2026-11-12. Only his descriptor declares
`mailFilingJob`. The required oneshot reconciles `mountainous:mail-not-me`
through `cron.add` and `cron.update`, retaining its ID and history. It never
runs the job during activation. The job belongs to `mail`, runs at :15 each
hour in America/Denver, uses a fresh isolated session, has delivery `none`,
and disables failure alerts. Its finite tool cap contains only list, ownership,
label and archive: no body-read, draft, messaging or delegation tool.
Laure receives neither this job nor the new brief prompt.

The two-hour inbox window overlaps hourly runs. Only `mail_not_mine` verdict
`not_mine` permits `Not Me`, then whole-thread archive. Known mixed-ownership
threads are skipped. Each write has a stable per-message, per-action key.
A bounded second query recovers labelled messages left in the inbox after an
archive failure. Both queries share the 100-message cap. Unknown outcomes are
not retried with fresh keys. The agent reports incomplete work privately.
It cannot inspect unseen siblings of a thread with the metadata-only tools;
whole-thread archive retains the existing tool's semantics.

The 07:00 brief delegates read-only from main to mail. It requests at most eight
person-to-person inbox items, plus Not Me, unsure and unread counts. Gmail's
`newer_than:1d` counts receipt time, not the time a label changed; the brief
states that limit rather than claiming a filing timestamp. Unsure is computed
from ownership verdicts, not a new Gmail label or a second state store. Partial
pages produce lower bounds. An unavailable reader is one line, not a failed
whole brief. Delegated requests no longer authorize mailbox or draft writes;
only the hourly job's declared flow permits label/archive.

Installed 2026.11.3 docs on Yari are the config authority, rooted at
`/nix/store/rf8fr0x9k1v1xylfxc04jis1yqjdpx37-openclaw-gateway-2026.11.3/lib/node_modules/openclaw/docs`:

- `automation/cron-jobs/schedules.md:14-34`: cron expressions, timezone and
  explicit zero stagger.
- `automation/cron-jobs/payloads.md:29-67,140-143`: agent-turn message, timeout
  and finite `payload.toolsAllow` policy. The installed CLI serializer
  `dist/cron-cli-BJLw2-Bv.mjs:405-414` confirms the payload nesting; root-level
  `toolsAllow` is rejected by `cron.add`.
- `automation/cron-jobs/payloads.md:374-400`: isolated execution and fresh
  conversation history per run.
- `automation/cron-jobs/delivery.md:16-20,41-53,119-135`: `none` writes no
  conversation result; `failureAlert: false` disables alerts and owner repair.
  There is no main conversation binding on this job. The reader has no message
  tool or outgoing agent access.
- `automation/cron-jobs/managing-jobs.md:122-147,173-177`: manual force-run,
  wait for terminal status, declaration reconciliation and full job inspection.
- `automation/cron-jobs/managing-jobs.md:140-142`: explicit agent selection.

Before deployment, evaluate the parent cairn commit's Yari output and require
that exact running system. Refuse concurrent switches, check both gateways idle,
and compare Laure's candidate container closure/config/unit with the live ones.
Keep counts/IDs only for her sessions, pairings and jobs. After deployment,
check both health endpoints, every configured HTTP MCP tool list, the two
Simon's job declarations and Laure's unchanged process identities and job IDs.
Run only the hourly job once; never manually run the delivery-enabled brief.
Inspect tool metadata and Gmail label/INBOX state, not mail content.

Rollback must first disable the persisted `mountainous:mail-not-me` job through
`cron.update` (Nix rollback alone leaves jobs in SQLite). Then use the guarded
`/tmp/claw/mail-brief-rollback.sh`, which restores the pre-step closure/profile
and reconciles the prior brief prompt. Do not erase history or Google state.
Mailbox undo is separate: remove `Not Me` and add `INBOX` on the recorded IDs
only if Simon asks; system rollback cannot undo Gmail changes.

### eBay model-awareness deployment evidence (2026-11-13 UTC)

These are this run's verified generations, not the latest cairn tip or a claim
about later live generations. Rakku 152 was built from cairn commit
`3b4fd1d7d64f47be2a1c62e39ba4a4fcc546baf6`. Yari 46 was built from
`560bd06cb4425a6decd9d60be919506e04020a59` (its derivation is unchanged at
`3b4fd1d7`). Later commits, including `92d75023` (Gmail step 3), are deployed
by their own session, not this deployment. No further host operation was made
after that concurrent commit appeared.

Implementation `0695bf0e` and input follow-up `3b4fd1d7` pin eBay
`aae1854bf09c1f2eee375287e29c1533f00aeb2c` (including `0e20d5c2`). Only the
`ebay` lock node changed. The model now gets replacement IDs/values, exact live
price direction, recent confirmed card prices, and pending/done-today values
and UTC times. Disk-only summaries label saved baselines, not live prices.
Simon's skill requires fresh drafts/listings before advice, explains card clicks,
forbids a price-raising “drop”, and keeps replies after cards short, without tables.

| Host | Generation | System | Builder |
| --- | --- | --- | --- |
| Rakku | **152** | `/nix/store/apyq1zb0w3rq4b6g0x44py5j9vpkr1p1-nixos-system-rakku-26.11.20260923.4975466` | root@unzen; copied through Zao as root |
| Yari | **46** | `/nix/store/4b64i2rmar98kwcai3vxhycgpm8pfhi4-nixos-system-yari-26.11.20260923.4975466` | Yari; builders disabled |

Rakku first ran generation 151, then 152 for the saved-baseline wording fix.
Yari switched after the first Rakku switch; its derivation is identical under
the final input, so it needed no second switch. Rebased on latest origin/cairn
before builds and activation; both built derivations were rechecked. No target
switch or Simon agent run was in flight. Rakku only restarted ebay-server;
Yari only restarted Simon's container. No reboot. Other sessions' Gmail commits
`75f74901`, `c5f656fc`, and evidence `b1a5141e` are retained.

The required `claw-tools` check initially failed on a stale pre-Gmail assertion.
Separate commit `560bd06c` only replaces that assertion: Simon's exact seven-tool
Gmail filter, no mail_send, no Laure Gmail server. No Gmail behavior changed.

Passed: TDD HTTP regression (failed before implementation), **56 Rust tests**,
Rust fmt/clippy with warnings denied, **35 view tests**, byte-for-byte view build
check, and eBay `nix build`. Passed focused x86 `claw-ebay`, `claw-tools`,
`tailnet-names`, `openclaw`, `openclaw-people`, `openclaw-in-place`, both host
`toplevel.drvPath` evaluations, native ARM `openclaw-config`, Nix formatting,
whitespace, and all-other-lock-nodes equality. No aggregate flake check ran.

Through verified TLS as the OpenClaw user in `claw-simon`: initialize, all 14
descriptors (five app-only), seven views' committed full SHA256/stamp/MIME/image
CSP, unknown-tool refusal, and local `ebay_drafts` passed. The final text reports
**six pending**, **two confirmed writes today**, including Simon's **$15.00**
card approval for **137575778518** at **03:09 UTC on 2026-11-13**. The exact-config
CLI probe with empty throwaway state discovers exactly nine model-visible tools,
none app-only, approval `approve`, no diagnostics. Throwaway state was removed.
The serving gateway's `tools.effective` reports a cold/not-yet-connected MCP
catalog until the next agent turn; it does not yet prove the live nine-tool list.
No agent turn was started to warm it. Model adherence and phone clicks were not
exercised. The six other established endpoint tool lists pass.

One live listings read succeeded (count three). Complete static request events:
**two eBay HTTP attempts total**, one OAuth and one GetMyeBaySelling; **zero eBay
writes**, no retries. The final server invocation has zero HTTP attempts; the
single read was on generation 151 before the summary-only follow-up. Home
Assistant HTTP 200 and Z-Wave handshake/version passed; their, ai-gateway's,
all three Pi assistants', and the eBay proxy's start times are unchanged.
All 17 proxies are active. Simon gateway health is ok, zero automatic restarts,
started **03:34:09 UTC**. The new eBay skill is eligible and enabled.

Before either activation, `/var/lib/private/ebay` was backed up with numeric
owners, ACLs and xattrs to root-only
`/var/backups/ebay-awareness-20261113/ebay.tar` on Rakku. Final full-directory
inventory, modes, numeric ownership and all file SHA256 values equal the backup.
No draft state migration or cleanup occurred. Directory remains 0700; data
files 0600; service mount is ebay-server:ebay-server (host nobody:nogroup).

- drafts.json: `109ef964d1a55d11c64ea3af5801e6d69cc16bdbfbf4ad38bbe95b3f07ff7e2f`
- writes.jsonl: `e931010f5aaa7495e143367deec9efa955378889d8d0f4a0ee9a6b78f5da2de6`

Laure's live/candidate unit, container config, system closure and gateway config
were compared before activation. Full before/after/final evidence is identical:
container PID **1462903**, gateway PID **391**, both still started **2026-11-12
04:38:53 UTC**; InvocationIDs, system/config hashes and signed app profile equal
the selling-approval evidence above. No Laure restart or agent run occurred.

The same job **819b4130-7f43-478d-9033-acadb60db88d** stays enabled, declaration
`mountainous:ebay-selling`, `0 8 * * *`, America/Denver, no stagger. Next run is
**2026-11-13 08:00 MST (1794582000000)**. It was not run or edited.
Evidence and Nix-shebang scripts: `/tmp/ebay-awareness-evidence/` on Zao.

Rollback: retain the state directory; inspect intervening changes first.
Rakku generation **150** restores the prior server. Yari generation **45**
(`/nix/store/lxzj3skfjng70vpl11ig6ykbvz9sl05s-nixos-system-yari-26.11.20260923.4975466`)
restores the prior skill without removing the concurrent Gmail work or changing
Laure. Use the guarded switch procedure and do not disable the automation for
this text-only rollback. Prefer a forward revert after later host changes.

### Step 3 deployment evidence — 2026-11-13 UTC

Implementation `92d75023`, corrected payload nesting `40a41314`, pushed to
`cairn` fast-forward after rebasing. Concurrent eBay `3b4fd1d7` and evidence
`37c8373c` were preserved. Each activation required Yari's running output to
match that source commit's parent output. No host rebooted; Rakku was unchanged.

The first activation (generation **47**) installed the new brief but its filing
reconciler failed closed: `cron.add` rejects root-level `toolsAllow`. No hourly
job was created and no mail action ran. The installed CLI confirms that field
belongs inside `payload`. The correction and regression assertion landed before
the second activation. Final generation **48** is:
`/nix/store/gbw0winmm54djg2y62pdw5y3wk03nwbl-nixos-system-yari-26.11.20260923.4975466`.
Both switches stopped only Simon's container. Health sampling measured **19.9 s**
and **19.3 s** interruptions. Laure had **0 s**, no restart, identical container
unit/config store paths and bytes, unchanged container/gateway invocation IDs
and unchanged app profile. Her **6 sessions (1 archived)**, **4 pairings**,
zero pending pairings and two job IDs stayed unchanged. No conversation text
was opened and her agent was not run.

Verified the real scheduler declaration:
`ab4b714c-04c9-4980-a3b8-d5448351dfcf`, `mountainous:mail-not-me`, enabled,
agent `mail`, isolated, `15 * * * *`, America/Denver, zero stagger, delivery
`none`, failureAlert false, payload cap exactly the four filing tools.
Morning brief `66d2d1b5-48d2-45a1-b899-ec86179df374` retained its ID and schedule;
the deployed prompt matches source after the scheduler's trailing-newline trim.
It was **not run**. Its before/after prompt diff is retained as
`/tmp/claw/mail-brief-prompt.diff` on Zao. Laure has neither declaration.

The hourly job was manually force-run **once**, with completion `succeeded`,
status `ok`, duration **23.581 s**, `delivered=false`, delivery `not-requested`.
Run ID: `cron-request.d456b503-807d-4f87-93b2-b3df1de0956e`.
Both actual mail_list results were complete empty pages. Counts: **seen 0,
not_mine 0, mine 0, unsure 0, labelled 0, archived threads 0, errors 0**;
message IDs `[]`. Audit metadata proves exactly two mail_list calls and zero
body-read, label, archive, draft, discard or send calls. An independent
read-only claw-gmail check as the serving OpenClaw user confirmed zero messages
for both `in:inbox newer_than:2h` and `label:"Not Me" newer_than:2h`.
There were no labelled messages to verify or undo. **The live write branch
was not exercised**, because no qualifying mail arrived in the window; no mail
was manufactured or broadened into the run to produce a write.

Passed focused x86 `openclaw`, `openclaw-people` (generated-config drift) and
`openclaw-in-place`, Yari drvPath evaluations, native ARM `openclaw-config`
(real CLI validation for both people), both native system builds, Nix formatting,
whitespace and check-flake-inputs. The first new contract failed before code;
the final contract also rejects a root-level tool cap. Native config validation
retains the existing sandbox log-path warning. No aggregate check ran.
All six Simon and four Laure HTTP MCP tool lists passed as the serving user;
Gmail still exposes exactly seven tools. Both gateway health and root return
HTTP 200. Audit remains **1 critical, 3 warnings, 1 info**; no exception changed.

Helpers and counts-only evidence use `/tmp/claw/mail-brief-*` on Zao/Yari.
Rollback, only if no later deployment intervened:
`ssh -F /dev/null root@yari /tmp/claw/mail-brief-rollback.sh`.
It disables the persisted hourly job, checks both gateways idle, verifies
Laure's unchanged closure, restores pre-step **generation 46** output
`/nix/store/4b64i2rmar98kwcai3vxhycgpm8pfhi4-nixos-system-yari-26.11.20260923.4975466`,
and reconciles the previous brief without running it. It does not undo Gmail
changes or erase job history. Rollback was linted and inspected, not executed.
The bounded window can miss mail during outages over two hours or a sustained
100-message backlog; this step deliberately does not add a backfill poll.


## Simon's wind-down v1 — 2026-11-13 UTC

Code **3f6b7286** and verified-save wording correction **ffa86906** landed on
`cairn`. The first deployment was generation **49** at 21:11 UTC. Final
**generation 50**, healthy by 21:25 UTC, is:
`/nix/store/k8kjdkiwkwcpxkgdwdd9gv3hhw84sgc3-nixos-system-yari-26.11.20260923.4975466`.
Both systems and ARM config checks built natively on Yari, builders disabled.
Only `claw-simon` restarted. No reboot, plugin, ClawHub install, API key, or
Rakku/Pi/Logbook/SparkyFitness change was made.

The Simon descriptor enables `openclaw-wind-down` and adds only `show_widget`
to its existing exact tool policy. `group:runtime` remains denied. The skill
is in `lib/openclaw-skills/simon/wind-down/SKILL.md`; Laure gets neither the
skill, job nor widget permission. Cards use the existing Canvas baseline.
Ratings, capture and tomorrow notes write only to Flakey's private daily note.
Unavailable integrations are stated, not replaced with invented measurements.

The actual `openclaw-admin cron list --all --json` contains exactly one enabled
`mountainous:wind-down`, ID **d963c743-e6fe-47b4-8a67-94df999a735a**, agent
`main`, session `agent:main:main`, isolated, announce, **0 21 * * ***,
**America/Denver**, zero stagger, 60-second timeout. Its opener reads the exact
wind-down day's daily note, suppresses a recorded close with `NO_REPLY`, and
fails closed if memory cannot be checked. Scheduled openers are text only.
The five existing jobs' IDs, schedules, payloads, delivery and enablement
compare unchanged, including the **07:00 morning brief**. Neither delivery job
was run manually. The new oneshot retried once during startup, then reconciled.

Before each switch, current `origin/cairn`, the built derivation and running
parent output were checked. Both gateways were audit-idle. The guarded switch
compared Laure's unit/config bytes and store paths, system closure and private
config before activation; her process identities, profile, session IDs, device
IDs and job IDs matched afterward. Her **7 sessions (1 archived)** and **4
pairings** did not change. Health sampling measured Simon interruptions of
**61.3 s** and **22.5 s**, Laure **0 s**. The separate offline memory cleanup
stopped only Simon's gateway. Both gateways are healthy; Simon has zero automatic
restarts. Both switches returned success, not exit 4.

Verified in agent-browser, in two NEW conversations, not the main conversation:

- `agent:main:dashboard:0db835e8-e462-4668-b7b6-8da39e3ddfcd`
- `agent:main:dashboard:c398931c-b506-4b22-a69b-985d6dbe04e8`

Every answer was fictional and contained TEST. Both completed Rate, Day,
lookBack (charge 5), Capture, Tomorrow and Stop. Real `calendar_busy` reads were
successful empty days, so cards showed no busy blocks and tomorrow's one
08:00–22:00 calendar-free window. The capture textarea's actual Continue click
sent its explicit prompt into the same test session. Cards were inspected at
390×844 and desktop sizes. Progress showed six steps and updated with answers.
Audit metadata confirms each daily-note write was followed by a successful
read; no messaging, delegation or runtime tool ran. Each saved exactly one
Wind-down block with ratings, own-word capture and a date-labelled tomorrow
note with three must-dos. Screenshots for every step: **21 PNGs** under
`/tmp/claw/winddown-v1/` on Zao.

The first run said “saved” before Stop, despite not yet writing the file. The
wording correction was deployed and the whole normal flow rerun. The final run
said “noted, but not saved yet” while the file was absent, then wrote/read it and
closed plainly. No early save claim or post-close report remained in that run.
The installed ask_user schema has a hard four-option limit. Ratings therefore
show 1, 2, 3, “4 or 5”, followed by a 4/5 choice when needed; free text accepts
any 1–5 plus the optional note. This costs a follow-up for high button ratings.
No package or tool policy was expanded to bypass that limit.

Cleanup verified: both TEST blocks and test-created daily files were removed,
restoring the original absent `memory/2026-11-13.md`. Temporary test-note
backups were removed. With Simon's gateway stopped, `openclaw memory forget
--agent main --session <first-key> --session <second-key> --dry-run --json`
resolved exactly IDs `dbf651ee-17be-47ca-b4e9-1e1c3ce09e4a` and
`6bec8f7e-df27-4e73-93ca-3f79a8890dfb`; the real command succeeded. A repeated
preview had no tracked entries, mixed lineage or refusals. The two conversations
were then deleted through the Gateway; retained transcript archives remain
excluded by Forget. The browser was closed and its one temporary pairing removed.
No SQLite writes or deletion of gateway state files were used.

Passed focused x86 checks **openclaw**, **openclaw-people**, **openclaw-in-place**,
Yari toplevel evaluation, native ARM **openclaw-config** (both person configs),
both native system builds, Nix formatting and whitespace checks. The new check
first failed before implementation. Statix passes the new declaration/test and
person descriptor; the shared container/module retain their existing 7 warnings
(confirmed against the parent source). Ruff passes the retained Python cleanup,
proof and rollback helpers. ARM validation retains the existing sandbox log-path
warning; validation itself succeeds. No aggregate flake check ran.

Limits: midnight short mode, Sunday's weekly chart, nonempty/overlapping calendar
blocks and failure/skip branches are instructed, not exercised at their real
times in the browser. The 21:00 opener was deliberately
not force-run. This is an agent skill, not a deterministic workflow engine;
model adherence can vary. No disconnected source or burnout scale was tested.

Evidence and copied Nix-shebang operational helpers: `/tmp/claw/winddown-*` on
Zao/Yari. Immediate rollback is generation **49**:
`/nix/store/2wxmdfr4ajcm5rhdls60ja8ydrmyvqpc-nixos-system-yari-26.11.20260923.4975466`.
After checking for intervening deployments:
`ssh -F /dev/null root@yari /tmp/claw/winddown-rollback.py`.
That restores the previous skill wording, not removal of the feature. To remove
the feature, the helper's `--remove-feature` mode first disables the persisted
wind-down job through `cron.update`, then restores pre-feature **generation 48**:
`/nix/store/gbw0winmm54djg2y62pdw5y3wk03nwbl-nixos-system-yari-26.11.20260923.4975466`.
The helper refuses a later deployment or a Laure unit/config change. Nix rollback
alone does not remove gateway-owned jobs. Neither rollback was executed. Keep
real memory and job history; never restore the removed TEST data.


## Simon Family calendar writes and Undo — 2026-11-13

Simon's approved boundary is calendar read plus owned-event write. Google documents
`calendar.events.owned` as “See, create, change, and delete events on Google calendars
you own”: https://developers.google.com/workspace/calendar/api/auth. Simon owns
both primary and Family, so broader `calendar.events` is not needed. Retain
`calendar.readonly`: `calendar_busy` lists events across calendars and gog needs
calendar-list access; Family reads remain unchanged. OAuth refuses full calendar,
unowned-event write, settings and Gmail send-only grants. Existing Gmail modify
is unchanged (and itself includes sending capability); no send tool is exposed.

New `claw-family-calendar-simon` exposes only events/add/remove. The old Laure
`claw-family-calendar` remains read-only. Existing endpoints verify only that
WhoIs returns a tailnet node, so omitting a server from Laure's config would not
be a security boundary. The new proxy verifies **stable node ID
`nbQJZMcewG11CNTRL`**, measured from claw-simon's real Tailscale status, on every
request. HTTP identity headers, shared `tag:claw`, hostname and source-IP strings
cannot grant access. Re-enrolling Simon as a new node fails closed until this
explicit Nix allowlist is updated. Other endpoints keep their existing policy.
The shared proxy binary change restarts existing Rakku proxies, not assistants.

The Google app's durable write store is the authority for idempotency and Undo.
Keep it private and retain it across rollback. Remove permits only completed adds
recorded in the currently configured Family calendar. No arbitrary calendar,
attendees or notification-bearing tool is exposed. A timed event needs offsets;
all-day end dates are exclusive. The skill uses a labelled one-hour default when
Simon gives only a start; vague date/time asks one short question. Duplicate reads
and model adherence are skill policy, not a transactional cross-key uniqueness
constraint. Ambiguous outcomes are never retried with a new key.

### Consent handoff (do not start until Simon is ready)

1. Parent asks Simon whether he is ready. Preflight is untimed:
   `ssh -F /dev/null root@rakku claw-google-auth --check`.
2. Once ready, run `ssh -F /dev/null -t root@rakku claw-google-auth`. It uses the
   saved Google account. Press Enter through the intro; answer `y` only when
   ready for the ten-minute consent URL. No URL should be generated in advance.
3. Open the exact `https://accounts.google.com/o/oauth2/v2/auth?...` URL printed
   by the wizard, including its PKCE/state query. It can be opened on a phone;
   choose the saved account, approve calendar read plus owned-event write and
   existing Gmail modify. If shown, use Advanced to continue past Google's
   unverified-app warning. Do not broaden scopes or enable settings/send-only.
4. The phone/desktop browser ends on a **failed loopback page**. This is expected:
   the wizard does not run a callback web server. Copy the complete address-bar
   URL (`http://127.0.0.1:<port>/oauth2/callback?state=...&code=...`) and paste
   it into the wizard's hidden prompt. Do not share that URL in chat or logs.
5. The helper validates state, PKCE, age, scopes and account before importing
   the refresh token. The launcher restarts only assistant-app-simon-google and
   verifies reads. A successful read alone does not prove write scope: inspect
   imported scope **names only**, then use Simon's restricted endpoint.

After consent, first read 2026-11-14 to avoid a duplicate, then add “Lego Robotics
event”, 13:00–14:00 America/Denver (`-07:00`), location “Fort Collins (place TBD)”.
Read back and record the returned event ID. Test Undo only with a separate
“TEST – delete me” event on a read-confirmed empty date; read back after removal.
No real write or timed OAuth session runs before that handoff.

Rollback: revert the Simon server/permissions/skill and new endpoint, rebuild
Rakku then Yari with the existing Laure continuity guard. Keep Google write
store and tsnet identities. A system rollback does not delete calendar events,
revoke Google's grants, or erase persistent state. Undo events separately through
the restricted remove tool. Prefer a forward revert if later generations include
unrelated work; do not restart Laure. App rollback selects the prior application
profile then restarts **only assistant-app-simon-google**.


### Family calendar deployment evidence — awaiting Simon's consent

Implementation **28a28f8a** landed on cairn after fetch/rebase. Apps main contains
**9363d9f** plus **7bdd96b** (removes the temporary local dependency link from
tracked source). Final apps source is `7bdd96b6c1b297f8d10b27beab030a8b8c5917c3`.

| Host | Generation | Running system |
| --- | --- | --- |
| Rakku | **155** | `/nix/store/r56yg127y7a4p5mkd44y73x23wldbj49-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | **51** | `/nix/store/l5ijg6gxxxwm55c9qasq8vyavr0gcq7w-nixos-system-yari-26.11.20260923.4975466` |

Rakku was built on Unzen and copied through Zao, then deployed before Yari.
Yari built natively with remote builders disabled. App profile is
`/nix/store/s530c35x0l531lswij4gs44dgkqraash-pi-assistant-application`.
The default deploy script started rebuilding unrelated core main, so that run
was stopped before installation. The focused helper reuses the deploy script's
`build_package` and `assemble` seams: only apps came from new committed main;
core, web, tsgo and Atlas links compare exactly to the previous running profile.
Only assistant-app-simon-google restarted among assistant/app services.
The shared proxy binary restarted all 17 existing Rakku proxies; the new one
is active. SparkyFitness/Logbook application services were not changed.
All three Pi assistants, tsgo, Atlas, Home Assistant, Z-Wave and ai-gateway kept
their invocation/start identities. HA HTTP 200 and Z-Wave handshake/version passed.
Google's private `google.json` write store was absent before deployment (no
existing write ledger to back up). The switch prepared a root-only backup
directory but made no store file. The first real write creates the ledger;
retain that new ledger in place across upgrades and rollback.

Only claw-simon restarted on Yari; measured interruption **60.5 s**. Laure had
**0 s** interruption and unchanged container/gateway invocation IDs, byte-identical
unit/config paths and bytes, identical container closure and app profile.
Her **7 sessions (1 archived)**, **4 pairings**, zero pending pairings and job IDs
were unchanged. No Laure conversation was read or agent run created.

Passed: Google app **65 tests** (new regressions failed before implementation),
app syntax build and Nix app build; **20 OAuth/verifier tests**, wizard shellcheck;
five Go MCP boundary tests plus go vet; focused x86 `claw-tools`, `claw-google-auth`,
`tailnet-names`, `openclaw`, `openclaw-people`, `openclaw-in-place`; both host drvPath
evaluations; native ARM `openclaw-config`; Nix/Go formatting, Ruff and whitespace.
No aggregate flake check ran. The initial direct Go run lacked gcc; CGO_ENABLED=0
matched the packaged check and passed. Remote build wrappers initially failed on
argument/execute-mode errors before corrected direct invocation; no activation
ran in those failed attempts. Native config validation retains its known sandbox
log-path warning, but config validation succeeded.

Verified with TLS as the real OpenClaw user in both containers:
Simon's new endpoint initializes and lists exactly three tools with correct
read-only hints; Laure's tools/list **and add call return HTTP 403**. Spoofed
HTTP identity headers cannot bypass the tested node check. Simon's generic
`calendar_add_event` call returns -32601; a schema-invalid add is rejected before
execution. A real Family read of **2026-11-14** succeeded with **zero events**.
All seven Simon and four Laure HTTP MCP tool lists and both health/root routes
passed. Exact deployed-config CLI probe discovers the three qualified family
tools, approval `approve`, no diagnostics. Both family-calendar and wind-down
skills are eligible, enabled and model-visible. No live model write/card click
was exercised before consent. First TLS provisioning timed out once, then passed.

Untimed `claw-google-auth --check` passes. The scope-only keyring reader verifies
`ownedEventWriteImported=false`: fresh consent is still required. No OAuth window
was started, and no actual authorization URL was generated. The wizard now gives
phone address-bar/callback-copy instructions. Actual phone consent and widget
rendering are pending Simon/parent; mobile success is not claimed.
**No Google write occurred.** The real Lego event ID and throwaway Undo proof
remain pending consent and must be added to this evidence after sign-in.

Helpers/evidence: `/tmp/claw/family-*` on Zao and copied target scripts.
After consent run `ssh -F /dev/null root@rakku /tmp/claw/family-check-scopes.py --require-write`
(scope names only, no token export), then the approved real write and throwaway
Undo verification through Simon's endpoint. Preserve the durable add result ID.

Rollback (guarded, not executed):
- Yari first: `ssh -F /dev/null root@yari /tmp/claw/family-yari-switch.py /nix/store/l5ijg6gxxxwm55c9qasq8vyavr0gcq7w-nixos-system-yari-26.11.20260923.4975466 /nix/store/k8kjdkiwkwcpxkgdwdd9gv3hhw84sgc3-nixos-system-yari-26.11.20260923.4975466`.
  This restores generation 50's output with the same Laure continuity guard.
- Rakku: `ssh -F /dev/null root@rakku /tmp/claw/family-rakku-rollback.py`.
  It refuses later deployments and restores generation 154's output plus app
  `/nix/store/8smn0sbsvwx2rhav0zm4ir615zmmz3f2-pi-assistant-application`, restarting
  only Simon's Google app among assistant services. Keep state, events, grants
  and tsnet identities. Later deployments require a forward revert instead.


## Rename to flakey — 2026-11-14

Simon approved renaming his gateway's tailnet node from `claw-simon` to
`flakey`: **https://flakey.hummingbird-lake.ts.net**. He also approved that his
phone app and browsers pair again afterwards. It is the same node: the same
node ID `nbQJZMcewG11CNTRL`, IP `100.75.156.21`, tag, keys and container
state. Only the name changes.

### What changes, what stays

`lib/openclaw-people.nix` sets Simon's `nodeName = "flakey"`; his
`containerName` stays `claw-simon`. Everything that names the tailnet host
derives from `nodeName`:

| Names the tailnet host: now `flakey` | Names the container or a unit: stays `claw-simon` |
| --- | --- |
| `gateway.publicOrigin`, `gateway.controlUi.allowedOrigins` | container `claw-simon`, `container@claw-simon.service`, `ve-claw-simon` |
| `mcp.apps.sandboxOrigin` (`https://flakey.hummingbird-lake.ts.net:8443`) | state `/var/lib/nixos-containers/claw-simon` (sessions, pairings, memory, workspace) |
| `tailscale up --hostname` (first join only) and the OS hostname | `openclaw-wait-idle claw-simon`, the safe-switch and in-place scripts' container arguments |
| Laure's `peerNodeName`, so her Session Share source's `--host` | the tests' and checks' `host.containers.claw-simon` lookups |
| The key in `lib/tailnet-nodes.nix` (`flakey`, same ID) | the negative name inputs in `packages/ai-mcp-tsnet-proxy/routes_test.go` |
| The HTTPS certificate: Tailscale Serve gets one for the node's current DNS name on the first TLS request | the historical evidence in these documents |

The trusted-proxy settings name no host: `trustedProxies` is loopback, and
`claw-identity-proxy` matches `tag:mountainous`. The caller locks match the
stable ID, so `/mcp/sparkyfitness` on `ai`, the `ai-staging` echo row and
`claw-family-calendar-simon` need no change; Rakku's system does not change.
`routes_test.go` keeps its `claw-simon` negative inputs: they still prove that
names are refused, and a change there would rebuild and restart every Rakku
proxy for no behaviour change.

### How a rename takes effect

- `claw-tailnet` passes `--hostname` only to `tailscale up`, which runs only
  in `NeedsLogin` or `NoState`. A registered node ignores a changed flag and
  keeps its name, keys, ID and IP across restarts.
- The rename is a one-time `tailscale set --hostname=flakey` in the running
  container. tailscaled reports the new hostname; the control plane renames
  the machine (its name is generated from the hostname) and the DNS name
  follows. A tagged node does not authenticate again and keeps its tags. If
  the name were taken, the control plane would give `flakey-1`: the switch
  script then sets `claw-simon` back and stops.
- The tailnet policy matches tags and IDs, not machine names, so it needs no
  change. (The fleet OAuth client cannot read the policy; this is inferred
  from how Tailscale policies select nodes.)
- Serve's configuration is keyed by `<dns name>:<port>`. After the rename the
  script runs `tailscale serve reset`; `claw-tailnet` sets 443 and 8443 again
  under the new name when the container starts.
- Laure's Session Share source keeps its pairing. Its saved endpoint changes,
  but OpenClaw node tokens are not bound to an endpoint (2026.11.3,
  `node-host/gateway-auth`): with no environment or config credential, the
  source presents its stored node token to the new host.

### Laure stays up: her container switches in place

A `container@` unit lists the container's system as a restart trigger, so any
change to Laure's container system restarted her whole container and gateway.
The first commit sets `reloadIfChanged` for her container only
(`reloadContainerInPlace` in `lib/openclaw-people.nix`). The switch then
reloads the unit: its `ExecReload` runs `switch-to-configuration test` inside
the running container, and only the changed units restart. In this stage
that is `openclaw-session-share` alone; her `openclaw.json`, gateway unit and
`claw-tailnet` are byte-identical.

Rehearsal on flakey's container with its unchanged system
(`/tmp/claw/flakey-rehearse.py`): `systemctl reload container@claw-simon`
took 1.0 s, restarted no running service, and the gateway kept its process
and its uptime.

Cost: nspawn settings in the container conf (bind mounts, addresses) now take
effect only at a deliberate container restart. Removing the flag later
restarts her container once. flakey keeps restart-on-change.

### Deploy

On Zao, from a clean checkout at the landed rename commit. Never run the
aggregate flake check. Scripts in `/tmp/claw` on Zao, each with a Nix shebang.

```sh
EXPECTED_SOURCE_SHA=<landed rename commit>
# Rakku: evaluated only; stops if Rakku's derivation would change. Yari: the
# target, the REVERT system (the parent commit) and the ARM checks
# openclaw-config and openclaw-in-place-config, built natively, builders off.
/tmp/claw/flakey-build.sh "$PWD" "$EXPECTED_SOURCE_SHA"
/tmp/claw/flakey-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-yari
/tmp/claw/flakey-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" yari
/tmp/claw/flakey-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" accept
/tmp/claw/flakey-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" check-rollback-yari
```

`yari` waits until neither gateway has an unfinished run, then runs
`flakey-yari-switch.py forward` under `systemd-run` (unit `flakey-yari-switch`).
It refuses unless the target's `container@openclaw` unit carries
`X-ReloadIfChanged=true`, her config is byte-identical, every unit file in her
target container except `openclaw-session-share.service` is byte-identical,
both gateways are healthy and idle, and the node is `claw-simon` with the
expected ID. It checks idle again, renames, resets Serve and switches. It rolls
back at once, in the same unit, if the switch exits other than 0 or 4, health
does not return in 180 s, Laure's gateway or container restarted or her uptime
went back, her config changed, her container does not run the target's
container system, the node ID changed, or Serve is not exactly `flakey:443`
and `flakey:8443`. The rollback sets the hostname back, resets Serve and
switches to REVERT, never to the previous generation.

### Acceptance (`accept`, read-only)

1. Zao: `https://flakey.hummingbird-lake.ts.net/` serves the OpenClaw Control
   page over verified TLS; the certificate names flakey; `:8443` answers.
2. The node ID is `nbQJZMcewG11CNTRL` before and after; DNS name, hostname
   preference, OS hostname and Serve all say flakey.
3. From inside `claw-simon` as `openclaw`: every MCP server answers
   initialize and `tools/list` with exactly its filter (sparkyfitness 23), and
   one read-only call each. No writes.
4. OpenClaw's own CLI `mcp probe` of the deployed config lists every server
   with its tool count and no diagnostics.
5. Session Share both ways: each receiver invokes the other side's source
   once (`openclaw.sessions.list.v1`); counts only.
6. Laure: gateway InvocationID and container InvocationID unchanged, config
   unchanged, keyed `/v1/models` 200, her source's `--host` is flakey, her
   `claw-tailnet` untouched.
7. No failed units on Yari or in either container.
8. `claw-simon.hummingbird-lake.ts.net` no longer resolves (Zao and both
   containers).

### Rollback

Preferred, Laure's gateway stays up (her source restarts once more):

```sh
/tmp/claw/flakey-deploy.sh "$PWD" "$EXPECTED_SOURCE_SHA" rollback-yari
```

It waits only for Laure to be idle, sets the hostname back to `claw-simon`,
resets Serve and switches to REVERT (the parent commit's system: flakey's old
configuration, Laure's container still switching in place). flakey restarts.
Then revert the rename commit on cairn. The caller locks need nothing.

A rollback to the generation before both commits restarts Laure's container
once (the restart trigger returns). Only with Laure idle and her agreement:

```sh
ssh -F /dev/null root@yari /tmp/claw/flakey-launch.sh yari-rollback-full \
  /tmp/claw/flakey-yari-switch.py rollback \
  /nix/store/rfvqx5amjsyd6qcjf22fnv75nzap42a2-nixos-system-yari-26.11.20260923.4975466 \
  /nix/store/hxkrg1n16j4zds2py72j6w5nx09pw7cw-nixos-system-yari-26.11.20260923.4975466 \
  --allow-laure-restart
```

Without `--allow-laure-restart` the script refuses that target (checked).

### Deployment evidence — 2026-11-14 UTC

Landed on cairn as `672ead00` (in-place switch for Laure's container) and
`bc06d3bd` (rename), fast-forward from `54e37497`. Yari built natively,
builders off, both gateways idle. Rakku: evaluated only; its derivation
`mgqr767f0x4jd7wivch1j6m3wm3hdnb6` equals the running generation 158, so Rakku
was not built or switched.

| Host | Before | After |
| --- | --- | --- |
| Yari | 52 `/nix/store/hxkrg1n16j4zds2py72j6w5nx09pw7cw-nixos-system-yari-26.11.20260923.4975466` | 53 `/nix/store/rfvqx5amjsyd6qcjf22fnv75nzap42a2-nixos-system-yari-26.11.20260923.4975466` |
| Rakku | 158 `/nix/store/11a2g7zh8zmb286903b35js57znqrmi2-nixos-system-rakku-26.11.20260923.4975466` | unchanged |
| REVERT (not active; GC root `/nix/var/nix/gcroots/flakey-rename-revert`) | | `/nix/store/6s1ccb47lmal04bczra56d64ldy5fhmv-nixos-system-yari-26.11.20260923.4975466` |

- Built unit files, generation 52 → 53: on the host only `container@claw-simon`
  (restart trigger) and `container@openclaw` (restart trigger plus
  `X-ReloadIfChanged=true`), of 393. In Laure's container only
  `openclaw-session-share.service` (`--host flakey.hummingbird-lake.ts.net`),
  of 333; her `openclaw.json` SHA256 `00c26526…` is the same. In flakey's
  container `claw-tailnet`, `dnsmasq` and `nftables` (the hostname reaches
  `/etc/hosts`, which their triggers and the ruleset check include), of 345.
- Checks: x86 `openclaw`, `openclaw-people`, `openclaw-in-place`, `claw-tools`,
  `ai-mcp-proxy`, `tailnet-names`, `claw-ebay` on both commits; native ARM
  `openclaw-config` and `openclaw-in-place-config`; nixfmt 1.2.0; no whitespace
  errors. The new assertions failed before each change.
- Switch at 07:31:17 UTC under `flakey-yari-switch`: the rename converged in
  1.5 s (`claw-simon` → `flakey`, ID `nbQJZMcewG11CNTRL`), Serve reset, switch
  rc 0. Laure's container reloaded in place; her source restarted once at
  07:31:33–34 (`44c01861…` → `236a1175…`, NRestarts 0). flakey unhealthy
  60.9 s; Laure 0 s. Her gateway `5dbd700ddc1f4214b772e5a0522652ff` (PID 391)
  and container `16c35f6d…` kept their identities; her uptime kept growing.
  Her 8 sessions, 4 pairings, jobs and config did not change. No rollback.
- Acceptance 19/19 on Yari and 5/5 on Zao: node ID unchanged; DNS name,
  hostname preference, OS hostname and Serve (`flakey:443`, `flakey:8443`) all
  flakey; flakey's origins name flakey; every MCP server initialize and
  `tools/list` exactly its filter (sparkyfitness 23, ebay 14, gmail 7,
  scryer 5, family calendar 3, calendar, maps, web search, two demos) and one
  read call each (30/30); OpenClaw's CLI `mcp probe` lists all ten servers, no
  diagnostics; Session Share both ways (each side's source connected, one
  `sessions.list` each: 0 shared sessions on either side); keyed `/v1/models`
  200 with five models from both containers; no failed units; paired devices
  unchanged on both gateways. From Zao: `https://flakey.hummingbird-lake.ts.net/`
  is the OpenClaw Control page (HTTP 200, TLS verified), the Let's Encrypt
  certificate names `flakey.hummingbird-lake.ts.net`, `:8443` answers, and
  `/control-ui-config.json` returns 200 for Simon (trusted-proxy sign-in at the
  new origin). `claw-simon.hummingbird-lake.ts.net` resolves nowhere (Zao, both
  containers): `curl: (6) Could not resolve host`.
- Laure's source kept its pairing: it connected to flakey with its stored node
  token, no new pairing. Phone app and browsers have not paired again yet.
- Finding (not caused by the rename): at flakey's container start, tailscaled
  stayed in `NoState` for 48 s because it did not load its netmap cache, and
  `claw-tailnet` took the first-join `tailscale up --auth-key` branch. It
  failed before it reached Tailscale (no DNS yet), retried 15 s later in
  `Running`, and only set prefs and Serve. The node key and ID did not change.
  A successful `up` there would mint an auth key; treat a transient `NoState`
  as "wait", not "log in".
- Scripts, logs and evidence: `/tmp/claw/flakey-*` on Zao; copies on Yari.

### Re-pair after the rename (Simon)

His old pairings point at the old origin. Browser identities are kept per
origin, so every browser is a new device at the new origin. Do this when
Simon is ready: a setup code is valid for 10 minutes.

**OpenClaw Android app (phone `usu`):**

1. The operator mints a limited setup code in flakey's container and checks
   that it names `wss://flakey.hummingbird-lake.ts.net`:
   `ssh -F /dev/null -t root@yari nixos-container run claw-simon -- openclaw-admin qr --limited`.
   It shows a QR code and a setup code. Treat both as a password.
2. In the app: **Settings → Gateway → Add Gateway**, scan the QR code (or
   paste the setup code), check the confirmation names flakey, tap **Connect**.
   Grant the phone permissions it asks for. If the app shows **Pending
   approval**, the operator runs `openclaw-admin devices list` in `claw-simon`
   and approves only the request from `100.110.243.2` (usu):
   `openclaw-admin devices approve <requestId>`.
3. In **Settings → Gateway**, tap flakey so it has the checkmark. Then
   **Manage Gateways → claw-simon → Forget**. Forget deletes that entry's
   credentials, tokens, TLS pin and cached chats on the phone only; the
   conversations stay on the gateway and appear under flakey.
4. Check: `openclaw-admin nodes list` shows usu connected.

**Browser (Myoko's Chromium, the phone's browser):**

1. Open `https://flakey.hummingbird-lake.ts.net` in the usual browser
   profile, not a private window. Replace bookmarks; an installed app (PWA)
   from the old address must be installed again from the new one.
2. Sign-in is through Tailscale: no password. If the page says pairing is
   required, keep it open; the operator runs `openclaw-admin devices list` and
   approves only the `openclaw-control-ui` request from that machine's address
   (Myoko `100.117.218.54`, usu `100.110.243.2`). The page connects by itself.
3. Turn notifications on again in this page if they were on before.

After both work, remove the stale rows with `openclaw-admin devices remove
<deviceId>`: the old browser devices `f54b4e4d…` (Myoko) and `354ebb88…`
(usu's browser), and `9a68bc5f…` (usu app) only if the app paired as a new
device instead of reusing it. Check `devices list` first.

### Clients of the old URL

| Client | Where | Action |
| --- | --- | --- |
| Laure's Session Share source | `openclaw-session-share` in `openclaw` | follows `peerNodeName`; restarts once |
| flakey's own gateway origins | `openclaw.json` in `claw-simon` | follows `nodeName` |
| Simon's Android app (usu, device `9a68bc5f…`) | the app's saved gateway | re-pair (above) |
| Myoko Chromium (device `f54b4e4d…`) | browser site data for the old origin | re-pair (above) |
| usu's browser (device `354ebb88…`) | browser site data | re-pair (above) |
| Pi assistants, Forgerie, Home Assistant | Rakku, Unzen, Zao configuration and state | none found |
| `/var/lib/openclaw-pairing/join-claw-simon.json` on Yari | the used single-use join code from the handoff | none; it cannot be used again |
| Notes in other repositories (assistant ADR 0021 and handoffs, pace-service plan, ebay `CONTEXT.md`) | documentation | none; they name the container |
