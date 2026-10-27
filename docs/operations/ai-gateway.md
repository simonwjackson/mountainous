# Production AI gateway and the first client cutover

Simon deploys Rakku. These changes do not authorize an automated switch.
Keep the production instance and the first client cutover as separate commits.

## Source and evaluation

The private input is `git+ssh://git@github.com/simonwjackson/ai-gateway?ref=main`.
The tested revision is `3924b6597d9ef4af515d617efe0d71bad569b38c`. Its source
hash is unchanged from staging. No GitHub API token is needed. Rakku evaluation
and builds need a GitHub-authorized SSH identity. Other hosts do not force the
input. Lock updates still need access to the private repository.

The negative-source test replaced both the URL and locked revision with an
unavailable local Git source and an unknown revision. Unzen and Myoko toplevel
evaluations passed with evaluation caching off. Rakku's gateway ExecStart
failed on that source as expected. The test restored the real input in a
`finally` block. Its output is `/tmp/ai-gateway-unused-input-proof.txt`.

## Commit A: add production, do not change clients

The `ai-gateway` layer declares `mountainous.features.ai-gateway.enable`.
Rakku enables it beside the unchanged staging feature. Both instances use
`lib/ai-gateway-instance.nix` and the same sandbox and provider allowlist.
Their identities, accounts, state, ports and gateway keys remain separate.

| Instance | Front door | Egress | Account and state | Tailnet name |
| --- | --- | --- | --- | --- |
| staging | 127.0.0.1:8420 | 127.0.0.1:8421 | ai-gateway-staging, /var/lib/ai-gateway-staging | ai-staging |
| production | 127.0.0.1:8430 | 127.0.0.1:8431 | ai-gateway, /var/lib/ai-gateway | ai |

Production units are `ai-gateway.service`, `ai-gateway-egress.service` and
`tsnet-proxy-ai.service`. The tailnet proxy serves
`https://ai.hummingbird-lake.ts.net`. A read-only `ss -lnt` on Rakku found ports
8430 and 8431 free before this change. Check again before deployment.

The front door uses a static system account and a persisted 0700 state
directory owned by that account and group. Its only writable state path is
that directory. It retains loopback-only IP access, strict system and home
protection, private read-only temporary directories, no capabilities,
`@system-service` syscalls, restricted address families and a 512 MiB limit.
The proxy uses DynamicUser, a private 0700 runtime directory and private,
bounded 16 MiB shared memory. It accepts only provider-host CONNECTs on 443.
It denies private, link-local and CGNAT destinations. There is no CORS setting.

The new account uses the same nologin executable by path. Using the default
shell package would duplicate `shadow` in `system.path` and change D-Bus's
reload trigger. This path setting avoids a new change to a running unit.
The older staging account remains unchanged.

### Credentials and grant

Two independent random 32-byte values are encrypted in
`secrets/hosts/rakku.yaml`: `ai-gateway-usage` and
`ai-gateway-key-assistant-rakku`. No manual sops step is required. Existing
encrypted entries remain byte-identical. Systemd copies them with
`LoadCredential`. Raw values are not in the Nix store or command line.

The login keeper stays at `http://127.0.0.1:8317`. Production reads the existing
`pi-cliproxyapi-api-key` secret through LoadCredential. Staging's alias reads
the same key from `secrets/fleet.yaml`. Neither declaration, owner nor key
value changes. The existing Gemini secret and the Typesafe/Upstage dotenv
secret are reused. ElevenLabs is enabled for production speech as described
below. xAI and OpenRouter stay off.

| Production gateway key | Grant |
| --- | --- |
| name | assistant@rakku |
| dialects | codex, models, responses, systemone |
| models | claude-opus-5-5, gpt-6.1-sol, gemini-3.8-flash-high, gpt-5.6-luna, jev |
| paid cap | USD 5/month |
| rate limit | 600 requests/minute |

The assistant key can use one paid model: Jev, through System One. The
assistants ask Jev for reflexes, thread choice and recall (assistant ADR 0001),
at the fixed $0.0001 charge per call. Past the cap the front door returns 402,
and core falls back to its rules. Subscription requests do not charge the paid
cap. The usage key only reads the usage endpoint. The separate voice
key below can use only ElevenLabs Flash v2.5. Other configured prices remain
staging **ceilings, not tariffs**; the Flash v2.5 price is a verified tariff.

### Checks and diff scopes

Run focused checks sequentially. Do not run `nix flake check`.

```sh
nix build .#checks.x86_64-linux.ai-gateway --no-link --max-jobs 1 --cores 1
nix build .#checks.x86_64-linux.ai-gateway-staging --no-link --max-jobs 1 --cores 1
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
./scripts/check-ai-staging-rakku --phase A --staging-base <rebased-staging-commit> \
  --candidate <A> --output /tmp/ai-gateway-A-rakku-diff.txt
```

The production check validates the exact subscription-only grant, sandbox,
loopback ports, default-deny allowlist and absence of CORS. It starts the real
proxy and proves 13 requests are denied and logged. Both checks reject an
unexpected unit-text change in their diff-test fixtures.

The diff output includes both cairn and the rebased staging baseline. A adds
only the three production units, two secrets and `ai` relative to staging.
No existing unit text, ExecStart, environment, secret declaration or tailnet
name changes. This includes every staging unit.

