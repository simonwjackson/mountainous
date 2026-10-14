# Independent application profiles

Unzen selects an input revision, checks each architecture and deploys each app
profile separately. It never calls a system activator, commits to `cairn`, or
runs flake-wide checks. The shared account `app-deploy` has an unprivileged
shell and a writable home. SSH `restrict` disables forwarding, PTY and user rc;
it does **not** limit shell commands to app deployment. The account owns the
shared profile directory `/nix/var/nix/profiles/apps`. It has no sudo rules,
wheel membership or Nix trusted-user access. Host system profiles remain
root-owned and isolated. Signed closures permit imports through the Nix daemon.
A stolen deploy key can replace **all app profiles**, not host system profiles.
A stolen signing key can authorize store content; keep both private on Unzen.

The host system contains directory, access, PATH, secret and settings hooks.
It does not contain pi or its extension. Changing those hooks needs an approved
system rebuild. Changing application inputs does not. There is no CLIProxyAPI
updater change.

## pi policy

The Bun package is `pi.packages.<system>.coding-agent-bun`, with its own
nixpkgs pin. The extension is an app-closure dependency, passed with `-e`.
Only `simon` is provisioned to run pi. All users see its profile on PATH, but
other users get an explicit unprovisioned-directory error. Additional users
need their own system-owned layout, mount and secret policy.

`/var/lib/pi/simon` is root-owned 0755. Its `agent` child is simon-owned 0700
for auth, sessions and caches. The root systemd mount binds the store settings
file read-only onto `agent/settings.json`. `nofail` removes its implicit
`Before=local-fs.target` dependency, so waiting for tmpfiles does not form a
boot cycle. A failed mount does not block host boot; pi still fails closed.

The fleet Bun package patches its executed, unbundled SettingsManager module.
Global reads bypass the user-owned lock entirely. A pre-made
`settings.json.lock` therefore cannot hide the global policy. Missing, empty
or malformed global settings throw out of startup rather than fall back to
`{}`. Global writes are rejected; project settings retain upstream behavior.
The patch pins the complete module hash, checks the CLI/startup import chain,
checks for embedded SettingsManagers, and requires unique replacement matches.
**Cost:** an upstream SettingsManager change stops the affected application
builds on the four-times-a-day schedule until an operator reviews and updates
the patch. The updater records failure and leaves deployed/accepted releases
unchanged when no architecture succeeds. The patched runtime needs a local
rebuild; upstream dependency and Bun-workspace cache paths remain unchanged.
`What=` and `restartTriggers` change with the settings store path, so the NixOS
switch restarts that mount rather than only remounting its old source.
The wrapper refuses to start unless that exact mountpoint has read-only VFS
options. User IDs are resolved by account names; Rakku keeps uid 1001.

The wrapper creates a fresh mode-0700 TMPDIR inside the private agent tmp
directory for every invocation. This prevents the extension's predictable
patched-module filename from executing another user's code. Normal exits
remove it. SIGKILL can leave temporary directories; remove those when pi is
not running. The key is read only at runtime from
`/run/secrets/pi-cliproxyapi-api-key` (simon, 0400). It is encrypted in
`secrets/fleet.yaml` for the existing fleet recipients. Plaintext did not enter
an argument, repository file or store derivation.

Telemetry is disabled in settings, and `PI_OFFLINE=1` suppresses startup network
probes. We deliberately omit `lastChangelogVersion`: it cannot follow an app
update in a system-built file. **Cost:** pi treats starts as fresh installs and
may attempt settings bookkeeping; the changelog stays collapsed, not
acknowledged. There is no install telemetry. Locked writes can fail silently:
the TUI can claim a changed default, and `pi install` can say “Installed” even
though settings did not change. Restart pi to see the actual system policy.

## One-time Deploy preparation (not performed by Build)

1. On Unzen, as root, make `/var/lib/app-updater` and `ssh` mode 0700.
   Generate dedicated keys, unrelated to the CLIProxyAPI keys:
   ```sh
   umask 077
   install -d -m 0700 /var/lib/app-updater/ssh
   ssh-keygen -t ed25519 -N '' -f /var/lib/app-updater/ssh/id_ed25519
   ssh-keygen -t ed25519 -N '' -f /var/lib/app-updater/ssh/builder_ed25519
   nix key generate-secret --key-name app-updater-1 > /var/lib/app-updater/signing-key
   nix key convert-secret-to-public < /var/lib/app-updater/signing-key
   ```
2. Commit **only** the public keys in a shared base layer:
   `mountainous.appDeployment.{deployPublicKey,signingPublicKey,builderPublicKey}`.
   Set `mountainous.appDeployment.enable = true`. Assertions require all three.
   The Fuji builder key runs only `nix-daemon --stdio`, like Zao's key.
   Access is disabled until this step; host profiles and pi hooks still evaluate.
3. Verify pinned SSH host keys against operator-controlled host identities.
   Six live ed25519 keys were collected on 2026-10-14. Myoko's scanner connection
   failed; its pin comes from its existing public install key on Zao. Hiyori
   timed out and remains a TODO in `deploy/known_hosts`; it fails closed until
   its verified key is committed. Myoko's unattended Tailscale SSH check remains
   an access-policy blocker. Neither blocker stops other hosts.
4. Apply the approved host system changes once. Do not use `nix run .#install`.
   Confirm the settings mount is read-only and points at the current store file.
5. Seed an operator-reviewed, fixed source revision on Unzen:
   ```sh
   git clone --branch cairn https://github.com/simonwjackson/mountainous.git /var/lib/app-updater/repository
   git -C /var/lib/app-updater/repository checkout --detach <reviewed-commit>
   ```
   GitHub's repository API returned HTTP 200 without credentials on 2026-10-14:
   this repository is public. No GitHub credential is required. The updater
   never pulls mountainous or modifies this checkout. **Cost:** shared updater
   code/extension/system-policy changes require Deploy to replace the reviewed
   checkout revision. This avoids silently running new orchestration code.
