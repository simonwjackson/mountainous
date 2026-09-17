# Tailscale Auto-Join and Deduplication

## Purpose
Tailscale on every machine, joined whenever a network first appears, and never under a name with a number stuck on the end (`<hostname>-1`).

## Credential Choice
An OAuth client secret, not an auth key. Auth keys cannot outlive 90 days ("You cannot generate long-lived auth keys, because they expire after 90 days"), which is useless for a machine that spends three months in a drawer. An OAuth secret does not expire, and nodes it registers are tag-owned, so their keys do not expire either.

Two parameters are required:
- `ephemeral`: register as an ephemeral node (defaults to `true` in OAuth docs). Must be explicitly set to `false` for durable machines.
- `preauthorized`: skip manual device approval (defaults to `false`).

## Name Deduplication
Tailscale identifies a node by the key in `tailscaled.state`, not by its hostname. Reinstall a machine and the control plane sees a second device requesting a name that is taken, handing out `<hostname>-1`. There is no built-in deduplication (open issue: `tailscale/tailscale#4371`).

Per Tailscale docs: "If the conflicting machine's name is later changed, this machine will still maintain the `<hostname>-1` machine name." The stale device must be deleted via API before the new one registers.

## Why One Convergent Unit
The legacy pattern was a `claim-name` unit ordered before `tailscaled`, gated on `ConditionPathExists=!/var/lib/tailscale/tailscaled.state`.

On a real first boot:
- 21:18:01 boot
- 21:18:23 claim-name runs, `curl: (6) Could not resolve api.tailscale.com`
- 21:18:34 gives up; tailscaled starts and creates `tailscaled.state`
- 21:21:07 network usable (3m06s after boot on Wi-Fi DHCP)

Two faults:
1. `network-online.target` means a managed interface appeared, not that DNS/internet routing works.
2. `tailscaled` writes `tailscaled.state` immediately on start, before registration. The gate condition was unsound.

The replacement: one unit ordered after `tailscaled` that queries backend status (`tailscale status --json`), retries until success, and verifies the hostname is free before calling `tailscale up`.
