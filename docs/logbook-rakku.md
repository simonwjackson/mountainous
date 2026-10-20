# Logbook on Rakku

NixOS owns `logbook`, its persistent home `/var/lib/logbook`, and its units.
The application profile is `/nix/var/nix/profiles/per-user/logbook/application`.
It contains `logbook-server`, `logbook-tsnet`, and `logbook`. No application
package is part of Rakku's system closure. Before the first app deployment,
the units skip startup because that profile does not exist.

`logbook.service` binds to `127.0.0.1:3160`. `logbook-tsnet.service` uses hostname
`logbook`, its own state at `/var/lib/logbook/state/tsnet`, and the loopback
upstream. The sidecar allows only `/rpc`, `/mcp`, and `/healthz`. The first start
needs the operator to authorize this new, non-ephemeral Tailscale node through
the login URL in `journalctl -u logbook-tsnet`. Do not run a second copy of its
identity. Tailscale HTTPS must be enabled for the tailnet.

Both units copy CLIProxyAPI's sandbox. The core receives SIGINT on stop,
matching its graceful shutdown handler. The core is the only data-directory
writer. The sidecar's write access is limited to its tsnet directory. The
account is neither wheel nor a Nix trusted user. Unzen's existing app-updater
public deploy/signing keys are reused. Its private keys remain on Unzen.
The only sudo commands for `logbook` are fixed `logbook-service-control start`
and `logbook-service-control stop` actions, which control only these two units.

## Gadgetbridge and ProtectHome

The phone folder defaults off. In `modules/logbook.nix`, replace both `null`s:

- `mountainous.fleetSync.externalDevices.phone.deviceId`: the phone's existing
  eight-group public Syncthing device ID, copied from its Syncthing app.
- `mountainous.fleetSync.externalDevices.phone.tailnetName`: its full stable
  MagicDNS name, `<name>.hummingbird-lake.ts.net`, without scheme or port.

Then change `mountainous.fleetSync.folders.gadgetbridge.enable` to `true`.
The assertions run only for enabled folders on participating hosts. Leaving
this disabled does not block Rakku's other services or another host's
evaluation. The phone settings are in [Declarative trust](app-profiles.md).

A root-only path/oneshot bridge watches exactly
`/home/simon/.local/share/fleet-sync/gadgetbridge/Gadgetbridge.db`. It copies
only a non-empty, regular, stable SQLite snapshot. It checks SQLite integrity,
sets `logbook:logbook 0600`, fsyncs the temporary file, and atomically replaces
`/var/lib/logbook/inbox/gadgetbridge/Gadgetbridge.db`. It fsyncs the directory
after the rename. Incomplete or changing exports retain the last good snapshot
and retry after 30 seconds. The directory is root-owned and not writable by
Logbook. The core mounts it read-only, and its `--gadgetbridge-export` points
at that copy. No home ACLs, whole-home mounts, or core restarts are needed.
The path/oneshot pair is absent when the folder is disabled.

This uses one duplicate export (a few MB), but avoids two single-file bind
mount problems: a 0600 source remains unreadable by another UID, and Syncthing's
atomic replacement leaves a file bind attached to the old inode. The directory
mount instead sees every new snapshot. The importer's WatchFile schedule can
observe those replacements. The inspected initial Logbook build still has a
manual Gadgetbridge importer stub; the real importer must be merged before
exports are ingested. All required server flags already exist.

## After landing: host provisioning (not performed by this change)

Review the phone fields first; they can remain disabled for the initial host
and app deployment. From the operator's mountainous checkout on `cairn`:

```sh
git -C /home/simonwjackson/code/github/simonwjackson/mountainous switch cairn
git -C /home/simonwjackson/code/github/simonwjackson/mountainous pull --ff-only
NIX_SSHOPTS='-F /dev/null' nixos-rebuild switch --no-reexec \
  --flake /home/simonwjackson/code/github/simonwjackson/mountainous#rakku \
  --target-host simonwjackson@192.168.1.178 --use-remote-sudo --option builders ''
```

This is the only required host rebuild. Do not rebuild Unzen or other hosts.
Do not reboot Rakku as a verification step. Confirm Home Assistant and Z-Wave
remain healthy after the host change, as in the CLIProxyAPI migration.

## After Logbook main changes: build, sign, push from Unzen

There is **no nightly upstream check or Unzen watcher**. The main-merge release
job/operator runs `scripts/logbook-deploy MAIN_SHA LOGBOOK_CHECKOUT
PROSEQL_CHECKOUT` on Unzen. This repository supplies the deployment entry point;
a Logbook main workflow still needs to invoke it. It rejects a non-main SHA,
dirty checkouts, and SHA mismatches before deployment. A lock prevents concurrent
Logbook deployments. `--check` permits a
non-main candidate and builds/tests it without signing, SSH, or activation.

