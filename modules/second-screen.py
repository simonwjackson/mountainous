"""Give a Moonlight client its own Hyprland monitor, below the laptop panel.

Sunshine runs this program three ways (see modules/sunshine.nix):

  attach  prep "do".  Creates the headless output SUNSHINE at the size the
          client asked for, scaled and placed directly under the panel.
  detach  prep "undo", and before and after Sunshine itself.  Removes the
          output.  Hyprland then moves the output's pages to the panel.
  hold    the app command.  Sunshine treats the app as running while this
          process lives.  Once the client has been gone for the grace
          period, it removes the output itself and exits.

Without `hold`, a client that disconnects without quitting the app leaves
the app running, so the output, and every window on it, would stay on a
screen nobody can see.

`hold` removes the output itself rather than leaving that to "undo".
Sunshine notices that an app has exited only when something asks whether it
is running (src/process.cpp running()). While a client streams, the control
loop asks every 150 ms. Once the last client has gone, that loop has ended
(src/stream.cpp controlBroadcastThread), and nothing asks until a client
polls again. "undo" still runs then, and finds nothing left to remove.

The pure parts (plan, Tracker) take no I/O and are tested by
scripts/test-second-screen.py.
"""

import json
import math
import os
import subprocess
import sys
import time
from dataclasses import dataclass

OUTPUT = "SUNSHINE"
# Hyprland stores scale as N/120 and needs whole logical pixels; see
# hypr-scale in modules/hyprland.nix for the derivation.
SCALE_STEPS = 120
MIN_SCALE_N = 120  # 1.0: never make the client's pixels bigger than real ones
MAX_SCALE_N = 360  # 3.0
GRACE_SECONDS = 15.0
FIRST_CONNECT_SECONDS = 60.0

# Sunshine log lines, as written by src/stream.cpp at v2026.914.233613.
CONNECTED = "CLIENT CONNECTED"
DISCONNECTED = ("CLIENT DISCONNECTED", ": Ping Timeout")
# src/process.cpp logs this just before it starts the app command, which is
# this process. The last one in the log is therefore this launch.
LAUNCH = "Executing: ["


class Refused(Exception):
    """A request this program will not act on.  The message says why."""


@dataclass(frozen=True)
class Panel:
    """The monitor the client sits under, in Hyprland's terms."""

    x: int
    y: int
    width: int  # pixels
    height: int
    scale: float

    @property
    def logical_width(self) -> int:
        return round(self.width / self.scale)

    @property
    def logical_height(self) -> int:
        return round(self.height / self.scale)


@dataclass(frozen=True)
class Rule:
    """One hl.monitor rule for the client's output."""

    width: int
    height: int
    fps: int
    scale_n: int
    x: int
    y: int

    @property
    def scale(self) -> str:
        return f"{self.scale_n / SCALE_STEPS:.6f}"

    @property
    def logical_width(self) -> int:
        return self.width * SCALE_STEPS // self.scale_n

    @property
    def logical_height(self) -> int:
        return self.height * SCALE_STEPS // self.scale_n

    def lua(self) -> str:
        return (
            "return {\n"
            f'    output   = "{OUTPUT}",\n'
            f'    mode     = "{self.width}x{self.height}@{self.fps}",\n'
            f'    position = "{self.x}x{self.y}",\n'
            f'    scale    = "{self.scale}",\n'
            "}\n"
        )


def client_size(env: dict) -> tuple[int, int, int]:
    """The width, height and frame rate Sunshine says the client asked for."""
    values = []
    for key, low, high in (
        ("SUNSHINE_CLIENT_WIDTH", 320, 8192),
        ("SUNSHINE_CLIENT_HEIGHT", 240, 8192),
        ("SUNSHINE_CLIENT_FPS", 1, 240),
    ):
        raw = env.get(key, "")
        if not raw.isdigit() or not low <= int(raw) <= high:
            raise Refused(f"{key}={raw!r} is not a number from {low} to {high}")
        values.append(int(raw))
    return values[0], values[1], values[2]


