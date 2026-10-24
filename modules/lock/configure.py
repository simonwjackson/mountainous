#!/usr/bin/env python3
"""Write one session's hyprlock config; stdout is the config path, never a password."""

import argparse
import json
import math
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import TypedDict

import lockplan


class Monitor(TypedDict):
    name: str
    width: int
    height: int
    scale: float
    transform: int
    focused: bool


def monitors_from_json(value: object) -> list[Monitor]:
    """Reject malformed IPC data before using it as config text or image sizes."""
    if not isinstance(value, list) or not 1 <= len(value) <= 16:
        raise ValueError("expected 1 to 16 monitors")
    monitors: list[Monitor] = []
    for item in value:
        if not isinstance(item, dict):
            raise ValueError("invalid monitor")
        name = item.get("name")
        if not isinstance(name, str) or not re.fullmatch(r"[\w.:-]+", name, re.ASCII):
            raise ValueError("invalid monitor name")
        if any(m["name"] == name for m in monitors):
            raise ValueError("duplicate monitor name")
        width, height = item.get("width"), item.get("height")
        if (
            not isinstance(width, int)
            or isinstance(width, bool)
            or not isinstance(height, int)
            or isinstance(height, bool)
            or not 1 <= width <= 16384
            or not 1 <= height <= 16384
        ):
            raise ValueError("invalid monitor dimensions")
        scale = item.get("scale")
        if (
            not isinstance(scale, (int, float))
            or isinstance(scale, bool)
            or not math.isfinite(scale)
            or not 0.25 <= scale <= 8
        ):
            raise ValueError("invalid monitor scale")
        transform = item.get("transform", 0)
        if type(transform) is not int or not 0 <= transform <= 7:
            raise ValueError("invalid transform")
        focused = item.get("focused", False)
        if type(focused) is not bool:
            raise ValueError("invalid focus")
        monitors.append(
            Monitor(
                name=name,
                width=width,
                height=height,
                scale=scale,
                transform=transform,
                focused=focused,
            )
        )
    if sum(m["width"] * m["height"] for m in monitors) > 100_000_000:
        raise ValueError("monitor buffers exceed the pattern memory budget")
    if not any(m["focused"] for m in monitors):
        monitors[0]["focused"] = True
    return monitors


def read_word(path: Path, default: str) -> str:
    try:
        return "".join(path.read_text().split()) or default
    except OSError:
        return default


def configure(art: Path, state: Path, runtime: Path, monitors: list[Monitor]) -> Path:
    appearance = lockplan.appearance_from_state(
        read_word(state / "theme", "dark"), read_word(state / "theme-extra", "off")
    )
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    widgets = lockplan.plan(monitors, appearance, "peaks", art_dir=art, bg_dir=runtime)
    for widget in widgets:
        if widget["type"] == "image" and not Path(widget["path"]).is_file():
            raise FileNotFoundError(widget["path"])
        generation = widget.get("gen")
        if generation and not Path(widget["path"]).is_file():
            lockplan.pattern_png(
                widget["path"],
                generation["pattern"],
                appearance,
                generation["w"],
                generation["h"],
                generation["scale"],
            )
    path = runtime / "hyprlock.conf"
    with tempfile.NamedTemporaryFile(mode="w", dir=runtime, delete=False) as file:
        temporary = Path(file.name)
        try:
            file.write(lockplan.conf_text(widgets))
            file.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art", required=True, type=Path)
    parser.add_argument("--monitors-json", type=Path, help="offline config inspection")
    args = parser.parse_args()
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]) / "mountainous-lock"
    if args.monitors_json:
        raw = args.monitors_json.read_text()
    else:
        # Never guess instance 0: a nested compositor and a live session may coexist.
        signature = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
        if not signature:
            raise ValueError("missing session instance")
        raw = subprocess.run(
            ["hyprctl", "--instance", signature, "-j", "monitors"],
            capture_output=True,
            text=True,
            check=True,
            timeout=2,
        ).stdout
    print(
        configure(
            args.art,
            state / "mountainous",
            runtime,
            monitors_from_json(json.loads(raw)),
        )
    )


if __name__ == "__main__":
    main()
