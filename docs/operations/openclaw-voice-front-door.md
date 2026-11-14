# Flakey voice through the front door — prepared 2026-11-14 UTC

**PREPARE ONLY. Nothing in this change authorizes a deployment.** Simon approves
**every** `ai` deployment himself. Ship with the front-door MCP redesign's step 2,
not as a separate restart. Do not deploy Rakku, `ai-staging`, production `ai`, or
Yari during preparation. Do not register a tailnet node. The superseded node
implementation is local-only `claw-voice-node-wip` commit `cd097324`; never push,
merge or deploy it.

## Source and boundary

- ai-gateway branch `claw-voice-front-door`, pinned commit
  `f2d754ea588f72d768a27d8bc3fedc0367e011ef` (implementation `49d0275`,
  proxy-aware proof harness `f2d754e`). It adds the `transcription` dialect
  and credential-free `openai_audio` backends. No realtime route is added.
- Mountainous branch `claw-voice-front-door`, based on `cairn` `53d583e3`.
  Rebase it onto the MCP redesign before landing. Prepared step 1 `b0e62483`
  (`work/ai-mcp-proxy`, `docs/operations/ai-mcp-staging.md`) overlays
  `routing.patch` and touches `lib/ai-gateway-instance.nix`. Keep both changes.
- No changes to `packages/media-tsnet-proxy`, `modules/tailnet-names.nix`,
  Zao's services, the `unified` branch, Tailscale ACLs or tags.
- Simon and Laure currently share the `openclaw@yari` gateway grant. This change
  extends that existing key, not any other client's key. Only Simon's generated
  OpenClaw config enables speech; Laure's gateway config, container closure,
  unit and container-config paths must remain identical before a Yari switch.

The front door exposes only POST `/v1/audio/transcriptions` and
`/v1/audio/speech` for these models. The caller cannot choose a backend URL.
Transcription is inspected before dispatch, including duplicate model/file
rejection and a 32 MiB encoded/decoded cap. It sends a canonical multipart form
with `whisper-1` to the voice gateway, which converts browser audio with ffmpeg.
Speech maps `kokoro` to `tts-1` and allows only `af_heart` / `af_bella` and WAV /
PCM. Response bytes stream unchanged with backpressure, including `0xffffffff`
RIFF sizes. Local audio has no paid reservation or charge; rate limits remain.

**Critical risk:** Zao's `/v1/realtime` invokes Simon's private Pi brain. It is
not an OpenClaw voice backend. Do not expose it through an HTTP passthrough,
request-supplied URL, model alias, MCP route or WebSocket upgrade. OpenClaw must
still be unable to reach `voice` or `dictate` directly. The front door uses
`voice`, never `dictate`. Caller keys/cookies are not copied to either local
backend request. The trusted front door can reach the voice hostname, but the
untrusted caller can reach only its two fixed audio operations.

## Exact authored configuration

Production front door adds:

```toml
[local_backends.zao]
kind = "openai_audio"
base_url = "https://voice.hummingbird-lake.ts.net/v1"

[[local_models]]
id = "whisper-1"
backend = "zao"
dialect = "transcription"
upstream_model = "whisper-1"

[[local_models]]
id = "kokoro"
backend = "zao"
dialect = "speech"
upstream_model = "tts-1"
voices = ["af_heart", "af_bella"]
```

Only `openclaw@yari` adds dialects `transcription`, `speech` and models
`whisper-1`, `kokoro` to its exact existing lists. Its cap and rate remain
unchanged. All other grants, including `voice@zao`'s ElevenLabs-only grant,
remain unchanged. Staging receives neither local catalog entries nor an egress
exception. Its binary pin changes with the shared input, but it is not deployed
by this preparation.

Only claw-simon adds these fields (environment substitution is the existing
credential mechanism, not a new secret):

```json
{
  "models": {"providers":{"openai":{"request":{"allowPrivateNetwork":true}}}},
  "tools": {"media": {
    "audio": {"enabled": true},
    "models": [{"provider":"openai","model":"whisper-1","language":"en","capabilities":["audio"]}]
  }},
  "tts": {
    "provider":"openai",
    "providers":{"openai":{
      "baseUrl":"https://ai.hummingbird-lake.ts.net/v1",
      "apiKey":"${FRONT_DOOR_API_KEY}",
      "model":"kokoro","speakerVoice":"af_heart","responseFormat":"wav"
    }}
  },
  "talk": {"realtime":{"mode":"stt-tts"}}
}
```

