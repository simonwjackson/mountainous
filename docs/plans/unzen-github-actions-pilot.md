# Forgerie native runner implementation

The feature remains disabled on UNZEN. The dedicated App and encrypted credential are ready. Live admission and deployment acceptance remain open.

## Verified configuration

| Item | Evidence |
| --- | --- |
| Repository | GitHub API identifies `forgerie/forgerie` as public, with default branch `main`. |
| UNZEN registration | None. The physical host's runner unit is inactive. Test registrations use only a disposable VM. |
| Dedicated App | `forgerie-unzen-runner`, ID `5264213`, authenticated with only `organization_self_hosted_runners: write`. The operator's OAuth scopes and existing Forgerie App are unchanged. |
| Live group policy | Group `unzen-forgerie-manual`, ID `3`, selects only Forgerie and the exact main workflow. GitHub accepted the policy and production preflight passed its read-back. Scheduling enforcement needs a live test. |
| Encrypted key | `secrets/hosts/unzen-github-actions.yaml` has exactly operator and UNZEN recipients. Both identities decrypted it and matched the protected source key in memory. |
| Feature defaults | `github-actions-contract` proves disabled configurations create no runner unit or CI account. |
| Admission guard | Python policy tests reject changed refs, PR refs, extra workflows, other repositories and absent restrictions. |
| Actual unit policy | The VM checks disk scratch, hidden credentials and host daemon, Node 24, loopback HTTP, slice limits, stopping and cleanup. It also calls the shipped runner SDK's directory-permission validator and refuses parent-directory writes. |
| GitHub lifecycle | App authentication and registration work in a disposable VM. Admission controls and physical UNZEN artifact, cancellation, reboot and warm-run acceptance remain open. |

The committed isolation VM uses invalid credentials. Its probe replaces GitHub authentication and job dispatch, but calls the real runner SDK's workspace validator. It is not a successful Actions job. A separate disposable live-admission VM uses the App at runtime, without putting its key in a derivation or Nix store path.

## Source

- `modules/github-actions.nix` adds `mountainous.features.github-actions.enable`, disabled by default. It configures exactly one ephemeral runner in group `unzen-forgerie-manual` with label `unzen-forgerie`.
- `modules/github-actions-preflight.py` authenticates as the dedicated App and requires only `forgerie/forgerie` plus `forgerie/forgerie/.github/workflows/unzen-pilot.yml@refs/heads/main`. API errors and policy changes refuse registration.
- `tests/github-actions-contract.nix`, `tests/test_github_actions_preflight.py` and `tests/github-actions-isolation.nix` cover evaluation, admission policy and the real unit's runtime restrictions.
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

The existing UNZEN 95 W power limits, tmpfs policy, host daemon, weekly GC and other services are unchanged. The feature is not enabled on any host.

## Next activation

The dedicated runner-only App is installed on `forgerie`. Its organization runner-management permission can manage organization runners; selected repository installation does not narrow that organization permission. The existing App and operator token remain unchanged.

The protected source key lives outside Git, mode `0400`. The matching browser attachment was removed after encrypted recovery passed. No key bytes or tokens were printed.

The exact selected-repository/workflow group exists and passes read-back validation. Before registering UNZEN, prove that changed-ref and fork jobs stay unassigned while an online disposable runner accepts the allowed main workflow. The initial zero-runner probes stayed queued and were cancelled. Queuing with no runner is not admission evidence. If live enforcement fails, keep UNZEN disabled; do not substitute labels or a YAML condition.

After admission passes, declare the existing encrypted key as a root-owned SOPS secret, mode `0400`, set upstream `services.github-runners.forgerie.githubApp` fields and enable the feature only on UNZEN. Build and deploy a reviewed committed source, not the shared working tree's concurrent edits. Use verified SSH and non-destructive NixOS activation. Never run `nix run .#deploy`.

Only after registration passes, enable Forgerie's variable and run the pilot twice. Complete failure, cancellation, retry, reboot, offline, artifact and store-reuse checks. Do not expand registrations or move required checks before these pass.
