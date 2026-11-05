#!/usr/bin/env python3
"""Validate the installed registry and reject dependencies between themes."""
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
registry = json.loads((root / 'themes.json').read_text())
ids = [theme['id'] for theme in registry]
prefixes = [theme['qmlPrefix'] for theme in registry]
assert len(ids) == len(set(ids)) and 'platinum' in ids
assert len(prefixes) == len(set(prefixes))
for theme in registry:
    assert theme.get('pyxampFace') in ('platinum', 'winamp'), (theme['id'], 'pyxampFace')
    name, prefix = theme['id'], theme['qmlPrefix']
    assert re.fullmatch(r'[a-z][a-z0-9-]*', name), name
    assert re.fullmatch(r'[A-Z][A-Za-z0-9]*', prefix), prefix
    for file in [theme['desktop'], theme['picker']]:
        assert '/' not in file and file.startswith(prefix) and (root / file).is_file(), file
    appearance_ids = [appearance['id'] for appearance in theme['appearances']]
    assert len(appearance_ids) == len(set(appearance_ids)), (name, 'duplicate appearance')
    for appearance in theme['appearances']:
        assert re.fullmatch(r'[a-z][a-z0-9-]*', appearance['id']), (name, 'appearance id')
        file = appearance['thumbnail']
        assert appearance['id'] and file == f"themes/{name}/previews/{appearance['id']}.png", file
        # Design assets can land separately. Only the two legacy mode files
        # are permitted as a temporary missing-thumbnail fallback.
        fallback = root / f"themes/{name}/previews/{appearance['mode']}.png"
        assert (root / file).is_file() or fallback.is_file(), file
    desktop = (root / theme['desktop']).read_text()
    for contract in ['required property var screen', 'required property var context',
                     'required property var theme', 'property bool active',
                     'function reveal(', 'function hide(', 'function open(', 'ThemePicker']:
        assert contract in desktop, (name, contract)
    assert theme['appearances'] and {a['mode'] for a in theme['appearances']} <= {'dark', 'light'}
    assert isinstance(theme['options']['extraDark'], bool)
    # Phase 4 art: icon and cursor theme names (lib/desktop-art.nix builds
    # them) and one pattern tile per appearance, Extra dark included.
    art = theme['art']
    assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*', art['icons']), (name, 'art.icons')
    assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*', art['cursors']), (name, 'art.cursors')
    assert isinstance(art['cursorSize'], int) and art['cursorSize'] > 0, (name, 'art.cursorSize')
    assert art['patternCell'] in (1, 2, 3, 4), (name, 'art.patternCell')
    looks = {a['id'] for a in theme['appearances']} | {'light', 'dark'} | ({'extra'} if theme['options']['extraDark'] else set())
    assert set(art['patterns']) == looks, (name, 'art.patterns')
    for key, file in art['patterns'].items():
        assert file.startswith(f'themes/{name}/'), file
        choice = next((a for a in theme['appearances'] if a['id'] == key), None)
        fallback = root / f"themes/{name}/patterns/{choice['mode'] if choice else key}.svg"
        assert (root / file).is_file() or fallback.is_file(), file

# The flat prefix fallback avoids Quickshell 0.3.1's dynamic directory-scan
# limitation. Asset and policy subfolders remain owned by their theme ID.
for theme in registry:
    name, prefix = theme['id'], theme['qmlPrefix']
    files = list(root.glob(prefix + '*.qml')) + list((root / 'themes' / name).rglob('*.js'))
    for file in files:
        text = file.read_text()
        for other in registry:
            if other['id'] == name:
                continue
            assert not re.search(r'\b' + re.escape(other['qmlPrefix']) + r'[A-Z]\w*', text), (
                f'{file}: cross-theme type dependency on {other["id"]}')
        for match in re.finditer(r'(?:import\s+|(?:source|sourceComponent)\s*:\s*)["\']([^"\']+)["\']', text):
            target = (file.parent / match[1]).resolve()
            if target.is_relative_to(root / 'themes'):
                other = target.relative_to(root / 'themes').parts[0]
                assert name == other, f'{file}: cross-theme dependency on {other}'
            elif target.parent == root:
                for other in registry:
                    assert other['id'] == name or not target.name.startswith(other['qmlPrefix']), (
                        f'{file}: cross-theme dependency on {other["id"]}')
for file in (root / 'panels').glob('*.qml'):
    text = file.read_text()
    assert not re.search(r'import\s+["\'][^"\']*themes/', text), file
    assert 'property Component menu' not in text, file
    for prefix in prefixes:
        assert not re.search(r'\b' + re.escape(prefix) + r'[A-Z]\w*', text), file
# Shell-local Theme is the host seam; all shared tokens have one URI identity.
for name in ('Theme', 'PlatinumTokens', 'MemphisTokens', 'PlatinumMetrics',
             'PlatinumIconStore', 'MemphisIconStore'):
    if name != 'Theme':
        assert not (root / (name + '.qml')).exists(), name
for file in root.glob('*.qml'):
    text = file.read_text()
    assert not re.search(r'^import Hensou(?:\s*$|\s+\d)', text, re.M), file
assert 'import Hensou as Kit' in (root / 'Theme.qml').read_text()
assert not (root / 'qmldir').exists()
assert 'Desktop theme…' in (root / 'OmniBar.qml').read_text()
assert 'text: "Desktop theme…"' in (root / 'PlatinumClockMenu.qml').read_text()
assert 'target: "themePicker"' in (root / 'shell.qml').read_text()
# Memphis opens the picker from Start > Settings > Display... and Ctrl+Esc /
# chrome open start reaches its Start menu.
start_model = (root / 'themes/memphis/start-model.js').read_text()
assert '"&Display..."' in start_model and 'action: "picker"' in start_model
assert 'item.action === "picker") ThemePicker.open' in (root / 'MemphisDesktop.qml').read_text()
assert 'control === "start"' in (root / 'MemphisDesktop.qml').read_text()
print('THEME_BOUNDARIES_PASSED')
