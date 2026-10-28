#!/usr/bin/env python3
"""Icon and cursor themes for the Platinum and Windows 98 desktop themes.

Everything that starts from Apple or Microsoft art is read from a locked flake
input at build time and written only to the Nix store: Chi-Nata (CC BY-SA 4.0),
Chicago95 (GPL-3.0+/MIT) and Retrosmart (GPL-3.0). The Platinum app cubes and
the web-app lettermarks are drawn here, from code, as original art.

Cursors are 1x pixel art scaled by whole factors with nearest neighbour. At
Hyprland's scale 1.5 each art pixel is exactly 2 device pixels (hyprcursor,
size 24 requests 36: nominal_size makes that the 64 px image of a 32 px canvas).
"""

import argparse
import configparser
import json
import os
import re
import shutil
import struct
import zipfile
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

# ---------------------------------------------------------------- cursors

# cursor-shape-v1 names (what Hyprland and modern clients ask for), each
# with the legacy X11 names and hashes that mean the same shape.
ROLES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "dnd-none", "size-bdiag-unused"],
    "context-menu": [],
    "help": [
        "question_arrow",
        "whats_this",
        "left_ptr_help",
        "5c6cd98b3f3ebcb1f9c7f1c204630408",
        "d9ce0ab605698f320427677b458ad60b",
    ],
    "pointer": [
        "hand",
        "hand1",
        "hand2",
        "pointing_hand",
        "9d800788f1b08800ae810202380a0822",
        "e29285e634086352946a0e7090d73106",
    ],
    "progress": [
        "left_ptr_watch",
        "half-busy",
        "00000000000000020006000e7e9ffc3f",
        "08e8e1c95fe2fc01f976f1e063a24ccd",
        "3ecb610c1bf2410f44200f48c40d3599",
    ],
    "wait": ["watch", "clock"],
    "cell": ["plus"],
    "crosshair": ["cross", "tcross", "cross_reverse", "diamond_cross"],
    "text": ["xterm", "ibeam"],
    "vertical-text": [],
    "alias": [
        "link",
        "dnd-link",
        "3085a0e285430894940527032f8b26df",
        "640fb0e74195791501fd1ed57b41487f",
        "a2a266d0498c3104214a47bd64ab0fc8",
    ],
    "copy": [
        "dnd-copy",
        "1081e37283d90000800003c07f3ef6bf",
        "6407b0e94181790501fd1e167b474872",
        "b66166c04f8c3109214a4fbd64a50fc8",
    ],
    "move": [
        "dnd-move",
        "4498f0e0c1937ffe01fd06f973665830",
        "9081237383d90e509aa00f00170e968f",
    ],
    "no-drop": ["dnd-no-drop"],
    "not-allowed": [
        "crossed_circle",
        "circle",
        "forbidden",
        "03b6e0fcb3499374a867c041f52298f0",
    ],
    "grab": ["openhand", "fcf21c00b30f7e3f83fe0dfd12e71cff"],
    "grabbing": ["closedhand"],
    "e-resize": ["right_side"],
    "n-resize": ["top_side"],
    "ne-resize": ["top_right_corner"],
    "nw-resize": ["top_left_corner"],
    "s-resize": ["bottom_side"],
    "se-resize": ["bottom_right_corner"],
    "sw-resize": ["bottom_left_corner"],
    "w-resize": ["left_side"],
    "ew-resize": [
        "size_hor",
        "h_double_arrow",
        "sb_h_double_arrow",
        "028006030e0e7ebffc7f7070c0600140",
        "14fef782d02440884392942c11205230",
    ],
    "ns-resize": [
        "size_ver",
        "v_double_arrow",
        "sb_v_double_arrow",
        "00008160000006810000408080010102",
        "2870a09082c103050810ffdffffe0204",
    ],
    "nesw-resize": [
        "size_bdiag",
        "fd_double_arrow",
        "fcf1c3c7cd4491d801f1e1c78f100000",
    ],
    "nwse-resize": [
        "size_fdiag",
        "bd_double_arrow",
        "c7088f0f3e6c8088236ef8e1e3e70000",
    ],
    "col-resize": ["split_h"],
    "row-resize": ["split_v"],
    "all-scroll": ["fleur", "size_all"],
    "zoom-in": [],
    "zoom-out": [],
}
for role in ROLES:
    ROLES[role] = [name for name in ROLES[role] if not name.endswith("-unused")]

