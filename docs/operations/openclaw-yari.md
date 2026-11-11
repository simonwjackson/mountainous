# OpenClaw trial on Yari

## Decision: one gateway, two agents (2026-11-11)

Simon and Laure share this one gateway. Each person has an own agent: `main`
(Simon, persona flakey) and `laure` (persona from her own BOOTSTRAP.md
interview). Each person signs in as themselves through Tailscale and has a
non-admin role limited to the own agent, with `sessions.others: "view"`.
Publishing a conversation shares it with the other person. Admin work happens
only on the command line on Yari. OpenClaw 2026.11.3 has no setting that makes
new conversations start as Draft: the New session page always starts as
"normal". The sidebar's default "My sessions" filter only hides the other
person's conversations. It does not block them. Sign-in uses Tailscale Serve
run outside OpenClaw with `trusted-proxy` auth, not OpenClaw-managed Serve,
because managed Serve needs OpenClaw to have write access to the container's
tailscaled.

Session tools use `tools.sessions.visibility = "agent"` and `tools.agentToAgent.enabled = false`: each agent can access only its own sessions, including same-agent sub-agents.

Both agents share the research skill in `lib/openclaw-skills/research/SKILL.md`, with at most 8 children per parent and a 900-second timeout per researcher or auditor spawn.

The gateway has `TasksMax=2048`; the former 256-task limit exhausted under session MCP workers and caused `EAGAIN` on 2026-11-11.

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
4 seconds. A slow stop has one known cause. In OpenClaw 2026.11.3 the
`plugin-services` close step did not return in the two stops that followed a
research run with sub-agents. The gateway then waits until its deadline, writes
a stability bundle under `/var/lib/openclaw/logs/stability/`, and its watchdog
kills it 2 s later. At a 35 s limit that stop takes about 32 s. Which plugin
service does not return is not known.

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

Adds resolve `mine` (default) or `family` against
`libraries(facet:, permission: MANAGE_TITLES)`, then pass `libraryId` explicitly.
Anime always resolves to Anime. Missing libraries fail without a write.
Cards show `libraryName`, with Add for me and Add for family actions.
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
  and **Add for me** / **Add for family** / **Monitor**. A series asks which episodes first: all, future,
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
  internal reasoning behavior. Native context/output limits were not verified;
  no contextWindow or maxTokens override is set.
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
