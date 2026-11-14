#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 systemd procps nix curl diffutils
"""Pace 2 Rakku preflight and ready/idle/go switch; rollback on EVERY failure.
Usage: pace2-rakku-switch.py preflight|switch rows OLD NEW.
Run switches under pace2-launch.sh. Rakku never builds and never reboots.
"""
import json
import os
import secrets
import subprocess
import sys
import time

action, phase, old, new = sys.argv[1:]
assert action in ("preflight", "switch"), action
assert phase in ("rows", "retire"), phase
for path in (old, new):
    assert path.startswith("/nix/store/") and "-nixos-system-rakku-" in path, path
    assert os.path.isdir(path), f"missing on Rakku: {path}"
ROWS = ["calendar", "ebay", "family-calendar", "family-calendar-laure", "gmail", "maps", "scryer", "scryer-laure",
        "sparkyfitness", "websearch", "pace", "pace-laure"]
OLD_NODES = []
if phase == "rows":
    EXPECTED = {"tsnet-proxy-ai.service", "pace2.service",
                "dbus-broker.service.d/overrides.conf", "systemd-tmpfiles-resetup.service"}
    MAY_CHANGE = {"tsnet-proxy-ai.service", "pace2.service", "systemd-tmpfiles-resetup.service"}
    STAY = [f"tsnet-proxy-{n}.service" for n in OLD_NODES]
else:
    EXPECTED = {f"tsnet-proxy-{n}.service" for n in OLD_NODES}
    MAY_CHANGE = set(EXPECTED)
    STAY = ["tsnet-proxy-ai.service", "tsnet-proxy-ai-staging.service"]
# Never restarted by this stage: the front door's model backend, the stores and
# apps behind every row, Laure's Pi assistant, Home Assistant and Z-Wave.
PROTECTED = ["ai-gateway.service", "ai-gateway-staging.service", "sparkyfitness.service", "home-assistant.service",
             "zwave-js.service", "ebay-server.service", "assistant-app-simon-google.service",
             "assistant-app-simon-maps.service", "pi-assistant-laure.service"] + STAY
BASE = "https://ai.hummingbird-lake.ts.net"
KEY = "/run/secrets/ai-gateway-key-assistant-rakku"  # models dialect; no paid call
STATE = "/var/tmp/pace2-rakku"
os.makedirs(STATE, mode=0o700, exist_ok=True)


