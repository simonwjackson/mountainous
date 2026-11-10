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
Members can reach Claw's 443 and 8443. This policy lives in Tailscale's admin
console, outside this repository. Never relax it to make registration work.

OpenClaw 2026.11.3 uses nix-openclaw's locked npm package, patches and Nix-mode
wrapper. nix-openclaw has no aarch64-linux flake package, so
`lib/openclaw-package.nix` supplies the pinned Node 24.22.1 ARM runtime.
All external release files are flake inputs. The official MCP React clock demo
2.0.4 is a pinned, self-contained release, tested offline over stdio. No runtime
npm installation is needed. No marketplace skills, messaging channels, Google
app, browser automation, or elevated tools are configured.

Security review on 2026-11-10 read all 722 published OpenClaw advisories using
GitHub's cursor pagination. The highest published fixed version was 2026.9.3.
The old GHSA-7xr2-q9vf-x4r5 lists no patched version and a vulnerable range
`<= 2026.2.22`; a release version alone does not prove that old report resolved.
Keep treating the service as hostile and keep its boundaries in place.

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

- Running generations: Unzen 54, Rakku 127, Yari 10.
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
  zero service restarts. Screenshots: `/tmp/claw/control-chat.png` and
  `/tmp/claw/mcp-app.png` on Zao; probes and health logs are beside them.
