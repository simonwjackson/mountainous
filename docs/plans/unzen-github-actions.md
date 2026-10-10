# UNZEN GitHub Actions rollout plan

Status: proposed. The operator selected planning, not implementation or deployment.

## Outcome

Run trusted Linux CI jobs from more than 30 operator-owned repositories on UNZEN. Keep GitHub's workflow logs, artifacts, PR checks, and merge requirements. Reuse matching Nix store outputs without adding a network cache service initially.

The proposed starting point is the upstream `services.github-runners` NixOS module, not a VM or a new runner-management dependency. Native services have less isolation than VMs. This plan does not approve running arbitrary fork PR code on the home server.

No system, workflow, credential, storage, or runner changes are authorized by this document.

## Checked starting point

| Item | Evidence and limit |
| --- | --- |
| UNZEN hardware | Earlier authenticated inspection found an i7-9700K with 8 threads, 62 GiB RAM, and about 1.7 TiB free on the shared pool. These are not CI capacity measurements. |
| Scratch space | Authenticated `findmnt /tmp` found tmpfs. Earlier `cairn` evaluation found `boot.tmp.tmpfsSize = "50%"` and no explicit Nix `build-dir`. |
| Store retention | `modules/server.nix` schedules weekly GC with `--delete-older-than 14d`. This does not guarantee retention of unrooted CI outputs. |
| Native module | The inspected pinned nixpkgs module supports labels, GitHub App authentication, ephemeral registrations, multiple registrations, disk-backed `workDir`, and service overrides. It disables the runner's self-update mechanism. |
| Secret handling | `modules/secrets.nix` uses SOPS with host SSH identities. CI credentials must be separate from existing fleet credentials. |
| Other host work | The current, uncommitted `modules/hosts/unzen.nix` enables the CLIProxyAPI updater feature. Its proposed service calls the host Nix daemon. This is repository evidence, not a claim that the service is already deployed. |
| Example workflow | Forgerie's CI currently runs Linux and Windows jobs, uses Node 24, and includes package-install tests. It is a possible pilot, not the selected pilot. |

See [storage and cache research](../research/unzen-github-actions-storage.md) for sources and inspection limits.

## Proposed design

### 1. One registration inventory, explicit execution capacity

Create a version-controlled allowlist describing owner, repository or organization scope, labels, enabled state, and credential reference. Do not store credentials in this inventory. Do not enable newly discovered repositories automatically.

| Repository placement | Registration approach | Cost or limit |
| --- | --- | --- |
| Repositories already in one organization | Use organization-level workers restricted to selected repositories. | Confirm account policy, public-repository access, and available runner-group controls. |
| Personal-account repositories | Use repository-level registrations generated from the allowlist. | Each registration can start a job. Thirty entries do not form one shared two-worker pool. |
| Several organizations or owners | Declare each scope separately. | Worker counts and credentials must not accidentally multiply the intended host load. |

Pilot with one enabled registration and one active job. Enable further registrations only after testing aggregate resource control. Prefer a shared organization pool where the repositories already permit it; do not move repositories as part of this rollout.

GitHub workflow `concurrency` is not a host-wide semaphore across unrelated repositories. For personal-repository registrations, explicitly resolve global job admission before enabling all 30+ repositories. The implementation must either provide and test admission control or keep a bounded set of registrations enabled. A shared cgroup bounds resource use but does not itself limit the number of running jobs.

The repository/owner inventory and this admission decision are implementation gates, not assumptions to hide in a generator.

### 2. Native services with narrow privileges

Propose a `mountainous.features.github-actions.enable` feature and an UNZEN-only configuration. Forward runner settings to upstream `services.github-runners` rather than redeclaring its options. Keep other hosts disabled.

Prefer a GitHub App with only the registration permissions and installations needed by the allowlist. Store its private key as a root-only, UNZEN-scoped SOPS secret. A narrowly scoped fine-grained PAT is a fallback requiring explicit approval; a one-hour registration token is not unattended credential management.

Use separate runner identities and working directories for separate registrations. Retain upstream service hardening. Do not grant wheel membership, sudo, Nix `trusted-users`, a privileged Docker socket, deployment keys, or access to the human user's home.

