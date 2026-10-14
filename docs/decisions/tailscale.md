# Tailscale Auto-Join and Identity Preservation

## Purpose
Join fresh machines under their hostname. Preserve saved node identities and addresses across boots and reinstalls that carry `tailscaled.state`. Do not reclaim a name automatically.

## Credential Choice
An OAuth client secret, not an auth key. Auth keys cannot outlive 90 days ("You cannot generate long-lived auth keys, because they expire after 90 days"), which is useless for a machine that spends three months in a drawer. An OAuth secret does not expire, and nodes it registers are tag-owned, so their keys do not expire either.

Two parameters are required:
- `ephemeral`: register as an ephemeral node (defaults to `true` in OAuth docs). Must be explicitly set to `false` for durable machines.
- `preauthorized`: skip manual device approval (defaults to `false`).

The OAuth client also needs read access to devices (`devices:core`) for the name-collision check. The join program does not use device-write access.

## Name Collisions
Tailscale identifies a node by the key in `tailscaled.state`, not by its hostname. Reinstall without that state and the control plane sees a second device requesting a name that is taken, handing out `<hostname>-1`. There is no built-in deduplication (open issue: `tailscale/tailscale#4371`).

Per Tailscale docs: "If the conflicting machine's name is later changed, this machine will still maintain the `<hostname>-1` machine name."

A matching name, missing API entry, or different local public key does **not** prove that a device is stale. The join program never deletes devices and never calls `tailscale logout`. An operator must review a collision and decide how to recover it. Restore the original state when available to preserve the original identity. Deleting a device or joining without its state can lose its address. This policy deliberately gives up unattended recovery from lost state.

## Why One Retrying Unit
The legacy pattern was a `claim-name` unit ordered before `tailscaled`, gated on `ConditionPathExists=!/var/lib/tailscale/tailscaled.state`.

On a real first boot:
- 21:18:01 boot
- 21:18:23 claim-name runs, `curl: (6) Could not resolve api.tailscale.com`
- 21:18:34 gives up; tailscaled starts and creates `tailscaled.state`
- 21:21:07 network usable (3m06s after boot on Wi-Fi DHCP)

Two faults:
1. `network-online.target` means a managed interface appeared, not that DNS/internet routing works.
2. `tailscaled` writes `tailscaled.state` immediately on start, before registration. The gate condition was unsound.

The replacement is one unit ordered after `tailscaled`. It queries backend status (`tailscale status --json`) and retries failures every 30 seconds. Each decision reads state, name, and identity from one JSON snapshot.

| Local snapshot | Automatic action |
| --- | --- |
| `Running`, expected DNS name, nonempty public node key | Succeed without OAuth, API access, or `tailscale up` |
| `NoState`, `Starting`, `Stopped`, or any ambiguous/existing identity | Preserve state and retry; no registration |
| `NeedsLogin` with null/missing `Self` | Read API devices; refuse any exact or numeric-suffixed name collision |
| Fresh login and a valid device list with no collision | Recheck local status, then join with OAuth only if still identity-free |
| Join returns a different name | Fail for operator review; keep the new identity, do not log out |

The API check cannot reserve a name atomically. Another machine can claim it during registration. Outcome verification detects that race but does not destroy either identity. Other inherited non-default preferences can still make `up` refuse; the program fails rather than resetting preferences.

## Cold-boot incidents

On 2026-09-25, Myoko booted with a valid control-plane node while local `tailscaled` still reported `NoState`. The join unit treated every `myoko` API entry as stale, deleted its own node, then failed `tailscale up` because it omitted Myoko's saved `--ssh` preference. The failed command printed the OAuth secret into the journal.

The initial guard compared the local public node key with the API `nodeKey`. Fuji's first reboot after reinstall showed why that guard was insufficient: `tailscaled` progressed from `NoState` at 06:10:42, through `Starting` with the old identity at 06:10:49, to `Running` at 06:10:50. Separate status reads could combine transient state, name, and key. The join program deleted Fuji device `1686527239378143`, logged out, and registered a new identity. Fuji lost its original IP. Even an early different key is not safe evidence for deletion.

The current policy removes all automatic deletion and logout paths. A valid saved node never runs `up`. Fresh joins preserve saved SSH, netfilter-mode, and operator preferences. All `up` output redacts `tskey-...` values before reaching the journal. A secret exposed in an earlier journal still requires rotation; redaction does not repair earlier exposure.

## Regression checks

`scripts/test-tailscale-join` executes the generated service `ExecStart`, not a copy of the join logic. Configurable shell commands supply daemon snapshots and API responses; no live API calls occur. `checks.<system>.tailscale-join` runs it against the shipped module (Myoko on x86_64, Fuji on aarch64).

Before the fix, with the new regression and the original x86_64 generated program:

```sh
./scripts/test-tailscale-join /nix/store/ima40gr60ny15jg9xa8b45izqmqz3kdz-tailscale-join/bin/tailscale-join
```

Exit 1: `Unsafe mutation: changing startup snapshots deleted the original Fuji identity`. The recorded calls included `DELETE` for device `1686527239378143` and `up`; output included `removed device 1686527239378143 holding fuji` and `lost --netfilter-mode preference`.

After the fix:

```sh
nix build --no-link -L .#checks.x86_64-linux.tailscale-join
```

Exit 0: eight test groups passed, ending with `TAILSCALE_JOIN_TESTS_PASSED`. Coverage includes changing startup snapshots, retry with the restored identity, valid identity without API access, ambiguous identities, collisions, invalid API responses and saved preferences, a local identity appearing during API access, fresh OAuth joins with inherited preferences, secret redaction, and unexpected assigned names.

`nix flake check --option builders '' --max-jobs 1` passed on x86_64, including host evaluation for Fuji. Remote builders were disabled. `nixfmt --check modules/tailscale.nix`, `shellcheck scripts/test-tailscale-join`, and `git diff --check` passed. The x86_64 runner cannot execute Fuji's aarch64 CLI dependencies; deployment and on-device verification remain separate steps. No fleet changes or live control-plane writes were part of this regression run.

`nix flake check --all-systems --no-build` fails on the existing `checks.aarch64-linux.media-runtime`: the pinned nix-extras input has no aarch64 `nzbfast` package. The same failure was reproduced at unchanged base commit `2575be68`. The new `checks.aarch64-linux.tailscale-join.drvPath` evaluates successfully.
