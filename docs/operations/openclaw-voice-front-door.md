# Flakey voice through the front door — 2026-11-14

Simon approved this deployment on 2026-11-14, “as soon as possible”. Voice is
an independent deployment. The `/mcp` redesign has shipped; do not redeploy or
roll back its historical stages to add voice.

## Source, names and boundaries

- ai-gateway implementation `49d0275`, proof harness `f2d754e`, landed on main:
  **`f2d754ea588f72d768a27d8bc3fedc0367e011ef`**. Mountainous pins `ref=main`
  at that exact SHA, not a feature branch. The previous pin was `761f9de`.
- Voice landed on cairn as `0e5d9c61211b7b785bc1b4374617344037aa56ff` and
  `af42ac253cff66d803b508a709fd7db3a06ffc9b`. The actual host build used
  isolated branch **`deploy/voice-rakku`**, exact source
  **`0e6c441b8aa561e8481ffb25d2ac88a790031b73`**, from live-equivalent
  `b247e23c14779fe533e83f29f5152c38a660763e` plus only the voice commits.
  This excluded the unrelated Pi pause `f36aeeb7`; do not deploy current cairn
  to reproduce this deployment without reviewing its additional changes.
- Simon: **https://flakey.hummingbird-lake.ts.net**, container `claw-simon`,
  stable node ID **`nbQJZMcewG11CNTRL`**. Laure: **https://snowy.hummingbird-lake.ts.net**,
  container `openclaw`. Container names have not changed.
- Tools remain `https://ai.hummingbird-lake.ts.net/mcp/<row>`. The complete
  current rows and caller locks come from `lib/ai-mcp-rows.nix`. Voice changes
  no row, proxy flag, credential, tag, ACL or tailnet identity. The rendered
  `tsnet-proxy-ai` and staging proxy units and their store paths are identical
  to cairn. Do not restart either proxy.
- The existing `openclaw@yari` front-door key is shared by both gateways.
  Only Simon's OpenClaw config enables voice. Snowy's generated config,
  gateway unit, container unit/config and closure remain identical to cairn.
- The local-only superseded node branch `claw-voice-node-wip` (`cd097324`) is
  reference material, never pushed or deployed. No `claw-voice` node exists.

**Critical:** Zao `/v1/realtime` drives Simon's private Pi brain. The front door
must never route a caller there. Audio requests cannot select a URL. No new
WebSocket/realtime route is added. OpenClaw must still fail to reach `voice`
and `dictate` directly. The two fixed local operations use `voice`, never
`dictate`; caller keys/cookies do not cross that second hop.

## Configuration

Production declares a credential-free `local_backends.zao` of kind
`openai_audio`, base URL `https://voice.hummingbird-lake.ts.net/v1`, and:

| Public model | Dialect | Upstream model | Allowed voices/formats |
| --- | --- | --- | --- |
| `whisper-1` | `transcription` | `whisper-1` | Multipart file; `language=en` |
| `kokoro` | `speech` | `tts-1` | `af_heart`, `af_bella`; WAV or PCM |

Only `openclaw@yari` adds `transcription`, `speech`, `whisper-1` and `kokoro`
to its existing exact grant. Other grants, caps and rates are unchanged.
Transcription is inspected before forwarding, with a 32 MiB encoded/decoded
body cap, unique model/file fields, canonical multipart and 120-second timeout.
Zao converts browser audio with ffmpeg. Speech streams unchanged with
backpressure, including unknown-length RIFF sizes (`0xffffffff`). No local
request reserves paid spend; usage records contain metadata, not audio/text.
Staging gets the new binary but no local model/grant/egress changes.

Simon-only additions, merged with the existing config:

