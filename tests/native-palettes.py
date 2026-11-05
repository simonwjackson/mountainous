"""Check the native palette seams and every packaged CSS asset reference."""

import importlib.util
import json
import os
import re
import sys
from pathlib import Path

from PIL import Image

script, qml, package = map(Path, sys.argv[1:])
spec = importlib.util.spec_from_file_location("native", script)
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)
for theme, variants in native.PALETTES.items():
    dark = variants["dark"]
    assert native.recolor("#ffffff", dark, theme, "dark", foreground=True) == "#ffffff"
    assert (
        native.recolor("#ffffff", dark, theme, "dark", background=True) == dark["base"]
    )
    assert native.recolor("#ffffff", dark, theme, "dark") == dark["hi"]
    assert (
        native.recolor("#000000", dark, theme, "dark", foreground=True) == dark["text"]
    )
manifest = json.loads((package / "share/mountainous/native/manifest.json").read_text())
# Check semantic roles, not just whether a colour occurs somewhere in QML.
roles = {
    "platinum": {
        "face": "menuSurface",
        "text": "menuText",
        "base": "field",
        "hi": "bevelLight",
        "shade": "bevelDark",
        "selected": "highlight",
        "muted": "menuTextOff",
    },
    "memphis": {
        "face": "face",
        "text": "text",
        "base": "win",
        "hi": "hi",
        "shade": "sh",
        "selected": "selection",
        "muted": "gray",
    },
}
for theme, mapping in roles.items():
    source = (
        qml / ("PlatinumTokens.qml" if theme == "platinum" else "MemphisTokens.qml")
    ).read_text()
    for role, token in mapping.items():
        pattern = r"\b" + token + r': dark \? "(#[0-9a-f]+)" : "(#[0-9a-f]+)"'
        match = re.search(pattern, source)
        assert match, (theme, role, token)
        assert native.PALETTES[theme]["dark"][role] == match[1]
        assert native.PALETTES[theme]["light"][role] == match[2]
palettes = native.palettes(Path(os.environ["SCHEMES_JSON"]))
expected = {
    f"{theme}-{appearance}"
    for theme, variants in palettes.items()
    for appearance in variants
    if appearance != "font"
}
assert set(manifest) == expected
assert len(expected) == 26  # 25 selectable appearances plus the retained OLED option.
for theme, variants in palettes.items():
    tokens = (
        (qml / ("PlatinumTokens.qml" if theme == "platinum" else "MemphisTokens.qml"))
        .read_text()
        .lower()
    )
    for appearance, colors in variants.items():
        if appearance == "font":
            continue
        if appearance in ("light", "dark", "extra"):
            for role, color in colors.items():
                assert color in tokens, (theme, appearance, role, color)
        assert all(
            manifest[f"{theme}-{appearance}"][role] == color
            for role, color in colors.items()
        )
        key = f"{theme}-{appearance}"
        name = manifest[key]["name"]
        gtk2 = (package / "share/themes" / name / "gtk-2.0/gtkrc").read_text()
        assert f'bg[NORMAL] = "{colors["face"]}"' in gtk2
        assert f'text[SELECTED] = "{colors["selected_text"]}"' in gtk2
        for version in (3, 4):
            main_css = (
                package / "share/themes" / name / f"gtk-{version}.0/gtk.css"
            ).read_text()
            assert f"@define-color theme_fg_color {colors['text']};" in main_css
            assert f"@define-color theme_bg_color {colors['face']};" in main_css
        if appearance != "light":
            for version in (3, 4):
                checkbox = (
                    package
                    / "share/themes"
                    / name
                    / f"gtk-{version}.0/assets/checkbox-checked.png"
                )
                if checkbox.exists():
                    image = Image.open(checkbox).convert("RGBA")
                    assert (*native.rgb(colors["text"]), 255) in image.getdata(), (
                        checkbox
                    )
        for css in (package / "share/themes" / name).rglob("*.css"):
            # Upstream image-set URLs can be unquoted, quoted or url().
            source = re.sub(r"/\*.*?\*/", "", css.read_text(), flags=re.DOTALL)
            for url in re.findall(r"url\([\'\"]?([^\)\'\"]+)[\'\"]?\)", source):
                if url.startswith(("resource:", "data:")):
                    continue
                assert (css.parent / url).exists(), (css, url)
        conf = package / "share/mountainous/native" / key / "ghostty.conf"
        assert f"background = {colors['base'][1:]}" in conf.read_text()
        assert f"foreground = {colors['base_text'][1:]}" in conf.read_text()
        assert conf.read_text().count("palette = ") == 16
        assert (
            f"selection-foreground = {colors['selected_text'][1:]}" in conf.read_text()
        )
        assert f"window-theme = {native.mode_for(appearance)}" in conf.read_text()
        assert (conf.parent / "web.css").is_file()
        tab_css = (conf.parent / "ghostty.css").read_text()
        assert "window tabbar tabbox > tabboxchild" in tab_css
        assert "window toast label" in tab_css
        for url in re.findall(r'url\("([^"]+)"\)', tab_css):
            assert (conf.parent / url).exists(), (conf, url)
        if theme == "platinum":
            assert "window tabbar tab:selected" in tab_css
            assert "border-bottom-left-radius" in tab_css
            kv = package / "share/Kvantum" / name
            assert (kv / f"{name}.svg").is_file()
            assert (kv / f"{name}.kvconfig").is_file()
        else:
            assert "window tabbar tab:selected" in tab_css
            assert "window tabbar tab:checked" in tab_css
            assert "background-color: @bg_color" not in tab_css
            assert (
                f"/share/themes/{name}/gtk-3.0/assets/notebook_top_checked.png"
                in tab_css
            )
print("NATIVE_PALETTE_TESTS_PASSED")
