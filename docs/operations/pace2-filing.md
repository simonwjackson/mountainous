# Pace 2 filing: deployment preparation only

Branch `pace2-filing` prepares a host-only `pace@rakku` client. Do not deploy
this branch before the secret below exists and the Pace filing build is pinned.
No real key was generated and no SOPS file was changed during preparation.
Rebase onto the latest working branch first: the writes deployment is concurrent.

## Logged guesses

- Model: `gemini-3.8-flash-high`. It is already granted to the assistant and
  OpenClaw in `modules/ai-gateway.nix`. Choose the existing Flash text model,
  not an image model or the Opus model, for this small classification batch.
  This choice is a guess; no live benchmark or cost measurement was made.
- Dialect: `chat_completions`, the only dialect on this new key. JSON mode.
- Rate: 10 requests/minute, a conservative non-interactive allowance (guess).
  Pace itself sends one batch of at most 40 items per six-hourly sync, waits
  at most 30 seconds, and requests at most 8,000 output tokens per sync.
- Spend: the front door removed per-key dollar caps (see `ai-gateway.md`,
  Monthly cap removal rollout). Do not emit the retired cap field. This client
  has the same prepaid-balance boundary as other non-interactive clients.
  Cost: a looping client can consume that shared provider allowance. There
  is no isolated dollar budget for Pace in the current front door.

## Deployment-stage key commands

Run on Zao in the rebased mountainous checkout, after the normal idle gate.
This creates one key in one SOPS value. Both services load that value; never
copy it into an environment variable in a unit or into a user-facing client.
The shell variables below exist only while encrypting the new key.

```sh
nix shell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#openssl nixpkgs#jq --command bash <<'SH'
set -euo pipefail
set +x
export SOPS_AGE_KEY="$(ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519")"
key="$(openssl rand -hex 32)"
sops set secrets/hosts/rakku.yaml '["ai-gateway-key-pace-rakku"]' "$(printf '%s' "$key" | jq -Rs .)"
unset key SOPS_AGE_KEY
SH
```

Commit the encrypted value with the reviewed configuration at deploy time.
The root-only `ai-gateway-key-pace-rakku` secret becomes the front door's
`pace-rakku` credential and Pace's `pace-model-key` credential. Env contains
only `PACE_MODEL_URL` and `PACE_MODEL`, never the key.

Adding this key restarts `ai-gateway`, `pace2` and `tsnet-proxy-ai`. The latter
interrupts every agent's `/v1` for about 23 seconds. Wait for idle before
activation. No push, activation, restart or deployment was performed here.

## Verification notes

`checks.pace2` and Rakku toplevel evaluation pass. The aggregate
`checks.ai-gateway` fails the disabled-feature invariants (services, tailnet
name and persistence), also reproduced on untouched base `21637bd2934e`.
Do not weaken those assertions to hide this existing problem. Evaluate the
production grant and run its generated-TOML test separately until fixed.
The generated production TOML and Squid test passed separately, including
18 denied loopback proxy requests. No test sent an external provider request.
