# Forgerie native runner implementation

UNZEN runs the reviewed native runner configuration. Registration and physical resource checks passed. The first complete pilot found two application cache failures on bcachefs; cold/warm and lifecycle acceptance remain open.

## Verified configuration

| Item | Evidence |
| --- | --- |
| Repository | GitHub API identifies `forgerie/forgerie` as public, with default branch `main`. |
| UNZEN registration | Physical runner `unzen-forgerie`, initially ID `10`, was online and idle in group `3` before the first main pilot. |
| Dedicated App | `forgerie-unzen-runner`, ID `5264213`, authenticated with only `organization_self_hosted_runners: write`. The operator's OAuth scopes and existing Forgerie App are unchanged. |
| Live group policy | Group `unzen-forgerie-manual`, ID `3`, selects only Forgerie and the exact main workflow. GitHub accepted the policy and production preflight passed its read-back. An online runner accepted main while changed-ref and fork controls remained unassigned. |
| Encrypted key | `secrets/hosts/unzen-github-actions.yaml` has exactly operator and UNZEN recipients. Both identities decrypted it and matched the protected source key in memory. |
| Feature defaults | `github-actions-contract` proves disabled configurations create no runner unit or CI account. |
| Admission guard | Python policy tests reject changed refs, PR refs, extra workflows, other repositories and absent restrictions. |
| Actual unit policy | The VM checks disk scratch, hidden credentials and host daemon, Node 24, loopback HTTP, slice limits, stopping and cleanup. It also calls the shipped runner SDK's directory-permission validator and refuses parent-directory writes. |
| GitHub lifecycle | The first physical main job uploaded its native environment artifact and completed with an application test failure. Successful full runs, cancellation, reboot and warm-run acceptance remain open. |

The committed isolation VM uses invalid credentials. Its probe replaces GitHub authentication and job dispatch, but calls the real runner SDK's workspace validator. It is not a successful Actions job. A separate disposable live-admission VM uses the App at runtime, without putting its key in a derivation or Nix store path.

## Live admission evidence

The group policy was not widened for testing. A disposable runner was online and idle for 62 seconds while both negative jobs stayed queued with no assignment or started steps. The allowed main control then reached that same runner in group `3`; checkout and the native toolchain check passed. The controls were deliberately cancelled after routing evidence was collected.

