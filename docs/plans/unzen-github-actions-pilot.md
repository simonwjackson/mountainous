# Forgerie native runner implementation

Live admission passed. The committed UNZEN configuration now declares the dedicated App, root-only SOPS secret and runner feature. Physical deployment and lifecycle acceptance remain open.

## Verified configuration

| Item | Evidence |
| --- | --- |
| Repository | GitHub API identifies `forgerie/forgerie` as public, with default branch `main`. |
| UNZEN registration | None. The physical host's runner unit is inactive. Test registrations use only a disposable VM. |
| Dedicated App | `forgerie-unzen-runner`, ID `5264213`, authenticated with only `organization_self_hosted_runners: write`. The operator's OAuth scopes and existing Forgerie App are unchanged. |
| Live group policy | Group `unzen-forgerie-manual`, ID `3`, selects only Forgerie and the exact main workflow. GitHub accepted the policy and production preflight passed its read-back. An online runner accepted main while changed-ref and fork controls remained unassigned. |
| Encrypted key | `secrets/hosts/unzen-github-actions.yaml` has exactly operator and UNZEN recipients. Both identities decrypted it and matched the protected source key in memory. |
| Feature defaults | `github-actions-contract` proves disabled configurations create no runner unit or CI account. |
| Admission guard | Python policy tests reject changed refs, PR refs, extra workflows, other repositories and absent restrictions. |
| Actual unit policy | The VM checks disk scratch, hidden credentials and host daemon, Node 24, loopback HTTP, slice limits, stopping and cleanup. It also calls the shipped runner SDK's directory-permission validator and refuses parent-directory writes. |
| GitHub lifecycle | App authentication, registration and main-only admission passed in a disposable VM. Physical UNZEN artifact, cancellation, reboot and warm-run acceptance remain open. |

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
- `.sops.yaml` restricts `secrets/hosts/unzen-github-actions.yaml` to the operator and UNZEN. The encrypted credential now exists. It has not been deployed.
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

The existing UNZEN 95 W power limits, tmpfs policy, host daemon, weekly GC and other services are unchanged. Only UNZEN's source configuration enables the runner feature; physical deployment is still pending.

## Next activation

The dedicated runner-only App is installed on `forgerie`. Its organization runner-management permission can manage organization runners; selected repository installation does not narrow that organization permission. The existing App and operator token remain unchanged.

The protected source key lives outside Git, mode `0400`. The matching browser attachment was removed after encrypted recovery passed. No key bytes or tokens were printed.

The exact selected-repository/workflow group passed read-back and live admission. The initial zero-runner probes were inconclusive. The later online-runner test supplied both negative controls and a working main positive control. Keep the registration preflight enabled so future policy changes fail closed.

The host source now declares the encrypted key and upstream `services.github-runners.forgerie.githubApp` fields. Build and deploy a reviewed committed source, not the shared working tree's concurrent edits. Compare the candidate against the running system before activation, preserve its kernel and other service units, and retain a rollback root. Use verified SSH and non-destructive NixOS activation. Never run `nix run .#deploy`.

Only after registration passes, enable Forgerie's variable and run the pilot twice. Complete failure, cancellation, retry, reboot, offline, artifact and store-reuse checks. Do not expand registrations or move required checks before these pass.
