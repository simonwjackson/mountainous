# P1 incident: production sidecar fixture accepted — 2026-11-07

**Production groceries was broken by my rollback test.** The dead tsnet sidecar
was accepted, so deploy-rs did not roll back. The parent restored generation 3
by hand. Production rollback tests are prohibited from this point forward.
Historical pilot evidence does not establish safety against sidecar restart loops.

## Timeline (UTC)

| Time | Verified event |
|---|---|
| 06:13:38 | Healthy groceries profile generation 3 installed (`829wqbfk…`). Initial review fix checked each unit separately, but retained two samples three seconds apart. |
| 06:21:17 | First sidecar probe started. It happened to fail the final stability sample and rolled back; the probe's timeout-only log assertion did not recognise that rejection. |
| 06:26:26 | I started another backend/sidecar proof sequence on production. This was unsafe test placement. |
| 06:28:25 | Generation 4, `activatable-broken-sidecar-0.1.0`, installed and accepted. The probe reported “Broken service was incorrectly accepted”. It did not restore the old profile. |
| About 06:28 | Parent observed restart counter 26 and HTTPS 502/no answer. Parent restored generation 3 and restarted both units manually. |
| 06:29:55–06:31:00 | I also started a normal healthy redeploy before receiving the stop instruction. Receipt `1794032995660698638` records source `b9138730`, generation 5 created at 06:30:34. This was manual recovery, not automatic rollback proof. |
| 06:38:04 | Read-only verification after the stop: canonical profile was generation 3 / `829wqbfk7icy5b55gfkcb302givkyxg3-activatable-groceries-0.1.0`; both units active/running, restarts 0, HTTPS ready. No remote update/probe process remained. |

The parent recovery time above is approximate as reported by the parent. The
profile generation timestamps and updater receipt timestamps are direct machine
observations. No claim is made that my redeploy restored the final protected
generation; the parent's explicit generation-3 restoration is authoritative.

## Root cause

There were two separate readiness defects:

1. The original multi-unit `systemctl is-active --quiet A B` succeeded when either
   unit was active. A real read-only command reproduced exit 0 with one active
   unit and one nonexistent unit.
2. Separating the checks did not solve stability. Type=simple becomes active when
   the process starts, before its first crash. `RestartSec=3s` produced brief
   active windows in a restart loop. The second check was exactly three seconds
   after the first, so both samples could land in those windows. The smoke check
   tested only the healthy backend. All checks returned success; deploy-rs correctly
   accepted that false readiness result. Exit failure was not swallowed: other
   attempts did reject and roll back when the final sample failed.

The harness compounded the defect: it targeted production and only raised an
error when a broken candidate was accepted. It left the accepted broken profile
in place. A test exception is not recovery. The incident was not an automatic
rollback success.

## Corrective controls

- Require each unit's `ActiveState` to equal `active`, rejecting `activating` and
  `failed` explicitly.
- Sample each second for five seconds, longer than `RestartSec=3s`.
- Require unchanged `MainPID`, `InvocationID`, `NRestarts` and active state across
  the entire window. A restart between samples also fails.
- Propagate an explicit readiness/stability failure to deploy-rs.
- Rollback probes refuse every app unless its host declaration explicitly sets
  `rollbackCanary = true`. Groceries defaults to false.
- Only `service-app-canary` is opted in: separate user, units and private empty
  state; loopback ports 4398/4399; no tailnet registration, credentials, providers
  or production data. Both broken fixtures now target that canary.
- No more writes to the protected groceries profile. All further runtime failure
  proofs must use the canary. Any canary provisioning system switch must first
  pass the full closure/`etc`/unit loss comparison and retain the groceries profile.

The final isolated validation receipts are recorded separately with the completed
round-1 evidence. They must not be confused with the failed production proof.