The inspected module hides its registration source files from the running service and removes the temporary registration token. Verify this behavior in the deployed unit. Runner-owned registration credentials and each job's `GITHUB_TOKEN` still exist; do not describe a runner as credential-free.

Use one-job ephemeral registration when its re-registration and cleanup behavior passes the pilot. This restarts the runner and cleans its configured directories; it does not reset the whole host or make untrusted execution safe.

### 3. Separate disposable work from retained outputs

| State | Proposed location or policy | Validation |
| --- | --- | --- |
| Checkouts and job temporary files | Distinct disk-backed directories under `/srv/github-actions/work/`. Set `workDir` explicitly; do not use the upstream default under `/run`. | A failing or cancelled job must not contaminate the next job or delete another registration's files. |
| Nix build scratch | An explicit disk-backed `build-dir`, such as `/srv/github-actions/build/`. | Verify actual daemon behavior, ownership, and cleanup. Changing this setting affects non-CI builds too. |
| Matching Nix tools and build outputs | Existing `/nix/store`. | A second representative build must demonstrate reuse. Arbitrary npm test results are not automatically cached by Nix. |
| Retained results | Explicit per-repository GC roots outside disposable checkouts. | Rotation must remove only CI-owned roots, preserve active builds, and have a bounded retention policy. |
| Logs and downloadable results | GitHub logs/artifacts plus bounded runner diagnostics. | Keep enough diagnostics to investigate cancellation, offline runners, and failed registration. |

Do not repartition, rerun Disko, or apply Nothing but Nix to UNZEN. Its destructive cleanup is for disposable Ubuntu runners before Nix installation.

Set retention after measuring representative output sizes. Do not retain every commit indefinitely. Disk exhaustion affects the same pool that holds the OS and data. Preserve active roots and define cleanup for stale workspaces, scratch directories, and inactive results separately.

### 4. Bound the runner and the actual build processes

Start the pilot with one job. Suggested initial workload targets are up to four CPU threads and 16 GiB RAM, subject to the selected repository's requirements. These are proposed budgets, not measured requirements or promised capacity.

Use a shared CI systemd slice to bound aggregate runner shell processes. Measure worker overhead before increasing concurrency. Prefer queuing work to repeatedly killing jobs at a memory limit.

Nix builds requested through the host daemon do not automatically inherit the runner client's cgroup or network policy. A runner slice therefore does not prove that all build work is bounded or isolated.

Before applying daemon-wide build counts, core counts, memory limits, or network restrictions, check all non-CI consumers, including the CLIProxyAPI updater and system rebuilds. Record and approve the resulting host-wide policy. Do not silently impose CI limits on another service. Restrict access to loopback, LAN, tailnet, and link-local services at the actual execution point where feasible, then test required substitutions and downloads.

Preserve the existing 95 W CPU power policy. Measure build duration, CPU/memory pressure, free space, and thermal behavior during representative workloads. Do not increase worker counts merely because more repositories are registered.

### 5. Trusted jobs first; preserve existing PR checks

Start with an optional, manually dispatched workflow pinned to a known revision. Then allow trusted branch pushes after validation. Jobs on public or externally contributed PRs remain on GitHub-hosted runners initially.

Audit reusable workflows, checkout refs, dependencies, job secrets, and repository Actions settings. Owning a repository does not make fork PRs or downloaded dependencies trusted. Do not use `pull_request_target` to execute untrusted PR code.

For public repositories, prove that an outside fork cannot route a changed workflow to UNZEN. A condition inside PR-controlled YAML is not an adequate boundary by itself. Check available GitHub access/approval controls and any host-enforced admission policy. Do not approve outside workflows for local execution. If the implementation cannot enforce the trusted-origin boundary, keep that repository on hosted runners or require a separately approved isolation design.

Use `contents: read` by default. Pin third-party actions to reviewed commits. Keep cache publication and release/deployment credentials out of build-only and PR jobs.

Provide build tools through each repository's pinned Nix environment where practical. Do not force every project into full Nix packaging just to obtain Node or Python. Check actions that download binaries, invoke package managers, install browsers, or assume Ubuntu paths individually.

