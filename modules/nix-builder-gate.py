"""Decide whether this machine accepts a Nix remote build right now.

A builder's SSH key entry runs `nix-builder-gate serve` instead of the Nix
daemon. `serve` checks the rules below. If they pass, it records the session
and replaces itself with `nix daemon --stdio`. If they fail, it refuses, the
client's Nix sees a failed connection, and Nix tries the next builder.

Rules (mode "home", used by a laptop):
  - at home (the default route's gateway has a MAC from homeMacs) and on
    mains power: accept by default;
  - away, on battery, or with no default route: refuse by default;
  - a manual choice ("on" or "off") wins over the default. It is stored with
    the gateway MAC it was made on, and it clears when a different gateway is
    seen. Losing the network clears nothing.
Mode "always" accepts every session.

Commands:
  serve              gate one SSH session (used by authorized_keys)
  status [--json]    print the decision and why
  set on|off|default store or clear the manual choice
  stop               end the remote builds running now
  refresh            clear a stale choice and rewrite the state file
"""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

CONFIG = Path(os.environ.get("NIX_BUILDER_GATE_CONFIG", "/etc/nix-builder-gate.json"))
STATE_DIR = Path(os.environ.get("NIX_BUILDER_GATE_STATE", "/var/lib/nix-builder-gate"))
RUN_DIR = Path(os.environ.get("NIX_BUILDER_GATE_RUN", "/run/nix-builder-gate"))
POWER = Path(os.environ.get("NIX_BUILDER_GATE_POWER", "/sys/class/power_supply"))
PROC = Path(os.environ.get("NIX_BUILDER_GATE_PROC", "/proc"))
DAEMON = os.environ.get("NIX_BUILDER_GATE_DAEMON", "nix")


def log(message):
    print(f"nix-builder-gate: {message}", file=sys.stderr, flush=True)


def config():
    try:
        value = json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        return {"mode": "always"}
    value.setdefault("mode", "always")
    value["homeMacs"] = [m.lower() for m in value.get("homeMacs", [])]
    return value


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def gateway_mac():
    """The MAC of the default route's gateway, or None without a route."""
    routes = []
    for line in run(["ip", "-4", "route", "show", "default"]).splitlines():
        fields = line.split()
        if "via" not in fields or "dev" not in fields:
            continue
        metric = int(fields[fields.index("metric") + 1]) if "metric" in fields else 0
        routes.append((metric, fields[fields.index("via") + 1], fields[fields.index("dev") + 1]))
    if not routes:
        return None
    _, gateway, device = min(routes)
    for attempt in range(2):
        fields = run(["ip", "neigh", "show", gateway, "dev", device]).split()
        if "lladdr" in fields:
            return fields[fields.index("lladdr") + 1].lower()
        if attempt == 0:
            # No ARP entry yet: one ping makes the kernel resolve it.
            run(["ping", "-c", "1", "-W", "1", gateway])
    return ""


def on_mains():
    """True on mains power, and on machines that have no mains supply to report."""
    supplies = list(POWER.glob("*")) if POWER.is_dir() else []
    mains = [s for s in supplies if (s / "type").is_file() and (s / "type").read_text().strip() == "Mains"]
    if not mains:
        return True
    return any((s / "online").is_file() and (s / "online").read_text().strip() == "1" for s in mains)


def load_choice():
    try:
        value = json.loads((STATE_DIR / "choice.json").read_text())
    except (OSError, ValueError):
        return None
    if value.get("choice") not in ("on", "off"):
        return None
    return value


def save_choice(value):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path = STATE_DIR / "choice.json"
    if value is None:
        path.unlink(missing_ok=True)
        return
    write_atomic(path, value)


def write_atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=path.parent, prefix=".tmp-")
    with os.fdopen(handle, "w") as stream:
        json.dump(value, stream)
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def sessions():
    """PIDs of the remote build sessions that are still running."""
    folder = RUN_DIR / "sessions"
    alive = []
    for entry in folder.glob("*") if folder.is_dir() else []:
        pid = entry.name
        try:
            command = (PROC / pid / "cmdline").read_bytes().split(b"\0")
        except OSError:
            entry.unlink(missing_ok=True)
            continue
        if any(part.endswith(b"nix") for part in command[:1]) and b"daemon" in command:
            alive.append(int(pid))
        else:
            entry.unlink(missing_ok=True)
    return alive


def decide(cfg, mac, mains, choice):
    """Return (accepting, reason, location). Pure: no I/O."""
    if cfg["mode"] != "home":
        return True, "always", "unknown"
    if mac is None:
        location = "unknown"
    elif mac in cfg["homeMacs"]:
        location = "home"
    else:
        location = "away"
    if choice is not None:
        return choice["choice"] == "on", "choice-" + choice["choice"], location
    if mac is None:
        return False, "no-network", location
    if location == "away":
        return False, "away", location
    if not mains:
        return False, "battery", location
    return True, "home", location


def refresh(cfg):
    """Clear a choice made on another network, then return the full state."""
    mac = gateway_mac() if cfg["mode"] == "home" else None
    choice = load_choice()
    if choice is not None and mac and choice.get("mac") != mac:
        log(f"network changed; clearing the manual choice '{choice['choice']}'")
        save_choice(None)
        choice = None
    mains = on_mains()
    accepting, reason, location = decide(cfg, mac, mains, choice)
    state = {
        "accepting": accepting,
        "reason": reason,
        "location": location,
        "power": "ac" if mains else "battery",
        "choice": choice["choice"] if choice else None,
        "running": len(sessions()),
    }
    try:
        write_atomic(RUN_DIR / "state.json", state)
    except OSError:
        pass
    return state, mac


def main(argv):
    cfg = config()
    command = argv[1] if len(argv) > 1 else "status"
    if command == "serve":
        state, _ = refresh(cfg)
        if not state["accepting"]:
            log(f"refusing remote builds: {state['reason']}")
            return 1
        folder = RUN_DIR / "sessions"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / str(os.getpid())).touch()
        os.execvp(DAEMON, [DAEMON, "daemon", "--stdio"])
    if command == "status":
        state, _ = refresh(cfg)
        if "--json" in argv:
            print(json.dumps(state))
        else:
            word = "accepting" if state["accepting"] else "refusing"
            print(f"{word} remote builds ({state['reason']}); {state['running']} running")
        return 0
    if command == "set" and len(argv) == 3 and argv[2] in ("on", "off", "default"):
        _, mac = refresh(cfg)
        if argv[2] == "default":
            save_choice(None)
        else:
            save_choice({"choice": argv[2], "mac": mac})
        state, _ = refresh(cfg)
        print(json.dumps(state))
        return 0
    if command == "stop":
        for pid in sessions():
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass
        refresh(cfg)
        return 0
    if command == "refresh":
        refresh(cfg)
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
