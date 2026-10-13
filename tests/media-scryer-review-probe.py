#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Root VM probes: interrupted password publication and metadata-only catalog adds."""
import importlib.util
import json
from pathlib import Path
import secrets
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
import urllib.parse
import sys
import time


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name('media-scryer-' + name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


common = load('common')
provision = load('provision')
importer = load('import')
parity = load('parity')
common.root_only()
action = sys.argv[1]
if action in ('password-before-server', 'password-after-server'):
    pending = common.PASSWORD.with_name('scryer-admin-password.pending')
    replacement = secrets.token_urlsafe(48)
    common.protected_write(pending, replacement + '\n')
    client = common.Scryer()
    login = client.mutate('login', 'LoginInput',
                         {'username': 'admin', 'password': common.protected_read(common.PASSWORD).strip()},
                         'token passwordChangeRequired')
    assert login['passwordChangeRequired'] is True
    if action == 'password-after-server':
        client.key = login['token']
        changed = client.mutate('completeRequiredPasswordChange', 'CompleteRequiredPasswordChangeInput',
                               {'password': replacement}, 'token passwordChangeRequired')
        assert changed['token'] and changed['passwordChangeRequired'] is False
elif action == 'password-after-publish':
    common.protected_write(common.PASSWORD.with_name('scryer-admin-password.pending'),
                           common.protected_read(common.PASSWORD))
elif action == 'source-profiles':
    out = Path('/var/lib/media-migration/review-archive')
    out.mkdir(mode=0o700, exist_ok=True)
    profiles = [{'name': name, 'upgradeAllowed': bool(index % 2)}
                for index, name in enumerate(provision.PROFILE_TIERS)]
    for app in common.ARR:
        common.protected_write(out / (app + '-qualityprofile.json'), json.dumps(profiles))
elif action == 'source-profiles-conflict':
    path = Path('/var/lib/media-migration/review-archive/radarr-qualityprofile.json')
    rows = json.loads(common.protected_read(path))
    rows[0]['upgradeAllowed'] = not rows[0]['upgradeAllowed']
    common.protected_write(path, json.dumps(rows))
elif action == 'verify-acquisition-off':
    assert common.Scryer.saved().graphql('query{acquisitionSettings{enabled}}')['acquisitionSettings']['enabled'] is False
elif action == 'verify-acquisition-on':
    assert common.Scryer.saved().graphql('query{acquisitionSettings{enabled}}')['acquisitionSettings']['enabled'] is True
elif action == 'permission-finalize':
    # Real upstream warmup/finalize against GET-only empty ARR instances with
    # Unzen's permission values; this exercises the explicit-setting skip.
    class Source(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            resource = urllib.parse.urlsplit(self.path).path.split('/api/v3/')[-1]
            kind = self.server.kind
            root = common.SCOPES['SERIES' if kind == 'SONARR' else 'MOVIE']
            if resource == '/api':
                payload = {'current': 'v3'}
            elif resource == 'system/status':
                payload = {'appName': 'Sonarr' if kind == 'SONARR' else 'Radarr',
                           'version': '4.0.16' if kind == 'SONARR' else '6.0.4'}
            elif resource == 'rootfolder':
                payload = [{'id': 1, 'path': root}]
            elif resource == 'config/naming':
                payload = {'renameEpisodes': False, 'renameMovies': False}
            elif resource == 'config/mediamanagement':
                payload = {'setPermissionsLinux': False, 'chmodFolder': '755', 'chownGroup': ''}
            else:
                payload = []
            body = json.dumps(payload).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(body)

    client = common.Scryer.saved()
    before = client.require_held_import()
    servers, sessions = [], []
    try:
        for kind, port in [('SONARR', 8989), ('RADARR', 7878)]:
            server = ThreadingHTTPServer(('127.0.0.1', port), Source)
            server.kind = kind
            threading.Thread(target=server.serve_forever, daemon=True).start()
            servers.append(server)
            result = client.mutate('startExternalImportArrSourceWarmup', 'StartExternalImportArrSourceWarmupInput',
                                   {'kind': kind, 'connection': {'baseUrl': f'http://127.0.0.1:{port}', 'apiKey': 'fixture-only'}},
                                   'sessionId')
            sessions.append(result['sessionId'])
        deadline = time.monotonic() + 60
        for session in sessions:
            importer.poll(client, session, deadline)
        preview = client.mutate('previewExternalImport', 'PreviewExternalImportInput',
                                {'sourceWarmupSessionIds': sessions},
                                'rootFolders{sourceWarmupSessionId sourceKey kind arrRootPath}')
        libraries = client.graphql('query{libraries{id facet roots{path}}}')['libraries']
        mappings = []
        for root in preview['rootFolders']:
            facet = 'SERIES' if root['kind'] == 'SONARR' else 'MOVIE'
            library = next(item for item in libraries if item['facet'] == facet)
            mappings.append(dict(root, facet=facet, libraryId=library['id'], scryerRootPath=root['arrRootPath']))
        assert len(mappings) == 2
        finalized = client.mutate('finalizeExternalImport', 'FinalizeExternalImportInput',
                                 {'sourceWarmupSessionIds': sessions, 'mappings': mappings}, 'finalizeSessionId')
        importer.poll(client, finalized['finalizeSessionId'], deadline)
        assert client.require_held_import() == before
        for scope in common.SCOPES:
            value = client.graphql('query{mediaSettings(scope:' + scope + '){folderChmod chownGroup setPermissionsLinux}}')['mediaSettings']
            assert value == {'folderChmod': '755', 'chownGroup': None, 'setPermissionsLinux': False}
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
elif action == 'verify-match-source':
    expected = provision.source_upgrade_policy([json.loads(common.protected_read(
        Path('/var/lib/media-migration/review-archive') / (app + '-qualityprofile.json')))
        for app in common.ARR])
    client = common.Scryer.saved()
    rows = client.graphql('query{qualityProfileSettings{profiles{name criteria{allowUpgrades}}}}')['qualityProfileSettings']['profiles']
    assert all(row['criteria']['allowUpgrades'] == expected.get(row['name'], False) for row in rows)
    try:
        client.require_held_import()
    except ValueError:
        pass
    else:
        raise AssertionError('upgrade policy did not disarm held-import admission')
elif action == 'catalog-only':
    client = common.Scryer.saved()
    client.require_held_import()
    source = []
    for kind, count, prefix in [('MOVIE', 25, 'tmdb'), ('SERIES', 18, 'tvdb')]:
        for index in range(count):
            source.append({'key': prefix + ':' + str(999000 + index),
                           'name': f'Catalog-only fixture {kind} {index}',
                           'root': common.SCOPES[kind], 'monitored': bool(index % 2),
                           'quality_profile': 'Any', 'seasons': {}, 'episodes': {}, 'paths': []})
    # Mirror the admission defect: 19/25 movies and 15/18 series already exist.
    present = [s for s in source if int(s['key'].split(':')[1]) - 999000
               >= (6 if s['key'].startswith('tmdb:') else 3)]
    assert importer.add_missing_source_titles(client, present) == 34
    counts, gaps = parity.compare(source, parity.target_catalog(client))
    assert len([gap for gap in gaps if gap.startswith('missing title:')]) == 9
    assert importer.add_missing_source_titles(client, source) == 9
    assert importer.add_missing_source_titles(client, source) == 0
    importer.await_source_metadata(client, source, time.monotonic() + 5)
    counts, gaps = parity.compare(source, parity.target_catalog(client))
    assert counts['movies'] == 25 and counts['series'] == 18 and not gaps
    client.require_held_import()
else:
    raise ValueError('unknown probe')
print('Review probe passed: ' + action)
