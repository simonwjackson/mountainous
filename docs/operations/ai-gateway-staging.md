# AI gateway staging on Rakku

This is an additive staging service, not a production cutover. Do not change
CLIProxyAPI, LiteLLM, Pi, the assistants or client keys to test it. No host was
deployed, switched or restarted while preparing this change.

## Identity and placement

- Placement: Rakku only. The `ai-gateway-staging` layer declares the feature.
  Rakku sets `mountainous.features.ai-gateway-staging.enable = true`.
  Disabling the feature removes its units, secrets, tailnet name and state
  persistence declarations. It does not delete saved service state.
- Identity: `https://ai-staging.hummingbird-lake.ts.net`, using the existing
  fleet OAuth tailnet-name mechanism. Its backend is `http://127.0.0.1:8420`.
- Units: `ai-gateway-staging`, `ai-gateway-staging-egress`,
  `tsnet-proxy-ai-staging`. Ports 8420 and 8421 were free in Rakku's `ss -lnt`
  output on 2026-10-26. Check again before an approved deployment.
- Service state: SQLite usage and key hashes in `/var/lib/ai-gateway-staging`.
  Systemd manages the DynamicUser backing directory under `/var/lib/private`.
  That directory is persisted on Rakku's permafrost volume. Tailnet identity
  state is persisted by `tailnet-names` as for its other names.

## Source pin: publication blocker

`flake.nix` has one temporary `ai-gateway` URL:
`git+file:///home/simonwjackson/code/sandbox/ai-gateway?ref=front-door`.
`flake.lock` records its immutable commit. The staging layer alone consumes
its package. Other host configurations do not consume the input, but resolving
or updating the whole flake's inputs and evaluating Rakku's staging unit need
this local repository. Do not push cairn with this URL.

Before sharing cairn:

1. Publish ai-gateway.
2. Replace this URL.
3. Update only its lock entry.
4. Repeat the focused checks.

The cost of this temporary arrangement is no portable full-flake
input resolution until publication.

The module keeps the TOML in one `settings` attrset, generated with
`pkgs.formats.toml`. It follows `examples/front-door.toml` at ai-gateway commit
`e0f6568503f6f714ad49820003c5c87467016890`. Optional paid chat models declare the
positive context windows needed for cap reservations: DeepSeek 1,048,576 and
Grok 4 256,000 tokens, each with an 8,192-token output ceiling. The focused
check evaluates those optional-provider settings too. With these conservative
prices, reserving the full context can exceed test-a's USD 2 cap. Enabling a
provider does not guarantee that this small grant can use its chat model.

## Credentials

Systemd `LoadCredential` copies root-readable sops files for DynamicUser. No
credential value is in the Nix store, TOML, environment or command line.

| Credential | Encrypted source | Use |
| --- | --- | --- |
| `ai-staging-test-a` | `secrets/hosts/rakku.yaml` | Staging test grant |
| `ai-staging-test-b` | `secrets/hosts/rakku.yaml` | Small paid-cap test grant |
| `ai-staging-usage` | `secrets/hosts/rakku.yaml` | Read-only usage endpoint |
| `ai-staging-login-keeper` | `secrets/fleet.yaml`, key `pi-cliproxyapi-api-key` | Existing CLIProxyAPI client key |
| existing `cliproxyapi-gemini-api-key` | `secrets/hosts/rakku.yaml` | Gemini image fallback only |
| existing `litellm-env` | `secrets/hosts/rakku.yaml` | `TYPESAFE_API_KEY`, `UPSTAGE_API_KEY` |

Three independent random 32-byte keys (hex encoded) are already encrypted for
Simon and Rakku. No manual sops step is required for these initial grants.
Existing encrypted entries are unchanged. The login-keeper declaration reads
the same fleet key that `modules/pi.nix` puts in `CLIPROXYAPI_API_KEY` while
calling the production CLIProxyAPI endpoint. It does not change Pi's secret
ownership or its unit. Reading Pi's use verifies the intended existing client
credential. No paid provider request was made to test it.

The reused Gemini/dotenv secrets retain their existing restartUnits. After an
operator rotates either one, restart the staging front door too in an approved
maintenance step: credentials are loaded at service start, not reread live.

### Optional providers

ElevenLabs, xAI and OpenRouter are disabled. No sops entry is required for a
disabled provider. To enable one later:

1. Run `./scripts/secrets secrets/hosts/rakku.yaml`. This wraps sops with
   Simon's SSH-derived age identity.
2. Add the corresponding key below in the editor. Do not put secret values in
   a shell command. Do not commit plaintext.
3. Set `mountainous.features.ai-gateway-staging.providers.<provider>.enable = true`
   on Rakku in a reviewed change. This declares the new sops secret and credential.
4. Verify its model IDs and conservative prices.
5. Repeat the focused check.
6. Review the evaluated diff. Allow only the expected extra secret.