# Retrosmart's source file for each role (src/<name>.in and its XPMs).
RETROSMART = {
    "move": "dnd-move",
    "grab": "openhand",
    "grabbing": "closedhand",
    "e-resize": "right_side",
    "n-resize": "top_side",
    "ne-resize": "top_right_corner",
    "nw-resize": "top_left_corner",
    "s-resize": "bottom_side",
    "se-resize": "bottom_right_corner",
    "sw-resize": "bottom_left_corner",
    "w-resize": "left_side",
    "ew-resize": "size_hor",
    "ns-resize": "size_ver",
    "nesw-resize": "size_bdiag",
    "nwse-resize": "size_fdiag",
}

# One art pixel is this many image pixels at each XCursor nominal size.
XCURSOR_SIZES = {24: 1, 36: 2, 48: 2, 72: 3}
CANVAS = 32
# Hyprland asks hyprcursor for size * scale (24 * 1.5 = 36) and draws the
# image 1:1 on device pixels. side = round(request / nominal): 36 -> 64,
# 54 -> 96, 72 -> 128, so scales 1.5, 2.25 and 3 are exact whole factors.
HYPR_NOMINAL = 36 / 64
HYPR_FACTORS = (1, 2, 3, 4)


def xpm(path, outline, fill):
    """A Retrosmart XPM: coral is the outline, cyan the fill (its makefile)."""
    strings = re.findall(r'"([^"]*)"', path.read_text())
    width, height, count, cpp = map(int, strings[0].split()[:4])
    colours = {}
    for line in strings[1 : 1 + count]:
        rest = line[cpp:].split()
        value = rest[rest.index("c") + 1].lower()
        value = {"#00ffff": "cyan", "#ff7f50": "coral"}.get(value, value)
        if value == "none":
            colours[line[:cpp]] = None
        elif value == "coral":
            colours[line[:cpp]] = outline
        elif value == "cyan":
            colours[line[:cpp]] = fill
        else:
            colours[line[:cpp]] = ImageColor.getrgb(value)[:3] + (255,)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y, row in enumerate(strings[1 + count : 1 + count + height]):
        for x in range(width):
            colour = colours[row[x * cpp : (x + 1) * cpp]]
            if colour:
                image.putpixel((x, y), colour)
    return image


def read_xcursor(path):
    data = path.read_bytes()
    _, _, _, count = struct.unpack("<4sIII", data[:16])
    frames = []
    for index in range(count):
        kind, _, position = struct.unpack(
            "<III", data[16 + index * 12 : 28 + index * 12]
        )
        if kind != 0xFFFD0002:
            continue
        _, _, size, _, width, height, xhot, yhot, delay = struct.unpack(
            "<IIIIIIIII", data[position : position + 36]
        )
        pixels = data[position + 36 : position + 36 + width * height * 4]
        image = Image.frombytes("RGBA", (width, height), pixels, "raw", "BGRA")
        frames.append((size, image, (xhot, yhot), delay))
    # The smallest nominal size is the 1x art.
    smallest = min(frame[0] for frame in frames)
    return [frame[1:] for frame in frames if frame[0] == smallest]


def write_xcursor(path, entries):
    """entries: (nominal, image, (xhot, yhot), delay), premultiplied ARGB."""
    chunks = []
    for nominal, image, hot, delay in entries:
        width, height = image.size
        pixels = bytearray()
        for r, g, b, a in image.getdata():
            pixels += struct.pack("<BBBB", b * a // 255, g * a // 255, r * a // 255, a)
        header = struct.pack(
            "<IIIIIIIII",
            36,
            0xFFFD0002,
            nominal,
            1,
            width,
            height,
            hot[0],
            hot[1],
            delay,
        )
        chunks.append((nominal, header + bytes(pixels)))
    position = 16 + 12 * len(chunks)
    toc, body = b"", b""
    for nominal, chunk in chunks:
        toc += struct.pack("<III", 0xFFFD0002, nominal, position + len(body))
        body += chunk
    path.write_bytes(
        struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(chunks)) + toc + body
    )


def scale(image, factor):
    return image.resize((image.width * factor, image.height * factor), Image.NEAREST)


