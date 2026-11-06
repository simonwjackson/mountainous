"""Verify generated title-bar and native ramps against the cited system data."""

import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path

script, source, lua = map(Path, sys.argv[1:4])
shell = Path(sys.argv[4]) if len(sys.argv) > 4 else None
assert (
    hashlib.sha256(source.read_bytes()).hexdigest()
    == "a7f330d2e3ccc077a98ef220f86e3aee8c19be488c93c569bb81cbbfee59d406"
)
spec = importlib.util.spec_from_file_location("native", script)
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)
palettes = native.palettes(source)
text = lua.read_text()
roles = {
    "face": "Control",
    "hi": "ControlLightLight",
    "li": "ControlLight",
    "lo": "ControlDark",
    "edge": "ControlDarkDark",
    "glyph": "ControlText",
    "text": "ActiveCaptionText",
    "text_off": "InactiveCaptionText",
    "caption1": "ActiveCaption",
    "caption2": "GradientActiveCaption",
    "inactive1": "InactiveCaption",
    "inactive2": "GradientInactiveCaption",
}
count = 0
for scheme in json.loads(source.read_text()):
    if scheme["name"].startswith("Classic"):
        continue
    identifier = scheme["name"].lower().replace(" #", "-").replace(" ", "-")
    match = re.search(r'\["' + identifier + r'"\] = \{([^}]+)\}', text)
    assert match, identifier
    actual = dict(re.findall(r'(\w+) = "([0-9a-f]+)"', match[1]))
    expected = {key: scheme["colors"][color][1:] for key, color in roles.items()}
    assert actual == expected, (identifier, actual, expected)
    p = palettes["memphis"][identifier]
    for role, key in {
        "base": "Window",
        "base_text": "WindowText",
        "selected": "Highlight",
        "selected_text": "HighlightText",
        "menu": "Menu",
        "menu_text": "MenuText",
        "tip": "Info",
        "tip_text": "InfoText",
        "desktop": "Desktop",
    }.items():
        assert p[role] == scheme["colors"][key], (identifier, role)
    if shell:
        css = (shell / "themes/memphis/web.css").read_text()
        token_block = re.search(
            r"/\* @tokens " + identifier + r" \*/(.*?)(?=/\* @|/\* <<<)", css, re.DOTALL
        )
        assert token_block, identifier
        expected_web = native.shell_tokens("memphis", p, identifier).strip()
        assert token_block[1].strip() == expected_web, identifier
    count += 1
assert count == 20
board = re.search(r'\["drawing-board"\] = \{([^}]+)\}', text)
actual = dict(re.findall(r'(\w+) = "([0-9a-f]+)"', board[1]))
p = native.DRAWING_BOARD
for role, key in {
    "face": "face",
    "text": "text",
    "text_off": "muted",
    "hi": "face",
    "lo": "face",
    "edge": "edge",
    "box": "base",
    "rule": "edge",
}.items():
    assert actual[role] == p[key][1:], (role, key)
if shell:
    css = (shell / "themes/platinum/web.css").read_text()
    block = re.search(r"/\* @tokens drawing-board \*/(.*?)(?=/\* <<<)", css, re.DOTALL)
    assert (
        block[1].strip() == native.shell_tokens("platinum", p, "drawing-board").strip()
    )
print("SYSTEM_PALETTES_PASSED: 20 source palettes, Drawing Board, source SHA256")
