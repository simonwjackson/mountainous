#!/usr/bin/env python3
"""The desktop-art package: icon and cursor themes for both desktop themes.

usage: desktop-art.py <desktop-art package> <themes.json> <web-apps.json> <web-app-pwas.json>

Checks what desktop-theme names exists and is whole: every index directory,
every link, every PNG; Myoko's apps resolve in both icon themes through
their Inherits chains to a themed icon (never to hicolor), and so do the
window classes of Chromium's web apps and installed PWAs (app-icon.js asks
for the class), each to its own lettermark; every cursor
shape exists as XCursor and hyprcursor, at whole multiples of the 1x art,
and Hyprland's request at scale 1.5 (24 x 1.5 = 36) picks the 2x image.
"""

import configparser
import json
import struct
import sys
import zipfile
from pathlib import Path

from PIL import Image

art = Path(sys.argv[1])
registry = {t["id"]: t["art"] for t in json.loads(Path(sys.argv[2]).read_text())}
web_apps = json.loads(Path(sys.argv[3]).read_text())
pwas = json.loads(Path(sys.argv[4]).read_text())
# Each lettermark and the window class that asks for it (app-icon.js).
marks = {f"webapp-{k}": f"chrome-{a['host']}__-Default" for k, a in web_apps.items()}
marks.update({f"webapp-{k}": f"chrome-{a['appId']}-Default" for k, a in pwas.items()})
icons = art / "share/icons"
manifest = json.loads((art / "share/mountainous/desktop-art/manifest.json").read_text())
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def index(theme):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read(icons / theme / "index.theme")
    return parser


def lookup(theme, name, seen=()):
    """The file a freedesktop lookup finds for name, and the theme it is in."""
    if theme in seen or not (icons / theme / "index.theme").exists():
        return None
    parser = index(theme)
    for directory in parser["Icon Theme"]["Directories"].split(","):
        for ext in ("png", "svg"):
            file = icons / theme / directory / f"{name}.{ext}"
            if file.exists():
                return theme, file
    for parent in parser["Icon Theme"].get("Inherits", "").split(","):
        found = lookup(parent.strip(), name, seen + (theme,))
        if found:
            return found
    return None


for theme_id, entry in registry.items():
    check(
        manifest[theme_id] == {k: entry[k] for k in ("icons", "cursors", "cursorSize")},
        f"{theme_id}: manifest",
    )
    theme = entry["icons"]
    parser = index(theme)
    head = parser["Icon Theme"]
    check(head.get("Inherits"), f"{theme}: no Inherits")
    check((icons / theme / "icon-theme.cache").exists(), f"{theme}: no icon cache")
    for directory in head["Directories"].split(","):
        check((icons / theme / directory).is_dir(), f"{theme}: missing {directory}")
        check(
            parser.has_section(directory) and parser[directory].get("Size"),
            f"{theme}: {directory} has no Size",
        )
    for file in (icons / theme).rglob("*.png"):
        check(file.exists(), f"{file}: broken link")
        if file.exists():
            with Image.open(file) as image:
                size = (
                    int(file.parent.parent.name.split("x")[0])
                    if "x" in file.parent.parent.name
                    else int(file.parent.name)
                )
                check(
                    image.size == (size, size),
                    f"{file}: {image.size} in a {size} px directory",
                )
    # Myoko's apps (host and layers) and the web apps: a themed icon in
    # this theme or what it inherits, never the app's own hicolor icon.
    for name in [
        "com.mitchellh.ghostty",
        "chromium",
        "zed",
        "com.obsproject.Studio",
        "signal-desktop",
        "obsidian",
        "chromium-browser",
        *marks,
        *marks.values(),
        "application-x-executable",
        "folder",
        "text-x-generic",
    ]:
        found = lookup(theme, name)
        check(
            found is not None and found[0] != "hicolor", f"{theme}: {name} -> {found}"
        )

    # A class finds the same image as its lettermark, and lettermarks differ.
    for mark, window_class in marks.items():
        a, b = lookup(theme, mark), lookup(theme, window_class)
        check(
            a and b and a[1].resolve() == b[1].resolve(),
            f"{theme}: {window_class} is not {mark}",
        )
    drawn = [lookup(theme, mark) for mark in marks]
    drawn = [found[1].read_bytes() for found in drawn if found]
    check(len(set(drawn)) == len(marks), f"{theme}: two web apps share a lettermark")