def on_canvas(image, offset=(0, 0)):
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(image, offset, image)
    return canvas


def retrosmart_shapes(root):
    """Platinum: Retrosmart's bitmap set, black fill with a white outline,
    the Mac OS arrow. Monochrome (not the colour variant), as Mac OS 8."""
    source = root / "src"
    shapes = {}
    for role in ROLES:
        name = RETROSMART.get(role, role)
        spec = source / f"{name}.in"
        if not spec.exists():
            raise SystemExit(f"retrosmart: no {spec}")
        frames = []
        for line in spec.read_text().splitlines():
            parts = line.split()
            if len(parts) < 4 or parts[0] != "32":
                continue
            image = xpm(
                source / "bitmap.base" / parts[3].replace(".png", ".xpm"),
                (255, 255, 255, 255),
                (0, 0, 0, 255),
            )
            frames.append(
                (
                    on_canvas(image),
                    (int(parts[1]), int(parts[2])),
                    int(parts[4]) if len(parts) > 4 else 0,
                )
            )
        # Retrosmart lists its first wait frame twice; keep the loop even.
        shapes[role] = frames
    return shapes


# Chicago95 draws grab and grabbing as its copy arrow and closedhand as its
# shortcut arrow. Windows 98 had no hand cursors; it dragged with Move.
CHICAGO = {"grab": "move", "grabbing": "move"}


def chicago_shapes(root):
    """Win98: Chicago95's standard (static) set, its 32 px 1x images."""
    source = root / "Cursors/Chicago95_Standard_Cursors/cursors"
    shapes = {}
    for role, aliases in ROLES.items():
        for name in [CHICAGO.get(role, role)] + aliases:
            if (source / name).exists():
                shapes[role] = [
                    (on_canvas(image), hot, delay)
                    for image, hot, delay in read_xcursor(source / name)
                ]
                break
        else:
            raise SystemExit(f"chicago95: no cursor for {role}")
    return shapes


def cursor_theme(out, name, label, shapes):
    theme = out / "share/icons" / name
    cursors = theme / "cursors"
    cursors.mkdir(parents=True)
    (theme / "index.theme").write_text(
        f"[Icon Theme]\nName={label}\nComment={label} cursors\n"
    )
    (theme / "cursor.theme").write_text(f"[Icon Theme]\nInherits={name}\n")
    hypr = out / "build" / name
    for role, frames in shapes.items():
        entries = []
        for nominal, factor in XCURSOR_SIZES.items():
            for image, hot, delay in frames:
                entries.append(
                    (
                        nominal,
                        scale(image, factor),
                        (hot[0] * factor, hot[1] * factor),
                        delay,
                    )
                )
        write_xcursor(cursors / role, entries)
        for alias in ROLES[role]:
            if not (cursors / alias).exists():
                (cursors / alias).symlink_to(role)
        # hyprcursor: one directory per shape, packed below.
        shape = hypr / role
        shape.mkdir(parents=True)
        hot = frames[0][1]
        lines = [
            "resize_algorithm = nearest",
            f"nominal_size = {HYPR_NOMINAL}",
            f"hotspot_x = {hot[0] / CANVAS}",
            f"hotspot_y = {hot[1] / CANVAS}",
        ]
        lines += [f"define_override = {alias}" for alias in ROLES[role]]
        for factor in HYPR_FACTORS:
            for index, (image, _, delay) in enumerate(frames):
                file = f"{role}-{CANVAS * factor}-{index}.png"
                scale(image, factor).save(shape / file)
                lines.append(
                    f"define_size = {CANVAS * factor}, {file}"
                    + (f", {delay}" if len(frames) > 1 else "")
                )
        (shape / "meta.hl").write_text("\n".join(lines) + "\n")
    # Pack like hyprcursor-util --create: one zip per shape, stored entries
    # in a fixed order and timestamp, so the output is reproducible.
    (theme / "manifest.hl").write_text(
        f"name = {name}\ndescription = {label} cursors\nversion = 1\ncursors_directory = hyprcursors\n"
    )
    (theme / "hyprcursors").mkdir()
    for shape in sorted(hypr.iterdir()):
        with zipfile.ZipFile(
            theme / "hyprcursors" / f"{shape.name}.hlc", "w", zipfile.ZIP_STORED
        ) as archive:
            for file in sorted(shape.iterdir()):
                info = zipfile.ZipInfo(file.name, date_time=(1980, 1, 1, 0, 0, 0))
                archive.writestr(info, file.read_bytes())