| Provider | Host sops key to add |
| --- | --- |
| `elevenlabs` | `ai-staging-elevenlabs-api-key` |
| `xai` | `ai-staging-xai-api-key` |
| `openrouter` | `ai-staging-openrouter-api-key` |

OpenRouter's key is not in fleet sops. Do not read CLIProxyAPI's private config
to copy it. `deepseek-v4.1-flash` remains allowed through the login keeper's
existing catalog until a reviewed separate paid OpenRouter key is supplied.
Speech models remain in test-a's grant, but requests fail clearly until a
speech provider is enabled. Only the configured image fallback has a paid
Gemini price. Other granted image IDs use subscriptions and have no paid fallback
price of their own.

## Grants and staging accounting

| Key | Models / dialects | RPM | Monthly paid cap |
| --- | --- | --- | --- |
| test-a | Listed subscription, decision, image and speech IDs. All nine gateway dialects | 10 | USD 2 |
| test-b | `jev`. `systemone` only | 10 | USD 0.01 |

**Test-b differs from the initial chat-completions-only request.** The parent
approved a System One / Jev grant because no independent paid chat-provider key
exists. This tests the cap with the existing Typesafe key, without expanding the
Gemini image key's purpose. Jev's staging ceiling is USD 0.005 per request: two
successful paid decisions fill the cap. The next must fail before an upstream
call. A failed upstream request can leave the cap unchanged. Keep requests minimal.

Every configured paid price is nonzero and deliberately a **ceiling, not a
tariff**. They are not verified provider bills. Gemini images reserve USD 1
per image. Optional speech reserves USD 500 per million characters. Optional
paid chat uses USD 10/50 per million input/output tokens. Solar reserves
USD 0.01/request plus USD 1/1 per million tokens. Plan prices (Claude USD 200,
Codex USD 200, Antigravity USD 20) are estimates for plan-share accounting.
Replace estimates with verified tariffs before production. This conservatism
reduces available test traffic. It does not prove that every future provider
price is below the ceiling. Subscription traffic has no paid API charge.

## Egress and sandbox

The front door denies all IP addresses except `127.0.0.1/32` and `::1/128`.
The login keeper at port 8317 is its only direct upstream. All external
provider calls use the loopback CONNECT proxy at port 8421.

Squid is chosen over a simple domain-filter proxy because its `dst` ACL also
rejects allowed hostnames that resolve to private/reserved addresses. It accepts
only CONNECT, only port 443, and only these exact names (no suffix wildcards):
`api.elevenlabs.io`, `api.x.ai`, `openrouter.ai`, `api.typesafe.ai`,
`api.upstage.ai`, `generativelanguage.googleapis.com`.
LiteLLM's `litellm/llms/typesafe/decisions/transformation.py`,
`get_default_api_base`, confirms `https://api.typesafe.ai`.

It denies private IPv4/IPv6, loopback, link-local, CGNAT `100.64.0.0/10`,
multicast and reserved test ranges, and all other requests by default. The
proxy does not cache content or log requests. Its cost is a second service and
DNS-dependent provider availability. A new provider needs both configuration
and a reviewed allowlist change. There is no CORS setting.

Both units use DynamicUser, strict filesystem protection, private read-only
temporary directories, no capabilities, restricted address families and
`@system-service` syscalls, and a 512 MiB memory limit. The front door can write
only its state directory. The proxy has only its private runtime directory.
Kernel-enforced IP filtering and systemd sandboxes still need an approved
on-host verification after deployment. They were evaluated, not activated.

## Bounded verification (no deployment)

Do not run `nix flake check`: repository AGENTS forbids it after a fleet memory
incident. Use these focused commands sequentially:

```sh
nix build .#checks.x86_64-linux.ai-gateway-staging --no-link \
  --max-jobs 1 --cores 1 --option builders ''
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath \
  --option eval-cache false
./scripts/check-ai-staging-rakku --base cairn --candidate HEAD \
  --output /tmp/ai-staging-rakku-diff.txt
```

Run these again on the final commit. The focused check inspects the generated
TOML, evaluates the systemd invariants, parses the real Squid configuration,
and sends 13 denied requests to the real proxy (including a provider hostname
forced to resolve to loopback). It makes no external provider call. It also
checks that disabling the feature removes its declarations. It proves that the
evaluation-diff guard rejects production changes.

The diff script evaluates cairn and the selected commit sequentially. It
compares all unit names and every service's ExecStart/environment, all secret
declarations (normalizing only the sops source's store hash), and tailnet-name
config. It also checks that existing encrypted host-secret entries are byte
identical. Only the three new units, four staging secret declarations and
`ai-staging` tailnet name can differ. Output lists changed field names, never
environment or secret values. This does not compare unrelated NixOS options.
Review the Git diff as well.

An operator must separately approve deployment. After that, verify the new
units, tailnet join, usage endpoint, grant rejection and paid-cap rejection
before any production cutover. To roll back, set
`mountainous.features.ai-gateway-staging.enable = false` in a reviewed change.
Keep or archive its usage and tailnet state. No production service state belongs
to this service.