`talk.agentId` stays `main`; `talk.provider` stays unset, so Talk uses `tts`.
The media entry inherits the existing OpenAI provider's front-door base URL and
key. No base-URL/header override can redirect that key to Zao. The only private
opt-in added is `models.providers.openai.request.allowPrivateNetwork`, documented
in OpenClaw 2026.11.3 `web/webchat.md` Speech. The existing Images-only browser
SSRF setting is not changed. Source inspection of the integrity-verified pinned
2026.11.3 npm package found that `openaiTTS` (`tts-CgW9EDQv.mjs:95`) already sets
an exact-host policy from its configured base URL. Its SSRF helper
(`ssrf-K50Tjeok.mjs:68-70,105-106`) lets that exact hostname use private addresses.
TTS therefore needs no broader private-network setting. This is source evidence,
not a deployed request: verify both routes after approval. Do not widen other
provider or browser policy to bypass an error.

## Outbound restriction finding

`lib/ai-gateway-instance.nix` restricts the front-door unit itself to loopback
with systemd `IPAddressDeny=any`, `IPAddressAllow=127.0.0.1/32,::1/128`.
Reqwest sends external requests through the configured loopback Squid CONNECT
proxy. Squid previously accepted only six exact public provider names on 443
and then denied private/reserved destinations, including `100.64.0.0/10`.
Adding `voice` to the provider list alone would still fail private-address denial.

Production adds this exception **after** the loopback/CONNECT/443 checks and
**before** the provider/private-address denials:

```squid
acl local_audio dstdomain -n voice.hummingbird-lake.ts.net
acl local_audio_tailnet dst 100.64.0.0/10
http_access allow loopback_client connect_method tls_port local_audio local_audio_tailnet
```

Both conditions must hold. An IP literal, `dictate`, another tailnet host,
subdomain/suffix trick, wrong port or a voice name resolving to loopback is still
denied. The front door's IP sandbox stays loopback-only. TLS still verifies the
voice hostname. No global CGNAT/private-address allowance is added. The allowed
backend must continue resolving within CGNAT; IPv6-only tailnet resolution would
need a separately reviewed exact destination rule, not a broad private exception.

## Preparation evidence

The retained local proof harness is ai-gateway
`scripts/prove-local-audio.py`. It starts only a throwaway loopback front door
on Zao with dummy keys and private state, calls only voice HTTP audio routes,
and terminates its child afterward. It never calls the realtime brain or an
OpenClaw conversation. Evidence: `/tmp/claw/voice-front-door/` on Zao.

The phrase was made with Kokoro, then ffmpeg converted it to a normal mono
16 kHz PCM WAV: `test-dictation.wav`. Whisper returned
**`Test dictation, check 123.`** for the spoken phrase
“TEST dictation check one two three”. The harness accepts digit rendering;
its first run failed only because it expected spelled-out numbers.

Three alternating direct/front-door samples, using the running Zao voice
service, initially measured:

| Measurement, median | Direct voice HTTPS | Loopback front door → voice HTTPS |
| --- | ---: | ---: |
| Speech first PCM sample | 274.6 ms | 277.2 ms |
| Completed transcription | 226.3 ms | 217.6 ms |

These are local Zao measurements, **not** production `ai` or Yari latency. First
PCM is not first audible word. They do not include microphone capture, browser
playback or Flakey's model response. Differences this small include sampling
noise. Wrong transcription model returned **403**, missing key **401**, and the
unchanged second client **403**. WAV was returned through the front door; browser
playback is not yet proven.

A second Zao-only proof used the **Nix-built binary** and the actual generated
production Squid ACL on a throwaway loopback port. TLS CONNECT to voice succeeded;
CONNECT to dictate returned 403. It repeated all HTTP/audio/auth proofs. Three
alternating samples had medians **430.8 ms direct / 364.4 ms through front door
and Squid** for first PCM, and **291.7 / 263.8 ms** for transcription. Warm-up,
queue/network variation and three samples do not support a speedup claim.
Evidence: `/tmp/claw/voice-front-door-squid/`, including `access.log` and
`audio/results.json`. Both throwaway processes were stopped afterward.