# ------------------------------------------------------------------ icons

PLATINUM_CONTEXTS = {
    "actions": "Actions",
    "apps": "Applications",
    "devices": "Devices",
    "emblems": "Emblems",
    "mimes": "MimeTypes",
    "places": "Places",
}
# Chi-Nata names that are not freedesktop names, or freedesktop names it
# lacks that one of its icons fits.
CHI_NATA_ALIASES = {
    "places": {
        "inode-directory": "folder",
        "folder-documents": "user-writings",
        "folder-download": "user-download",
        "folder-remote": "network-server",
    },
    "mimes": {
        "application-octet-stream": "file-x-generic",
        "unknown": "file-x-generic",
        "application-x-archive": "package-x-generic",
        "application-x-zip": "package-x-generic",
    },
    "apps": {
        "internet-mail": "Generic.Mail",
        "mail-client": "Generic.Mail",
        "office-calendar": "generic.calendar",
    },
}

# Myoko's apps (modules/hosts/myoko.nix and its layers) by every icon name
# their desktop entries, window classes and packages use.
APP_NAMES = {
    "terminal": ["com.mitchellh.ghostty", "ghostty", "utilities-terminal", "terminal"],
    "browser": [
        "chromium",
        "chromium-browser",
        "google-chrome",
        "web-browser",
        "internet-web-browser",
    ],
    "editor": [
        "zed",
        "dev.zed.Zed",
        "dev.zed.Zed-Preview",
        "zed-editor",
        "accessories-text-editor",
        "text-editor",
    ],
    "chat": ["signal-desktop", "signal", "org.signal.Signal", "Signal"],
    "video": ["com.obsproject.Studio", "obs", "obs-studio"],
    "notes": ["obsidian", "md.obsidian.Obsidian"],
}
# The Chicago95 icon each Win98 role borrows when Chicago95 has none of the
# names above (it has chromium, utilities-terminal, accessories-text-editor).
CHICAGO_ROLES = {
    "terminal": "utilities-terminal",
    "browser": "chromium",
    "editor": "accessories-text-editor",
    "chat": "empathy",
    "video": "kazam",
    "notes": "tomboy",
}

BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)


def rgb(value, alpha=255):
    return ImageColor.getrgb(value)[:3] + (alpha,)


def shade(colour, amount):
    """Toward white (> 0) or black (< 0)."""
    r, g, b = colour[:3]
    if amount > 0:
        return (
            int(r + (255 - r) * amount),
            int(g + (255 - g) * amount),
            int(b + (255 - b) * amount),
            255,
        )
    return (int(r * (1 + amount)), int(g * (1 + amount)), int(b * (1 + amount)), 255)


def cube(face):
    """A Mac OS 9 style cube, 32 x 32: an upright front face (x 3-18,
    y 12-27) for the emblem, a top and a right face in oblique projection,
    a 1 px black outline and a soft drop shadow, after Chi-Nata's style
    guide (drawn here, not copied)."""
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon(
        [(19, 28), (26, 21), (30, 21), (30, 24), (24, 30), (19, 30)], fill=(0, 0, 0, 80)
    )
    draw.polygon(
        [(3, 12), (10, 5), (25, 5), (18, 12)], fill=shade(face, 0.45), outline=BLACK
    )
    draw.polygon(
        [(18, 12), (25, 5), (25, 20), (18, 27)], fill=shade(face, -0.35), outline=BLACK
    )
    draw.rectangle([3, 12, 18, 27], fill=face, outline=BLACK)
    # A highlight on the front face's top and left edge.
    draw.line([(4, 13), (17, 13)], fill=shade(face, 0.6))
    draw.line([(4, 13), (4, 26)], fill=shade(face, 0.6))
    return image, draw