# Chicago95's icon theme is copied without its SVG tracings, so lookups
# between PNG sizes scale pixel art instead of resampling a tracing, and the
# rest of the Chicago95 source stays out of the closure.
check((icons / "Chicago95/index.theme").exists(), "Chicago95 index")
check(
    not list((icons / "Chicago95").glob("*/scalable")), "Chicago95 scalable directories"
)
check(
    "scalable" not in index("Chicago95")["Icon Theme"]["Directories"],
    "Chicago95 index lists scalable",
)
check((icons / "Chicago95/icon-theme.cache").exists(), "Chicago95 icon cache")
for link in (icons / "Chicago95").rglob("*"):
    check(not link.is_symlink() or link.exists(), f"{link}: broken link")


def xcursor(path):
    data = path.read_bytes()
    magic, _, _, count = struct.unpack("<4sIII", data[:16])
    assert magic == b"Xcur", path
    images = []
    for i in range(count):
        kind, nominal, position = struct.unpack("<III", data[16 + i * 12 : 28 + i * 12])
        if kind == 0xFFFD0002:
            width, height = struct.unpack("<II", data[position + 16 : position + 24])
            images.append((nominal, width, height))
    return images


ROLES = [
    "default",
    "pointer",
    "text",
    "wait",
    "progress",
    "help",
    "crosshair",
    "not-allowed",
    "grab",
    "grabbing",
    "ew-resize",
    "ns-resize",
    "nesw-resize",
    "nwse-resize",
    "all-scroll",
    "copy",
    "alias",
    "move",
    "cell",
    "col-resize",
    "row-resize",
    "zoom-in",
    "zoom-out",
]
LEGACY = [
    "left_ptr",
    "hand2",
    "xterm",
    "watch",
    "left_ptr_watch",
    "fleur",
    "size_hor",
    "size_ver",
]
for theme_id, entry in registry.items():
    theme = icons / entry["cursors"]
    check((theme / "index.theme").exists(), f"{theme}: index.theme")
    check(
        f"name = {entry['cursors']}" in (theme / "manifest.hl").read_text(),
        f"{theme}: manifest name",
    )
    for name in ROLES + LEGACY:
        file = theme / "cursors" / name
        check(file.exists(), f"{theme}: no XCursor {name}")
        if not file.exists():
            continue
        for nominal, width, height in xcursor(file):
            # 24 is the 1x art (32 px canvas); 36 and 48 2x; 72 3x.
            factor = {24: 1, 36: 2, 48: 2, 72: 3}[nominal]
            check(
                (width, height) == (32 * factor, 32 * factor),
                f"{file}: {nominal} is {width}x{height}",
            )
    overrides = set()
    for hlc in (theme / "hyprcursors").glob("*.hlc"):
        with zipfile.ZipFile(hlc) as archive:
            meta = archive.read("meta.hl").decode()
            values = dict(
                line.split(" = ", 1)
                for line in meta.splitlines()
                if " = " in line and not line.startswith("define_")
            )
            check(values["resize_algorithm"] == "nearest", f"{hlc}: resize")
            nominal = float(values["nominal_size"])
            # Hyprland: side = round(size * scale / nominal_size).
            check(
                round(24 * 1.5 / nominal) == 64, f"{hlc}: scale 1.5 is not the 2x image"
            )
            sides = set()
            for line in meta.splitlines():
                if line.startswith("define_size"):
                    side, file = [
                        p.strip() for p in line.split("=", 1)[1].split(",")[:2]
                    ]
                    with Image.open(archive.open(file)) as image:
                        check(image.size == (int(side), int(side)), f"{hlc}: {file}")
                    sides.add(int(side))
                if line.startswith("define_override"):
                    overrides.add(line.split("=", 1)[1].strip())
            check(sides == {32, 64, 96, 128}, f"{hlc}: sides {sides}")
            overrides.add(hlc.stem)
    for name in ROLES + LEGACY:
        check(name in overrides, f"{theme}: hyprcursor has no {name}")

# Licences travel with the art.
for file in ["Chi-Nata-LICENSE", "Retrosmart-LICENSE", "Chicago95-README.md", "NOTICE"]:
    check((art / "share/licenses/desktop-art" / file).exists(), f"licence {file}")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print("DESKTOP_ART_TESTS_PASSED")
