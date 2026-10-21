"""Push new storage findings to ntfy through the notify CLI; clear them on recovery.

One run reads the local storage probe once. A new `bad` finding sends one
alert. A finding that disappears sends one recovery message, then clears the
original alert by its saved sequence ID. An unchanged finding is never sent
again. A probe that fails or returns incomplete output sends an "unavailable"
alert at most once per --unknown-interval seconds and never counts as recovery.

A failed publish or clear leaves the state as it was, so the next run retries.
The exit status is non-zero after any failed publish or clear; storage units
are never touched. Tokens reach the notify CLI through its environment
(NOTIFY_TOKEN_FILE, NOTIFY_BUTTON_TOKEN_FILE), never through argv.
"""

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time

SEQUENCE = re.compile(r"^agent-[A-Za-z0-9-]{1,64}$")
LEVELS = ("ok", "warn", "bad")


# Measurements that change between runs while the problem stays the same.
# Identifiers such as disk 03 or /srv/shores/towada/04 must stay distinct.
VOLATILE = re.compile(r"\d+(?=( h ago|%| I/O errors| files| bytes))")


def fingerprint(message: str) -> str:
    return VOLATILE.sub("#", message)


def parse(stdout: str, returncode: int, now: int, skew: int = 120):
    """Return (complete, {fingerprint: message}) for `bad` findings."""
    if returncode != 0:
        return False, {}
    lines = stdout.splitlines()
    if not lines:
        return False, {}
    last = lines[-1].split("\t")
    if len(last) != 2 or last[0] != "complete" or not last[1].isdigit():
        return False, {}
    if abs(int(last[1]) - now) > skew:
        return False, {}
    bad = {}
    for line in lines[:-1]:
        fields = line.split("\t")
        if len(fields) != 2 or fields[0] not in LEVELS or not fields[1]:
            return False, {}
        if fields[0] == "bad":
            bad[fingerprint(fields[1])] = fields[1]
    return True, bad


class Notifier:
    def __init__(self, binary: str, name: str, timeout: int = 60):
        self.binary, self.name, self.timeout = binary, name, timeout

    def send(self, summary: str, body: str):
        try:
            result = subprocess.run(
                [self.binary, "send", "--name", self.name, "--summary", summary, "--body", body],
                capture_output=True, text=True, timeout=self.timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            log(f"publish failed: {type(error).__name__}")
            return None
        seq = result.stdout.strip()
        if result.returncode != 0 or not SEQUENCE.fullmatch(seq):
            log(f"publish failed: exit {result.returncode}: {result.stderr.strip()[:200]}")
            return None
        return seq

    def clear(self, seq: str) -> bool:
        if not SEQUENCE.fullmatch(seq):
            return True  # Nothing valid to clear; drop the record.
        try:
            result = subprocess.run([self.binary, "clear", seq], capture_output=True, text=True, timeout=self.timeout)
        except (OSError, subprocess.TimeoutExpired) as error:
            log(f"clear failed: {type(error).__name__}")
            return False
        if result.returncode != 0:
            log(f"clear failed: exit {result.returncode}: {result.stderr.strip()[:200]}")
        return result.returncode == 0


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def load(path: Path) -> dict:
    try:
        state = json.loads(path.read_text())
    except FileNotFoundError:
        return {"alerts": {}, "unknown": None}
    except (OSError, ValueError):
        log("state unreadable; starting empty")
        return {"alerts": {}, "unknown": None}
    state.setdefault("alerts", {})
    state.setdefault("unknown", None)
    return state


def save(path: Path, state: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2, sort_keys=True))
    os.replace(temporary, path)


def check(state: dict, complete: bool, bad: dict, now: int, host: str, notifier: Notifier,
          unknown_interval: int, persist) -> int:
    """Apply one probe result to the state. Returns the number of failed sends/clears."""
    failures = 0
    if not complete:
        unknown = state["unknown"]
        if unknown is None or now - unknown["sentAt"] >= unknown_interval:
            seq = notifier.send(
                f"{host}: storage check unavailable",
                "The local storage probe failed or returned incomplete output. "
                "See the journal of storage-alert.service.",
            )
            if seq is None:
                return 1
            if unknown is not None and not notifier.clear(unknown["seq"]):
                failures += 1
            state["unknown"] = {"seq": seq, "sentAt": now}
            persist()
        return failures

    unknown = state["unknown"]
    if unknown is not None:
        if not unknown.get("recovered"):
            if notifier.send(f"{host}: storage check recovered", "The local storage probe answers again.") is None:
                failures += 1
            else:
                unknown["recovered"] = True
                persist()
        if unknown.get("recovered"):
            if notifier.clear(unknown["seq"]):
                state["unknown"] = None
                persist()
            else:
                failures += 1

    alerts = state["alerts"]
    for key, message in sorted(bad.items()):
        if key in alerts and not alerts[key].get("recovered"):
            alerts[key]["message"] = message
            continue
        if key in alerts:
            # It returned before its recovery could be cleared: retire the old
            # notice best-effort and alert again rather than staying silent.
            notifier.clear(alerts[key]["seq"])
        seq = notifier.send(f"{host}: storage problem", message)
        if seq is None:
            failures += 1
            continue
        alerts[key] = {"seq": seq, "message": message, "since": now}
        persist()

    for key in sorted(set(alerts) - set(bad)):
        entry = alerts[key]
        if not entry.get("recovered"):
            if notifier.send(f"{host}: storage recovered", entry["message"]) is None:
                failures += 1
                continue
            entry["recovered"] = True
            persist()
        if notifier.clear(entry["seq"]):
            del alerts[key]
            persist()
        else:
            failures += 1
    return failures


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--probe", required=True, help="storage probe script")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--notify", required=True, help="notify CLI")
    parser.add_argument("--probe-timeout", type=int, default=120)
    parser.add_argument("--unknown-interval", type=int, default=6 * 3600)
    args = parser.parse_args(argv)

    host = socket.gethostname()
    state_dir = Path(args.state_dir)
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    with open(state_dir / "lock", "w") as lock:
        # OnFailure triggers and the timer can overlap; runs are short.
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = state_dir / "state.json"
        state = load(path)
        now = int(time.time())
        try:
            result = subprocess.run(["bash", args.probe, args.profile], capture_output=True, text=True,
                                    timeout=args.probe_timeout)
            complete, bad = parse(result.stdout, result.returncode, now)
        except subprocess.TimeoutExpired:
            complete, bad = False, {}
        notifier = Notifier(args.notify, "storage-" + re.sub(r"[^A-Za-z0-9-]", "-", host))
        failures = check(state, complete, bad, now, host, notifier, args.unknown_interval,
                         lambda: save(path, state))
        save(path, state)
    log(f"probe {'complete' if complete else 'unavailable'}; {len(bad)} bad; "
        f"{len(state['alerts'])} open alerts; {failures} failed operations")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
