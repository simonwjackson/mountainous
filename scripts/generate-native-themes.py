#!/usr/bin/env python3
"""Generate the five native appearances from pinned artwork and one palette source.

No artwork is checked in. Generated derivatives retain the upstream licences.
The native ramps match PlatinumTokens and Win98Tokens; test-native-palettes.py
checks those seams. GTK3, GTK4, Kvantum, Qt palettes and Ghostty share these ramps.
"""

import argparse
import base64
import io
import json
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

PALETTES = {
    "platinum": {
        "font": "ChicagoFLF",
        "light": {
            "face": "#dddddd",
            "text": "#000000",
            "base": "#ffffff",
            "hi": "#ffffff",
            "shade": "#999999",
            "edge": "#000000",
            "selected": "#333399",
            "muted": "#8a8a8a",
        },
        "dark": {
            "face": "#3a3a3a",
            "text": "#ececec",
            "base": "#242424",
            "hi": "#565656",
            "shade": "#1e1e1e",
            "edge": "#000000",
            "selected": "#5858d0",
            "muted": "#767676",
        },
        "extra": {
            "face": "#000000",
            "text": "#e6e6e6",
            "base": "#000000",
            "hi": "#3a3a3a",
            "shade": "#262626",
            "edge": "#5c5c5c",
            "selected": "#5858d0",
            "muted": "#808080",
        },
    },
    "win98": {
        "font": "W95FA Grid",
        "light": {
            "face": "#c0c0c0",
            "text": "#000000",
            "base": "#ffffff",
            "hi": "#ffffff",
            "shade": "#808080",
            "edge": "#000000",
            "selected": "#000080",
            "muted": "#808080",
            "caption": "#000080",
            "caption_text": "#ffffff",
            "inactive_caption": "#808080",
            "inactive_text": "#c0c0c0",
            "tip": "#ffffe1",
            "tip_text": "#000000",
        },
        "dark": {
            "face": "#3c3c3c",
            "text": "#ececec",
            "base": "#1d1d1d",
            "hi": "#7a7a7a",
            "shade": "#222222",
            "edge": "#000000",
            "selected": "#41608a",
            "muted": "#8e8e8e",
            "caption": "#26364f",
            "caption_text": "#ffffff",
            "inactive_caption": "#2a2a2a",
            "inactive_text": "#9a9a9a",
            "tip": "#3a3a2a",
            "tip_text": "#f0f0d8",
        },
    },
}
# Keep the desktop's existing readable ANSI ramps; the historical UI font,
# chrome and surface change, not applications' terminal colour meanings.
ANSI = {
    "light": [
        "1a1a1a",
        "b3261e",
        "2e7d32",
        "8a6d00",
        "1f5fa8",
        "8e24aa",
        "00695c",
        "3a3a3a",
        "606060",
        "c62828",
        "388e3c",
        "a07800",
        "2962a8",
        "9c27b0",
        "00897b",
        "1a1a1a",
    ],
    "dark": [
        "141414",
        "e06c75",
        "98c379",
        "e5c07b",
        "61afef",
        "c678dd",
        "56b6c2",
        "e0e0e0",
        "606060",
        "e06c75",
        "98c379",
        "e5c07b",
        "61afef",
        "c678dd",
        "56b6c2",
        "ffffff",
    ],
}

HEX = re.compile(r"#[0-9a-fA-F]{8}\b|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b")


def rgb(value):
    value = value.lstrip("#")
    if len(value) == 3:
        value = "".join(c * 2 for c in value)
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def recolor(value, palette, theme, appearance, foreground=False, background=False):
    channels = rgb(value)
    lo, hi = min(channels), max(channels)
    if hi - lo < 20:
        level = sum(channels) / 3
        if foreground:
            if level < 100:
                return palette["text"]
            if level > 240:
                return "#ffffff"  # selected text, not a bevel highlight
            if appearance != "light":
                return palette["muted"]
        if background and level > 245:
            return palette["base"]
        if appearance == "light":
            return value
        if level < 35:
            return palette["edge"]
        if level < 175:
            return palette["shade"]
        if level < 240:
            return palette["face"]
        return palette["hi"]
    if value.lower() in ("#9999ff", "#333399", "#000080"):
        return palette["selected"]
    return value


