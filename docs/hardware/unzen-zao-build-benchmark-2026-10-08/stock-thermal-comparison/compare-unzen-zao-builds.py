#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import json
from pathlib import Path
import statistics

reports = {}
for host in ["zao", "unzen"]:
    folder = Path(f"/tmp/bcachefs-build-benchmark-{host}-stockthermal-20261008")
    report = json.loads((folder / "summary.json").read_text())
    assert report["completed"] and len(report["runs"]) == 3
    assert report["power_limits_before"] == report["power_limits_after"]
    for number in range(1, 4):
        content = (folder / f"build-{number}.log").read_text()
        assert "CC [M]" in content and "-j" + str(report["logical_build_cores"]) in content
        assert "Running phase: installPhase" in content
    assert report["median_wall_seconds"] == statistics.median(run["wall_seconds"] for run in report["runs"])
    reports[host] = report
assert reports["zao"]["derivation_sha256"] == reports["unzen"]["derivation_sha256"]
z, u = [reports[host]["median_wall_seconds"] for host in ["zao", "unzen"]]
result = {"median_seconds": {"zao": z, "unzen": u}, "unzen_relative_build_speed": z / u, "unzen_extra_build_time_percent": 100 * (u / z - 1), "workload": "Three clean bcachefs 6.18.53-1.39.6 module builds, each host's full logical-core parallelism, Unzen 95 W and Zao unchanged power policy"}
for host, report in reports.items():
    result[host] = {"times": [run["wall_seconds"] for run in report["runs"]], "cpu_peaks_c": [run["cpu_peak_c"] for run in report["runs"]], "throttle_counter_increases": {key: value - report["throttle_counters_before"].get(key, 0) for key, value in report["throttle_counters_after"].items() if value > report["throttle_counters_before"].get(key, 0)}}
Path("/tmp/unzen-zao-build-comparison.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
