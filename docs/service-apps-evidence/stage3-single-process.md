# Single-process service-app proof

The module supports `sidecar = null` for apps that already serve their own tsnet node. No app HTTP behavior was changed to fit the platform.

## Compatibility proof

Before the change (source `a87afa8f`), and after it, each existing app's backend unit drvPath, sidecar unit drvPath and deploy-profile drvPath were evaluated separately. All **21 drvPaths** match exactly. Compare `stage3-single-before.json` and `stage3-single-after.json`. That includes Groceries and the existing paired canary. Added `/etc/service-apps/*.json` manifests contain only the derived unit list, and do not change old units or activation profiles.

Single-process controllers, readiness, five-second incarnation stability, SOPS restarts, rollback probes and cutover stop/ready confirmation use the one declared unit. The module emits the authoritative unit manifest; migration tools refuse missing/invalid manifests rather than assuming two processes.

## Isolated live proof

Permanent app: `service-app-single-canary`, own user and persistent empty state, loopback **4400**, no tailnet name, credentials, appUpdates entry or updater gate. The existing `service-app-canary` was not changed.

| Check | Verified result |
|---|---|
| Production bootstrap guard | Knowledge rejected as not a rollbackCanary, before signing/profile mutation (`stage3-single-production-refused.txt`) |
| Healthy bootstrap | Signed first install accepted at pinned source `e712d639b29e1c1772fc0bcb1d9fdd2b3e94908d`; exactly one unit active (`stage3-single-bootstrap.json`, `.log`) |
| Broken single-process fixture | Runtime readiness timed out; deploy exit 1; deploy-rs restored the original healthy profile and HTTP identity without manual repair (`stage3-single-probe.json`, `.log`) |
| Host health afterwards | Rakku running, zero failed units; all household core units plus Meetings, Storia and the new canary active |
| Canary memory afterwards | `MemoryCurrent=14979072` bytes (14.3 MiB), `NRestarts=0` |
| Loss check before platform switch | `lylhzywb` → `3gscgzm2`: only manifest files and the new canary resources; two unit/wants additions, zero removed |

The migration lock was held on Unzen for staging, bootstrap signing/deploy and the rollback proof. The bootstrap mode lives only in the guarded rollback-probe helper and refuses production apps, existing profiles, running units and broken-fixture selection. No general-purpose signing helper was added.

## Focused checks

- Python service-app tests: **11 passed**, including single/paired authoritative manifests, invalid/missing manifests, all-unit status, and bootstrap argument boundaries.
- Python compilation: passed for the shared module, cutover and rollback probe.
- `checks.x86_64-linux.service-apps`: passed, including actual single controller and activation scripts.
- `checks.x86_64-linux.service-app-tools`: passed (rebuild after bootstrap mode also required in final checks).
- `nixfmt`: applied to changed Nix files.
- Statix and Deadnix: ran on the module; reported existing style/unused-argument warnings, no implementation failure.
- Input guard and `git diff --check`: passed. No aggregate flake check was run.