def platinum_app(role):
    if role == "terminal":
        image, draw = cube(rgb("#c8c8c8"))
        draw.rectangle([5, 14, 16, 25], fill=BLACK)
        green = rgb("#33ff66")
        for x, y in [(6, 16), (7, 17), (8, 18), (7, 19), (6, 20)]:
            draw.point((x, y), fill=green)
        draw.line([(10, 21), (13, 21)], fill=green)
    elif role == "browser":
        image, draw = cube(rgb("#dcdcdc"))
        draw.ellipse([5, 14, 16, 25], fill=rgb("#2f5fd0"), outline=BLACK)
        land = rgb("#2fa84f")
        draw.polygon([(7, 17), (10, 16), (11, 18), (9, 20), (8, 23)], fill=land)
        draw.polygon([(12, 20), (14, 19), (15, 21), (13, 23)], fill=land)
        draw.point((9, 15), fill=rgb("#9fc0ff"))
    elif role == "editor":
        image, draw = cube(rgb("#f4f4f4"))
        for y in (15, 18, 21, 24):
            draw.line([(5, y), (12, y)], fill=rgb("#7a7a7a"))
        draw.line([(9, 25), (16, 18)], fill=BLACK, width=3)
        draw.line([(10, 24), (15, 19)], fill=rgb("#ffcc33"))
        draw.point((8, 26), fill=BLACK)
        draw.point((16, 17), fill=rgb("#ff8fa3"))
    elif role == "chat":
        image, draw = cube(rgb("#3a76f0"))
        draw.rounded_rectangle([5, 14, 16, 22], radius=2, fill=WHITE, outline=BLACK)
        draw.polygon([(7, 22), (7, 25), (10, 22)], fill=WHITE, outline=BLACK)
        draw.line([(8, 22), (9, 22)], fill=WHITE)
        for x in (8, 10, 12):
            draw.point((x, 18), fill=BLACK)
    elif role == "video":
        image, draw = cube(rgb("#5a5a5a"))
        draw.ellipse([5, 14, 16, 25], fill=rgb("#202020"), outline=BLACK)
        draw.ellipse([8, 17, 13, 22], fill=rgb("#406080"))
        draw.point((9, 18), fill=WHITE)
        draw.rectangle([14, 14, 16, 16], fill=rgb("#ff2020"), outline=BLACK)
    elif role == "notes":
        image, draw = cube(rgb("#e8e0f4"))
        draw.polygon(
            [(10, 14), (15, 19), (10, 26), (6, 19)], fill=rgb("#7a4fc0"), outline=BLACK
        )
        draw.polygon([(10, 15), (13, 19), (10, 19)], fill=rgb("#b496f0"))
        draw.polygon([(10, 19), (13, 19), (10, 24)], fill=rgb("#4a2a80"))
    elif role == "application":
        # The generic application: a platinum cube with a plain diamond.
        image, draw = cube(rgb("#c8c8c8"))
        draw.polygon(
            [(10, 14), (16, 19), (10, 25), (5, 19)], fill=rgb("#9a9aff"), outline=BLACK
        )
        draw.line([(7, 19), (10, 16)], fill=WHITE)
    else:
        raise SystemExit(role)
    return image


