# Unzen versus Zao build speed

The requested number is Zao's median clean build time divided by Unzen's.
A value above 1 means Unzen finishes this build faster. There is no valid ratio
yet: Zao's full-parallel attempt stopped at the temperature safety cutoff.

## Workload and controls

The operator selected a clean bcachefs kernel-module build. Both hosts use:

- The exact derivation `/nix/store/98klz3frilgg1k4d1i2xxar32dqdjxky-bcachefs-6.18.53-1.39.6.drv`, with SHA-256 `f58f9cb51e872a5beb8d08498440d383f727f8bee674acf9020410b2c001e84f`.
- The same kernel development tree, GCC 15.3.0, and source inputs.
- `nix build --rebuild --offline --builders '' --max-jobs 1`, with build cores set to all logical CPUs.
- Inputs loaded and copied before timing. Nix store verification checked recursive input contents on both stores.
- No remote builders or cached build-output reuse. The logs show actual C compilation and successful deterministic output comparisons for completed runs.
- CPU and SSD composite cutoffs of 100°C and 80°C, sampled about once per second. The script cancels the build on cutoff. It makes no power, fan, or firmware changes.

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

A lower-parallel comparison would measure a different operating point. It must
use the same job limit on both machines and must not be labelled an all-core
speed ratio. This workload also does not establish performance for every
NixOS build or project.