def raster(image, palette, theme, appearance, glyph=False, reference=None):
    """Keep alpha and geometry; state-pair differences identify dark indicator ink."""
    if appearance == "light":
        return image.copy()
    original = list(image.getdata())
    baseline = (
        list(reference.getdata())
        if reference and reference.size == image.size
        else original
    )
    result = image.copy()
    pixels = []
    for pixel, before in zip(original, baseline):
        indicator = (
            pixel[3] > 0
            and max(pixel[:3]) < 100
            and (before[3] == 0 or min(before[:3]) >= 100)
        )
        color = recolor(
            "#{:02x}{:02x}{:02x}".format(*pixel[:3]),
            palette,
            theme,
            appearance,
            foreground=glyph or indicator,
        )
        pixels.append((*rgb(color), pixel[3]))
    result.putdata(pixels)
    return result


def svg_theme(text, palette, theme, appearance, glyph=False):
    """Recolour vector paint AND the upstream Kvantum SVG's embedded PNGs."""
    for prefix, namespace in re.findall(r'xmlns(?::([\w-]+))?="([^"]+)"', text):
        ET.register_namespace(prefix or "", namespace)
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(text, parser=parser)
    image_tag = "{http://www.w3.org/2000/svg}image"
    href = "{http://www.w3.org/1999/xlink}href"
    groups = {e.get("id"): e for e in root.iter() if e.get("id")}
    images = {}
    for element in root.iter(image_tag):
        uri = element.get(href, "")
        if uri.startswith("data:image/png;base64,"):
            images[id(element)] = Image.open(
                io.BytesIO(base64.b64decode(uri.split(",", 1)[1]))
            ).convert("RGBA")

    def walk(element, group=""):
        identifier = element.get("id", "")
        if identifier.startswith(("checkbox-", "radio-", "arrow-")):
            group = identifier
        marker = "tristate" in group
        for key, value in list(element.attrib.items()):
            if key != href:
                element.set(
                    key,
                    HEX.sub(
                        lambda m: recolor(
                            m[0],
                            palette,
                            theme,
                            appearance,
                            foreground=appearance != "light"
                            and (glyph or marker)
                            and max(rgb(m[0])) < 100,
                        ),
                        value,
                    ),
                )
        if id(element) in images:
            reference = None
            unchecked = group.replace("-checked", "").replace("-tristate", "")
            if unchecked != group and unchecked in groups:
                candidate = groups[unchecked].find(".//" + image_tag)
                if candidate is not None:
                    reference = images.get(id(candidate))
            converted = raster(
                images[id(element)],
                palette,
                theme,
                appearance,
                glyph=glyph or "arrow" in group,
                reference=reference,
            )
            output = io.BytesIO()
            converted.save(output, format="PNG")
            element.set(
                href,
                "data:image/png;base64," + base64.b64encode(output.getvalue()).decode(),
            )
        for child in element:
            walk(child, group)

    walk(root)
    return ET.tostring(root, encoding="unicode")


