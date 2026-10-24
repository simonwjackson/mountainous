#!/usr/bin/env python3
"""Check the evaluated hypridle policy, not an independent copy of its values."""

import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
assert "before_sleep_cmd = loginctl lock-session" in text
assert "inhibit_sleep = 3" in text
assert re.search(
    r"lock_cmd = pidof hyprlock \|\| /nix/store/[^\n]+/bin/mountainous-lock", text
)
assert (
    "on_lock_cmd = systemctl --user restart mountainous-lock-screen-off.service" in text
)
assert (
    "on_unlock_cmd = systemctl --user stop mountainous-lock-screen-off.service" in text
)
listeners = re.findall(r"listener \{([^}]+)\}", text)
assert len(listeners) == 3
assert "timeout = 300" in listeners[0]
assert "on-timeout = loginctl lock-session" in listeners[0]
assert "timeout = 30" in listeners[1]
assert (
    "pidof hyprlock && systemctl --user is-active --quiet mountainous-lock-screen-off.service"
    in listeners[1]
)
assert "on-resume = /nix/store/" in listeners[1]
assert "timeout = 900" in listeners[2]
assert "condition_retry = 60" in listeners[2]
assert "on-timeout = systemctl suspend" in listeners[2]
condition = re.search(r"condition_cmd = (/nix/store/\S+)", listeners[2]).group(1)
assert (
    "grep -qsx Discharging /sys/class/power_supply/BAT*/status"
    in Path(condition).read_text()
)
print("evaluated Myoko hypridle policy: passed")