```json
{
  "models":{"providers":{"openai":{"request":{"allowPrivateNetwork":true}}}},
  "tools":{"media":{
    "audio":{"enabled":true},
    "models":[{"provider":"openai","model":"whisper-1","language":"en","capabilities":["audio"]}]
  }},
  "tts":{"provider":"openai","providers":{"openai":{
    "baseUrl":"https://ai.hummingbird-lake.ts.net/v1",
    "apiKey":"${FRONT_DOOR_API_KEY}","model":"kokoro",
    "speakerVoice":"af_heart","responseFormat":"wav"
  }}},
  "talk":{"realtime":{"mode":"stt-tts"}}
}
```

`talk.provider` remains unset, so Talk uses `tts`. Media inherits OpenAI's
existing front-door base URL/key. The only private-network opt-in added is the
documented provider-scoped request setting. Integrity-verified pinned OpenClaw
2026.11.3 source shows TTS already gives its configured exact hostname a
private-network exception (`openaiTTS`, `tts-CgW9EDQv.mjs:95`;
`ssrf-K50Tjeok.mjs:68-70,105-106`). No broader browser/SSRF setting changes.
The existing TTS helper reads a bounded binary response (default 16 MiB) before
returning. First audible output can therefore wait for a whole chunk, even
though the front door never buffers speech.

## Egress and exact restart set

The Rust unit stays loopback-only under systemd `IPAddressDeny=any`. It uses
its existing loopback Squid CONNECT proxy. Production adds this exception after
the loopback/CONNECT/443 gates, before provider/private-address denials:

```squid
acl local_audio dstdomain -n voice.hummingbird-lake.ts.net
acl local_audio_tailnet dst 100.64.0.0/10
http_access allow loopback_client connect_method tls_port local_audio local_audio_tailnet
```

A hostname-only addition would still hit CGNAT denial. Both exact hostname and
CGNAT resolution are required. IP literals, other tailnet names, subdomains,
suffix tricks, wrong ports and a voice name resolving to loopback remain denied.
No broad private/CGNAT exception exists. TLS verifies the voice hostname.

The source unit comparison against cairn found:

| Host | Changed unit | Activation expected |
| --- | --- | --- |
| Rakku | `ai-gateway.service` | Restart: binary and config |
| Rakku | `ai-gateway-egress.service` | Restart: exact voice allowance |
| Rakku | `ai-gateway-staging.service` | Restart: shared package pin; Simon accepted this restart |
| Yari | `container@claw-simon.service` | **Reload**, applying changed units inside the running container |

Neither `tsnet-proxy-ai` nor `tsnet-proxy-ai-staging` changes. No `/mcp` outage
or tsnet enrollment/certificate delay occurred. **Correction:** the prepared
1–5 second `/v1` estimate was wrong. The measured production outage upper bound
was **23.251 seconds**, with both proxy identities unchanged. Other clients'
active streams can delay Rust shutdown up to its systemd stop timeout. Always
sample the real HTTPS `/v1/models` status throughout activation.

### Prove Yari's apply before activation

`reloadContainerInPlace=true` for both people feeds `reloadIfChanged` in
`modules/openclaw.nix`. The rendered unit must have `X-ReloadIfChanged=true` and
an `ExecReload` that runs the target container's `switch-to-configuration test`
inside the existing container. Inspect `X-RestartIfChanged`, `X-ReloadIfChanged`,
restart/reload trigger bytes/store paths and that script. A changed restart
trigger does not mean a full container restart when reload-on-change applies.
Run the candidate's **dry-activate** on Yari and require a container **reload**,
not stop/start/restart. Also compare inner container units: only the gateway
and its existing gateway-coupled reconciliation oneshots may be reapplied;
`claw-tailnet` must remain identical. Refuse a full container restart.

Afterward require unchanged flakey container and `claw-tailnet` InvocationIDs,
unchanged snowy gateway/container start times and InvocationIDs, flakey's exact
stable node ID, and a successful `/mcp` tools/list from flakey. This avoids the
first-join race described in `openclaw-yari.md`: a new node ID would fail every
caller lock. Never force a new login or register another node to repair it.

## Deployment order and guard