def legal_scales(width: int, height: int) -> list[int]:
    """Every N where N/120 gives whole logical pixels on both axes."""
    whole = SCALE_STEPS * math.gcd(width, height)
    return [n for n in range(MIN_SCALE_N, MAX_SCALE_N + 1) if whole % n == 0]


def plan(panel: Panel, width: int, height: int, fps: int) -> Rule:
    """Scale the client to the panel's logical height and put it underneath.

    Matching logical height makes text a similar size on both screens when
    their pixel densities are close, which is true of a laptop panel and a
    tablet. The client is centred under the panel. When it is wider than
    the panel it starts at the panel's left edge instead: a negative x would
    put part of the desktop left of zero, and Sunshine maps absolute mouse
    input from zero.
    """
    target = SCALE_STEPS * height / panel.logical_height
    # Nearest legal step; on a tie, the smaller scale, which shows more.
    scale_n = min(legal_scales(width, height), key=lambda n: (abs(n - target), n))
    logical_width = width * SCALE_STEPS // scale_n
    x = panel.x + max(0, (panel.logical_width - logical_width) // 2)
    y = panel.y + panel.logical_height
    return Rule(width, height, fps, scale_n, x, y)


def pick_panel(monitors: list[dict]) -> Panel:
    """The internal panel if there is one, otherwise the first real monitor."""
    real = [m for m in monitors if m["name"] != OUTPUT]
    if not real:
        raise Refused("Hyprland reports no monitor besides " + OUTPUT)
    chosen = next((m for m in real if m["name"].startswith("eDP")), real[0])
    return Panel(chosen["x"], chosen["y"], chosen["width"], chosen["height"], chosen["scale"])


def matches(rule: Rule, monitor: dict) -> bool:
    return (
        monitor["width"] == rule.width
        and monitor["height"] == rule.height
        and monitor["x"] == rule.x
        and monitor["y"] == rule.y
        and round(monitor["scale"] * SCALE_STEPS) == rule.scale_n
    )


class Tracker:
    """Decides when the client has gone for good.

    `seen` takes Sunshine log lines in order. `expired` is true once no client
    has been connected for `grace` seconds, or when no client connected at
    all within `first_connect` seconds of launch.
    """

    def __init__(self, now: float, grace: float = GRACE_SECONDS, first_connect: float = FIRST_CONNECT_SECONDS):
        self.started = now
        self.grace = grace
        self.first_connect = first_connect
        self.clients = 0
        self.ever_connected = False
        self.empty_since: float | None = None

    def seen(self, line: str, now: float) -> None:
        if CONNECTED in line:
            self.clients += 1
            self.ever_connected = True
            self.empty_since = None
        elif any(marker in line for marker in DISCONNECTED):
            # A ping timeout and a disconnect can both end one session, so
            # the count stops at zero rather than going negative.
            self.clients = max(0, self.clients - 1)
            if self.clients == 0 and self.empty_since is None:
                self.empty_since = now

    def expired(self, now: float) -> bool:
        if not self.ever_connected:
            return now - self.started >= self.first_connect
        return self.empty_since is not None and now - self.empty_since >= self.grace


def lines_since_launch(text: str) -> list[str]:
    """The log lines after the last app launch, which is this one."""
    lines = text.splitlines()
    for index in range(len(lines) - 1, -1, -1):
        if LAUNCH in lines[index]:
            return lines[index + 1 :]
    return lines


# ------------------------------------------------------------------ I/O


def hyprctl(*args: str) -> str:
    try:
        result = subprocess.run(
            ["hyprctl", "--instance", "0", *args], capture_output=True, text=True, check=False, timeout=10
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Refused(f"hyprctl {' '.join(args)} did not run: {error}") from error
    if result.returncode != 0:
        raise Refused(f"hyprctl {' '.join(args)} failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def monitors() -> list[dict]:
    return json.loads(hyprctl("-j", "monitors", "all"))


def find(name: str) -> dict | None:
    return next((m for m in monitors() if m["name"] == name), None)


def state_file() -> str:
    # second-screen.lua reads the same path; keep the two in step.
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "mountainous-second-screen.lua")


def write_state(rule: Rule) -> None:
    path = state_file()
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(rule.lua())
    os.replace(tmp, path)


def clear_state() -> None:
    try:
        os.remove(state_file())
    except FileNotFoundError:
        pass


def attach() -> None:
    width, height, fps = client_size(os.environ)
    rule = plan(pick_panel(monitors()), width, height, fps)
    # The rule goes in before the output exists, so the output never shows
    # up at Hyprland's default position first. hyprctl exits 0 even when
    # the Lua fails, so the check below is what proves it worked.
    write_state(rule)
    hyprctl("eval", 'require("second-screen").apply()')
    if find(OUTPUT) is None:
        reply = hyprctl("output", "create", "headless", OUTPUT).strip()
        if reply != "ok":
            raise Refused(f"Hyprland did not create {OUTPUT}: {reply}")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        monitor = find(OUTPUT)
        if monitor is not None and matches(rule, monitor):
            print(
                f"{OUTPUT}: {rule.width}x{rule.height}@{rule.fps} scale {rule.scale} "
                f"({rule.logical_width}x{rule.logical_height} logical) at {rule.x},{rule.y}"
            )
            return
        time.sleep(0.1)
    raise Refused(f"{OUTPUT} did not reach {rule.width}x{rule.height} at {rule.x},{rule.y}; got {find(OUTPUT)}")


def detach() -> None:
    clear_state()
    try:
        present = find(OUTPUT) is not None
    except Refused as error:
        # No compositor: nothing to remove. This happens when Sunshine stops
        # during logout, after Hyprland has gone.
        print(f"no Hyprland to detach from: {error}")
        return
    if present:
        reply = hyprctl("output", "remove", OUTPUT).strip()
        if reply != "ok":
            raise Refused(f"Hyprland did not remove {OUTPUT}: {reply}")
    print(f"{OUTPUT}: removed" if present else f"{OUTPUT}: not present")


def sunshine_log() -> str:
    # Sunshine's own rule, src/platform/linux/misc.cpp appdata().
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.environ["HOME"], ".config")
    return os.path.join(base, "sunshine", "sunshine.log")


def hold(grace: float) -> None:
    tracker = Tracker(time.monotonic(), grace=grace)
    path = sunshine_log()
    # Bytes, not text: the position is compared with the file size.
    with open(path, "rb") as log:
        for line in lines_since_launch(log.read().decode(errors="replace")):
            tracker.seen(line, time.monotonic())
        position = log.tell()
        pending = b""
        while not tracker.expired(time.monotonic()):
            time.sleep(0.5)
            if os.path.getsize(path) < position:
                # Sunshine restarted and began a new log, so the app that
                # started this process is gone.
                print("Sunshine started a new log; ending the session")
                detach()
                return
            log.seek(position)
            pending += log.read()
            position = log.tell()
            *complete, pending = pending.split(b"\n")
            for line in complete:
                tracker.seen(line.decode(errors="replace"), time.monotonic())
    reason = "no client connected" if not tracker.ever_connected else f"client gone for {grace:.0f}s"
    print(f"{reason}; ending the session")
    detach()


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else ""
    try:
        if command == "attach":
            try:
                attach()
            except Exception:
                # Sunshine runs "undo" only for steps that succeeded, so a
                # failed attach must not leave a half-made output behind.
                detach()
                raise
        elif command == "detach":
            detach()
        elif command == "hold":
            hold(float(os.environ.get("MOUNTAINOUS_SECOND_SCREEN_GRACE", GRACE_SECONDS)))
        else:
            print("usage: mountainous-second-screen attach|detach|hold", file=sys.stderr)
            return 2
    except Refused as error:
        print(f"mountainous-second-screen {command}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
