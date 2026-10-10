# Forgerie native runner implementation

The feature and tests are prepared. UNZEN remains unchanged and no runner is registered. Activation is blocked by GitHub credentials and access-policy verification.

## Verified configuration

| Item | Evidence |
| --- | --- |
| Repository | GitHub API identifies `forgerie/forgerie` as public, with default branch `main`. |
| Existing runners | Repository runner API returns zero runners. |
| Current setup rights | Organization runner-group API returns HTTP 403 and requests `admin:org` or fine-grained runner permissions. No scope was widened. |
| Feature defaults | `github-actions-contract` proves disabled configurations create no runner unit or CI account. |
| Admission guard | Python policy tests reject changed refs, PR refs, extra workflows, other repositories and absent restrictions. |
| Actual unit policy | NixOS VM test exercises production hardening with a deterministic workload. It checks disk-backed scratch, hidden key/token and host-daemon paths, Node 24, loopback HTTP, slice membership, stopping and scratch cleanup. |
| GitHub lifecycle | Not tested. No real App key, registration, fork routing, artifact upload, cancellation, reboot or warm-run measurements exist yet. |

The VM uses invalid test data, not real credentials. Its probe replaces the external GitHub runner/auth command boundary. Do not describe this as a successful Actions job.

## Source

- `modules/github-actions.nix` adds `mountainous.features.github-actions.enable`, disabled by default. It configures exactly one ephemeral runner in group `unzen-forgerie-manual` with label `unzen-forgerie`.
- `modules/github-actions-preflight.py` authenticates as the dedicated App and requires only `forgerie/forgerie` plus `forgerie/forgerie/.github/workflows/unzen-pilot.yml@refs/heads/main`. API errors and policy changes refuse registration.
- `tests/github-actions-contract.nix`, `tests/test_github_actions_preflight.py` and `tests/github-actions-isolation.nix` cover evaluation, admission policy and the real unit's runtime restrictions.
- `.sops.yaml` adds a creation rule for `secrets/hosts/unzen-github-actions.yaml`, encrypted only for the operator and UNZEN. No credential file has been created.
- Forgerie's `.github/workflows/unzen-pilot.yml` is manual and gated by `UNZEN_PILOT_ENABLED`. Its hosted CI workflow and required checks are unchanged. The operator guide is `docs/ci-unzen-pilot.md` in Forgerie.

Run the feature tests from this repository:

```bash
nix build .#checks.x86_64-linux.github-actions-contract \
  .#checks.x86_64-linux.github-actions-preflight \
  .#checks.x86_64-linux.github-actions-isolation --no-link -L
```

## Resource and storage choice

The CI slice has a 400% CPU quota, 12 GiB memory high, 16 GiB maximum and 2048 tasks. Root-owned parent directories protect cleanup paths. The service replaces tmpfs-backed private temporary files with disk-backed private bindings. Node 24 comes from the pinned OS closure, which roots it across garbage collection.

The pilot cannot access the host Nix daemon. This bounds actual npm build/test processes without silently imposing build limits on CLIProxyAPI updates or system rebuilds. It does not support Nix source builds yet, nor does it cache arbitrary npm test/build results.

LAN, tailnet and link-local destinations are blocked. Loopback remains available for HTTP tests. Native jobs share the kernel and host loopback, so this configuration does not permit untrusted code. A compromised dependency is still a host risk.

The existing UNZEN 95 W power limits, tmpfs policy, host daemon, weekly GC and other services are unchanged. The feature is not enabled on any host.

## Next activation

Create a dedicated App with only organization self-hosted runner read/write permissions, install it on `forgerie`, and store its PEM key locally outside the repository and chat. The App can supply the narrowly scoped runner-management API access that the current CLI lacks.

Before registration, create and verify a selected-repository runner group with exact workflow restrictions. Confirm an altered fork workflow cannot reach the group. If the account cannot enforce this policy, keep the feature disabled; do not substitute labels or a YAML condition.

Then encrypt the key in the UNZEN-only file, configure its SOPS secret as root mode `0400`, set the upstream `services.github-runners.forgerie.githubApp` fields and enable the feature only on UNZEN. Build and deploy a reviewed committed source, not the shared working tree's concurrent edits. Use verified SSH and non-destructive NixOS activation. Never run `nix run .#deploy`.

Only after registration passes, enable Forgerie's variable and run the pilot twice. Complete failure, cancellation, retry, reboot, offline, artifact and store-reuse checks. Do not expand registrations or move required checks before these pass.
