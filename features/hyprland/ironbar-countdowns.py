#!/usr/bin/env python3
"""Render editable date countdowns for Ironbar.

The default file is ~/.config/ironbar/countdowns. Supported line formats:

    Label | YYYY-MM-DD
    Label | YYYY-MM-DD | business
    YYYY-MM-DD Label with spaces

The optional "business" mode counts weekdays only, excluding Saturday and Sunday.
Blank lines and lines beginning with # are ignored.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import sys
from dataclasses import dataclass
from datetime import date, timedelta


@dataclass(frozen=True)
class Countdown:
    label: str
    target: date
    mode: str = "calendar"


def default_countdowns_file() -> pathlib.Path:
    configured = os.environ.get("IRONBAR_COUNTDOWNS_FILE")
    if configured:
        return pathlib.Path(configured).expanduser()

    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        return pathlib.Path(config_home).expanduser() / "ironbar" / "countdowns"

    return pathlib.Path.home() / ".config" / "ironbar" / "countdowns"


def parse_today() -> date:
    configured = os.environ.get("IRONBAR_COUNTDOWNS_TODAY")
    if configured:
        return date.fromisoformat(configured)

    return date.today()


def parse_countdown(line: str) -> Countdown:
    if "|" in line:
        parts = [part.strip() for part in line.split("|")]
        if len(parts) not in (2, 3):
            raise ValueError("expected 'Label | YYYY-MM-DD | business'")

        label, target = parts[0], parts[1]
        mode = parts[2].lower() if len(parts) == 3 else "calendar"
        if mode not in ("calendar", "business"):
            raise ValueError("mode must be 'calendar' or 'business'")

        return Countdown(label=label, target=date.fromisoformat(target), mode=mode)

    target, separator, label = line.partition(" ")
    if not separator or not label.strip():
        raise ValueError("expected 'Label | YYYY-MM-DD' or 'YYYY-MM-DD Label'")

    return Countdown(label=label.strip(), target=date.fromisoformat(target.strip()))


def load_countdowns(path: pathlib.Path) -> list[Countdown]:
    if not path.exists():
        return []

    countdowns: list[Countdown] = []
    for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        try:
            countdown = parse_countdown(line)
        except ValueError as error:
            print(
                f"ironbar-countdowns: skipping invalid countdown line {line_number}: {error}",
                file=sys.stderr,
            )
            continue

        if not countdown.label:
            print(
                f"ironbar-countdowns: skipping invalid countdown line {line_number}: empty label",
                file=sys.stderr,
            )
            continue

        countdowns.append(countdown)

    return countdowns


def business_days_between(start: date, end: date) -> int:
    if start == end:
        return 0

    if end < start:
        return -business_days_between(end, start)

    days = 0
    current = start + timedelta(days=1)
    while current <= end:
        if current.weekday() < 5:
            days += 1
        current += timedelta(days=1)

    return days


def days_remaining(countdown: Countdown, today: date) -> int:
    if countdown.mode == "business":
        return business_days_between(today, countdown.target)

    return (countdown.target - today).days


def render_countdowns(countdowns: list[Countdown], today: date) -> str:
    return "  ".join(
        f"{countdown.label} {days_remaining(countdown, today)}d" for countdown in countdowns
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Ironbar date countdown segments")
    parser.add_argument(
        "--file",
        type=pathlib.Path,
        default=default_countdowns_file(),
        help="countdowns file to read (default: ~/.config/ironbar/countdowns)",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    print(render_countdowns(load_countdowns(args.file.expanduser()), parse_today()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