Operational helpers/evidence are under `/tmp/claw/voice-v2/` on Zao and copied
to `/tmp/claw/` on the target. All helpers use Nix shebangs. Build only from a
clean checkout whose full SHA equals the recorded approved source SHA.

1. Land ai-gateway on main, pin that exact commit with `ref=main`, rerun focused
   checks, then rebase and fast-forward Mountainous onto cairn. Never run an
   aggregate flake check. Record full SHAs, derivations and running parents.
2. Build Rakku on **Unzen**, relay Unzen → Zao → Rakku with `--no-check-sigs`.
   Rakku never builds and must not reboot. Build Yari and ARM config validation
   natively on Yari, remote builders disabled.
3. Rakku preflight requires exactly the three unit differences above, unchanged
   MCP table and proxy units, a keyed model baseline, healthy HA/Z-Wave.
   Reuse the redesign's ready/go handshake (`ai-mcp-production.md`): the
   systemd-run switch unit snapshots identities, writes a fresh random nonce
   to `ready`, and waits at most 120 seconds. Zao checks **both** gateways idle
   again, then writes the same nonce to `go`. Busy, timeout or stale go means
   no activation. Recheck parent output and competing switches immediately
   before activation. Gate only covers OpenClaw, not other front-door clients.
4. Switch under durable `systemd-run --wait --collect`; sample `/v1`. Only the
   three expected running services may restart. Require proxy identities
   unchanged, model baseline unchanged for existing clients, MCP caller locks,
   **Home Assistant HTTP 200 on 127.0.0.1:8123**, and the Z-Wave JS version
   handshake. On failure run **`nixos-rebuild switch --rollback`** on Rakku and
   verify the recorded previous system/health. Do not continue to Yari.
5. From `claw-simon` as user `openclaw`, use its own front-door key without
   printing it: POST the test WAV with `whisper-1` and require text; POST
   `kokoro`/`af_heart`/WAV and require audio. Require direct voice and dictate
   to time out. Check a real `/mcp` tools/list and refuse `/v1/realtime`.
6. Before Yari, prove the in-place apply above, then inspect chat-activity
   **metadata** for the last ten minutes. Wait if Simon is active. Check both
   gateways audit-idle immediately before switching. Apply only the flakey
   gateway config in place; snowy must not restart. Require the same tailnet
   ID and tools/list afterward. `talk.catalog` must show transcription ready
   and speech configured; follow with browser proof, not catalog-only claims.

Both restarts must finish before **02:30Z**. If not ready by **02:15Z**, stop
before restarting and resume after **04:45Z**. Preserve the 04:00Z / 21:00 Denver
wind-down, its job, morning brief, memory and other existing jobs.

## Browser proof and TEST cleanup

Read the agent-browser skill. Use a NEW TEST conversation on
**https://flakey.hummingbird-lake.ts.net**, never the main conversation. Kokoro
made “TEST dictation check one two three”; ffmpeg converted it to a normal WAV.
Launch Chromium with `--use-fake-ui-for-media-stream`,
`--use-fake-device-for-media-stream` and
`--use-file-for-fake-audio-capture=<normal-wav>`.

Prove: hold/release microphone writes the words in the actual composer; a Talk
tap transcribes, answers in that chat, succeeds in TTS and plays/queues audio;
Read aloud plays and Stop reading cancels. Stop Talk before the repeating
fixture starts another turn. Save screenshots under `/tmp/claw/voice-v1/`.
Measure end of input speech → first played/queued audio, separating this from
local server first-PCM and Flakey's model response time. Retain errors if WAV
playback or the private-network guard fails; do not claim browser success from
HTTP audio or silently change formats.

Record all TEST session keys. With only flakey idle/stopped for offline memory
work, run supported `memory forget --agent main --session KEY --dry-run --json`,
verify only TEST lineage, then run it without dry-run. Repeat preview and require
no tracked entries or refusals. Delete TEST conversations through the Gateway
API after Forget. Remove only TEST additions in Markdown memory; preserve real
content. Remove the temporary browser pairing. No SQLite writes or state-file
deletions. Do not touch snowy. Apply the same restart timing window to cleanup.

