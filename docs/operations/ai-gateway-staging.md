# AI gateway staging on Rakku

This is an additive staging service, not a production cutover. Do not change
CLIProxyAPI, LiteLLM, Pi, the assistants or client keys to test it. This runbook
does not authorize a deployment. Sandbox verification runs transient test units
on Zao only.

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
  The static system user and group `ai-gateway-staging` own that directory with
  mode 0700. That directory is persisted on Rakku's permafrost volume.
  Do not change `/var/lib/private`. Its existing 0755 mode belongs to production
  state and prevents use of DynamicUser with StateDirectory on this host.
  Tailnet identity state is persisted by `tailnet-names` as for its other names.

## Source pin: private Git over SSH

The input is now `git+ssh://git@github.com/simonwjackson/ai-gateway?ref=main`,
locked to the same tested revision. The repository is private. SSH avoids the
GitHub API token requirement. Only enabled Rakku instances force the input.
Other hosts passed toplevel evaluation with an unavailable input URL and
revision. See [the production runbook](ai-gateway.md) for that proof and the
separate production/client cutover checks.

The module keeps the TOML in one `settings` attrset, generated with
`pkgs.formats.toml`. It follows `examples/front-door.toml` at ai-gateway commit
`3924b6597d9ef4af515d617efe0d71bad569b38c`. Optional paid chat models declare the
positive context windows needed for cap reservations: DeepSeek 1,048,576 and
Grok 4 256,000 tokens, each with an 8,192-token output ceiling. The focused
check evaluates those optional-provider settings too. It checks that two fixed
Jev charges fit test-b's cap and a third does not. With these conservative prices,
reserving the full context can exceed test-a's USD 2 cap. Enabling a
provider does not guarantee that this small grant can use its chat model.

## Credentials

Systemd `LoadCredential` copies root-readable sops files for the non-root
front door. No credential value is in the Nix store, TOML, environment or command line.

| Credential | Encrypted source | Use |
| --- | --- | --- |
| `ai-staging-test-a` | `secrets/hosts/rakku.yaml` | Staging test grant |
| `ai-staging-test-b` | `secrets/hosts/rakku.yaml` | Small paid-cap test grant |
| `ai-staging-usage` | `secrets/hosts/rakku.yaml` | Read-only usage endpoint |
| `ai-staging-login-keeper` | `secrets/fleet.yaml`, key `pi-cliproxyapi-api-key` | Existing CLIProxyAPI client key |
| existing `cliproxyapi-gemini-api-key` | `secrets/hosts/rakku.yaml` | Direct Gemini images and GPT-image fallback |
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
speech provider is enabled.

Gemini image requests go directly to the paid Gemini API with the requested
model ID. All six existing Gemini image grants have a catalog entry and a
USD 1 per-image staging ceiling. These are ceilings, not verified tariffs.

Test-a also allows `gpt-image-2` through the login keeper first. That subscription
model has no paid-model or price entry. A successful keeper call does not charge
the paid cap. A 429 or known plan exhaustion can use the configured paid Gemini
fallback, `gemini-3.1-flash-image`, at its USD 1 ceiling. A keeper 400 never
triggers paid fallback. All paid image calls still require remaining paid cap.

## Grants and staging accounting

| Key | Models / dialects | RPM | Monthly paid cap |
| --- | --- | --- | --- |
| test-a | Listed subscription, decision, image and speech IDs. All nine gateway dialects | 10 | USD 2 |
| test-b | `jev`. `systemone` only | 10 | USD 0.01 |

**Test-b differs from the initial chat-completions-only request.** The parent
approved a System One / Jev grant because no independent paid chat-provider key
exists. This tests the cap with the existing Typesafe key, without expanding the
Gemini image key's purpose. The `systemone_charges` table sets a fixed USD 0.004
charge for each Jev or Solar attempt. This is a **ceiling, not a tariff**.
Two successful Jev calls spend USD 0.008 of test-b's USD 0.01 cap. The third
call must fail before an upstream call because its reservation exceeds
the cap. A confirmed unbilled attempt releases its reservation. An ambiguous
failure retains its charge. Keep requests minimal.

