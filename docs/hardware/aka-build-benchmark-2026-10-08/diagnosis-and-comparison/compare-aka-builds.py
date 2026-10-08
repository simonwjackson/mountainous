#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import json
from pathlib import Path
import statistics

reports = {}
for host, folder in [
    ("aka", "/tmp/bcachefs-build-benchmark-aka-existing-controls-20261008"),
    ("zao", "/tmp/bcachefs-build-benchmark-zao-stockthermal-20261008"),
    ("unzen", "/tmp/bcachefs-build-benchmark-unzen-stockthermal-20261008"),
]:
    path = Path(folder)
    report = json.loads((path / "summary.json").read_text())
    assert report["completed"] and len(report["runs"]) == 3
    assert report["power_limits_before"] == report["power_limits_after"]
    assert statistics.median(run["wall_seconds"] for run in report["runs"]) == report["median_wall_seconds"]
    for number in range(1, 4):
        content = (path / f"build-{number}.log").read_text()
        assert "CC [M]" in content and "-j" + str(report["logical_build_cores"]) in content
        assert "Running phase: installPhase" in content
    reports[host] = report
assert len({report["derivation_sha256"] for report in reports.values()}) == 1
aka = reports["aka"]["median_wall_seconds"]
result = {"aka_median_seconds": aka, "aka_run_seconds": [run["wall_seconds"] for run in reports["aka"]["runs"]], "aka_cpu_peaks_c": [run["cpu_peak_c"] for run in reports["aka"]["runs"]], "comparisons": {}}
for host in ["zao", "unzen"]:
    baseline = reports[host]["median_wall_seconds"]
    result["comparisons"][host] = {"baseline_median_seconds": baseline, "aka_relative_build_speed": baseline / aka, "aka_build_time_change_percent": 100 * (aka / baseline - 1)}
result["aka_raw_cpu_sensor_peaks_c"] = [max(sample["cpu_sensor_max_c"] for sample in run["samples"]) for run in reports["aka"]["runs"]]
result["aka_cpu_alarm_available"] = all(sample["cpu_critical_alarm_available"] for run in reports["aka"]["runs"] for sample in run["samples"])
Path("/tmp/aka-build-comparison.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
