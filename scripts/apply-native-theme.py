#!/usr/bin/env python3
"""Write toolkit preferences for the choice desktop-theme has validated.

The three watched state files remain the only preference store. These files
are derived outputs. Preserve unrelated GTK/Qt keys and user GTK4 CSS.
"""

import argparse
import configparser
import json
import os
import re
import stat
import tempfile
from pathlib import Path

BEGIN = "/* >>> Mountainous native theme BEGIN */"
END = "/* <<< Mountainous native theme END */"


def atomic(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Preserve private user settings. Do not turn an existing 0600 file
    # (notably OBS preferences) into a world-readable file on replacement.
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    descriptor, name = tempfile.mkstemp(
        prefix=path.name + ".mountainous-", dir=path.parent
    )
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(content)
        temporary.chmod(mode)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def theme_link(path, target):
    # Kvantum searches this directory before its compiled-in DATADIR; it
    # does not use XDG_DATA_DIRS for installed themes. Do not erase an
    # unrelated real directory if this reserved name already exists.
    if path.exists() and not path.is_symlink():
        raise FileExistsError(f"Refusing to replace a real theme directory: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".mountainous-new")
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target, target_is_directory=True)
    temporary.replace(path)


def ini(path, section, values, defaults=None, space_around_delimiters=True):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    if path.exists():
        parser.read(path)
    if not parser.has_section(section):
        parser.add_section(section)
    for key, value in (defaults or {}).items():
        if not parser.has_option(section, key):
            parser.set(section, key, value)
    for key, value in values.items():
        parser.set(section, key, value)
    from io import StringIO

    content = StringIO()
    parser.write(content, space_around_delimiters=space_around_delimiters)
    atomic(path, content.getvalue())


def cursor_alias(name):
    """~/.icons/Mountainous-cursors inherits the current cursor theme.

    hyprland.lua exports XCURSOR_THEME=Mountainous-cursors, so a client that
    loads XCursor files itself (XWayland, a toolkit without the cursor
    shape protocol) gets the current theme even when its environment is
    older than the last switch. NixOS's XCURSOR_PATH searches ~/.icons.
    """
    atomic(
        Path.home() / ".icons/Mountainous-cursors/index.theme",
        f"[Icon Theme]\nName=Mountainous cursors\nComment=The desktop theme's cursors (desktop-theme)\nInherits={name}\n",
    )


def apply(root, theme, mode, extra, art=None):
    appearance = (
        "extra" if theme == "platinum" and mode == "dark" and extra == "on" else mode
    )
    key = f"{theme}-{appearance}"
    manifest = json.loads((root / "share/mountainous/native/manifest.json").read_text())
    palette = manifest[key]
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    # The XDG spec ignores empty and relative directory values. Never put
    # generated GTK/Qt files in the caller's working directory.
    config = config_home if config_home.is_absolute() else Path.home() / ".config"
    name, font = palette["name"], palette["font"]
    assets = root / "share/mountainous/native" / key
    names = {}
    if art is not None:
        names = json.loads(
            (art / "share/mountainous/desktop-art/manifest.json").read_text()
        )[theme]
    for entry in manifest.values():
        if entry["style"] == "kvantum":
            theme_link(
                config / "Kvantum" / entry["name"],
                root / "share/Kvantum" / entry["name"],
            )
    for version in (3, 4):
        ini(
            config / f"gtk-{version}.0/settings.ini",
            "Settings",
            {
                "gtk-theme-name": name,
                "gtk-font-name": f"{font} 12",
                "gtk-application-prefer-dark-theme": "false"
                if mode == "light"
                else "true",
            }
            | (
                {
                    "gtk-icon-theme-name": names["icons"],
                    "gtk-cursor-theme-name": names["cursors"],
                    "gtk-cursor-theme-size": str(names["cursorSize"]),
                }
                if names
                else {}
            ),
        )
    css = config / "gtk-4.0/gtk.css"
    previous = css.read_text() if css.exists() else ""
    # Never remove unmarked user CSS. The higher-priority user provider is
    # required for libadwaita; a named GTK theme alone is ignored there.
    previous = re.sub(
        re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?",
        "",
        previous,
        flags=re.DOTALL,
    )
    atomic(
        css,
        BEGIN
        + "\n"
        + f'@import url("{root}/share/themes/{name}/gtk-4.0/gtk.css");\n'
        + END
        + "\n"
        + previous.lstrip(),
    )
    for version in (5, 6):
        ini(
            config / f"qt{version}ct/qt{version}ct.conf",
            "Appearance",
            {
                "style": palette["style"],
                "custom_palette": "true",
                "color_scheme_path": str(assets / "qt-colors.conf"),
            }
            | ({"icon_theme": names["icons"]} if names else {}),
        )
        ini(
            config / f"qt{version}ct/qt{version}ct.conf",
            "Fonts",
            {
                "general": f'"{font},12,-1,5,50,0,0,0,0,0"',
            },
            defaults={"fixed": '"monospace,12,-1,5,50,0,0,0,0,0"'},
        )
    # Win98 uses QWindowsStyle, not Kvantum. Keep a valid dormant selection.
    kvantum = name if theme == "platinum" else "Mountainous-platinum-light"
    ini(config / "Kvantum/kvantum.kvconfig", "General", {"theme": kvantum})
    atomic(config / "ghostty/mountainous.conf", (assets / "ghostty.conf").read_text())
    if names:
        cursor_alias(names["cursors"])
    # Myoko's Qt Widgets app ships its own Yami stylesheet, which masks the
    # platform style. System is OBS's built-in opt-in to native widgets.
    # OBS reads this at startup; an already running OBS needs a restart.
    ini(
        config / "obs-studio/user.ini",
        "Appearance",
        {"Theme": "com.obsproject.System"},
        # libobs does not trim whitespace before '=' in option names.
        space_around_delimiters=False,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("theme", choices=("platinum", "win98"))
    parser.add_argument("mode", choices=("light", "dark"))
    parser.add_argument("extra", choices=("on", "off"))
    parser.add_argument("--art", type=Path, help="the desktop-art package")
    args = parser.parse_args()
    apply(args.root, args.theme, args.mode, args.extra, args.art)