For Forgerie, specifically test Node 24, dependency installation, browser verification, artifact upload, and package-install smoke tests. Keep Windows coverage on GitHub. Keep existing required checks until the replacement check names and fork routing have been tested.

An offline self-hosted runner queues jobs; it does not automatically fall back to a hosted runner. Keep a documented hosted rerun path. If automatic routing is later required, design it explicitly before job assignment. Do not make UNZEN a new required merge dependency during the pilot.

## Rollout and acceptance gates

| Phase | Work | Gate before advancing |
| --- | --- | --- |
| 0. Inventory | List the 30+ repos, owner scopes, visibility, workflow types, secrets, and current required checks. Select the pilot. | Approve eligible job origins, registration scope, credentials, and an aggregate admission strategy. |
| 1. Configuration | Add the disabled-by-default feature, secret references, storage paths, and resource policy in `cairn`. | Nix evaluation/build checks pass. Other hosts remain unchanged. New files are staged immediately so the flake includes them. |
| 2. Contract tests | Exercise actual generated units and filesystem behavior in a disposable NixOS test. Use a local HTTP registration test service without real credentials. | Check label/name uniqueness, denied privileges, credential visibility, ownership, one-job cleanup, cancellation recovery, and active-root preservation. This is not a substitute for real GitHub validation. |
| 3. Live pilot | After separate deployment approval, apply a reviewed commit and run the optional workflow on UNZEN. | Verify registration, correct tools, logs/artifacts, cold/warm builds, cancel/fail/retry, reboot, free space, and unchanged host services. |
| 4. Small batch | Enable a Nix-native project and a conventional project before broad expansion. | Measure aggregate concurrency and daemon load. Exercise simultaneous jobs, cleanup/GC, offline behavior, and required checks. A harmless test using a changed fork workflow must establish that it cannot reach UNZEN. |
| 5. Wider rollout | Expand by owner scope and measured capacity, not a fixed claim that all repos fit. | No unresolved host isolation, credential, queue, or retention failures. Record observed durations and cache reuse. |
| 6. Optional binary cache | Add a network cache only when other runners or development machines need matching outputs. | Approve provider, retention, signing/trust, reachability, and who may publish. Keep writer credentials out of PR jobs. |

GitHub Actions' archive cache is repository-scoped. A shared Nix binary cache is the separate mechanism for distributing matching store outputs across machines. Neither a cache signature nor an ephemeral registration makes untrusted PR execution safe.

## Operation and rollback

- Review runner-package freshness regularly. The NixOS module passes `--disableupdate`; Nix updates and redeployment must keep the runner within GitHub's supported-version window.
- Monitor offline runners, registration failures, queued-job age, job failures, memory pressure, scratch usage, and pool free space. The monitoring task must have an owner and an alert destination before required checks depend on UNZEN.
- For planned maintenance, stop admitting work, drain or explicitly cancel active jobs, then update the reviewed host configuration. Verify the runner and existing services afterward.
- Roll back workflow routing to hosted Linux jobs first, stop or disable CI services, and restore changed host-wide daemon settings if needed. Preserve diagnostic logs and approved store outputs. Revoke compromised credentials and remove stale GitHub registrations.
- Never use `nix run .#deploy` for this rollout: the repository identifies it as a destructive fresh-install command. Use reviewed NixOS rebuild/activation procedures with verified SSH identity instead.

## Future implementation files

These are proposed paths, not files created by this planning task:

- `modules/github-actions.nix` for the feature and upstream service composition.
- `modules/github-actions-repositories.nix` for the explicit registration allowlist, if a separate file keeps it easier to review.
- `modules/hosts/unzen.nix` for the enablement and approved host policy.
- A UNZEN-only encrypted credential file, following the repository's SOPS creation rules.
- `tests/github-actions-contract.nix` for generated-unit and lifecycle behavior.
- An optional pilot workflow in the chosen repository, followed by independently reviewed workflow changes in each rollout batch.

## Pending decisions

The first implementation gate needs the repository/owner inventory and pilot selection. Credentials, admission control for personal repositories, host-daemon policy, retention, and deployment approval remain open. A public/private network-cache provider is not an initial prerequisite.

This plan is not deployment evidence. No CI speed, sustainable worker count, or cache hit rate has been measured.
