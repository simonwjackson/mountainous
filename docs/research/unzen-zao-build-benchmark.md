# Unzen versus Zao build speed

The requested number is Zao's median clean build time divided by Unzen's.
A value above 1 means Unzen finishes this build faster. The verified ratio is
**0.939×**, or **6.49% longer build time on Unzen**. This uses three completed
clean module builds per host, with normal Zao thermal throttling permitted.
It is not a universal compiler-performance score.

## Workload and controls

The operator selected a clean bcachefs kernel-module build. Both hosts use:

- The exact derivation `/nix/store/98klz3frilgg1k4d1i2xxar32dqdjxky-bcachefs-6.18.53-1.39.6.drv`, with SHA-256 `f58f9cb51e872a5beb8d08498440d383f727f8bee674acf9020410b2c001e84f`.
- The same kernel development tree, GCC 15.3.0, and source inputs.
- `nix build --rebuild --offline --builders '' --max-jobs 1`, with build cores set to all logical CPUs.
- Inputs loaded and copied before timing. Nix store verification checked recursive input contents on both stores.
- No remote builders or cached build-output reuse. The logs show actual C compilation and successful deterministic output comparisons for completed runs.
- The original attempt stopped at CPU >=100°C or SSD composite >=80°C. The completed comparison permits exactly 100°C on Zao, but stops above it or at a CPU critical alarm. Unzen's CPU >=100°C cutoff and both SSD cutoffs remain unchanged. Neither attempt changes power, fan, or firmware settings.

Some Zao-built input artifacts lack cache signatures. Their import used
`nix copy --no-check-sigs` over SSH pinned to Unzen's enrolled key, followed by
recursive content verification. This did not change the target's global
signature policy. Copy and verification time are outside the measurements.

## Full-parallel attempt

| Host | CPU | Compiler jobs | Completed build times | CPU peaks | Median |
| --- | --- | ---: | --- | --- | --- |
| Unzen | i7-9700K, permanent 95 W limits | 8 | 41.244 s, 41.251 s, 42.258 s | 75°C, 78°C, 84°C | 41.251 s |
| Zao | i9-11900H, existing power policy unchanged | 16 | None | Cutoff tripped during first compilation | Not available |

Zao started at 67°C CPU and 30.85°C SSD composite. Its initial measured
background CPU use was 9.8%. The benchmark process stopped after about four
seconds. Its log ends with `error: interrupted by the user`. No compiler
process remained in the follow-up process check.

The aborted attempt's summary does not retain the cutoff sample, so it does
not establish the exact CPU peak or which temperature input caused the cutoff.
Do not infer a completed Zao time from the partial log.

Raw logs, summaries, input paths, and the executed scripts are under
`docs/hardware/unzen-zao-build-benchmark-2026-10-08/full-parallel-attempt/`.

## Completed comparison with normal laptop thermal control

The operator rejected changing laptop cooling and approved proceeding with
normal Zao thermal throttling. A read-only check confirmed the Zao `coretemp`
critical reference is 100°C. The revised guard permits that exact temperature
on Zao, not higher readings. It also checks CPU critical alarms and retains
failed-attempt samples. The pure guard boundary tests passed.

Both hosts reran the same pinned derivation with all logical CPUs. The revised
runner samples temperatures at about 0.25-second intervals and uses a bounded
process wait, reducing the previous one-second exit-detection delay.

| Host | Run 1 | Run 2 | Run 3 | Median | CPU peaks |
| --- | ---: | ---: | ---: | ---: | --- |
| Zao, 16 compiler jobs | 39.471 s | 38.805 s | 37.184 s | 38.805 s | 100°C, 100°C, 100°C |
| Unzen, 8 compiler jobs, 95 W | 40.905 s | 41.324 s | 41.333 s | 41.324 s | 73°C, 79°C, 84°C |

`38.805492710002 / 41.323855900000126 = 0.9390578847217856` gives
Unzen's build speed relative to Zao. For elapsed time,
`100 * (41.323855900000126 / 38.805492710002 - 1) = 6.489708064830291%`.
The user-facing number is **6.5% longer on Unzen**.

All six logs prove actual C compilation with the expected `-j` setting and
completed install phases. All six Nix rebuild comparisons succeeded. Both
hosts' raw derivation hashes match, and their reported power limits match
before and after the runs. The comparison replay checks these invariants.

Zao's thermal-throttle counters increased; Unzen's did not. Zao's package
counter increased by 29634 and is exposed identically on every logical CPU.
Do not sum those duplicate package values or treat them as throttled seconds.
These readings verify thermal throttling occurred, not its exact performance
cost. The snapshot does not establish hardware damage or a cooling fault.

The completed reports and executed scripts are in
`docs/hardware/unzen-zao-build-benchmark-2026-10-08/stock-thermal-comparison/`.
Both machines ran their existing power policies. Zao reported permissive
200 W long-term and 109 W short-term limits; those are configured limits,
not measured draw. Unzen retained both 95 W limits.

This is a roughly 40-second module build, not a prolonged full-system build.
Zao's three times improved during the sequence, so warm-cache and fan-state
changes remain possible contributors. The result describes this workload and
these machine states. It does not establish every project's speed or a
long-duration throughput difference.
