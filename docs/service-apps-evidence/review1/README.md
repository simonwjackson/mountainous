# Round-1 result

The production sidecar test caused a P1 outage. It was not a rollback success.
See [`../review1-incident.md`](../review1-incident.md) for the timeline, manual
recovery, root cause and corrective controls. All final failure tests below used
only the isolated `service-app-canary`.

## Changes and validation

| Review item | Result |
|---|---|
| Require every unit | Exact `ActiveState=active` for each unit; five one-second samples with unchanged PIDs, invocation IDs and restart counts; settle period exceeds `RestartSec=3s` |
| Sidecar failure proof | `canary-sidecar.json`: stability rejection, deploy exit 1, original profile restored, both units active and HTTP healthy, no manual repair |
| Backend failure proof | `canary-backend.json`: readiness timeout, deploy exit 1, original profile restored, both units active and HTTP healthy, no manual repair |
| Production protection | `groceries-probe-permitted.json` is false; the probe refuses apps without explicit `rollbackCanary=true` |
| Completed pilot scaffolding | Six pilot-only scripts removed; retained steps/evidence in docs |
| Generic helpers | Explicit host, app, architecture, branch/repo/SHA and health arguments; repo-built `service-app-tools` package installed on Unzen, not loose copies |
| Generic cutover | Source-active + destination-absent/stopped guards; confirmed-stop-before-recovery; restores only initially active units; retains state/definition links |
| Guard exercise | A completed-pilot attempt refused on inactive source before transport; target guard refused an existing profile; Zao units unchanged |
| Product integration | Probes moved to `tests/integration/groceries/` |
| Myoko | `ssh -F /dev/null root@myoko` succeeds on 22; deployment graph derives default port 22 |
| Unzen cleanup | All 16 listed scratch entries removed; only the nine required entries remain (`unzen-kept-entries.txt`) |

The canary has a dedicated `service-app-canary` user, private persistent state and
two loopback HTTP listeners, ports 4398/4399. It has no credentials, real data,
providers or tailnet registration. Both failing fixtures now wrap that canary,
not groceries. Canary auto-updates are not enabled.

## Platform and protected production

Adding the canary required a Rakku platform change. The complete closure and
`/etc`/unit content comparison is in `rakku-canary-compare.txt`. It contained only
additive canary resources and generated D-Bus/tmpfiles restart references; no
running feature or groceries unit was removed or changed. The reviewed SHA256
was `faf2ee183ef1890156f7576caf1425025bf904984e232ccc5ac459f3f4e22fa7`.
The switch log is `rakku-canary-switch.txt`.

Rakku moved from `jabc98p2…` to
`/nix/store/spaf2s6g382zdcl0xhhrhna71mwqd7w7-nixos-system-rakku-26.11.20260923.4975466`.
The groceries profile stayed exactly `groceries-3-link` →
`829wqbfk7icy5b55gfkcb302givkyxg3-activatable-groceries-0.1.0` before/after that
switch and after the isolated proofs. `protected-groceries-profile.txt` records
its healthy unchanged build. No production profile writes followed the parent's
stop instruction. Rakku reports running, zero failed system units and all seven
required core units active (`rakku-health.txt`).

## Focused checks

- Python safety contracts: 7 passed, including all-unit semantics, cutover guards,
  stop-confirmation recovery, public health validation and real Git staging on a
  differently named branch/repository.
- Existing updater Python tests: 9 passed.
- Native `checks.x86_64-linux.service-app-tools`: passed (`tools-check.txt`).
- Native `checks.x86_64-linux.service-apps`: passed (`service-apps-check.txt`).
- Generic native source-build helper and system-build helper exercised on Unzen.
- Nix formatting, Python compilation and Bash ShellCheck passed.
- Only focused single-attribute evaluations/builds ran, with two jobs and empty
  builders. No aggregate flake check ran. No ARM deploy or new builder key.

Pi's global gate remains closed. Zao's exact original groceries unit-definition
symlinks remain linked (not enabled) and inactive. All listed kept Unzen state,
keys, receipts, accepted release and cache remain present. Source state and
production migration snapshots were not deleted.