The Logbook flake currently refers to ProseQL through a zao-local `file://`
URL. Do not rely on that path on Unzen. Copy both Git histories, then override
both flake inputs with the pinned local clones. This script does that override.
Logbook's flake already replaces the four ProseQL Cargo dependencies with the
input's store paths and removes their Git source lines from Cargo.lock. Its
registry dependencies have lock hashes. No Logbook flake change is needed for
this route. A future change in that dependency scheme needs a new dry run.

Exact commands, after Logbook has landed on `main` and mountainous on `cairn`:

```sh
# On the source workstation. Bundles contain code, not Logbook state.
git -C /home/simonwjackson/code/sandbox/logbook rev-parse main > /tmp/logbook-main.sha
git -C /home/simonwjackson/code/sandbox/logbook bundle create /tmp/logbook-main.bundle main
git -C /home/simonwjackson/code/github/simonwjackson/proseql bundle create /tmp/logbook-proseql.bundle main
git -C /home/simonwjackson/code/github/simonwjackson/mountainous bundle create /tmp/logbook-mountainous.bundle cairn
ssh -F /dev/null root@unzen.hummingbird-lake.ts.net \
  'install -d -m 0700 /var/lib/app-updater/logbook/incoming'
scp -F /dev/null /tmp/logbook-main.sha /tmp/logbook-main.bundle \
  /tmp/logbook-proseql.bundle /tmp/logbook-mountainous.bundle \
  root@unzen.hummingbird-lake.ts.net:/var/lib/app-updater/logbook/incoming/
ssh -F /dev/null root@unzen.hummingbird-lake.ts.net 'bash -se' <<'UNZEN'
incoming=/var/lib/app-updater/logbook/incoming
EXPECTED_SOURCE_SHA=$(cat "$incoming/logbook-main.sha")
[[ "$EXPECTED_SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]]
release=/var/lib/app-updater/logbook/releases/$EXPECTED_SOURCE_SHA
test ! -e "$release"
install -d -m 0700 "$release"
git clone --branch main "$incoming/logbook-main.bundle" "$release/source"
test "$(git -C "$release/source" rev-parse HEAD)" = "$EXPECTED_SOURCE_SHA"
git clone --branch main "$incoming/logbook-proseql.bundle" "$release/proseql"
PROSEQL_SHA=$(python3 - "$release/source/flake.lock" <<'PY'
import json, sys
lock = json.load(open(sys.argv[1]))
print(lock['nodes'][lock['nodes']['root']['inputs']['proseql']]['locked']['rev'])
PY
)
git -C "$release/proseql" checkout --detach "$PROSEQL_SHA"
git clone --branch cairn "$incoming/logbook-mountainous.bundle" "$release/mountainous"
"$release/mountainous/scripts/logbook-deploy" --check \
  "$EXPECTED_SOURCE_SHA" "$release/source" "$release/proseql"
# Publication uses the exact source checked above; the script checks it again.
"$release/mountainous/scripts/logbook-deploy" \
  "$EXPECTED_SOURCE_SHA" "$release/source" "$release/proseql"
UNZEN
```

Use a new release directory for a new SHA. If retrying an existing release,
inspect it and rerun its two script commands rather than discarding files.
The ProseQL bundle must include the revision in Logbook's lockfile; if it is
not reachable from main, create that bundle from a ref that contains it.

The script builds on Unzen with remote builders disabled. It makes an ephemeral
app-only flake from `deploy/logbook/flake.nix`, copies the authoritative SSH
pins from `deploy/known_hosts`, and locks both source inputs to their full SHAs.
It runs deploy-rs schema/activation checks, builds all three binaries, and tests
a temporary server's health, metrics RPC, and CLI. Before build and publication
it verifies both source HEADs and clean trees. It signs the entire activation
closure with `/var/lib/app-updater/signing-key`, then calls deploy-rs with
`--checksigs`, strict SSH host checking, and the existing deploy key. Only the
Logbook profile changes. Its activation restarts only the two Logbook units
and checks core health and a real metrics RPC response.

After the first node authorization, verify the tailnet path from a tailnet
client (health data is not printed):

```sh
curl -fsS https://logbook.hummingbird-lake.ts.net/healthz
curl -fsS https://logbook.hummingbird-lake.ts.net/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"metrics.list","params":{}}' \
  | jq -e '.result | length > 0'
```

Deploy-rs rolls back executables, not data schemas. A restart interrupts active
requests. Backups and alerts remain out of scope. Do not downgrade across an
incompatible data schema without a separate recovery plan.
