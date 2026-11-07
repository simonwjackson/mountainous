# Service-app pilot evidence — 2026-11-07

Verified: groceries runs on Rakku at its original HTTPS address. Signed app-only
deployment and automatic rollback work. Groceries' own update gate is open.
Pi's global gate remains closed; pi was not deployed in this stage.

## Runtime result

| Item | Verified result | Evidence |
|---|---|---|
| Address | `https://groceries.hummingbird-lake.ts.net` unchanged | `groceries-assistant-*.json` |
| Data | 4 original household lines; SHA256 `e0044707e3e474b3ebc2e62a39ec5b4ec4a67f7ef73fe3aa18b68e30ae55967e` unchanged | `groceries-zao-before.json`, assistant probes |
| Build | `da964fb179357a30` unchanged | probes, rollback receipt |
| Assistant users | `pi-simon`, `pi-laure`, `pi-household`; each read its own installed token | `probes-from-zao/`, `probes-after-rollback/` |
| Signed deploy | receipt `1794021172461424514`, source `6fa8bc40`, application `51ccf1a0` | `groceries-signed-deploy-receipt.json` |
| Healthy profile | `/nix/store/3sqalgsl6c581x9wwa6q9f0fmcil60pv-activatable-groceries-0.1.0` | signed deploy and rollback receipts |
| Broken candidate | `/nix/store/hcblz10h4fgkyhbp6l0qf0z8s9d1w2dk-activatable-broken-groceries-0.1.0`; server exits 1 | rollback receipt/log |
| Rollback | runtime readiness timeout; deploy exit 1; same healthy profile and HTTPS build restored without manual repair | `groceries-rollback-verified.json`, `.log` |
| Signature trust | recursive verification of 132 paths, one trusted signature required, no contents scan; exit 0 | `groceries-signature-verification.txt` |
| Automation | root-owned 0600 `enabled-groceries`; timer 04:15 UTC | `groceries-gate.txt` |

Rakku reports `running` and zero failed system units. All seven required units
are active: `home-assistant`, `zwave-js`, `pi-assistant-simon`,
`pi-assistant-laure`, `pi-assistant-household`, `beszel-hub`, `cliproxyapi`.
See `rakku-post-rollback-health.txt`. Source data, config and tsnet state remain
on Zao. Destination homes and retry snapshots live below Rakku's persistent
`/tundra/permafrost/var/lib/groceries` bind, with private ownership/modes.

## Correction: source unit definitions

The successful cutover ran only:

```
systemctl --user disable groceries.service groceries-proxy.service
```

Systemd removed four symlinks: the two `default.target.wants` enablement links
and the two main unit-definition links. No `rm` command removed a unit, and no
regular unit file or Nix-store content was deleted. The original targets were
recorded before the operation in `groceries-zao-units.txt`:

- `groceries.service` → `/nix/store/hd7x2gnyprhlq76vp329r87bsbz50z8z-groceries-0.1.0/share/systemd/user/groceries.service`
- `groceries-proxy.service` → `/nix/store/hd7x2gnyprhlq76vp329r87bsbz50z8z-groceries-0.1.0/share/systemd/user/groceries-proxy.service`

Both exact main links were restored in `~/.config/systemd/user`, then
`systemctl --user daemon-reload` ran. Both units are inactive. Neither has an
enablement link. `is-enabled` returns 1 and prints **linked**, rather than
**disabled**, because these definitions point outside the unit search paths
into the store. This is not the `enabled` state. The exact links were retained
instead of replacing them with regular files merely to change the label.
See `groceries-zao-units-restored.txt` and `groceries-zao-disabled.txt`.
The disable helper now preserves linked definitions.

## Systems and loss checks

| Host | Before | Running after platform provisioning |
|---|---|---|
| Unzen | `01ryl8slvlp7l92h6py14g55vdmnd30b` | `f7csfm4wi578fk0h7yd3pb4kpx4yd5cw` |
| Rakku | `xv36kpzahvhdv7wgh1fdgb2s37w94kj3` | `jabc98p2grcv0f5h04v01yq1rgqpm625` |

These abbreviate the full `nixos-system-*-26.11.20260923.4975466` store paths.
Every switch used an on-host closure comparison and complete `/etc` file-content
and unit comparison before setting the system profile and switching. No missing
running feature was accepted. The inherited `cd79a089` Tailscale SSH-off addition
was reviewed and approved; Rakku's `RunSSH` is false. The controller-only follow-up
changed system-path references and D-Bus restart triggers, not household services.
See `unzen-compare.txt`, `rakku-compare-before-switch.txt`, and
`rakku-controller-compare.txt`, plus their switch logs.