Checks: all **74 Rust tests** passed (13 front-door unit, 53 existing integration,
7 local-audio integration, 1 speech unit); Cargo clippy with `-D warnings` and
format checks passed. Production/staging gateway focused checks, x86 OpenClaw
check and Rakku/Yari toplevel evaluations passed. ARM `openclaw-config` built
natively on Yari **build-only**, with test credentials/private temporary state,
no live endpoint probes, activation or service changes; output
`/nix/store/c5ia1i8cfwh620h6rghmw8d2mj99pcz0-openclaw-config`. Its existing sandbox
log-path warnings do not affect successful config validation. The local
`voice-laure-unchanged.py` comparison found Laure's container derivation,
unit/config store paths and full gateway JSON identical to `cairn` `53d583e3`;
evidence `/tmp/claw/voice-laure-unchanged.json`. No generation changed. The final pin `f2d754e` also passed its Nix package build (which runs the test
suite). Its binary is
`/nix/store/1kbahj8ymj5x9sch41hh39fmzb1lzjdw-ai-gateway-front-door-0.1.0/bin/ai-gateway-front-door`.
The final source-pinned Squid proof repeated all successes, with three-sample
medians **390.3 / 411.7 ms** direct / front-door-plus-Squid for first PCM and
**297.4 / 268.0 ms** for transcription. Evidence is
`/tmp/claw/voice-front-door-final/`, including `tested-source.json`, `access.log`,
normal WAV fixture and `audio/results.json`. No runtime processes remain from
these probes. Nix formatting, Ruff and whitespace checks passed; Statix diagnostics
on the seven touched Nix files match `53d583e3` (no new warnings). Final focused
production/staging gateway and OpenClaw checks passed again after the pin update.
Final toplevel evaluations were Rakku
`/nix/store/06fn1bjqsi5k8x3fr03savmx2mq4f86y-nixos-system-rakku-26.11.20260923.4975466.drv`
and Yari
`/nix/store/1870f9y18gfk3by9q7y8g7mk018f7a8y-nixos-system-yari-26.11.20260923.4975466.drv`.
The ARM config derivation remained the already-built
`/nix/store/a6fcvial6kri2afw5i5avb8az4i2nbmz-openclaw-config.drv`.

## Approved deployment order — not executed

1. Rebase the Mountainous branch onto the redesign's landed step 1/step 2 work.
   Preserve the WhoIs caller-locked MCP routing. Review the ai-gateway pin and
   both exact audio model grants. Rerun focused `ai-gateway`,
   `ai-gateway-staging`, `openclaw` and native ARM `openclaw-config`; evaluate
   Rakku and Yari toplevels. Never run an aggregate flake check.
2. Record the current Rakku and Yari generation symlinks and full
   `/run/current-system` store paths in root-only rollback files immediately
   before activation. Pin those paths against garbage collection. Record
   `container@openclaw` and Laure's `openclaw-gateway` start times and InvocationIDs.
   Compare Laure's candidate unit bytes/store path, container-config bytes/store
   path, closure and gateway JSON with the running configuration. Refuse a change.
3. **Obtain Simon's explicit approval for this production `ai` deployment.**
   Build Rakku on Unzen; never build or reboot Rakku. Deploy the pin, catalog,
   grants and Squid exception with redesign step 2. Share its production `ai`
   restart, rather than adding a second interruption. Restart the egress proxy
   with its changed config too. Do not separately deploy `ai-staging` unless
   Simon explicitly approves that deployment as well. Verify Home Assistant,
   Z-Wave, existing front-door dialects and MCP routes after the switch.
4. From inside claw-simon **as user `openclaw`**, use its existing front-door key
   without printing it. POST the normal test WAV to `/v1/audio/transcriptions`
   with `model=whisper-1` and require text. POST speech with `model=kokoro`,
   `voice=af_heart`, `response_format=wav` and require audio. Test missing key,
   forbidden model, and refused `/v1/realtime`, including Upgrade headers.
   Confirm direct `voice` and `dictate` still time out. Do not add Claw access.
5. Build the new Yari system natively on Yari. Switch only **before 02:30Z or
   after 04:45Z**. Preserve the 21:00 Denver / 04:00Z wind-down and all existing
   jobs. Immediately before activation, check Simon's chat-activity metadata in
   the last ten minutes without opening message text. If active, wait. Run
   `openclaw-wait-idle --check openclaw claw-simon`; absent/unreadable audit
   receipts are not proof of idle. Use the continuity guard described in
   `openclaw-yari.md` and the wind-down deployment helpers. Stop if `cairn`, the
   running parent or Laure's candidate closure changed. Only claw-simon may
   restart. Compare Laure's recorded unit start times and InvocationIDs afterward.
6. Require `talk.catalog` transcription ready and speech configured. Retain
   actual request/error evidence if the private-network guard blocks either
   route. Do not claim ready based on config or catalog alone.

## Browser acceptance after deployment

Read the agent-browser skill. Use a **NEW TEST conversation**, never the main
chat. Reuse the normal WAV from the local harness. Launch Chromium with:

```text
--use-fake-ui-for-media-stream
--use-fake-device-for-media-stream
--use-file-for-fake-audio-capture=/tmp/claw/voice-front-door/test-dictation.wav
```