def run(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def refuse_if_switching():
    if subprocess.run(["pgrep", "-f", "[b]in/switch-to-configuration"], stdout=subprocess.DEVNULL).returncode == 0:
        sys.exit("another switch-to-configuration is running; nothing changed. Rerun the whole step, idle gate included.")
    current = os.path.realpath("/run/current-system")
    if current != old:
        sys.exit(f"running system is {current}, not OLD; nothing changed")


def models():
    with open(KEY) as handle:
        header = "Authorization: Bearer " + handle.read().strip() + "\n"
    result = subprocess.run(["curl", "-sS", "--max-time", "10", "-w", "\n%{http_code}", "-H", "@-", BASE + "/v1/models"],
                            input=header, capture_output=True, text=True)
    body, _, status = result.stdout.rpartition("\n")
    try:
        ids = sorted(m["id"] for m in json.loads(body)["data"])
    except (ValueError, KeyError, TypeError):
        ids = None
    return status, ids


def status_of(path, body=None):
    args = ["curl", "-sS", "--max-time", "10", "-o", "/dev/null", "-w", "%{http_code}"]
    if body is not None:
        args += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    return run(*args, BASE + path)


def rows():
    listing = {"jsonrpc": "2.0", "id": 1, "method": "tools/list"}
    return {row: status_of(f"/mcp/{row}", listing) for row in ROWS}


def unit_differences():
    live, built = "/etc/systemd/system", f"{new}/etc/systemd/system"
    differ = []
    for name in sorted(set(os.listdir(live)) | set(os.listdir(built))):
        a, b = os.path.join(live, name), os.path.join(built, name)
        if os.path.isdir(a) or os.path.isdir(b):
            links_a = set(os.listdir(a) if os.path.isdir(a) else [])
            links_b = set(os.listdir(b) if os.path.isdir(b) else [])
            if links_a != links_b:
                # In retire, a wants/ directory may lose exactly the removed units' links.
                if ((links_b - links_a) | (links_a - links_b)) <= EXPECTED:
                    print(f"    {name}/ loses only {sorted(links_a - links_b)}")
                    continue
                differ.append(name + "/")
                continue
            # Same entries: compare drop-in files too (overrides.conf and the like).
            # A .wants/.requires link names a unit compared on its own above.
            if not name.endswith(".d"):
                continue
            for entry in sorted(links_a):
                fa, fb = os.path.join(a, entry), os.path.join(b, entry)
                if os.path.isfile(fa) and os.path.isfile(fb) and subprocess.run(["cmp", "-s", fa, fb]).returncode:
                    differ.append(f"{name}/{entry}")
            continue
        if not (os.path.exists(a) and os.path.exists(b)) or subprocess.run(["cmp", "-s", a, b]).returncode:
            differ.append(name)
    return differ


def activation_trigger_only():
    # A new dedicated user and database ownership rule change these generated
    # triggers. Their command, security settings and every other byte must stay.
    for name in ("dbus-broker.service.d/overrides.conf", "systemd-tmpfiles-resetup.service"):
        def without_trigger(root):
            with open(f"{root}/etc/systemd/system/{name}") as handle:
                return [line for line in handle if not line.startswith("X-Restart-Triggers=")]
        assert without_trigger("/run/current-system") == without_trigger(new), name


def identities():
    names = [line.split()[0] for line in
             run("systemctl", "list-units", "--all", "--type=service", "--plain", "--no-legend").splitlines() if line.strip()]
    return {name: dict(line.partition("=")[::2] for line in run(
        "systemctl", "show", name, "-p", "MainPID", "-p", "InvocationID", "-p", "NRestarts", "-p", "ActiveState").splitlines())
        for name in names}


def ha_status():
    return run("curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "10", "http://127.0.0.1:8123/")


def failed():
    return sorted(line.split()[0] for line in run("systemctl", "--failed", "--plain", "--no-legend").splitlines() if line.strip())


def activate(system, log):
    subprocess.run(["nix-env", "-p", "/nix/var/nix/profiles/system", "--set", system], check=True)
    with open(log, "w") as handle:
        return subprocess.run([f"{system}/bin/switch-to-configuration", "switch"], stdout=handle, stderr=subprocess.STDOUT).returncode


if action == "preflight":
    current = os.path.realpath("/run/current-system")
    differ = unit_differences()
    activation_trigger_only()
    status, ids = models()
    before_rows = rows()
    print(f"phase {phase}; running {current} (expected OLD: {current == old})")
    print(f"unit files that differ from the live system: {differ}")
    print(f"expected: {sorted(EXPECTED)}")
    print(f"keyed /v1/models: HTTP {status}, {len(ids or [])} models")
    print(f"/v1/models without a key: HTTP {status_of('/v1/models')}; rows from this host: {before_rows}")
    print(f"home-assistant HTTP {ha_status()}; failed units: {failed() or 'none'}")
    with open(f"{STATE}/baseline-{phase}.json", "w") as handle:
        json.dump({"old": old, "new": new, "models": [status, ids], "failed": failed()}, handle)
    ok = current == old and set(differ) == EXPECTED and status == "200" and ids
    print("PREFLIGHT OK" if ok else "PREFLIGHT FAILED: stop")
    sys.exit(0 if ok else 1)

baseline = json.load(open(f"{STATE}/baseline-{phase}.json"))
assert baseline["old"] == old and baseline["new"] == new, "preflight was for other systems"
for name in ("ready", "go", "abort"):
    if os.path.exists(f"{STATE}/{name}"):
        os.remove(f"{STATE}/{name}")
refuse_if_switching()
before = identities()
# The slow part (nix-shell, identities) is done. Hand the last idle check to
# the orchestrator, then activate the moment it says go. The nonce ties go to
# this run: a second unit, or a stale go, cannot trigger it.
nonce = secrets.token_hex(8)
with open(f"{STATE}/ready", "w") as handle:
    handle.write(nonce)
print(f"ready {nonce}: waiting up to 120 s for go", flush=True)
deadline = time.time() + 120


def go_matches():
    try:
        with open(f"{STATE}/go") as handle:
            return handle.read().strip() == nonce
    except FileNotFoundError:
        return False


while not go_matches():
    if os.path.exists(f"{STATE}/abort") or time.time() > deadline:
        sys.exit("no go for this run (aborted or timed out); nothing changed")
    time.sleep(0.2)
refuse_if_switching()
started = time.time()
rc = activate(new, f"{STATE}/switch-{phase}.log")
switched = time.time()
print(f"switch rc={rc} in {switched - started:.1f} s; generation {os.readlink('/nix/var/nix/profiles/system')}; "
      f"running {os.path.realpath('/run/current-system')}", flush=True)
for line in open(f"{STATE}/switch-{phase}.log"):
    if any(w in line.lower() for w in ("restarting", "reloading", "starting", "stopping", "failed", "error", "warning")):
        print("   ", line.rstrip()[:240])
status, ids = "000", None
while time.time() < switched + 120:
    status, ids = models()
    if status == "200":
        break
    time.sleep(1)
print(f"keyed /v1/models back after {time.time() - started:.1f} s from switch start: HTTP {status}", flush=True)
time.sleep(5)
after = identities()
for _ in range(12):
    ha = ha_status()
    if ha == "200":
        break
    time.sleep(5)
changed = sorted(n for n in set(before) | set(after)
                 if before.get(n, {}).get("InvocationID") != after.get(n, {}).get("InvocationID")
                 or before.get(n, {}).get("MainPID") != after.get(n, {}).get("MainPID"))
print("services with a new identity:")
for name in changed:
    b, a = before.get(name, {}), after.get(name, {})
    print(f"    {name:44} {b.get('ActiveState', 'absent')}->{a.get('ActiveState', 'absent')} "
          f"pid {b.get('MainPID', '-')}->{a.get('MainPID', '-')} restarts {b.get('NRestarts', '-')}->{a.get('NRestarts', '-')}")
journal = run("journalctl", "-u", "tsnet-proxy-ai", "--since", f"@{int(started)}", "--no-pager", "-o", "cat")
row_status = rows()
unkeyed = status_of("/v1/models")
failed_after = failed()
print("tsnet-proxy-ai journal since the switch:\n    " + ("\n    ".join(journal.strip().splitlines()) or "(nothing)"))
print(f"rows from the Rakku host (not a caller): {row_status}; /v1/models without a key HTTP {unkeyed}")
print(f"home-assistant HTTP {ha}; failed units: {failed_after or 'none'} (before: {baseline['failed'] or 'none'})")

problems = [f"{n} changed identity" for n in PROTECTED if n in changed]
problems += [f"{n} not active" for n in PROTECTED if after.get(n, {}).get("ActiveState") != "active"]
if phase == "rows":
    problems += [f"{n} not active" for n in ("tsnet-proxy-ai.service", "pace2.service") if after.get(n, {}).get("ActiveState") != "active"]
elif phase == "retire":
    problems += [f"{n} still present ({after[n].get('ActiveState')})" for n in sorted(EXPECTED)
                 if after.get(n, {}).get("ActiveState") not in (None, "inactive")]
if rc != 0:
    problems.append(f"switch rc={rc}")
if [status, ids] != baseline["models"]:
    problems.append(f"keyed /v1/models differs from baseline: HTTP {status}, {ids}")
if unkeyed != "401":
    problems.append(f"/v1/models without a key HTTP {unkeyed}")
if phase == "rows" and (journal.count("proxy ready") != 1 or journal.count("MCP table loaded") != 1):
    problems.append("tsnet-proxy-ai did not start exactly once with a valid table")
mcp_problems = []
bad = {row: s for row, s in row_status.items() if s != "403"}
if phase == "rows" and bad and set(bad.values()) == {"404"} and len(bad) == len(ROWS):
    # Every row 404: the table was rejected (fail-closed); /v1 is healthy. Fix forward.
    problems.append(f"no row is served (all 404); MCP table loaded in journal: {'MCP table loaded' in journal}")
elif bad:
    problems.append(f"rows from a non-caller not 403: {bad} (the caller lock is not proven)")
if ha != "200":
    problems.append(f"home-assistant HTTP {ha}")
if set(failed_after) - set(baseline["failed"]):
    problems.append(f"new failed units {sorted(set(failed_after) - set(baseline['failed']))}")
unexpected = [n for n in changed if n not in MAY_CHANGE]
summary = {"phase": phase, "old": old, "new": new, "switchRc": rc, "generation": os.readlink("/nix/var/nix/profiles/system"),
           "changed": changed, "unexpected": unexpected, "v1BackSeconds": round(time.time() - started, 1),
           "rows": row_status, "problems": problems, "mcpProblems": mcp_problems,
           "protected": {n: after.get(n) for n in PROTECTED + sorted(EXPECTED)}}
with open(f"{STATE}/summary-{phase}.json", "w") as handle:
    json.dump(summary, handle, indent=1)
if unexpected:
    print(f"NOTE: other services changed identity (activation oneshots are normal): {unexpected}")
if problems:
    print(f"ROLLBACK NOW: {problems}", flush=True)
    rrc = activate(old, f"{STATE}/rollback-{phase}.log")
    back = "000"
    deadline = time.time() + 120
    while time.time() < deadline:
        back = status_of("/v1/models")
        if back == "401":
            break
        time.sleep(1)
    print(f"rollback rc={rrc}; running {os.path.realpath('/run/current-system')}; "
          f"/v1/models without a key HTTP {back}; HA {ha_status()}", flush=True)
    sys.exit(4)
if mcp_problems:
    print(f"MCP FAILED, /v1 HEALTHY, NO ROLLBACK: {mcp_problems}", flush=True)
    sys.exit(5)
print(f"OK ({phase}): only {sorted(MAY_CHANGE)} changed; /v1 matches the baseline; every row 403 to a non-caller")
