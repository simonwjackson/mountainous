# Aka clean-build benchmark attempt

There is no valid Aka-versus-Zao build-speed ratio yet. The first Aka clean
build stopped at the temperature guard before it completed. The partial time
must not be treated as a build time or compared with a completed build.

The operator requested the same benchmark used for Unzen and Zao. Authenticated
SSH succeeded with the trusted existing Aka host key and user `simonwjackson`.
The live machine is x86_64, AMD Ryzen 5 7600X, six cores/twelve logical CPUs,
Linux 6.18.17, Nix 2.34.1.

The exact pinned bcachefs 6.18.53-1.39.6 derivation and its build inputs were
copied before timing and recursively verified in both Nix stores. The original
completed output was also copied, so `--rebuild` would perform fresh compilation
and compare outputs rather than run an untimed preparation build on Aka.
Scoped import of our own Zao-built inputs used `--no-check-sigs` only over
already trusted SSH; Aka's global trust settings were not changed.

Aka's CPU sensors use the already loaded `k10temp` driver. The runner uses raw
CPU readings with no offset subtraction, no driver loading, and no firmware,
fan, or power changes. AMD specifies [95°C maximum operating temperature for
the Ryzen 5 7600X](https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-5-7600x.html).
The guard permits exactly 95°C but stops above it; SSD composite cutoff is 80°C.
AMD boundary tests passed before execution.

The first run used twelve compiler jobs with remote builders disabled and
inputs already present. Its background CPU sample was 7.5%. At elapsed
1.7726338519714773 seconds, the saved sample reports CPU maximum **96.25°C**
and SSD composite maximum **49.85°C**. The runner cancelled Nix immediately.
The follow-up `pgrep -a cc1` found no compiler process. No build completed.

The recorded CPU value is the maximum across `k10temp` readings, not an
independently calibrated junction-temperature measurement. The failed sample
does not retain each individual channel, so it does not identify whether Tctl
or Tccd1 supplied that maximum. The driver exposes no CPU critical-alarm files
on this machine; `cpu_critical_alarm_available=false` records that limitation.
Do not treat this short transient as proof of a cooling fault or hardware damage.

The [kernel k10temp documentation](https://docs.kernel.org/hwmon/k10temp.html)
distinguishes control, die, and CCD readings. Do not subtract an assumed offset
or silently raise the guard to obtain a completed benchmark.

Aka's Intel RAPL power-limit directory is absent. The runner makes no power
writes, but its empty before/after power dictionaries do not establish actual
AMD power limits or package watts. Those remain unmeasured.

Raw preflight, failed-build samples, logs, executed scripts, and boundary tests
are archived under `docs/hardware/aka-build-benchmark-2026-10-08/`.
