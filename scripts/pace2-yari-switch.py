#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 coreutils curl procps nix
"""Pace 2: restart both gateways in place, with Pace-only config drift guards.
Usage: pace2-yari-switch.py check|forward|check-rollback|rollback FROM TO.
Run through pace2-launch.sh. Preserve every other Laure config field and all
other unit files; check idle metadata only. Never read conversation content.
"""
import hashlib
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

mode, source, target = sys.argv[1:]
assert mode in ("check", "forward", "check-rollback", "rollback"), mode
rolling_back = mode in ("check-rollback", "rollback")
for path in (source, target):
    assert path.startswith("/nix/store/") and "-nixos-system-yari-" in path, path
    assert Path(path).is_dir(), f"missing on Yari: {path}"
STATE = Path("/var/tmp/pace2-yari")
STATE.mkdir(mode=0o700, exist_ok=True)
LAURE_CONFIG = Path("/var/lib/nixos-containers/openclaw/etc/openclaw/openclaw.json")
UNIT = "etc/systemd/system/container@openclaw.service"
LAURE_UNITS = {"openclaw-gateway.service"}



def run(*args, timeout=60):
    # A wedged container must not hang a rollback.
    return subprocess.check_output(args, text=True, timeout=timeout)


def inside(container, *args, timeout=60):
    return run("nixos-container", "run", container, "--", *args, timeout=timeout)


def admin(container, *args):
    result = json.loads(inside(container, "openclaw-admin", *args, timeout=120))
    if isinstance(result, dict) and result.get("ok") is False:
        raise RuntimeError(result.get("error"))
    return result


def show(container, unit, *props):
    try:
        out = inside(container, "systemctl", "show", unit, *[f"-p{p}" for p in props])
        return dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return None


def snapshot():
    sessions = admin("openclaw", "gateway", "call", "sessions.list", "--json", "--params", json.dumps({
        "agentId": "laure", "archived": "all", "includeDerivedTitles": False,
        "includeLastMessage": False, "rowMode": "compact", "limit": 10000}))
    assert not sessions.get("hasMore"), "incomplete Laure session inventory"
    devices = admin("openclaw", "devices", "list", "--json")
    config = LAURE_CONFIG.read_bytes()
    parsed = json.loads(config)
    assert sorted(parsed["agents"]["entries"]) == ["laure"]
    jobs = admin("openclaw", "cron", "list", "--all", "--json")["jobs"]
    return {
        "sessions": sorted(s["key"] for s in sessions["sessions"]),
        "devices": sorted(d["deviceId"] for d in devices["paired"]),
        "pending": len(devices["pending"]),
        "jobs": sorted(j["id"] for j in jobs),
        "configSHA256": hashlib.sha256(config).hexdigest(),
        "container": run("systemctl", "show", "container@openclaw", "-p", "InvocationID", "--value").strip(),
        "gateway": show("openclaw", "openclaw-gateway", "InvocationID", "MainPID", "NRestarts", "ActiveEnterTimestamp"),
        "sessionShare": show("openclaw", "openclaw-session-share", "InvocationID"),
        "appProfile": os.path.realpath("/nix/var/nix/profiles/apps/openclaw"),
    }


def healthy(container):
    try:
        result = json.loads(inside(container, "curl", "-fsS", "--max-time", "2",
                                   "http://127.0.0.1:18789/healthz", timeout=15))
        return result.get("ok") is True
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError):
        return False


def refuse_if_switching():
    if subprocess.run(["pgrep", "-f", "[b]in/switch-to-configuration"], stdout=subprocess.DEVNULL).returncode == 0:
        sys.exit("another switch-to-configuration is running; nothing changed. Rerun the step.")
    current = os.path.realpath("/run/current-system")
    if current != source:
        sys.exit(f"running system is {current}, not {source}; nothing changed")


def idle(*containers):
    try:
        return subprocess.run(["openclaw-wait-idle", "--check", *containers], timeout=60).returncode == 0
    except subprocess.TimeoutExpired:
        return False


def container_system(system, name="openclaw"):
    conf = Path(system) / f"etc/nixos-containers/{name}.conf"
    return next(line.split("=", 1)[1] for line in conf.read_text().splitlines()
                if line.startswith("SYSTEM_PATH="))


def unit_files(system):
    """Every unit file and .wants/.requires link under a system's etc/systemd/system, resolved."""
    directory = Path(system) / "etc/systemd/system"
    return {str(p.relative_to(directory)): hashlib.sha256(p.resolve().read_bytes()).hexdigest()
            for p in sorted(directory.rglob("*")) if p.is_file()}