def lettermark_platinum(letter, tint, font):
    image, draw = cube(rgb(tint))
    font = ImageFont.truetype(font, 12)
    draw.fontmode = "1"
    box = draw.textbbox((0, 0), letter, font=font)
    width, height = box[2] - box[0], box[3] - box[1]
    draw.text(
        (11 - width // 2 - box[0], 20 - height // 2 - box[1]),
        letter,
        font=font,
        fill=WHITE,
    )
    return image


def lettermark_win98(letter, tint, font, size):
    """A raised Win98 tile with the site's letter: white and light grey on
    the top left, dark grey and black on the bottom right."""
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    inset = 1 if size == 16 else 2
    lo, hi = inset, size - 1 - inset
    draw.rectangle([lo, lo, hi, hi], fill=rgb(tint))
    draw.line([(lo, lo), (hi - 1, lo)], fill=WHITE)
    draw.line([(lo, lo), (lo, hi - 1)], fill=WHITE)
    draw.line([(lo, hi), (hi, hi)], fill=BLACK)
    draw.line([(hi, lo), (hi, hi)], fill=BLACK)
    draw.line([(lo + 1, hi - 1), (hi - 1, hi - 1)], fill=rgb("#808080"))
    draw.line([(hi - 1, lo + 1), (hi - 1, hi - 1)], fill=rgb("#808080"))
    # W95FA Grid is drawn on its 12 px grid, struck twice for bold (as
    # Win98Text does), then doubled for the 32 px icon: whole pixels only.
    glyph = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pen = ImageDraw.Draw(glyph)
    pen.fontmode = "1"
    font = ImageFont.truetype(font, 12)
    box = pen.textbbox((0, 0), letter, font=font)
    width, height = box[2] - box[0] + 1, box[3] - box[1]
    for dx in (0, 1):
        pen.text(
            (8 - width // 2 - box[0] + dx, 8 - height // 2 - box[1]),
            letter,
            font=font,
            fill=WHITE,
        )
    glyph = scale(glyph, size // 16)
    image.paste(glyph, (0, 0), glyph)
    return image


def fits(file, size):
    """A real PNG of the directory's size (upstream has a few that are not:
    macOS alias records, a 32 px file in 256x256, a 47 x 48 one)."""
    if file.read_bytes()[:4] != b"\x89PNG":
        return False
    with Image.open(file) as image:
        return image.size == (size, size)


def png(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def link(target, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() and not path.is_symlink():
        path.symlink_to(target)


def platinum_icons(out, name, chi_nata, web_apps, font):
    theme = out / "share/icons" / name
    directories = []
    for size in ("32x32", "256x256"):
        for context in PLATINUM_CONTEXTS:
            source = chi_nata / "icons" / size / context
            if not source.is_dir():
                continue
            for file in sorted(source.glob("*.png")):
                if fits(file, int(size.split("x")[0])):
                    (theme / size / context).mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(file, theme / size / context / file.name)
            for alias, original in CHI_NATA_ALIASES.get(context, {}).items():
                if (theme / size / context / f"{original}.png").exists():
                    link(f"{original}.png", theme / size / context / f"{alias}.png")
    apps = theme / "32x32/apps"
    for role, names in APP_NAMES.items():
        png(platinum_app(role), apps / f"mountainous-{role}.png")
        for alias in names:
            link(f"mountainous-{role}.png", apps / f"{alias}.png")
    png(platinum_app("application"), theme / "32x32/mimes/application-x-executable.png")
    link("../mimes/application-x-executable.png", apps / "application-x-executable.png")
    for app_id, app in sorted(web_apps.items()):
        png(
            lettermark_platinum(app["letter"], app["tint"], font),
            apps / f"webapp-{app_id}.png",
        )
    for size in ("32x32", "256x256"):
        for context in PLATINUM_CONTEXTS:
            if (theme / size / context).is_dir():
                directories.append(
                    (
                        f"{size}/{context}",
                        int(size.split("x")[0]),
                        PLATINUM_CONTEXTS[context],
                    )
                )
    index_theme(
        theme,
        "Mountainous Platinum",
        "Chi-Nata (DawnVespero, CC BY-SA 4.0) and Mountainous pixel icons",
        "Adwaita,hicolor",
        directories,
    )


def chicago95(out, chicago):
    """Chicago95's icon theme, copied without its scalable and symbolic
    directories: Qt and GTK would draw the pixel art's SVG tracings,
    resampled, for sizes between the PNGs. The rest of the Chicago95
    source (sounds, Plymouth, KDE, screenshots) stays out of the closure."""
    source = chicago / "Icons/Chicago95"
    theme = out / "share/icons/Chicago95"
    shutil.copytree(
        source,
        theme,
        symlinks=True,
        ignore=lambda directory, names: [
            n for n in names if n in ("scalable", "symbolic", "icon-theme.cache")
        ],
    )
    for path in [theme, *theme.rglob("*")]:
        if path.is_symlink():
            if not path.exists():
                path.unlink()
        else:
            path.chmod(0o755 if path.is_dir() else 0o644)
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read(source / "index.theme")
    kept = [
        d
        for d in parser["Icon Theme"]["Directories"].split(",")
        if (theme / d).is_dir()
    ]
    lines = []
    for line in (source / "index.theme").read_text().splitlines():
        if line.startswith("Directories="):
            line = "Directories=" + ",".join(kept)
        lines.append(line)
    (theme / "index.theme").write_text("\n".join(lines) + "\n")
    return theme


def win98_icons(out, name, chicago, web_apps, font):
    base = chicago95(out, chicago)
    theme = out / "share/icons" / name
    directories = set()
    for role, names in APP_NAMES.items():
        source = CHICAGO_ROLES[role]
        for size in (16, 22, 24, 32, 48):
            file = base / "apps" / str(size) / f"{source}.png"
            if not file.exists() or not fits(file, size):
                continue
            for alias in names:
                # Chicago95's own name wins: Inherits finds it there.
                if (
                    alias == source
                    or (base / "apps" / str(size) / f"{alias}.png").exists()
                ):
                    continue
                link(
                    f"../../../Chicago95/apps/{size}/{source}.png",
                    theme / "apps" / str(size) / f"{alias}.png",
                )
                directories.add((f"apps/{size}", size, "Applications"))
    for app_id, app in sorted(web_apps.items()):
        for size in (16, 32):
            png(
                lettermark_win98(app["letter"], app["tint"], font, size),
                theme / "apps" / str(size) / f"webapp-{app_id}.png",
            )
            directories.add((f"apps/{size}", size, "Applications"))
    index_theme(
        theme,
        "Mountainous Windows 98",
        "Chicago95 (grassmunk, GPL-3.0+/MIT) with Myoko's apps",
        "Chicago95,hicolor",
        sorted(directories),
    )


def index_theme(theme, label, comment, inherits, directories):
    lines = [
        "[Icon Theme]",
        f"Name={label}",
        f"Comment={comment}",
        f"Inherits={inherits}",
        "Example=folder",
        "Directories=" + ",".join(d[0] for d in directories),
        "",
    ]
    for directory, size, context in directories:
        lines += [
            f"[{directory}]",
            f"Size={size}",
            f"Context={context}",
            "Type=Fixed",
            "",
        ]
    (theme / "index.theme").write_text("\n".join(lines))


# ------------------------------------------------------------------- main


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--web-apps", type=Path, required=True)
    parser.add_argument("--chicago", type=Path, required=True)
    parser.add_argument("--chi-nata", type=Path, required=True)
    parser.add_argument("--retrosmart", type=Path, required=True)
    parser.add_argument("--platinum-font", type=Path, required=True)
    parser.add_argument("--win98-font", type=Path, required=True)
    args = parser.parse_args()

    registry = {
        theme["id"]: theme["art"] for theme in json.loads(args.registry.read_text())
    }
    web_apps = json.loads(args.web_apps.read_text())
    out = args.out
    platinum, win98 = registry["platinum"], registry["win98"]
    platinum_icons(out, platinum["icons"], args.chi_nata, web_apps, args.platinum_font)
    win98_icons(out, win98["icons"], args.chicago, web_apps, args.win98_font)
    cursor_theme(
        out,
        platinum["cursors"],
        "Mountainous Platinum",
        retrosmart_shapes(args.retrosmart),
    )
    cursor_theme(
        out, win98["cursors"], "Mountainous Windows 98", chicago_shapes(args.chicago)
    )
    shutil.rmtree(out / "build")

    # What desktop-theme applies, read by apply-native-theme.py and checks.
    manifest = {
        theme: {
            "icons": art["icons"],
            "cursors": art["cursors"],
            "cursorSize": art["cursorSize"],
        }
        for theme, art in registry.items()
    }
    data = out / "share/mountainous/desktop-art"
    data.mkdir(parents=True)
    (data / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )

    licences = out / "share/licenses/desktop-art"
    licences.mkdir(parents=True)
    shutil.copy(args.chi_nata / "LICENSE", licences / "Chi-Nata-LICENSE")
    shutil.copy(args.retrosmart / "LICENSE", licences / "Retrosmart-LICENSE")
    shutil.copy(args.chicago / "README.md", licences / "Chicago95-README.md")
    (licences / "NOTICE").write_text(
        "Mountainous desktop art, generated at build time.\n\n"
        "Mountainous-platinum icons: Chi-Nata by DawnVespero, CC BY-SA 4.0\n"
        "(https://github.com/DawnVespero/Chi-Nata), linked unchanged; the app\n"
        "cubes and web-app lettermarks are drawn by scripts/generate-desktop-art.py.\n"
        "Mountainous-platinum-cursors: Retrosmart X11 cursors by Manuel Domínguez\n"
        "López, GPL-3.0, black variant, scaled by whole factors.\n"
        "Mountainous-win98 icons and cursors: Chicago95 by grassmunk\n"
        "(GPL-3.0+/MIT per its README); cursors scaled by whole factors.\n"
    )


if __name__ == "__main__":
    os.umask(0o022)
    main()