6. Run `app-update --config <app-updates.json path from ExecStart> --app pi
   --check-only` using the service environment. This builds ARM on Fuji via
   `ssh-ng://simon@fuji.hummingbird-lake.ts.net`; the ninth builder field pins its
   public host key through the local daemon. Private builder key stays in the
   state directory. **Cost:** first ARM build is large (probe: 463 derivations)
   and depends on Fuji. An ARM failure does not stop checked x86 deployments.
7. After verification, create `/var/lib/app-updater/enabled` and start
   `app-update-pi.service`. The timer is `*-*-* 00,06,12,18:00:00 UTC`.

The global flock serializes apps. Dirty checkouts are rejected. Both the
checked-in and accepted versions/revision dates are downgrade floors. Builds
use an exact `--override-input` ref and `--no-write-lock-file`; the tracked
lockfile stays unchanged. Targeted checks run the app's `--version` and check
the deployment schema. Each activation closure is built before deployment.
`deploy --checksigs --skip-checks` avoids evaluating host systems or Ibuki's
Zao-only Korri source. Rollback is scoped to the selected app profile.

Receipts and command logs under `receipts/` are private (0600 inside 0700).
Each receipt records per-host status. Any success advances `accepted-pi.json`;
failures are retried next run even for the same revision. Partial failure exits
nonzero for systemd reporting. No remote deployment was performed by Build.

## Add a second app

Add `inputs.tool.url = "github:owner/tool";` in `flake.nix`. In a shared module:

```nix
{ inputs, lib, ... }: {
  mountainous.appProfiles.tool.package = system:
    inputs.tool.packages.${system}.default;
  nixos.modules.base = { config, ... }: {
    mountainous.appUpdates.tool = lib.mkIf (config.networking.hostName == "unzen") {
      input = "tool";
      schedule = "*-*-* 00,06,12,18:00:00 UTC";
      hosts = [ "fuji" "hiyori" "ibuki" "myoko" "rakku" "tate" "unzen" "yari" ];
    };
  };
}
```

The package must expose `version` and `bin/tool --version`. GitHub and git
inputs are supported. Optional `hostModule` supplies app-specific host hooks.
No new deploy account, signing key, timer implementation or host-file setting
is needed. Add and lock new inputs, check, then Deploy the reviewed source and
any new host hooks.

## Build verification (2026-10-14)

- `nix flake check` passed on Zao (x86_64); its normal invocation omits ARM.
- All eight fleet `system.build.toplevel.drvPath` evaluations passed, including
  Ibuki with the local Korri checkout on Zao. Host files were not changed.
- The app, profile contract, deploy schema and deploy activation checks passed.
  Seven updater policy/filesystem/subprocess tests passed.
- At commit `b91a4a72`, a real clean-checkout `app-update --check-only` run resolved pi's latest
  revision and built/checked the x86 app and activator. It left the source clean
  and wrote a private receipt. The wrapper returned Bun pi version `1.2.0`;
  an unprovisioned prompt invocation failed before reading the key or calling
  the endpoint. Provider extension version is `1.4.22`.
- In an isolated copy, Korri's locked and original URLs were changed to an
  absent `/nonexistent/korri`. `.#deploy` and both app package derivations still
  evaluated with `--no-update-lock-file`. Unzen does not need Korri.
- At commit `b91a4a72`, plaintext-key scanning covered tracked files and
  189 `nix path-info -r` paths for the realized x86 app and updater (31,463
  files). No plaintext key or SSH private-key header was found. The settings
  file was subsequently realized and checked for its declared public policy.
  A final updater run and key scan including settings remain gated and were
  not executed. Deploy must rerun that scan. ARM was evaluated, not built.
- Additional `nix flake check --all-systems --no-build` exposed an existing
  nix-extras Nzbfast module error: `packages.aarch64-linux` is absent. This is
  outside app-profile scope and blocks fleet-wide ARM check evaluation, not
  the app packages or generated deployment graph.

No host deployment, switch, install, key generation or state change was done.
Deployment tests, ARM remote building and actual locked-setting interaction
remain for Deploy once dedicated keys and the initial host hooks are installed.

## Review corrections (2026-10-14)

The original boot-order and settings-lock claims were wrong. The original
mount formed a local-fs/tmpfiles cycle, and an existing user-owned lock made
upstream pi read `{}`. Both failures were reproduced before the fixes.

`checks.pi-policy` now boots the real host mount in a NixOS VM and runs
`systemd-analyze verify` with systemd 261.2. A negative control recreates the
original cycle; diagnostics matter because verify can return zero after
deleting a cyclic job. The VM tests effective settings through the actual Bun
SettingsManager as simon with a pre-made lock and a read-only bind mount. It
also confirms that the actual CLI exits on missing or malformed policy.
Six patch-drift tests use the real upstream dist tree. The package's install
checks repeat the lock/read/parse regression for every app build.

Pi's update declaration and cache policy now live in `modules/pi.nix`.
The shared updater takes each app's optional `substituters` and
`trustedPublicKeys`; it contains no pi-specific declaration or cache.

Review verification passed: `nix flake check` on x86_64, all eight fleet
`system.build.toplevel.drvPath` evaluations, the boot/lock/CLI VM test, six
patch-drift tests and seven updater tests. `nix path-info -r` plus `grep -c`
found **0 plaintext-key matches** across 108 realized pi closure paths
(22,334 files counted). The key reached grep only through an anonymous file
descriptor; it was not printed or placed in argv. ARM remains evaluation-only.
No deployment or host change was made.
