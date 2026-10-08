# Aka clean-build comparison

**Aka takes 28.1% less build time than Zao** for the tested bcachefs module.
It takes 32.5% less time than Unzen for this workload. The three completed Aka
builds have a 27.886-second median. This is a short-build result, not a universal
compiler score or a cooling validation.

| Host | CPU / compiler jobs | Median build time |
| --- | --- | ---: |
| Aka | Ryzen 5 7600X / 12 | 27.886 s |
| Zao | i9-11900H / 16 | 38.805 s |
| Unzen | i7-9700K, 95 W limits / 8 | 41.324 s |

Aka's times are 27.885735045187175, 27.886289491783828, and
27.931582069024444 seconds. Zao and Unzen use their earlier completed same-day
three-build baselines. They were not rerun alongside the final Aka attempt.
`100 * (27.886289491783828 / 38.805492710002 - 1) = -28.138292946873932%`.
The speed ratio is 1.39156, distinct from the elapsed-time reduction.

## Matched workload and verification

The operator requested the same benchmark used for Unzen and Zao. Authenticated
SSH succeeded with the trusted existing Aka host key and user `simonwjackson`.
The live machine is x86_64, Linux 6.18.17, Nix 2.34.1.

All hosts use `/nix/store/98klz3frilgg1k4d1i2xxar32dqdjxky-bcachefs-6.18.53-1.39.6.drv`,
SHA-256 `f58f9cb51e872a5beb8d08498440d383f727f8bee674acf9020410b2c001e84f`.
The exact source, GCC 15.3.0, kernel development tree, and other build inputs
were copied before timing and recursively verified in both Nix stores.
The original completed output was copied so `--rebuild` performed clean
compilation and output comparison rather than an untimed preparation build.
Scoped import of our own Zao-built inputs used `--no-check-sigs` only over
already trusted SSH; Aka's global trust settings were not changed.

The logs prove actual C compilation with twelve compiler jobs and completed
install phases. Remote builders and substitutions were disabled. All three
Nix rebuild output comparisons succeeded. The comparison replay verifies
completed runs, medians, compiler-job settings, and identical derivation hashes.
It does not include download or dependency-copy time.

## Why the original attempts stopped

I initially stopped the whole task after one aborted run. That was wrong:
a stopped benchmark was not the requested performance answer. Continuing
with labelled sensor instrumentation identified two measurement issues.

| Attempt | Observed reading | Outcome |
| --- | --- | --- |
| Original maximum of all CPU channels | 96.25°C at 1.773 s | The 95°C software guard stopped the build; the channel was not retained. |
| Labelled-channel reproduction | Tccd1 95.25°C, Tctl 88.625°C at 1.267 s | CCD and control readings were incorrectly treated as interchangeable. |
| Correct control selection | Tctl 95.125°C, Tccd1 96.125°C at 3.291 s | The exact-target software guard still stopped the build. |
| Bounded-transient experiment | Tctl 95.625°C, Tccd1 91°C at 5.320 s | The reading stayed above the added 95°C software target long enough to stop. |
| Existing thermal controls | Three completed builds | No extra 95°C software policy was imposed. |

The recorded channel-selection regression checks that Tctl 88.625°C, not CCD
95.25°C, supplies the control reading for the reproduced sample. The runner
uses Tdie when explicitly available, otherwise Tctl, and records CCD readings
separately. No assumed temperature offset is subtracted. No driver is loaded.

The [kernel k10temp documentation](https://docs.kernel.org/hwmon/k10temp.html)
distinguishes control, die, and CCD readings. AMD specifies [95°C maximum
operating temperature for the Ryzen 5 7600X](https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-5-7600x.html).
Those facts do not establish calibration of the individual live readings.

## Final operating conditions and limits

The final run measured Aka with its existing hardware thermal controls. It
made no fan, power, voltage, or firmware writes. The software retained a 100°C
emergency ceiling for every raw CPU reading and an 80°C SSD composite cutoff,
plus a bounded build timeout. This changed the benchmark's software stop
policy, not the machine's hardware thermal or power limits.

The three control-channel peaks were 96°C, 96°C, and 95.875°C. The corresponding
maximum raw CPU readings, including CCD, were 97.75°C, 98.375°C, and 97.125°C.
Do not describe these runs as verified compliance with AMD's listed 95°C
operating limit. They measure this machine's current performance, not the
safety or longevity of those operating conditions.

Aka exposes no CPU critical-alarm files through this driver;
`cpu_critical_alarm_available=false` records that limitation. It also exposes
no Intel thermal-throttle counters. Missing counters do not prove an absence
of AMD throttling. Its Intel RAPL limit directory is absent: empty before/after
power dictionaries do not establish AMD power limits or package watts.

The failed attempts warmed caches and changed fan state before the final
comparison. The completed times are consistent, but this does not remove that
history or establish long-duration throughput. No cooling fault or hardware
damage was diagnosed.

Initial artifacts are under `docs/hardware/aka-build-benchmark-2026-10-08/`.
Labelled reproductions, final raw logs/samples, the replay, and executed scripts
are under its `diagnosis-and-comparison/` directory.