The controller switch logged a legacy `simonwjackson` user-activation warning
while that user manager stopped. Its manager was then inactive. The system was
running, with zero failed system units and all seven core services active.
No unrelated user manager was restarted to hide this warning.

## Failures diagnosed before retries

1. Initial stopped import had a 0755 home. The pre-deploy mode guard rejected it.
   Staging now enforces 0700 private parent directories and preserves retry data.
2. A shallow configuration merge discarded the controller package list when
   persistence was enabled. `mkMerge` now composes both, and the contract builds
   the actual system path and checks that the controller executable is installed.
   An on-host scoped sudo stop succeeds; an unrelated Home Assistant restart is
   denied (`groceries-sudo-scope.txt`).
3. The next signed deployment succeeded, but the probe guessed the nonexistent
   account `pi-assistant-simon`. Probes now read each unit's actual `User=`. All
   three were tested alone against the Zao-served address before the final retry.
4. The final cutover passed. Each backout stopped the destination before resuming
   Zao. Unaccepted profile aliases and retry snapshots were preserved, not deleted.

The first rollback checker observed a transient HTTPS 502 after the old profile
and Type=simple units returned, but before old backend readiness. The app recovered
without repair. The checker now waits for HTTPS readiness and requires log evidence
of both runtime failure and deploy-rs rollback. The final proof passed.

## Checks

| Check | Result |
|---|---|
| Native groceries package, checks enabled | 65 Vitest files, 999 passed, 1 existing private-dataset skip; typecheck, lint, gates and script tests passed |
| App behaviour unchanged | old/new compiled server and web assets byte-identical; tsnet store path identical |
| `checks.x86_64-linux.service-apps` | passed, including installed-controller regression |
| `checks.x86_64-linux.app-updater-closure` | passed |
| Python updater unit tests | 9 passed |
| Bash helpers / Python helpers | ShellCheck and Python compilation passed |
| Backend preflight | checked binary, isolated copied data, actual credentials and legacy private binds; no second tsnet node |
| Actual assistant path | all 3 users authenticated before migration and after rollback, with unchanged data hash |
| Known-credential evidence audit | 62 files contained none of the six fixed plaintext credentials or two updater private keys |
| `checks.x86_64-linux.app-profiles` | **pre-existing failure**, also reproduced at baseline `cd79a089d384c1e264dfe825507f0234c2d9092a` |

The existing app-profiles contract wrongly requires pi to be enabled on every
host. Aka explicitly disables it at `modules/hosts/aka.nix:149`, in both baseline
and this branch. Diagnostic booleans isolate the failure to Aka's disabled pi
and its absent pi-only secrets/tmpfiles. Account and signing boundaries pass.
See `app-profiles-baseline-failure.txt` and `app-profiles-diagnostic.json`.
No aggregate flake check was run.

## Pi gate and remaining costs

Approved x86-only `--check-only` passed on source `96f6fb24`, selecting pi 1.5.0
at `a8602962df79d4be488c7a08ce56307370f4b475`. The selected host set was Aka,
Ibuki, Myoko, Rakku, Tate and Unzen. No host was deployed; this is not SSH or
fleet convergence proof. See `pi-x86-check-only-receipt.json`.

- **Pi global gate remains absent.** ARM native execution has no approved scoped
  transport. Fuji's existing key is forced to daemon protocol. No new key or
  controller was provisioned and no ARM deployment was attempted.
- Remote-store builds do not enforce the caller's empty builder policy. The old
  attempt delegated to Aka, whose daemon has `max-jobs = 0`. The updater now fails
  closed for ARM; successful x86 builds ran natively on Unzen with two jobs and
  empty builders. Fleet builder policy is a separate follow-up.
- Hiyori stays excluded while offline and unpinned. Myoko uses OpenSSH port 2222.
- Zao remains groceries' private Git source availability dependency, not a runtime
  dependency. Relocation needs retained history and an input update.
- Rotate server/client copies of the assistant token together. App rollback does
  not reverse data migrations. Every actual activation briefly interrupts the app.
- Migration snapshots, unaccepted profile aliases and all original source state
  remain available. Do not start the old tsnet node while Rakku serves it.

Reusable declaration and migration steps: [`../service-apps.md`](../service-apps.md).