There is one inherited difference against cairn: staging already changed
`dbus-broker.service`'s `X-Restart-Triggers` field through its default shell
package. Simon confirmed the earlier deployment reloaded D-Bus without ending
its process. The checker records this separately. It proves the candidate
retains that exact staging text. It rejects any new change to it. Changing
the old staging account now would change a live unit's text, so A leaves it
alone.

The real production sandbox also passes on Zao with synthetic credentials:

```sh
./scripts/test-ai-staging-sandbox --instance production \
  --output /tmp/ai-gateway-A-sandbox-proof.json
```

The front door returns 401 without a key on `/v1/models`. The proxy refuses
and logs a non-allowlisted CONNECT with 403. Both units have zero restarts
and stop cleanly. The script removes its own units, account and state. It
does not contact Rakku or providers and does not read production credentials.
This test does not prove sops decryption, tailnet joining or persistence
activation on Rakku. Simon verifies those at deployment before a client moves.

## Commit B: Pi assistant cutover

B sets Rakku's existing `cliproxyapiPort` option to 8430 and its existing
`cliproxyapiKeyFile` option to the new assistant gateway key. The option names
stay unchanged because the assistant still speaks the same compatible API.
Its provider and web-search config now point at the front door. Its prepare
step replaces the old key and base URL in each existing assistant home.

The three assistant units want and start after `ai-gateway.service` when that
feature is enabled. They retain ordering after `cliproxyapi.service` because
the front door still needs that login keeper. Other clients remain unchanged. B also adds those three services to the new
key's restartUnits, beside the front door. Rotation therefore refreshes the
server grant and the client credential copies together. No secret value changes
in B.

For B, run its focused check, the Rakku toplevel evaluation and this diff:

```sh
nix build .#checks.x86_64-linux.pi-assistant --no-link --max-jobs 1 --cores 1
nix build .#checks.x86_64-linux.ai-gateway --no-link --max-jobs 1 --cores 1
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
./scripts/check-ai-staging-rakku --phase B --staging-base <rebased-staging-commit> \
  --production-base <A> --candidate <B> --output /tmp/ai-gateway-B-rakku-diff.txt
```

Compared with A, exactly these existing unit texts change:
`pi-assistant-simon.service`, `pi-assistant-laure.service` and
`pi-assistant-household.service`. No gateway, login keeper, LiteLLM, voice,
tailnet-proxy or other client unit can change. The report also includes the
full diff against cairn and the inherited D-Bus field described above. The
only changed secret declaration relative to A is the assistant key's
restartUnits field. The checker permits only that exact rotation set.

To roll back the client cutover, revert B and deploy that configuration with
Simon. Keep A running while the assistants return to their old endpoint and
key. Do not remove or rotate the old key during this first cutover. Do not
remove the login keeper. Rollback of A is separate and must keep its saved
usage and tailnet identity state unless Simon chooses to remove them.

## Production speech (2026-10-27)

Production enables only ElevenLabs speech at `https://api.elevenlabs.io`.
Its existing `elevenlabs-api-key` sops entry is unchanged. Systemd loads it as
`elevenlabs` through `LoadCredential`. Rotation restarts `ai-gateway.service`.
The existing CONNECT allowlist already permits `api.elevenlabs.io:443`, so
the egress unit does not change. xAI and OpenRouter remain disabled; the
existing `xai-api-key` remains unused. Staging configuration is unchanged.

| Voice gateway key | Grant |
| --- | --- |
| name | voice@zao |
| encrypted source | secrets/hosts/rakku.yaml, ai-gateway-key-voice-zao |
| dialects | speech only |
| models | eleven_flash_v2_5 (ElevenLabs Flash v2.5) only |
| paid cap | USD 5/month |
| rate limit | 120 requests/minute |

The new key is an independent random 32-byte value, hex encoded and encrypted
for Simon and Rakku. It loads as credential `voice-zao`; key rotation restarts
only `ai-gateway.service`. No raw keys are in the config or Nix store.
Voice IDs are not mapped: voice-gateway sends ElevenLabs voice IDs directly.
The verified Flash/Turbo API tariff is USD 0.04 per 1K characters, every plan
([ElevenLabs API pricing](https://elevenlabs.io/pricing/api), checked
2026-10-27). `audio_per_million_characters = 40.0` is a tariff, not a ceiling.

Run the two focused checks and Rakku evaluation above on the final commit.
The voice diff phase compares against the current production baseline:

```sh
./scripts/check-ai-staging-rakku --phase voice --base origin/cairn \
  --candidate HEAD --output /tmp/ai-voice-rakku-diff.txt
./scripts/test-ai-staging-sandbox --instance production \
  --output /tmp/ai-voice-sandbox-proof.json
```

The diff permits only `ai-gateway.service` text/ExecStart, the new voice secret,
and the existing ElevenLabs secret's front-door rotation hook. It rejects
changes to every other unit, including the assistants and staging. Existing
encrypted entries must remain byte-identical. The sandbox test runs on Zao
with synthetic keys, without contacting Rakku or a provider.

Deployment restarts `ai-gateway.service` to load the new config and credentials.
Pi assistant traffic uses that front door and can be interrupted during this
restart. No deployment is part of this change. Live provider authentication,
paid synthesis and Rakku activation remain deployment-time checks.
