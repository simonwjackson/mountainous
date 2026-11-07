# Service apps

Mountainous owns accounts, units, storage, secrets and tailnet identity. The
signed app profile owns only executables. Logbook and CLIProxyAPI keep their
existing deploy paths.

## Add an app

Add a Git flake input exposing `packages.<system>.default` with a `version`.
Declare the service on its destination host:

```nix
mountainous.serviceApps.example = {
  input = "example";
  port = 4383;
  schedule = "*-*-* 04:30:00 UTC";
  secrets.example-token = ".config/example/token";
  smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4383/healthz >/dev/null";
};
```

Defaults: account/group `<name>`, 0700 home `/var/lib/<name>`, data in
`data`, tailnet state in `state/tsnet`, binaries `<name>-server` and
`<name>-tsnet`, profile `/nix/var/nix/profiles/apps/<name>`. The server gets
`--host 127.0.0.1 --port PORT --data-dir HOME/data`. The sidecar gets `--name`,
`--expected-fqdn`, `--upstream` and `--state`. Override `server`, `serverArgs`,
`sidecar`, `sidecarArgs`, `tailnet`, or `environment` for other CLI contracts.
Both units skip startup until their binary exists. Only the sidecar's tsnet
directory is writable in its sandbox. Persistence is automatic when the host
has impermanence; Rakku uses `/tundra/permafrost`.

`secrets` maps host SOPS keys to home-relative destinations. The service reads
the 0400 SOPS files and copies them to owned regular 0600 files before start.
This supports programs which reject symlinks. Do not use this for mutable
OAuth refresh state: persist that state instead. `readOnlyBinds` supports
legacy fixed credential paths without changing the upstream app.

`checkCommand` optionally runs in the build sandbox with `APP_PACKAGE` set to
the candidate. It must not need secrets or network access. `smokeCommand` runs
on the destination as `app-deploy`, not root. Use an absolute binary path and
a bounded command. `activationTimeout` defaults to 60 seconds (5–240 allowed).
Keep public checks free of personal data. App-specific CLI/secret adapters
belong in `lib/`, not copies of the unit or deploy machinery.

The module derives Unzen's `appUpdates` entry and destination hosts from the
host declarations. No second app/host registry is needed. An app's input and
update schedule must agree between hosts.

## Deploy and rollback

Unzen's updater requires a clean, pinned mountainous checkout. It follows the
app input, pins the selected revision, rejects downgrades, and builds only that
app's check and deploy-rs attributes. Jobs are bounded to two. ARM builds run
on Fuji's daemon with `builders = ""`; they cannot hand work back to Yari.
The builder key allows only the daemon protocol. Receipts record the source
commit, candidate, builds and per-host outcomes in `/var/lib/app-updater`.

The updater signs the activation closure with `app-updater-1`. Deploy-rs uses
`app-deploy`, strict SSH pins and `--checksigs`, with automatic and magic
rollback. It atomically changes only that app's profile. Activation resolves
the fixed controller from `/run/current-system/sw/bin/<name>-service-control`,
then invokes `sudo -n` with exactly `stop` and `start`. Sudo permits only those
two complete commands at that controller's immutable store path. The controller
can affect only `<name>.service` and `<name>-tsnet.service`; it accepts no unit
name, executable, shell command or extra argument.

Activation waits for both units to become active and the smoke check to pass,
then checks them again after three seconds. A failure or timeout fails the
deploy. Deploy-rs restores the previous profile and runs its activation, which
restarts the old executables. Data is **not** rolled back. An incompatible data
schema needs its own backup and restore plan. Every update briefly interrupts
requests. Keep the previous generation and test rollback before enabling a new
app's automatic deployment.

## Cut over an existing node

1. Read both source units and all drop-ins. Record flags, home, data, config,
   private credentials, OAuth state and the exact tsnet directory. Confirm
   that the assistant's service token matches without printing either copy.
2. Add the source input, destination declaration and SOPS values. Stage new
   files before evaluating. Build only the relevant app/check and system
   attributes, one at a time, with `--max-jobs 2`.
3. Copy the system closure with `nix copy --no-check-sigs --to ssh-ng://root@HOST`.
   Run `scripts/service-apps-host-target compare OLD NEW` on the host. Save and
   inspect the closure diff and **file-content** diffs for all of `NEW/etc`,
   including units. A missing running feature is a stop condition: find the
   source branch instead of switching. Recheck the running path at switch.
4. Stop only the source app and proxy. Do not delete their files. Copy data,
   config (including mutable refresh tokens) and tsnet state while stopped.
   Keep the old directories untouched. Verify hashes and set the destination
   account's ownership. Never run two copies of a tsnet identity.
5. Activate the reviewed system with `scripts/service-apps-host-target switch
   OLD NEW`. It sets the system profile, switches without rebooting, and
   checks system health. On Rakku all seven household core units must remain
   active. The profile gate prevents the new app from starting too early.
6. Run the signed app deployment from Unzen. Check old data and the unchanged
   tailnet FQDN through HTTPS, including authenticated requests as each Rakku
   assistant. Only then disable the two source units. Retain source state.
7. Deploy an intentionally failing candidate and save the deploy exit status,
   before/after profile targets, and old service health as rollback evidence.
   If data or node identity cannot be carried, stop the destination and start
   the source units again. Never start both nodes to diagnose the problem.

## Groceries source

Groceries' canonical source is Zao's Git repository at
`/home/simonwjackson/code/sandbox/groceries`, branch `main`; it has no published
remote. The input follows it over SSH. Unzen's existing app key has a forced
`git-upload-pack` command restricted to this one repository. The verified Zao
host key is in `deploy/known_hosts`. The updater's `GIT_SSH_COMMAND` supplies
that key and pin. `scripts/service-apps-provision-groceries-source` installs
only this read authorization and preserves existing keys. Zao remains a
source availability dependency, but not a runtime dependency after cutover.
A future source relocation must retain Git history and update this input.

`lib/groceries-service.nix` adapts the existing private-file contract, including
Kroger's fixed `/run/agenix` paths. `scripts/service-apps-import-groceries-secrets`
imports six fixed credentials without printing them and verifies that every
existing Rakku SOPS value stays unchanged. Mutable credentials/config are
copied with the service state, not embedded in a Nix derivation.

Hiyori is excluded from pi updates while offline and without a verified SSH
pin. The global updater gate must remain closed until one signed pi run
succeeds on every remaining pi host. Do not open it on a partial receipt.