def json_paths(a, b, prefix=""):
    if isinstance(a, dict) and isinstance(b, dict):
        out = []
        for key in sorted(set(a) | set(b)):
            out += json_paths(a.get(key), b.get(key), f"{prefix}{key}.")
        return out
    return [] if a == b else [prefix[:-1]]


def activate(system):
    subprocess.run(["nix-env", "--profile", "/nix/var/nix/profiles/system", "--set", system], check=True)
    return subprocess.run([system + "/bin/switch-to-configuration", "switch"]).returncode


# Preconditions, all modes.
refuse_if_switching()
if "X-ReloadIfChanged=true" not in (Path(target) / UNIT).read_text():
    sys.exit("TO would RESTART Laure's container (no X-ReloadIfChanged); stop.")
laure_running = inside("openclaw", "readlink", "-e", "/run/current-system").strip()
assert laure_running == container_system(source), "Laure's container does not run FROM's container system; stop"
laure_target = container_system(target)
target_config = Path(laure_target + "/etc/openclaw/openclaw.json").resolve().read_bytes()
live_config = LAURE_CONFIG.read_bytes()
run(sys.executable, str(Path(__file__).with_name("pace2-config-guard.py")),
    str(LAURE_CONFIG), str(Path(laure_target) / "etc/openclaw/openclaw.json"), "pace-laure",
    *(["--rollback"] if rolling_back else []))
config_paths = ["mcp.servers.pace", "skills.load.extraDirs[0]"]
# Apply the same contract to Simon and require both containers to switch in place.
simon_container_before = run("systemctl", "show", "container@claw-simon", "-p", "InvocationID", "--value").strip()
simon_running = inside("claw-simon", "readlink", "-e", "/run/current-system").strip()
simon_target = container_system(target, "claw-simon")
assert "X-ReloadIfChanged=true" in (Path(target) / "etc/systemd/system/container@claw-simon.service").read_text()
run(sys.executable, str(Path(__file__).with_name("pace2-config-guard.py")),
    "/var/lib/nixos-containers/claw-simon/etc/openclaw/openclaw.json",
    str(Path(simon_target) / "etc/openclaw/openclaw.json"), "pace",
    *(["--rollback"] if rolling_back else []))
sa, sb = unit_files(simon_running), unit_files(simon_target)
assert {Path(n).name for n in set(sa) | set(sb) if sa.get(n) != sb.get(n)} <= {"openclaw-gateway.service"}
live_units = unit_files(laure_running)
target_units = unit_files(laure_target)
changed = sorted(n for n in set(live_units) | set(target_units) if live_units.get(n) != target_units.get(n))
assert {Path(n).name for n in changed} <= LAURE_UNITS, f"Laure units other than {LAURE_UNITS} change: {changed}; stop"
print(f"Laure: container switches in place; changed unit files {changed}; config paths {config_paths}", flush=True)
assert healthy("openclaw"), "Laure's gateway is not healthy; stop"
watched = ("openclaw",) if rolling_back else ("openclaw", "claw-simon")
if not rolling_back:
    assert healthy("claw-simon"), "flakey's gateway is not healthy; stop (use rollback mode to undo a broken flakey)"
assert idle(*watched), f"unfinished agent run in {watched}; nothing changed. Retry when idle."
before = snapshot()
simon_before = show("claw-simon", "openclaw-gateway", "InvocationID")
(STATE / f"{mode}-before.json").write_text(json.dumps(before))
print(f"snapshot: Laure {len(before['sessions'])} sessions, {len(before['devices'])} paired devices, "
      f"{len(before['jobs'])} jobs; gateway {before['gateway']}; flakey gateway {simon_before}", flush=True)
if mode.startswith("check"):
    print(f"CHECK OK: {'rollback' if rolling_back else 'forward'} preconditions hold; nothing switched")
    sys.exit(0)

# The last idle check, immediately before activation.
refuse_if_switching()
assert idle(*watched), f"a run started in {watched}; nothing changed. Retry when idle."
stop = threading.Event()
samples = {c: [] for c in ("openclaw", "claw-simon")}


def monitor(container):
    while not stop.is_set():
        samples[container].append([time.time(), healthy(container)])
        stop.wait(0.4)


threads = [threading.Thread(target=monitor, args=(c,)) for c in samples]
for thread in threads:
    thread.start()
problems = []
started = time.time()
try:
    rc = activate(target)
    print(f"switch rc={rc} after {time.time() - started:.1f} s", flush=True)
    if rc not in (0, 4):
        problems.append(f"switch exited {rc}")
    deadline = time.time() + 180
    while not all(healthy(c) for c in watched):
        if time.time() >= deadline:
            problems.append(f"health did not return within 180 s: {[c for c in watched if not healthy(c)]}")
            break
        time.sleep(1)
    time.sleep(3)
