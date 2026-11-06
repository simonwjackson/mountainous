#!/usr/bin/env python3
"""Private HTTP target list and original PNGs for the real shell icon check."""

import functools
import http.server
import json
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

work, mode = Path(sys.argv[1]), sys.argv[2]
data = work / "data"
apps = data / "applications"
apps.mkdir(parents=True, exist_ok=True)
web = work / "web"
(web / "json").mkdir(parents=True, exist_ok=True)
ids = ["lneafpomhdmfgkblnkjeglpppndalpik", "ompifgpmddkgmclendfeacglnodjjndh"]


def entry(name, label, icon, wmclass):
    (apps / f"{name}.desktop").write_text(
        f"[Desktop Entry]\nType=Application\nExec=true\nName={label}\nIcon={icon}\nStartupWMClass={wmclass}\n"
    )


entry("chromium-browser", "Chromium", "chromium", "chromium-browser")
entry("webapp-reddit", "Reddit", "webapp-reddit", "chrome-www.reddit.com__-Default")
for app_id, label in zip(ids, ["Jellyfin", "Microsoft Teams"]):
    name = f"chrome-{app_id}-Default"
    entry(
        name,
        label,
        str(web / f"{label}.png") if mode == "site" else name,
        f"crx_{app_id}",
    )

# Different colours AND asymmetric shapes: a swapped icon must fail, even
# after the Platinum renderer maps both sources into its system palette.
for i, (name, colour) in enumerate(
    [
        ("browser", "#ff00ff"),
        ("tab", "#00ffff"),
        ("reddit", "#ff8800"),
        ("Jellyfin", "#8800ff"),
        ("Microsoft Teams", "#008800"),
        ("wrong-pwa-page", "#ffff00"),
    ]
):
    image = Image.new("RGBA", (32, 32), colour)
    draw = ImageDraw.Draw(image)
    draw.rectangle((3 + i, 4, 7 + i, 25 - i), fill="white")
    draw.rectangle((8 + i, 21 - i, 25, 25 - i), fill="white")
    image.save(web / f"{name}.png")

# A fallthrough to upstream Chromium must remain visible to the check.
icons = data / "icons/hicolor/32x32/apps"
icons.mkdir(parents=True, exist_ok=True)
logo = Image.new("RGBA", (32, 32))
draw = ImageDraw.Draw(logo)
for box, colour in zip(
    [(0, 0, 15, 15), (16, 0, 31, 15), (0, 16, 15, 31), (16, 16, 31, 31)],
    ["#db4437", "#0f9d58", "#f4b400", "#1a73e8"],
):
    draw.rectangle(box, fill=colour)
logo.save(icons / "chromium.png")

# Exercise the host's build-time path, including the competing hicolor logo.
helper = Path(os.environ["MOUNTAINOUS_PLATINUM_ICON"])
subprocess.run(
    [
        str(helper.with_name("mountainous-platinum-app-tokens")),
        str(data),
        str(data / "icons/Mountainous-platinum-apps"),
        "--covered",
        str(Path(os.environ["DESKTOP_ART"]) / "share/icons/Mountainous-platinum"),
    ],
    check=True,
)

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(web))
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
origin = f"http://127.0.0.1:{server.server_port}"
# Exercise CdpBrowser's real HTTP selection, not a replacement QML singleton.
# Both endpoints see this catalogue; endpoint filtering keeps matches unique.
targets = []
if mode == "site":
    for i, (title, host, icon) in enumerate(
        [
            ("Memphis - Wikipedia", "en.wikipedia.org", "browser"),
            ("New Tab", "example.net", "tab"),
            ("Reddit", "www.reddit.com", "reddit"),
            # No title match for Jellyfin; Teams has a conflicting page icon.
            # Both must still use the installed desktop entry's PNG.
            ("A different Jellyfin title", "jellyfin.example", "wrong-pwa-page"),
            ("Microsoft Teams", "teams.example", "wrong-pwa-page"),
        ]
    ):
        targets.append(
            {
                "id": str(i),
                "type": "page",
                "title": title,
                "url": f"https://{host}/",
                "faviconUrl": f"{origin}/{icon}.png",
            }
        )
(web / "json/list").write_text(json.dumps(targets))
for profile in [work / ".local/share/mountainous/browser", work / "config/chromium"]:
    profile.mkdir(parents=True, exist_ok=True)
    (profile / "DevToolsActivePort").write_text(str(server.server_port) + "\n")

# Generate independent, named references with the packaged renderer. The
# shell must still invoke the helper itself: its cache is a different folder.
refs = work / "references"
refs.mkdir()
g = json.loads((work / "strip.json").read_text())["tile"]
if mode == "site":
    env = dict(os.environ, XDG_CACHE_HOME=str(work / "reference-cache"))
    for name in ["browser", "tab", "reddit", "Jellyfin", "Microsoft Teams"]:
        token = subprocess.check_output(
            [
                os.environ["MOUNTAINOUS_PLATINUM_ICON"],
                str(web / f"{name}.png"),
                str(g["canvas"]["size"]),
                "platinum-light",
                "--extent",
                str(g["extent"]),
            ],
            env=env,
            text=True,
        ).strip()
        with Image.open(token) as image:
            image.save(refs / f"{name}.png")
(work / "ready").touch()
server.serve_forever()
