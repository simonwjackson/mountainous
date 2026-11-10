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

Rakku retains Simon's existing loopback-only apps and their credentials. Its
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
- **Blocked at enrollment:** the fleet OAuth token succeeds (HTTP 200), but
  creating a key with only `tag:claw-tools` returns HTTP 400:
  `requested tags [tag:claw-tools] are invalid or not permitted`. The console
  policy had not been saved. Neither node is registered, so endpoint listings,
  live denials and real calendar/maps answers are not yet verified. No ACL was
  relaxed and no broader tag was substituted.
- Both units already retry automatically every 30 seconds. Once Simon saves
  the tag owner and destination rules, registration needs no code change.
  Immediate retry if needed: `sudo systemctl restart tsnet-proxy-claw-calendar
  tsnet-proxy-claw-maps` on Rakku. Then verify each node has only
  `tag:claw-tools`, run the container endpoint probes, and ask OpenClaw for
  calendar busy blocks and a real route. Test coordinates from Wikipedia's
  coordinate API: Denver Union Station `(39.75305556, -105)` to Colorado State
  Capitol `(39.7392321, -104.9848677)`; these are not invented locations.
- Local evidence and copied probe scripts: `/tmp/claw-tools-evidence/`,
  `/tmp/claw-tools-probe` and `/tmp/claw-yari-health` on Zao (scripts also on
  Yari). Do not record calendar event titles, mail, or credential values here.
