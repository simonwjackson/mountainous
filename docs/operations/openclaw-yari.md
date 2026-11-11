# OpenClaw trial on Yari

## Placement and boundaries

| Service | Placement | State / address |
| --- | --- | --- |
| OpenClaw | Yari, `containers.openclaw` (nspawn) | `/var/lib/nixos-containers/openclaw` persisted under `/permafrost` |
| Claw overlay | Container's own tailscaled, `tag:claw` | `/var/lib/tailscale` inside the container |
| Home exit node | Unzen's main network, not its media VPN namespace | `100.120.204.5` |
| Model front door | Existing ai-gateway on Rakku | `https://ai.hummingbird-lake.ts.net/v1` |
| Control UI | Container loopback 18789, Tailscale Serve 443 | `https://claw.hummingbird-lake.ts.net` |
| MCP Apps sandbox | Container loopback 18790, Serve 8443 | `https://claw.hummingbird-lake.ts.net:8443` |

OpenClaw is untrusted execution. Its dedicated user has no capabilities, strict
filesystem protection, private temporary files, a 4 GiB memory cap, and write
access only to its state directory. The container has its own private network
and TUN device. Yari itself keeps Oracle egress for builds and Forgerie.

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
permits only `autogroup:internet:*` and `100.108.77.86:443` (ai-front-door).
It also permits `tag:claw-tools:443`. The fleet OAuth client, owned by
`tag:mountainous`, may mint `tag:claw-tools`; its tagOwners are
`autogroup:admin` and `tag:mountainous`. Members can reach Claw's 443 and 8443. This policy lives in Tailscale's admin
console, outside this repository. Never relax it to make registration work.

OpenClaw 2026.11.3 uses nix-openclaw's locked npm package, patches and Nix-mode
wrapper. nix-openclaw has no aarch64-linux flake package, so
`lib/openclaw-package.nix` supplies the pinned Node 24.22.1 ARM runtime.
All external release files are flake inputs. The official MCP React clock demo
2.0.4 is a pinned, self-contained release, tested offline over stdio. No runtime
npm installation is needed. No marketplace skills, messaging channels, browser automation, or elevated
tools are configured. Calendar and maps use the restricted remote endpoints below.

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

Each identity has only `tag:claw-tools`, enrolls with the existing fleet OAuth
client, and retains its state in `/var/lib/tsnet-proxy-claw-{calendar,maps}`
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

## Official interactive demos

The container also runs the official `@modelcontextprotocol/server-budget-allocator`
and `@modelcontextprotocol/server-system-monitor`, both **2.0.4**, matching the
React clock release. Their exact npm tarballs and content hashes are flake inputs.
`lib/openclaw-demo.nix` packages the self-contained JavaScript and HTML with the
same ARM Node runtime as the clock. No npm installation, outside service,
credentials, mounts, or additional permissions are needed. Both servers use
`--stdio` in declarative `mcp.servers`; neither opens an HTTP listener.

In a **new** Control UI session, ask “help me split a $5,000 monthly budget”
and “show me system stats”. The budget example uses business categories and
synthetic history/benchmarks, not personal finance data. Its initial budget is
$100,000; set the card's budget field to $5,000, then move an allocation slider.
The monitor polls its app-only `poll-system-stats` tool. It reads the container's
available OS metrics, including `/proc/meminfo`, not a remote machine; these
values need not equal the gateway's 4 GiB cgroup limit. The existing sandbox and
network restrictions remain unchanged.

To remove only these demos, remove `interactiveDemos` and its server merge from
`lib/openclaw-container.nix`, the two corresponding inputs from `flake.nix` and
`flake.lock`, and their names from the focused `openclaw` assertions. Keep the
shared package/test for `basic-react`. Run the focused check, evaluate Yari,
build the ARM config check and system on Yari, land on `cairn`, then deploy Yari.
No tailnet registration or saved service state needs removal. Existing chat
cards may no longer reconnect after removal. A Yari generation rollback restores
the former server configuration without deleting conversations.

## Daily morning brief

`morning-brief` runs at **07:00 America/Denver**, every day (`0 7 * * *`,
zero stagger, including DST). Each run is isolated and uses the normal default
model and full workspace persona (flakey). It reads today's `calendar_busy` and
returns one short message: busy blocks, calendar-free windows of at least 45
minutes within 08:00–22:00, one plain line about the day, and at most one question.
Empty calendars and failed reads are distinct. It has no task picks, mail,
health or training content. Maps may only use coordinates in event locations.

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

The grant `openclaw@yari` permits only chat_completions, responses and models,
with claude-opus-5-5 (default), gpt-6.1-sol and gemini-3.8-flash-high. Its cap is
USD 1/month and its rate is 300 requests/minute. The gateway's existing prepaid
provider exemption still applies; these three models use subscription routes.
No Jev, images or speech grant exists.

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

Deploy Unzen first. Confirm Unzen is advertised and approved (ExitNodeOption
true in another node's `tailscale status --json`). Deploy Rakku's grant, then
Yari. Root SSH works on these hosts; the simon account on Yari and Unzen needs
a sudo password. Do not reboot Rakku. Confirm Home Assistant, Z-Wave,
ai-gateway and all three pi-assistant units remain active after switching.

## Verify

Use `nixos-container run openclaw -- ...` or `machinectl shell` on Yari. Run
network probes as the OpenClaw user, not the trusted tailscaled UID. Check:

- Unzen and container `curl -4 https://ifconfig.me` return the same home IP;
  Yari's own probe still returns Oracle's IP.
- After stopping the container's tailscaled, an OpenClaw-user curl with a
  known public destination (`--resolve` to avoid a DNS-only failure) fails.
  Restore tailscaled and its `claw-tailnet` unit immediately.
- `/v1/models` returns 401 without a key, and succeeds with the OpenClaw key.
  Make one short completion using the default model.
- TCP to Rakku:22 and HTTPS to assistant.hummingbird-lake.ts.net fail.
- From Zao, load the Control UI, pair it, send a short chat, and capture a
  screenshot. Call the basic-react clock tool to inspect its MCP App.
- Run `openclaw security audit`, record its warnings and `free -m` on Yari.
  MCP Apps being enabled is an expected upstream security warning.

The application config is declarative and read-only. UI changes to config are
not the source of truth; edit this flake and deploy instead.

## Roll back / remove

For a failed switch, run `nixos-rebuild switch --rollback` on that host. Do not
reboot Rakku. A previous Yari generation stops the new container; a previous
Rakku generation revokes its grant. A previous Unzen generation removes the
unit but the Tailscale advertisement is a saved preference: explicitly run
`tailscale set --advertise-exit-node=false` when rolling it back. Do not clear
Tailscale state or service state during rollback.

To remove the trial completely: remove Yari's `openclaw` layer and its two
secret entries, remove the grant from ai-gateway and the encrypted copies,
build and deploy Yari and Rakku, then remove the unused flake inputs and code.
Disable Unzen's exit advertisement before removing its layer and deploy Unzen.
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