except Exception as error:  # a failed activation call must still roll back
    problems.append(f"switch raised {error!r}")
finally:
    stop.set()
    for thread in threads:
        thread.join()
    (STATE / f"{mode}-health-samples.json").write_text(json.dumps(samples))

alerts = []
try:
    after = snapshot()
except Exception as error:
    after = {}
    problems.append(f"Laure snapshot failed after the switch: {error!r}")
simon_after = show("claw-simon", "openclaw-gateway", "InvocationID", "NRestarts")
if run("systemctl", "show", "container@claw-simon", "-p", "InvocationID", "--value").strip() != simon_container_before:
    problems.append("flakey container restarted")
if (simon_after or {}).get("InvocationID") == (simon_before or {}).get("InvocationID") or (simon_after or {}).get("NRestarts") != "0":
    problems.append("flakey gateway did not restart exactly once")
(STATE / f"{mode}-after.json").write_text(json.dumps(after))
if after:
    if after["container"] != before["container"]:
        problems.append(f"Laure's container restarted: {before['container']} -> {after['container']}")
    gateway_before, gateway_after = before["gateway"] or {}, after["gateway"] or {}
    if gateway_after.get("InvocationID") == gateway_before.get("InvocationID"):
        problems.append("Laure's gateway did not restart onto the new config")
    if gateway_after.get("NRestarts") != "0":
        problems.append(f"Laure's gateway restarted more than once (NRestarts {gateway_after.get('NRestarts')})")
    if after["configSHA256"] != hashlib.sha256(target_config).hexdigest():
        problems.append("Laure's live config is not TO's")
    lost = sorted(set(before["sessions"]) - set(after["sessions"]))
    if lost:
        alerts.append(f"Laure lost {len(lost)} sessions")
    if set(before["devices"]) - set(after["devices"]):
        alerts.append(f"Laure lost paired devices {sorted(set(before['devices']) - set(after['devices']))}")
laure_now = inside("openclaw", "readlink", "-e", "/run/current-system").strip()
if laure_now != laure_target:
    problems.append(f"Laure's container runs {laure_now}, not TO's {laure_target}")
try:
    simon_now = inside("claw-simon", "readlink", "-e", "/run/current-system").strip()
except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
    simon_now = None
if simon_now != container_system(target, "claw-simon"):
    (alerts if rolling_back else problems).append(f"flakey's container runs {simon_now}, not TO's")
if os.path.realpath("/run/current-system") != target:
    problems.append("running system is not the target")
notes = [f"Laure {key} changed (her own use can do this)" for key in ("jobs", "pending")
         if after and after.get(key) != before.get(key)]
interruptions = {}
for container, rows in samples.items():
    bad = [t for t, ok in rows if not ok]
    interruptions[container] = round(max(bad) - min(bad) + 0.4, 1) if bad else 0
summary = {"mode": mode, "from": source, "to": target, "generation": os.readlink("/nix/var/nix/profiles/system"),
           "secondsUnhealthy": interruptions,
           "laureGateway": [before["gateway"], after.get("gateway")],
           "laureContainer": [before["container"], after.get("container")],
           "laureSessionShare": [before["sessionShare"], after.get("sessionShare")],
           "laureCounts": {k: [len(before[k]), len(after.get(k) or [])] for k in ("sessions", "devices", "jobs")},
           "simonGateway": [simon_before, simon_after],
           "problems": problems, "alerts": alerts, "notes": notes}
(STATE / f"{mode}-summary.json").write_text(json.dumps(summary, indent=1))
print(json.dumps(summary, indent=1), flush=True)

if problems and mode == "forward":
    print(f"ROLLBACK NOW to {source}: {problems}", flush=True)
    rrc = activate(source)
    deadline = time.time() + 180
    while not healthy("openclaw") and time.time() < deadline:
        time.sleep(1)
    print(f"rollback rc={rrc}; running {os.path.realpath('/run/current-system')}; "
          f"Laure healthy {healthy('openclaw')}; flakey healthy {healthy('claw-simon')}", flush=True)
    sys.exit(4)
if problems:
    print(f"ROLLBACK INCOMPLETE, do not flip forward: {problems}", flush=True)
    sys.exit(4)
if alerts:
    print(f"ALERT, no automatic rollback (it cannot restore state): {alerts}", flush=True)
    sys.exit(6)
print(f"OK: {mode} done; Laure's container stayed up and her gateway restarted once"
      + (f"; notes: {notes}" if notes else ""))
