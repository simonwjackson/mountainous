#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 systemd procps nix curl
"""On Rakku, as root: roll a stage-7 Rakku step back. DEPLOYED -> PREVIOUS.

Usage: laure-tools-rakku-rollback.py DEPLOYED PREVIOUS
Run it under laure-tools-launch.sh (systemd-run). Like the switch, it writes
STATE/ready and activates within a second of STATE/go, which the orchestrator
gives after its last idle check of Laure's gateway (flakey's state does not
matter here). No go in 120 s: nothing changes. Refuses unless DEPLOYED runs (after a later deployment, use a forward
revert) and exits, never waits, when another switch runs. Rolling back the
rows step restarts production ai and ai-staging once on the stage-5 binary and
table (Simon's six rows stay; the four old nodes still run). Rolling back the retire step brings the
old per-tool units back; a deleted tailnet node cannot come back with its
identity (see the runbook). Keeps every tsnet and gateway state directory.
Polls /v1 and Home Assistant for up to 120 s, then prints identities.
"""
import os
import secrets
import subprocess
import sys
import time

deployed, previous = sys.argv[1:]
for path in (deployed, previous):
    assert path.startswith("/nix/store/") and "-nixos-system-rakku-" in path, path
assert os.path.isdir(previous), "PREVIOUS is missing from the store"
UNITS = ["tsnet-proxy-ai", "tsnet-proxy-ai-staging", "ai-gateway", "sparkyfitness", "home-assistant", "zwave-js",
         "tsnet-proxy-claw-scryer-laure", "tsnet-proxy-claw-websearch"]


def show():
    return subprocess.run(["systemctl", "show", *UNITS, "-p", "Id", "-p", "MainPID", "-p", "InvocationID", "-p", "ActiveState"],
                          capture_output=True, text=True).stdout


def status(url):
    return subprocess.run(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "10", url],
                          capture_output=True, text=True).stdout


STATE = "/var/tmp/pace2-rakku"
os.makedirs(STATE, mode=0o700, exist_ok=True)


def refuse_if_switching():
    if subprocess.run(["pgrep", "-f", "[b]in/switch-to-configuration"], stdout=subprocess.DEVNULL).returncode == 0:
        sys.exit("another switch-to-configuration is running; nothing changed. Rerun the step, idle gate included.")
    current = os.path.realpath("/run/current-system")
    if current != deployed:
        sys.exit(f"running system is {current}, not DEPLOYED; use a forward revert. Nothing changed.")


for name in ("ready", "go", "abort"):
    if os.path.exists(f"{STATE}/{name}"):
        os.remove(f"{STATE}/{name}")
refuse_if_switching()
print("before:\n" + show(), flush=True)
# A nonce ties go to this run: a second unit, or a stale go, cannot trigger it.
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
subprocess.run(["nix-env", "-p", "/nix/var/nix/profiles/system", "--set", previous], check=True)
rc = subprocess.run([f"{previous}/bin/switch-to-configuration", "switch"]).returncode
# A front-door restart takes about 22 s; poll instead of a fixed sleep.
v1 = ha = "000"
while time.time() < started + 120:
    v1, ha = status("https://ai.hummingbird-lake.ts.net/v1/models"), status("http://127.0.0.1:8123/")
    if v1 == "401" and ha == "200":
        break
    time.sleep(1)
failed = subprocess.run(["systemctl", "--failed", "--plain", "--no-legend"], capture_output=True, text=True).stdout
print(f"switch rc={rc}; running {os.path.realpath('/run/current-system')} ({os.readlink('/nix/var/nix/profiles/system')})")
print(f"after {time.time() - started:.0f} s:\n" + show())
print(f"/v1/models without a key HTTP {v1} (want 401); home-assistant HTTP {ha}; failed units: {failed.strip() or 'none'}")
sys.exit(0 if rc == 0 and ha == "200" and v1 == "401" else 1)