## Verification and rollback

Rebase checks: focused `ai-gateway`, `ai-gateway-staging`, `ai-mcp-proxy`,
`openclaw`, `tailnet-names`; native ARM `openclaw-config`; Rakku/Yari toplevels.
Source comparison proves snowy config/closure/units, every MCP row and both
proxy units identical to cairn. Earlier Rust implementation passed **74 tests**,
clippy `-D warnings`, formatting and Nix build. Local Zao proof through the real
generated Squid ACL returned “Test dictation, check 123.” and audio; wrong model
403, missing key 401, unchanged client 403. Final prepared-pin median (3 samples)
was first PCM **390.3 ms direct / 411.7 ms through front door + Squid**, completed
STT **297.4 / 268.0 ms**. Noise/order do not support a speedup claim. These are not
browser or production latency. Evidence: `/tmp/claw/voice-front-door-final/`.

Verified live parents immediately before activation (supersede historical 167/64):

| Host | Previous generation | Exact system |
| --- | --- | --- |
| Rakku | **168** | `/nix/store/9709w007kxf4hixyhbhhl70rfv2cyxa6-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | **64** | `/nix/store/0vycq2lfzfvp9z99hkh2z8xf2qvrg2ns-nixos-system-yari-26.11.20260923.4975466` |

Pin these parents against GC and check no intervening deployment before every
switch. Rakku automatic failure rollback is `nixos-rebuild switch --rollback`
while this deployment is still the latest generation; verify it returns 168.
For later/manual rollback, use the exact recorded system rather than guessing
“previous”. Yari rollback runs the same snowy/in-place/timing/idle guard with
source/target reversed, restoring **generation-64 content** without restoring
memory or databases. Roll back Yari voice config before removing front-door
audio routes. No new persistent jobs or tailnet nodes need removal.

### Output-only ElevenLabs fallback

Existing `speech` and `eleven_flash_v2_5` need only grant/config changes, no Rust
code or new secret, and a valid ElevenLabs voice ID plus MP3. This does not solve
STT and sends reply text outside the tailnet. Reviewed tariff: $0.04/1,000
characters (recheck current pricing). At 10 min/day × 30 days × 900 chars/min,
**$10.80/month**; 30 min/day costs **$32.40/month**. These are assumptions, not
measured usage. No new fixed subscription is required by the existing account;
its shared prepaid balance is spent. The prepaid exemption bypasses gateway
caps, so the nominal $5 cap is not a hard speech spend limit.

## Execution record

Deployment completed on 2026-11-15 UTC. No system rollback, reboot, container
restart, mask, ACL edit, new node, plugin or Zao service change was performed.

| Host | Generation | Running system |
| --- | --- | --- |
| Rakku | **169** | `/nix/store/z2dzizw71pai8c9zqxk1namwdamnk2ip-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | **65** | `/nix/store/59kr63kkl6930rsbhym65hi0hpbr356n-nixos-system-yari-26.11.20260923.4975466` |

Rakku switched around 00:36:54Z. The three expected running services restarted.
Both tsnet proxies, HA and Z-Wave identities stayed unchanged. HA returned 200;
the Z-Wave handshake and existing MCP caller refusals passed. `/v1` outage upper
bound was 23.251 seconds, not the prepared 1–5 second estimate.

**Activation incident: five previously stopped services started.** Nix
activation started wanted-but-imperatively-stopped `signal-responder`,
`assistant-tsgo`, `pi-assistant-simon`, `pi-assistant-laure` and
`pi-assistant-household`, although their unit files did not change. They were
inactive/MainPID=0 again at 00:43:37–00:43:38Z; the later explicit plain stops
were idempotent. Per instruction, no rollback or masks were applied. Generation
169 still wants these units. **Another activation can start them again.**
Before a later activation, inventory wanted-but-inactive units and resolve this
with the pause owner; comparing changed unit files alone is not sufficient.

