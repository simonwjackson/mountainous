#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""VM-only verification of real credentials, plugin uploads and leak boundaries."""
import importlib.util
import json
from pathlib import Path
import subprocess

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)

common.root_only()
password = common.protected_read(common.PASSWORD).strip()
identity = json.loads(common.protected_read(common.IDENTITY))
result = common.Scryer().mutate('login', 'LoginInput',
                               {'username': identity['username'], 'password': password},
                               'token passwordChangeRequired')
assert result['token'] and result['passwordChangeRequired'] is False
assert not common.PASSWORD.with_name('scryer-admin-password.pending').exists()
client = common.Scryer.saved()
client.require_held_import()
plugins = client.graphql('query{plugins{id isInstalled installedVersion}}')['plugins']
for plugin, version in [('transmission', '2.0.2'), ('jellyfin', '1.1.1')]:
    assert any(p['id'] == plugin and p['isInstalled'] and p['installedVersion'] == version
               for p in plugins)
for command in (['systemctl', 'cat', 'scryer'], ['journalctl', '-u', 'scryer', '--no-pager']):
    text = subprocess.check_output(command).decode()
    for secret in (password, identity['api_key'], result['token']):
        assert secret not in text
print('Replacement password login, pinned plugins, and unit/journal leak guards passed')