def stylesheet(text, palette, theme, appearance):
    # Declaration-aware conversion: black text is not a black border; white
    # editable wells are not the white top hair of a bevel. Keep geometry.
    def declaration(match):
        prop, value = match.groups()
        foreground = prop.strip() in ("color", "caret-color", "-gtk-icon-shadow")
        background = prop.strip() in ("background-color", "background")
        value = HEX.sub(
            lambda m: recolor(m[0], palette, theme, appearance, foreground, background),
            value,
        )
        if appearance != "light":
            value = re.sub(
                r"\bwhite\b",
                "#ffffff"
                if foreground
                else palette["base"]
                if background
                else palette["hi"],
                value,
            )
            value = re.sub(
                r"\bblack\b", palette["text"] if foreground else palette["edge"], value
            )

            def rgba(m):
                r, g, b, alpha = m.groups()
                color = recolor(
                    f"#{int(r):02x}{int(g):02x}{int(b):02x}",
                    palette,
                    theme,
                    appearance,
                    foreground,
                    background,
                )
                c = rgb(color)
                return f"rgba({c[0]}, {c[1]}, {c[2]}, {alpha})"

            value = re.sub(
                r"rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\s*\)", rgba, value
            )
        return f"{prop}: {value};"

    text = re.sub(r"([\w-]+)\s*:\s*([^;{}]+);", declaration, text)
    if theme == "win98":
        # Chicago95 uses named colours for GTK3 and most GTK4 partials.
        # These are semantic system colours, so do not invert border black.
        roles = {
            "bg_color": "face",
            "fg_color": "text",
            "panel_fg_color": "text",
            "base_color": "base",
            "text_color": "text",
            "text_color_light": "muted",
            "selected_bg_color": "selected",
            "selected_fg_color": None,
            "selected_inactive_fg_color": "text",
            "border_bright": "hi",
            "border_light": "hi",
            "border_dark": "edge",
            "border_shade": "shade",
            "bg_bright": "base",
            "font_bright": "text",
            "window_title_bg_color": "caption",
            "window_title_text_color": "caption_text",
            "inactive_title_bg_color": "inactive_caption",
            "inactive_title_text_color": "inactive_text",
            "tooltip_bg_color": "tip",
            "tooltip_fg_color": "tip_text",
            "disabled_font": "muted",
        }
        for role, key in roles.items():
            color = palette[key] if key else "#ffffff"
            text = re.sub(
                r"(@define-color " + role + r") [^;]+;", r"\g<1> " + color + ";", text
            )
    return text


def gtk_overrides(p, font, version, theme):
    # Mac-OS-9 predates libadwaita. These public colour variables and explicit
    # surfaces cover its modern header/tab/sidebar nodes without GTK_THEME.
    aliases = {
        "theme_bg_color": "face",
        "theme_fg_color": "text",
        "theme_base_color": "base",
        "theme_text_color": "text",
        "theme_selected_bg_color": "selected",
        "theme_selected_fg_color": None,
        "theme_unfocused_bg_color": "face",
        "theme_unfocused_fg_color": "text",
        "theme_unfocused_base_color": "base",
        "theme_unfocused_text_color": "text",
        "theme_unfocused_selected_bg_color": "selected",
        "theme_unfocused_selected_fg_color": None,
    }
    variables = "".join(
        f"@define-color {role} {p[key] if key else '#ffffff'};\n"
        for role, key in aliases.items()
    )
    if version == 4:
        roles = {
            "window-bg": "face",
            "window-fg": "text",
            "view-bg": "base",
            "view-fg": "text",
            "headerbar-bg": "caption" if theme == "win98" else "face",
            "headerbar-fg": "caption_text" if theme == "win98" else "text",
            "sidebar-bg": "face",
            "sidebar-fg": "text",
            "card-bg": "face",
            "card-fg": "text",
            "popover-bg": "face",
            "popover-fg": "text",
            "dialog-bg": "face",
            "dialog-fg": "text",
            "accent-bg": "selected",
            "accent-fg": None,
        }
        variables += (
            ":root {\n"
            + "".join(
                f"  --{role}-color: {p[key] if key else '#ffffff'};\n"
                for role, key in roles.items()
            )
            + "}\n"
        )
    headerbar = (
        f"headerbar, .titlebar {{ background-color: {p['face']}; color: {p['text']}; border-radius: 0; }}"
        if theme == "platinum"
        else ""
    )
    return f"""\n/* Mountainous derivative: palette and type, generated, not upstream. */
{variables}
* {{ font-family: "{font}"; }}
/* Keep application-marked code and fixed-width content monospaced. */
.monospace, .monospace * {{ font-family: monospace; }}
.background, window, dialog {{ background-color: {p["face"]}; color: {p["text"]}; }}
{headerbar}
tabbar, tabbar tabbox {{ background-color: {p["face"]}; color: {p["text"]}; border-radius: 0; }}
entry, textview, textview text, .view, listview, columnview {{ background-color: {p["base"]}; color: {p["text"]}; }}
button, menubutton > button {{ color: {p["text"]}; }}
selection, *:selected {{ background-color: {p["selected"]}; color: #ffffff; }}
"""


