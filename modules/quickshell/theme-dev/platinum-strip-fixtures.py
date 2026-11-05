import sys
from pathlib import Path
from PIL import Image, ImageDraw
data = Path(sys.argv[1])
(data / "applications").mkdir(parents=True, exist_ok=True)
# Original synthetic site icons (no third-party art).
jelly = Image.new("RGBA", (192, 192)); d = ImageDraw.Draw(jelly)
d.rounded_rectangle((8, 8, 183, 183), radius=36, fill="#5a2ca0"); d.polygon([(70, 50), (150, 96), (70, 142)], fill="#ffffff")
jelly.save(data / "pwa-jellyfin.png")
teams = Image.new("RGBA", (192, 192)); d = ImageDraw.Draw(teams)
d.ellipse((10, 10, 181, 181), fill="#2f7d32"); d.rectangle((60, 60, 131, 80), fill="#ffffff"); d.rectangle((86, 60, 105, 140), fill="#ffffff")
teams.save(data / "pwa-teams.png")
# An app whose own icon is only in hicolor at 128 px (no Platinum 32 px art).
sync = Image.new("RGBA", (128, 128)); d = ImageDraw.Draw(sync)
d.ellipse((6, 6, 121, 121), fill="#1e88e5"); d.ellipse((34, 34, 93, 93), fill="#ffffff"); d.ellipse((48, 48, 79, 79), fill="#1e88e5")
(data / "icons/hicolor/128x128/apps").mkdir(parents=True, exist_ok=True)
sync.save(data / "icons/hicolor/128x128/apps/syncthing.png")
def entry(name, fields):
    (data / "applications" / f"{name}.desktop").write_text("[Desktop Entry]\nType=Application\nExec=true\n" + "".join(f"{k}={v}\n" for k, v in fields.items()))
entry("chromium-browser", {"Name": "Chromium", "Icon": "chromium", "StartupWMClass": "chromium-browser"})
entry("syncthing", {"Name": "Syncthing", "Icon": "syncthing", "StartupWMClass": "syncthing"})
for app_id, name, png in (("lneafpomhdmfgkblnkjeglpppndalpik", "Jellyfin", "pwa-jellyfin.png"), ("ompifgpmddkgmclendfeacglnodjjndh", "Microsoft Teams", "pwa-teams.png")):
    entry(f"chrome-{app_id}-Default", {"Name": name, "Icon": str(data / png), "StartupWMClass": f"crx_{app_id}"})