Every configured paid price is nonzero and deliberately a **ceiling, not a
tariff**. They are not verified provider bills. Gemini images reserve USD 1
per image. Optional speech reserves USD 500 per million characters. Optional
paid chat uses USD 10/50 per million input/output tokens. System One reserves
and settles the fixed charge for each attempt, not a token estimate. The
`prices.jev` and `prices.solar` reporting entries use the same fixed ceiling.
Plan prices (Claude USD 200, Codex USD 200, Antigravity USD 20) are estimates
for plan-share accounting.
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
proxy does not cache content. Its native access log records CONNECT targets
and outcomes, including denied requests. It does not record authorization
headers or request bodies. Read `/run/ai-gateway-staging-egress/access.log` as
root. Startup diagnostics are in `cache.log` in that same mode-0700 runtime
directory. Logs survive automatic restarts but are removed when the unit stops.
Its cost is a second service, local log storage and DNS-dependent availability. A new provider needs both configuration
and a reviewed allowlist change. There is no CORS setting.

The front door uses the static non-root account `ai-gateway-staging`. The
proxy retains DynamicUser. Both units retain strict filesystem protection,
private read-only temporary directories, no capabilities, restricted address
families and `@system-service` syscalls, and a 512 MiB memory limit. The front
door can write only its state directory. Its `/dev/shm` remains read-only.

Squid 7.6 creates IPC metadata even with `memory_cache_shared off` and
`cache_mem 0 MB`. The proxy therefore gets a private writable 16 MiB tmpfs at
`/dev/shm`, mounted nosuid, nodev and noexec. It never uses the host's shared
memory mount. Its only other writable directory is its private runtime
directory. This exception adds a bounded memory cost.

The first staging deployment found two startup defects that an ordinary
process test did not catch. DynamicUser rejected Rakku's existing 0755
`/var/lib/private`. Squid could not open the journal socket through
`/dev/stderr` and could not create IPC metadata on read-only shared memory.
The static front-door owner, runtime log files and private shm mount fix these
paths without changing production directory permissions.

## Bounded verification (no deployment)

Do not run `nix flake check`: repository AGENTS forbids it after a fleet memory
incident. Use these focused commands sequentially:

```sh
nix build .#checks.x86_64-linux.ai-gateway-staging --no-link \
  --max-jobs 1 --cores 1 --option builders ''
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath \
  --option eval-cache false
# Once production is present, use the phase-A/B diff commands in ai-gateway.md.
```

For sandbox changes, run this test on Zao before the commit:

```sh
./scripts/test-ai-staging-sandbox --output /tmp/ai-staging-sandbox-proof.json
```

The test requires Zao's passwordless sudo wrapper. It reads the evaluated
Rakku service properties and starts transient units with those properties.
Only unit names, the test config path and synthetic credential paths differ.
It refuses existing state paths, test units and occupied ports. It creates a
root-owned 0700 state directory and verifies that systemd gives it to the
static service account. It checks `/v1/models` without a key returns 401.
It checks a non-allowlisted CONNECT returns 403 and appears in the access log.
It verifies the private 16 MiB shm mount, zero restarts and clean shutdown.
It removes its own state, transient units and any test account it created.
It checks that `/var/lib/private` ownership and mode are unchanged. It does
not contact Rakku or a provider and never reads production credentials.

The real sandbox test on Zao does not prove sops decryption, tailnet joins or
impermanence activation on Rakku. Verify those after an approved deployment.

Run the focused build and evaluation diff again on the final commit.
The focused check inspects the generated
TOML, evaluates the systemd invariants, parses the real Squid configuration,
and sends 13 denied requests to the real proxy (including a provider hostname
forced to resolve to loopback). It verifies that those denials appear in the
access log. It makes no external provider call. It also
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