def qt_colors(p):
    # QPalette::ColorRole order, shared by qt5ct and qt6ct (21 roles).
    colors = [
        p["text"],
        p["face"],
        p["hi"],
        p["hi"],
        p["shade"],
        p["shade"],
        p["text"],
        p["text"],
        p["text"],
        p["base"],
        p["face"],
        p["edge"],
        p["selected"],
        "#ffffff",
        p["selected"],
        p["selected"],
        p["face"],
        p["edge"],
        p.get("tip", p["face"]),
        p.get("tip_text", p["text"]),
        p["base"],
    ]
    active = ", ".join(colors)
    disabled = ", ".join(
        p["muted"] if i in (0, 6, 7, 8) else c for i, c in enumerate(colors)
    )
    return f"[ColorScheme]\nactive_colors={active}\ninactive_colors={active}\ndisabled_colors={disabled}\n"


def kvantum_palette(conf, p):
    roles = {
        "window.color": "face",
        "base.color": "base",
        "alt.base.color": "face",
        "button.color": "face",
        "light.color": "hi",
        "mid.light.color": "hi",
        "dark.color": "shade",
        "mid.color": "shade",
        "highlight.color": "selected",
        "inactive.highlight.color": "shade",
        "disabled.text.color": "muted",
        "link.color": "selected",
        "link.visited.color": "selected",
    }

    def color(match):
        name, previous = match.groups()
        if name in ("highlight.text.color", "inactive.highlight.text.color"):
            value = "#ffffff"
        elif name in roles:
            value = p[roles[name]]
        elif "text" in name:
            value = p["text"]
        else:
            value = previous
        return f"{name}={value}"

    return re.sub(r"(?m)^([\w.]+\.color)=(.+)$", color, conf)