| Control | GitHub run | Observed behavior |
| --- | --- | --- |
| Changed branch | [38065018631, attempt 3](https://github.com/forgerie/forgerie/actions/runs/38065018631) | Unassigned before and after the main positive control. |
| Fork PR | [38065123150, attempt 3](https://github.com/forgerie/forgerie/actions/runs/38065123150) | Unassigned before and after the main positive control. |
| Allowed main | [38066539907](https://github.com/forgerie/forgerie/actions/runs/38066539907) | Assigned to runner ID `8`, `unzen-admission-disposable-vm`, in the restricted group. |

The VM registration, runtime key and disposable disk were removed. The pilot variable returned to `false`. [Test PR #28](https://github.com/forgerie/forgerie/pull/28) was closed without merging. No negative job ran on UNZEN.

## Source

- `modules/github-actions.nix` adds `mountainous.features.github-actions.enable`, disabled by default. It configures exactly one ephemeral runner in group `unzen-forgerie-manual` with label `unzen-forgerie`.
- `modules/github-actions-preflight.py` authenticates as the dedicated App and requires only `forgerie/forgerie` plus `forgerie/forgerie/.github/workflows/unzen-pilot.yml@refs/heads/main`. API errors and policy changes refuse registration.
- `tests/github-actions-contract.nix`, `tests/test_github_actions_preflight.py` and `tests/github-actions-isolation.nix` cover evaluation, admission policy and the real unit's runtime restrictions.
- `modules/hosts/unzen.nix` enables only UNZEN and declares the App ID `5264213`, organization login `forgerie` and a root-owned, mode `0400` SOPS secret. Key rotation restarts only the runner service.
- `.sops.yaml` restricts `secrets/hosts/unzen-github-actions.yaml` to the operator and UNZEN. The encrypted credential is deployed as a root-owned, mode `0400` file.
- Forgerie's `.github/workflows/unzen-pilot.yml` is manual and gated by `UNZEN_PILOT_ENABLED`. Its hosted CI workflow and required checks are unchanged. The operator guide is `docs/ci-unzen-pilot.md` in Forgerie.

Run the feature tests from this repository:

```bash
nix build .#checks.x86_64-linux.github-actions-contract \
  .#checks.x86_64-linux.github-actions-preflight \
  .#checks.x86_64-linux.github-actions-isolation --no-link -L
```

## Resource and storage choice

The CI slice has a 400% CPU quota, 12 GiB memory high, 16 GiB maximum and 2048 tasks. Parent directories are root-owned, mode `0750`, with the runner's group. The runner can list and traverse them but cannot replace cleanup roots. Workspace and scratch leaves remain mode `0700`.

The live listener exposed a startup defect in the original `0711` parent policy. Its `IOUtil.ValidateExecutePermission` method enumerates every ancestor. A regression test calls that exact method from the shipped `Runner.Sdk.dll`: it failed on `/srv/github-actions/work` before the fix and passed afterward. The permission change exposes directory names only to the runner group, not credential contents. The service replaces tmpfs-backed private temporary files with disk-backed private bindings. Node 24 comes from the pinned OS closure, which roots it across garbage collection.

The pilot cannot access the host Nix daemon. This bounds actual npm build/test processes without silently imposing build limits on CLIProxyAPI updates or system rebuilds. It does not support Nix source builds yet, nor does it cache arbitrary npm test/build results.

LAN, tailnet and link-local destinations are blocked. Loopback remains available for HTTP tests. Native jobs share the kernel and host loopback, so this configuration does not permit untrusted code. A compromised dependency is still a host risk.

The physical host reports both package power limits as `95000000` µW. Its actual CI cgroup has `cpu.max = 400000 100000`, `memory.high = 12884901888`, `memory.max = 17179869184` and `pids.max = 2048`. The worker is inside that cgroup. The host tmpfs policy, daemon access for existing clients and weekly GC remain unchanged.

Adding the generation changed D-Bus/polkit restart-trigger store paths, not their commands or binaries. Inspection verified equivalent D-Bus configuration after normalizing the system-path reference and exactly five added CI tmpfiles rules. D-Bus reloaded without changing its process. Polkit restarted and stopped its `Requires=` dependent, ModemManager. The first guard detected that stop and rolled back. ModemManager was restored, and the corrected activation guard restores this verified dependent after activation and rollback. Other existing processes remained unchanged during the passing test and acceptance windows.

## Physical activation and first pilot

Source revision `cb233f3375718e9fd1f948ac40b04d94e8521456` built all three feature checks and the complete UNZEN system. The reviewed closure is `/nix/store/13vv0nisbl20ia16bgj0cy97adwn7qgv-nixos-system-unzen-26.11.20260923.4975466`. Guarded `test` activation passed, then the same closure became the default profile. Kernel and initrd paths were preserved. The previous system remains GC-rooted for rollback.

Public receipts are [admission.json](../hardware/unzen-github-actions-2026-10-10/admission.json) and [activation.json](../hardware/unzen-github-actions-2026-10-10/activation.json). No live Forgerie service on zao was restarted.

[Physical pilot 38069917257](https://github.com/forgerie/forgerie/actions/runs/38069917257) ran main `f71220c00afb72b5e631fb820d9f9cfee54eb288` on runner `10`. Checkout, native checks, npm installation, static checks and artifact upload passed. Server tests reported 1809 passed, two failed and three skipped. Browser verification, build and package smoke tests were skipped after that failure. The artifact verifies Node `v24.20.0` from the Nix store, bcachefs temporary files and inaccessible host daemon.

A bounded probe using the real scanners on disposable physical bcachefs files reproduced both failures. Distinct 64-bit inodes collapse to the same JavaScript Number, and the numeric durable index rejects unsafe identities on reload. [Forgerie #31](https://github.com/forgerie/forgerie/issues/31) tracks the fix. Do not weaken assertions or isolation to pass the pilot.

The upstream ephemeral runner cleans its complete workspace on each registration. Since `HOME` is that workspace, npm cache is also cleared. A warm repeat tests persistent Nix-store/toolchain reuse, not retained npm downloads.

## Remaining acceptance

The dedicated runner-only App is installed on `forgerie`. Its organization runner-management permission can manage organization runners; selected repository installation does not narrow that organization permission. The existing App and operator token remain unchanged.

The protected source key lives outside Git, mode `0400`. The matching browser attachment was removed after encrypted recovery passed. No key bytes or tokens were printed.

The exact selected-repository/workflow group passed read-back and live admission. The initial zero-runner probes were inconclusive. The later online-runner test supplied both negative controls and a working main positive control. Keep the registration preflight enabled so future policy changes fail closed.

Future deployment must also use reviewed committed source, not the shared working tree's concurrent edits. Compare against the running system, preserve the kernel and other service commands, and retain rollback. Use verified SSH and non-destructive NixOS activation. Never run `nix run .#deploy`.

The first physical dispatch restored `UNZEN_PILOT_ENABLED` to `false` after failure. Fix #31, review the resulting main revision, and run the pilot twice. Complete cancellation, retry, reboot, offline, artifact and store-reuse checks. Do not expand registrations or move required checks before these pass.