- Hold the composer microphone, then release. Require the actual composer to
  contain the phrase (digits are acceptable). Measure capture-end → text.
- Clear the draft, then tap Talk. Require the transcript and Flakey's answer in
  that same new chat. Require a successful Talk TTS request **and** audio played
  or queued. Record agent-response latency separately from speech-first-byte
  and actual playback/queue timing. The pinned `openaiTTS` helper reads a bounded
  binary response before returning (default 16 MiB), even though this front door
  never buffers speech. Its first audible word can therefore wait for a whole
  synthesized chunk. Stop before the repeating fixture sends
  another turn.
- Click **Read aloud** on the reply. Require successful TTS and playback/queue;
  test Stop reading. Check the unknown-length streaming WAV in Chromium, not
  only ffmpeg or the HTTP status. If playback fails, retain console/network
  evidence and report it; do not silently change formats or claim success.
- Screenshots and bounded network/timing evidence go into
  `/tmp/claw/voice-v1/`. No browser proof was run during preparation.

### TEST cleanup

Record every TEST session key. Wait for Simon to be idle and stop **only** his
Gateway before offline memory work, as the wind-down v1 runbook did. Use supported
`openclaw memory forget --agent main --session KEY --dry-run --json`; verify it
resolves only the TEST lineage, then run it without `--dry-run`. Repeat preview
and require no tracked entries, mixed lineage or refusals. Restore/remove only
TEST additions to Flakey's Markdown memory, retaining any real content. Delete
the TEST conversations through the Gateway API after Forget; remove only the
temporary browser pairing. Verify no TEST phrase remains in memory files. Do not
write SQLite or delete gateway state files. Do not touch Laure's state or jobs.
This preparation made no OpenClaw conversation, so it requires no memory cleanup.

## Rollback after an approved deployment

No host generation changed during preparation. Do not invent generation numbers.
Before deployment, record full previous paths in `/var/tmp/voice-before-ai-system`
on Rakku and `/var/tmp/voice-before-yari-system` on Yari and pin them. After
checking there was no intervening deployment, the exact activation operations
for each recorded path are:

```sh
# Rakku, only after Simon approves this ai rollback/restart:
nix-env --profile /nix/var/nix/profiles/system --set "$(cat /var/tmp/voice-before-ai-system)"
"$(cat /var/tmp/voice-before-ai-system)/bin/switch-to-configuration" switch
# Yari, after timing/idle checks and the same Laure continuity guard:
nix-env --profile /nix/var/nix/profiles/system --set "$(cat /var/tmp/voice-before-yari-system)"
"$(cat /var/tmp/voice-before-yari-system)/bin/switch-to-configuration" switch
```

Put these operations into local Nix-shebang helpers, scp them, then run them;
never embed multi-step SSH commands. Roll back Yari's voice configuration before
removing front-door audio grants/routes. A whole Rakku rollback also rolls back
redesign step 2, so coordinate it with that runbook. For voice-only recovery,
revert this pin/config/grant/egress change on a reviewed branch and obtain
Simon's approval for the `ai` restart. Keep unrelated MCP redesign changes.
No memory/database restore and no wind-down job change is needed. Retain
private state and tsnet identities; this feature creates no new identity.

## Zero-code output fallback: ElevenLabs

Existing production already has `eleven_flash_v2_5`, the `speech` dialect,
provider credential and Squid allowance. Grant that exact model plus `speech`
to `openclaw@yari`, then configure Simon's OpenClaw TTS with the existing
front-door key, `model=eleven_flash_v2_5`, a valid ElevenLabs voice ID (not
`af_heart`) and `responseFormat=mp3`. No Rust change, Kokoro backend or new secret
is needed. It still needs an approved `ai` config restart and Simon-only Yari
switch/browser proof. It does **not** solve dictation/STT, and reply text leaves
the tailnet for ElevenLabs.

The repository's reviewed production tariff is **$40 / million characters**
(**$0.04 / 1,000**, checked 2026-10-27; recheck before adopting it). That adds
no new fixed monthly subscription to the already configured account, but
consumes its shared prepaid balance. Example: 10 spoken minutes/day × 30 days ×
900 characters/minute = 270,000 characters, **$10.80/month**. At the same assumed
rate, 30 minutes/day costs **$32.40/month**. Actual usage, voice/model and current
provider pricing determine the invoice; these are assumptions, not measured
Flakey usage. The existing prepaid exemption bypasses gateway dollar caps, so
the nominal `monthly_cap_usd` does not enforce a $5 speech limit. A provider
balance/credit limit is needed if a hard spend ceiling is required.