def ghostty_tabs(gtk_css, theme, palette, font, target):
    # AdwTabBar has an extra tabboxchild background that otherwise leaves a
    # modern white pill behind a historical tab. Keep the native layout and
    # close buttons. Platinum reuses its upstream top-notebook rules verbatim,
    # with CSS node names translated, rather than inventing a second tab.
    p = palette
    sheet = f'''/* Generated native AdwTabBar adapter. */
@import url("{target}/gtk-4.0/gtk.css");
window tabbar, window tabbar .box, window tabbar.inline .box {{ background: {p["face"]}; border-radius: 0; box-shadow: none; }}
window tabbar tabbox {{ background: none; border-radius: 0; }}
window tabbar tabbox > tabboxchild {{ background: none; border-radius: 0; box-shadow: none; }}
window * {{ font-family: "{font}"; }}
window .monospace, window .monospace * {{ font-family: monospace; }}
window tabbar label {{ font-family: "{font}"; color: {p["text"]}; }}
window toast {{ background-color: {p["face"]}; color: {p["text"]}; }}
window toast label {{ color: {p["text"]}; }}
'''
    if theme == "platinum":
        rules = []
        prefix = "notebook > header.top > tabs > tab"
        for match in re.finditer(r"([^{}]+)\{([^{}]*)\}", gtk_css):
            selectors, body = match.groups()
            for selector in selectors.split(","):
                selector = selector.strip()
                if selector.startswith(prefix):
                    translated = selector.replace(
                        prefix, "window tabbar tab", 1
                    ).replace(":checked", ":selected")
                    rules.append(translated + " {" + body + "}\n")
        if len(rules) < 2:
            raise ValueError("Platinum upstream no longer defines top notebook tabs")
        sheet += "".join(rules)
    else:
        # GTK's startup user provider can keep the previous family's rules at
        # the same priority as Ghostty's custom provider. Give the current
        # upstream AdwTabBar rules one more window-node specificity, just as
        # the Platinum adapter does. Preserve Chicago95's bevel artwork.
        source = target / "gtk-4.0/gtk-adwaita.css"
        named = dict(re.findall(r"@define-color\s+([\w-]+)\s+([^;]+);", gtk_css))

        def color_alias(match, seen=()):
            name = match[1]
            if name not in named:
                return match[0]
            if name in seen:
                raise ValueError(f"Cyclic GTK colour alias: {name}")
            return re.sub(
                r"@([A-Za-z_][\w-]*)",
                lambda m: color_alias(m, (*seen, name)),
                named[name],
            )

        rules = []
        for match in re.finditer(r"([^{}]+)\{([^{}]*)\}", source.read_text()):
            selectors, body = match.groups()
            selectors = re.sub(r"/\*.*?\*/", "", selectors, flags=re.DOTALL)
            for selector in selectors.split(","):
                selector = selector.strip()
                if selector.startswith("tabbar"):
                    body = re.sub(
                        r'url\("([^"]+)"\)',
                        lambda m: f'url("{(source.parent / m[1]).resolve()}")',
                        body,
                    )
                    # Literal paint avoids stale names in GTK's startup
                    # user provider winning over the new provider's names.
                    body = re.sub(r"@([A-Za-z_][\w-]*)", color_alias, body)
                    rules.append("window " + selector + " {" + body + "}\n")
        if len(rules) < 10:
            raise ValueError("Chicago95 upstream no longer defines AdwTabBar rules")
        sheet += "".join(rules)
    return sheet


