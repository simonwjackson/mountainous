#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import statistics
import subprocess
import time

DRV = "/nix/store/98klz3frilgg1k4d1i2xxar32dqdjxky-bcachefs-6.18.53-1.39.6.drv"


def temperatures():
    cpu, ssd = [], []
    for hw in Path("/sys/class/hwmon").glob("hwmon*"):
        name = (hw / "name").read_text().strip()
        if name == "coretemp":
            cpu.extend(int(p.read_text()) / 1000 for p in hw.glob("temp*_input"))
        elif name == "nvme":
            for item in hw.glob("temp*_input"):
                label = item.with_name(item.name.replace("input", "label"))
                if (label.exists() and label.read_text().strip().lower() == "composite") or item.name == "temp1_input":
                    ssd.append(int(item.read_text()) / 1000)
    if not cpu:
        raise RuntimeError("CPU temperatures unavailable; refusing unguarded build")
    return {"cpu_c": max(cpu), "ssd_composite_c": max(ssd) if ssd else None}


def guard(sample):
    if sample["cpu_c"] >= 100 or (sample["ssd_composite_c"] is not None and sample["ssd_composite_c"] >= 80):
        raise RuntimeError("Temperature safety cutoff reached")
    if platform.node() == "unzen":
        zone = Path("/sys/class/powercap/intel-rapl:0")
        if any((zone / f"constraint_{i}_power_limit_uw").read_text().strip() != "95000000" for i in [0, 1]):
            raise RuntimeError("Unzen 95 W limits changed; refusing benchmark")


def cpu_counters():
    return [int(v) for v in Path("/proc/stat").read_text().splitlines()[0].split()[1:9]]


def busy_fraction():
    before = cpu_counters()
    time.sleep(2)
    after = cpu_counters()
    delta = [a - b for a, b in zip(after, before)]
    return 1 - (delta[3] + delta[4]) / sum(delta)


def stop_build(process):
    if process.poll() is not None:
        return
    process.send_signal(signal.SIGINT)
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)


def interrupted(signum, frame):
    raise InterruptedError(f"Benchmark interrupted by signal {signum}")


signal.signal(signal.SIGTERM, interrupted)
signal.signal(signal.SIGHUP, interrupted)
parser = argparse.ArgumentParser()
parser.add_argument("--result-dir", required=True)
args = parser.parse_args()
folder = Path(args.result_dir)
folder.mkdir(parents=True, exist_ok=False)
cores = len(os.sched_getaffinity(0))
command = ["nix", "build", "--no-link", "--rebuild", "--offline", "--builders", "", "--max-jobs", "1", "--cores", str(cores), "--timeout", "900", "-L", DRV + "^out"]
report = {
    "hostname": platform.node(), "kernel": platform.release(),
    "nix_version": subprocess.check_output(["nix", "--version"], text=True).strip(),
    "cpu": subprocess.check_output(["lscpu", "--json"], text=True),
    "logical_build_cores": cores, "derivation": DRV,
    "derivation_sha256": hashlib.sha256(Path(DRV).read_bytes()).hexdigest(),
    "command": command, "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "runs": [], "completed": False,
}
initial = temperatures()
guard(initial)
report["initial_temperatures"] = initial
cool_target = min(80, initial["cpu_c"] + 5)
try:
    for number in range(1, 4):
        cooldown_deadline = time.monotonic() + 180
        while temperatures()["cpu_c"] > cool_target:
            guard(temperatures())
            if time.monotonic() > cooldown_deadline:
                raise RuntimeError("CPU did not cool to baseline within 180 seconds")
            time.sleep(3)
        idle = busy_fraction()
        if idle > 0.25:
            raise RuntimeError(f"Other CPU work uses {idle:.1%}; postpone comparable build")
        print(f"{platform.node()} CLEAN_BUILD_{number}_START cores={cores} background_busy={idle:.3f}", flush=True)
        samples = []
        with (folder / f"build-{number}.log").open("w") as log:
            started = time.monotonic()
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                while process.poll() is None:
                    sample = temperatures()
                    sample["elapsed_s"] = time.monotonic() - started
                    samples.append(sample)
                    guard(sample)
                    if time.monotonic() - started > 960:
                        raise RuntimeError("Build exceeded bounded timeout")
                    time.sleep(1)
                elapsed = time.monotonic() - started
                if process.returncode:
                    raise RuntimeError(f"Build exited {process.returncode}; inspect build-{number}.log")
            finally:
                stop_build(process)
        content = (folder / f"build-{number}.log").read_text()
        if "CC " not in content or "bcachefs" not in content:
            raise RuntimeError("Build log does not prove actual C compilation")
        result = {"wall_seconds": elapsed, "background_busy_fraction": idle, "cpu_peak_c": max(v["cpu_c"] for v in samples), "samples": samples}
        report["runs"].append(result)
        print(f"{platform.node()} CLEAN_BUILD_{number}_DONE seconds={elapsed:.3f} cpu_peak={result['cpu_peak_c']}", flush=True)
    report["median_wall_seconds"] = statistics.median(r["wall_seconds"] for r in report["runs"])
    report["completed"] = True
except BaseException as error:
    report["error"] = str(error)
    raise
finally:
    (folder / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"{platform.node()} BENCHMARK_COMPLETE median_seconds={report['median_wall_seconds']:.3f}", flush=True)