The read-only audit covers 00:36:50–00:43:40Z. Signal logged one subscription
start and no observed triage/send markers. Pi logged startup, shutdown, failed
weather refreshes, one failed mail poll and one unreachable MCP server. File
modification times changed in all three Pi state trees. These metadata and
journal checks do **not** prove that no outbound action or state write occurred;
they do not attribute each file write. Evidence: `side-effect-audit.json`.

Yari waited until the ten-minute real-chat activity guard cleared. Both host
and inner dry activation passed. The host reloaded `container@claw-simon`; only
its gateway restarted. Flakey health was unavailable for 14 sampled seconds;
Snowy had zero unhealthy samples. Flakey container InvocationID
`090c096c50844218b7543fadd1a4b948` and tailnet InvocationID
`e89923b738c645f1b65f145e777932ac` stayed unchanged. Node ID remains
`nbQJZMcewG11CNTRL`. Snowy container still started 2026-11-12 04:38:11Z, and its
gateway still started 2026-11-14 22:54:25Z, with unchanged InvocationIDs.

As `openclaw` inside Flakey, production STT and Kokoro WAV returned 200;
`voice` and `dictate` direct access timed out, `/v1/realtime` returned 404, and
`/mcp/maps` tools/list returned only `travel_time`. `talk.catalog` reported
transcription ready and speech configured. Chromium decoded and played the
unknown-length RIFF WAV without a format workaround.

### Browser results and remaining UI limitation

New conversation: **TEST VOICE 2026-11-15**, key
`agent:main:dashboard:96f59c2b-0deb-4889-b396-b51bb021fa88`.

| Check | Observed result |
| --- | --- |
| Hold microphone | Dictation starts; **release does not stop it** in the pinned UI. Reproduced with one trusted native CDP pointer held 4.2 seconds and released on “Stop and keep text”. Explicitly clicking that button completes transcription into the composer. No UI patch was made. |
| Tap microphone / split Talk | Transcription → `chat.send` → TEST answer in the same conversation → successful `tts.speak` → browser audio playback. No realtime route was used. |
| Talk speech end → first audio | **8.817 s**, **8.316 s** for two completed turns; audio duration 2.05 s each. Includes silence detection, STT, model response and buffered TTS, not just gateway latency. |
| Read aloud | Successful `tts.speak`; 2.05 s WAV played. Click → playback **2.143 s**. “Stop reading” appeared; cancellation was not separately exercised. |

Holding/releasing alone therefore does **not** meet the requested complete
interaction. The current workaround is explicit “Stop and keep text”. Long
recordings produced repeated fixture words; the proof used a looping synthetic
microphone, so this does not isolate natural-microphone repetition behavior.
Playback is verified by browser events, not a human hearing a physical speaker.

Screenshots and instrumentation: `/tmp/claw/voice-v1/`, including
`02-read-aloud.png`, `03-talk-answer-audio.png`,
`04-native-hold-explicit-stop.png`, and `browser-summary.json`. Host evidence:
`/tmp/claw/voice-v2/` on Zao, `/var/tmp/voice-yari/` and
`/var/tmp/voice-rakku/` on their hosts.

### TEST cleanup

Closed the browser, waited for Flakey idle, stopped only its gateway, and ran
supported offline `memory forget` preview/apply/re-preview for that exact TEST
session. No tracked entries or refusals remained. Deleted the session through
the supported CLI/Gateway path. All three Markdown memory files match their
pre-test SHA-256 hashes; no uppercase TEST additions existed. Removed both
browser pairing records created during authentication. Existing reconciliation
services were already active and remained active. Snowy stayed unchanged.
Flakey's cleanup restart completed at **02:03:07Z**, before the 02:15Z cutoff.
Both gateways were healthy afterward. The 04:00Z wind-down was not changed.

The backend deployment is verified. Full hold/release UX acceptance remains
blocked by the pinned OpenClaw UI behavior described above.