def generate(out, mac, chicago, kvantum):
    manifest = {}
    for theme, variants in PALETTES.items():
        source = mac if theme == "platinum" else chicago / "Theme/Chicago95"
        for appearance, p in variants.items():
            if appearance == "font":
                continue
            name = f"Mountainous-{theme}-{appearance}"
            target = out / "share/themes" / name
            target.mkdir(parents=True)
            for version in (3, 4):
                folder = target / f"gtk-{version}.0"
                shutil.copytree(source / f"gtk-{version}.0", folder)
                folder.chmod(0o755)
                for path in folder.rglob("*"):
                    if path.is_file():
                        path.chmod(0o644)
                    elif path.is_dir():
                        path.chmod(0o755)
                    if path.suffix == ".css":
                        path.write_text(
                            stylesheet(path.read_text(), p, theme, appearance)
                        )
                    elif path.suffix == ".svg":
                        path.write_text(
                            svg_theme(
                                path.read_text(),
                                p,
                                theme,
                                appearance,
                                glyph=path.name.startswith("arrow"),
                            )
                        )
                    elif path.suffix == ".png" and appearance != "light":
                        image = Image.open(path).convert("RGBA")
                        reference = None
                        if path.name.startswith(
                            ("checkbox-checked", "checkbox-mixed", "radio-checked")
                        ):
                            original = source / path.relative_to(target)
                            unchecked = original.with_name(
                                original.name.replace("-checked", "-unchecked").replace(
                                    "-mixed", "-unchecked"
                                )
                            )
                            if unchecked.exists():
                                reference = Image.open(unchecked).convert("RGBA")
                        raster(
                            image,
                            p,
                            theme,
                            appearance,
                            glyph=path.name.startswith("arrow"),
                            reference=reference,
                        ).save(path)
                css = folder / "gtk.css"
                css.write_text(
                    css.read_text() + gtk_overrides(p, variants["font"], version, theme)
                )
                (folder / "gtk-dark.css").write_text('@import url("gtk.css");\n')
            (target / "index.theme").write_text(
                f"[Desktop Entry]\nName={name}\nType=X-GNOME-Metatheme\n[X-GNOME-Metatheme]\nGtkTheme={name}\n"
            )
            assets = out / "share/mountainous/native" / f"{theme}-{appearance}"
            assets.mkdir(parents=True)
            (assets / "qt-colors.conf").write_text(qt_colors(p))
            # Ghostty reloads this user-priority provider through its own
            # config action; ordinary libadwaita apps need a restart.
            (assets / "ghostty.css").write_text(
                ghostty_tabs(
                    (target / "gtk-4.0/gtk.css").read_text(),
                    theme,
                    p,
                    variants["font"],
                    target,
                )
            )
            (
                assets / "ghostty.conf"
            ).write_text(f"""# Generated {name}; desktop-theme owns this include.
# Reset repeatable families on reload; UI/tab fonts remain in ghostty.css.
font-family =
font-family = {"ProFontIIx Grid" if theme == "platinum" else "Fixedsys Excelsior"}
font-family = DejaVu Sans Mono
font-family = Symbols Nerd Font Mono
font-size = {13.5 if theme == "platinum" else 16}
# Real grid-bold faces keep the advance; italic is not a historical pixel face.
font-synthetic-style = false
font-feature = -liga
font-feature = -dlig
font-codepoint-map = U+E000-U+F8FF=Symbols Nerd Font Mono
font-codepoint-map = U+F0000-U+FFFFD=Symbols Nerd Font Mono
font-codepoint-map = U+100000-U+10FFFD=Symbols Nerd Font Mono
window-padding-x = 8
window-padding-y = 6
window-theme = {"light" if appearance == "light" else "dark"}
background = {p["base"][1:]}
foreground = {p["text"][1:]}
cursor-color = {p["text"][1:]}
selection-background = {p["selected"][1:]}
selection-foreground = ffffff
gtk-custom-css = {assets}/ghostty.css
""")
            ansi = ANSI["light" if appearance == "light" else "dark"]
            with (assets / "ghostty.conf").open("a") as config:
                for index, color in enumerate(ansi):
                    config.write(f"palette = {index}={color}\n")
            if theme == "platinum":
                dest = out / "share/Kvantum" / name
                dest.mkdir(parents=True)
                svg = (kvantum / "Mac9KvantumClassic.svg").read_text()
                (dest / f"{name}.svg").write_text(svg_theme(svg, p, theme, appearance))
                conf = (kvantum / "Mac9KvantumClassic.kvconfig").read_text()
                conf = kvantum_palette(conf, p)
                (dest / f"{name}.kvconfig").write_text(conf)
            manifest[f"{theme}-{appearance}"] = dict(
                p,
                name=name,
                font=variants["font"],
                style="kvantum" if theme == "platinum" else "Windows",
            )
    (out / "share/mountainous/native/manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )
    licenses = out / "share/doc/desktop-native-themes"
    licenses.mkdir(parents=True)
    (licenses / "CHANGES.md").write_text(
        "# Mountainous native theme derivatives\n\n"
        "Generated and modified by Mountainous, 2026-10-27.\n"
        "The build changes palette values, neutral raster/SVG ramps, fonts, "
        "GTK4/libadwaita colour variables and the Ghostty tab-node adapter. "
        "The package and theme names distinguish these from upstream.\n\n"
        "Original authors and licence notices remain in the sources and the "
        "included provenance files. Chicago95 declares GPL-3.0+/MIT; the "
        "complete GPLv3 text is also included in platinum-gtk-GPL-3.0.txt.\n"
    )
    shutil.copy(mac / "LICENSE", licenses / "platinum-gtk-GPL-3.0.txt")
    shutil.copy(kvantum / "LICENSE.txt", licenses / "platinum-kvantum-GPL-3.0.txt")
    shutil.copy(kvantum / "README.md", licenses / "platinum-kvantum-provenance.md")
    shutil.copy(chicago / "README.md", licenses / "chicago95-provenance.md")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("out", "mac", "chicago", "kvantum"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    generate(args.out, args.mac, args.chicago, args.kvantum)
