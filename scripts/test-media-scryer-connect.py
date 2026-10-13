#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Connection contracts: stateful GraphQL transport and private ARR database fixtures."""
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).parent
spec = importlib.util.spec_from_file_location('connect', HERE / 'media-scryer-connect.py')
connect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(connect)
SECRET = 'fixture-secret-never-output'


class RecordingGraphQL:
    def __init__(self, corrupt=False, acquisition=False):
        self.corrupt, self.acquisition = corrupt, acquisition
        self.calls = []
        self.previous_config = {}
        self.tables = {name: [] for name in ('indexers', 'downloadClientConfigs', 'notificationChannels', 'notificationSubscriptions')}
        names = connect.SCALAR_OVERRIDES + tuple(connect.ROUTE_OVERRIDES)
        self.tables['libraries'] = [{'id': scope, 'facet': scope, 'roots': [{'path': root}],
                                     'settings': {name + 'Override': None for name in names}}
                                    for scope, root in connect.common.SCOPES.items()]
        # An override set by the import (dominant quality profile) must survive.
        for row in self.tables['libraries']:
            row['settings']['qualityProfileIdOverride'] = 'profile-' + row['facet']

    def graphql(self, query, variables=None):
        self.calls.append(('graphql', query, copy.deepcopy(variables)))
        if 'acquisitionSettings' in query:
            return {'acquisitionSettings': {'enabled': self.acquisition}}
        if 'syncIndexerConfig' in query:
            parent = variables['id']
            if not any(row.get('managedParentConfigId') == parent for row in self.tables['indexers']):
                self.tables['indexers'].append({'id': 'child', 'name': 'NZBGeek', 'providerType': 'newznab',
                    'baseUrl': connect.PROWLARR + '/12', 'managedParentConfigId': parent, 'isEnabled': True, 'hasApiKey': True})
            return {'syncIndexerConfig': {'parentConfigId': parent}}
        if 'testNotificationChannel' in query:
            return {'testNotificationChannel': {'status': 'ok'}}
        for table in self.tables:
            if table + '{' in query:
                rows = copy.deepcopy(self.tables[table])
                if self.corrupt and table == 'downloadClientConfigs' and rows:
                    rows[0]['config'][0]['value']['value'] = 'wrong-host'
                return {table: rows}
        raise AssertionError('unknown query')

    def mutate(self, field, input_type, value, selection):
        self.calls.append(('mutate', field, copy.deepcopy(value)))
        if field == 'testDownloadClientConnection':
            self.assert_saved_test(value)
            return {'status': 'ok'}
        if field == 'reorderDownloadClientConfigs':
            self.tables['downloadClientConfigs'].sort(key=lambda row: value['ids'].index(row['id']))
            return {'ids': value['ids']}
        if field == 'updateLibrary':
            # Upstream replaces: an omitted field deletes that override.
            row = next(row for row in self.tables['libraries'] if row['id'] == value['libraryId'])
            for name in connect.SCALAR_OVERRIDES + tuple(connect.ROUTE_OVERRIDES):
                row['settings'][name + 'Override'] = copy.deepcopy(value['settings'].get(name))
            return copy.deepcopy(row)
        table = next(table for token, table in [('IndexerConfig', 'indexers'), ('DownloadClientConfig', 'downloadClientConfigs'),
                                                ('NotificationChannel', 'notificationChannels'), ('NotificationSubscription', 'notificationSubscriptions')]
                     if token in field)
        data = copy.deepcopy(value)
        if field.startswith('create'):
            data['id'] = table + str(len(self.tables[table]))
            if table == 'notificationSubscriptions':
                data.update(targetKind='plugin_channel', targetId=data['channelId'], scopeId=None)
            self.tables[table].append(data)
        else:
            row = next(row for row in self.tables[table] if row['id'] == data['id'])
            row.update(data)
            data = row
        if 'config' in data:
            # Upstream masks these keys whatever slot they arrive in, keeps an
            # omitted stored secret on update, and drops one sent as clearSecret.
            masked = {'username', 'password', 'api_key'}
            kept = [] if field.startswith('create') else [
                c for c in self.previous_config.get(data['id'], [])
                if c['key'] in masked and c['key'] not in {v['key'] for v in value['config']}]
            data['config'] = kept + [
                {'key': v['key'], 'value': {'stored': True} if v['key'] in masked else
                 {'value': next(v[key] for key in ('stringValue', 'boolValue', 'intValue', 'secretValue') if key in v)}}
                for v in value['config'] if not v.get('clearSecret')]
            data['storedSecretKeys'] = [c['key'] for c in data['config'] if c['key'] in masked]
            self.previous_config[data['id']] = copy.deepcopy(data['config'])
        if table == 'notificationChannels':
            data['blockedReason'] = None
        if table == 'indexers':
            data['baseUrl'] = connect.PROWLARR
        return copy.deepcopy(data)

    def assert_saved_test(self, value):
        # A stored-ID test must carry the full connection, not only secrets.
        keys = {v['key'] for v in value['config']}
        assert value['id'] and {'host', 'port'} <= keys, keys


class FixtureSources:
    def __init__(self, path):
        self.path = path

    def indexers(self):
        return {'key': SECRET, 'categories': {'SERIES': ['5030', '5040'], 'MOVIE': ['2000', '2040']}}

    def clients(self):
        return {'key': SECRET, 'transmission': connect.read_sonarr_settings(self.path, 'DownloadClients', 'Transmission')}

    def jellyfin(self):
        return {'settings': connect.read_sonarr_settings(self.path, 'Notifications', 'MediaBrowser', 'Jellyfin Library Update'),
                'folders': [{'CollectionType': 'tvshows', 'Locations': ['/media/tv']},
                            {'CollectionType': 'movies', 'Locations': ['/media/movies']}]}


class ConnectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / 'sonarr.db'
        self.transmission = {'host': '10.200.200.2', 'port': 9091, 'useSsl': False, 'urlBase': '/transmission/',
                             'username': 'fixture-user', 'password': SECRET}
        self.jellyfin = {'host': 'jellyfin.test', 'port': 8096, 'useSsl': False, 'urlBase': '', 'apiKey': SECRET}
        with contextlib.closing(sqlite3.connect(self.path)) as db, db:
            for table, name, implementation, settings in [('DownloadClients', 'Transmission', 'Transmission', self.transmission),
                                                          ('Notifications', 'Jellyfin Library Update', 'MediaBrowser', self.jellyfin)]:
                db.execute(f'CREATE TABLE {table}(Name TEXT, Implementation TEXT, Settings TEXT)')
                db.execute(f'INSERT INTO {table} VALUES(?,?,?)', (name, implementation, json.dumps(settings)))
        self.source = FixtureSources(self.path)

    def tearDown(self):
        self.directory.cleanup()

    def test_connections_are_idempotent_and_read_back_and_credentials_are_not_output(self):
        client = RecordingGraphQL()
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            connect.connect(client, ['indexers', 'clients', 'jellyfin'], self.source)
            connect.connect(client, ['indexers', 'clients', 'jellyfin'], self.source)
        self.assertNotIn(SECRET, output.getvalue())
        self.assertEqual(len(client.tables['indexers']), 2)
        self.assertEqual(len(client.tables['downloadClientConfigs']), 2)
        self.assertEqual(len(client.tables['notificationChannels']), 1)
        self.assertEqual(len(client.tables['notificationSubscriptions']), 3)
        clients = client.tables['downloadClientConfigs']
        self.assertEqual([row['name'] for row in clients], ['NZBFAST (usenet)', 'Transmission (torrent)'])
        for library in client.tables['libraries']:
            routes = library['settings']['downloadClientRoutingOverride']
            self.assertEqual([r['category'] for r in routes], ['Movies', 'movies-radarr'] if library['facet'] == 'MOVIE' else ['Series', 'tv-sonarr'])
            self.assertTrue(all(r['removeCompleted'] and r['removeFailed'] for r in routes))
        self.assertEqual(sum(call[1] == 'testDownloadClientConnection' for call in client.calls), 4)
        self.assertFalse(client.acquisition)

    def test_routing_updates_preserve_every_other_library_override(self):
        client = RecordingGraphQL()
        connect.connect(client, ['indexers'], self.source)
        connect.connect(client, ['clients'], self.source)
        for library in client.tables['libraries']:
            settings = library['settings']
            self.assertEqual(settings['qualityProfileIdOverride'], 'profile-' + library['facet'])
            self.assertIsNotNone(settings['downloadClientRoutingOverride'])
            if library['facet'] in ('SERIES', 'MOVIE'):
                self.assertTrue(settings['indexerRoutingOverride'], library['facet'])

    def test_transmission_username_is_sent_as_secret_and_verified_present(self):
        client = RecordingGraphQL()
        connect.connect(client, ['clients'], self.source)
        row = next(r for r in client.tables['downloadClientConfigs'] if r['name'] == 'Transmission (torrent)')
        self.assertIn('username', row['storedSecretKeys'])
        sent = next(c for c in client.calls if c[0] == 'mutate' and c[1] == 'createDownloadClientConfig'
                    and c[2]['name'] == 'Transmission (torrent)')
        slots = {v['key']: v for v in sent[2]['config']}
        self.assertIn('secretValue', slots['username'])

    def test_reader_never_creates_source_sidecars(self):
        # A WAL-mode source without -shm: opening it in SQLite would create one.
        staging = Path(self.directory.name) / 'staging'
        staging.mkdir()
        live = staging / 'sonarr.db'
        with contextlib.closing(sqlite3.connect(self.path)) as db, contextlib.closing(sqlite3.connect(live)) as copy_db:
            db.backup(copy_db)
        writer = sqlite3.connect(live)
        writer.execute('PRAGMA journal_mode=WAL')
        writer.execute('PRAGMA wal_autocheckpoint=0')
        writer.execute('UPDATE DownloadClients SET Settings=?', (json.dumps(dict(self.transmission, port=9292)),))
        writer.commit()
        source = Path(self.directory.name) / 'source'
        source.mkdir()
        for name in ('sonarr.db', 'sonarr.db-wal'):
            (source / name).write_bytes((staging / name).read_bytes())
        writer.close()
        before = sorted(p.name for p in source.iterdir())
        self.assertEqual(before, ['sonarr.db', 'sonarr.db-wal'])
        settings = connect.read_sonarr_settings(source / 'sonarr.db', 'DownloadClients', 'Transmission')
        self.assertEqual(settings['port'], 9292)
        self.assertEqual(sorted(p.name for p in source.iterdir()), before)

    def _rewrite(self, table, settings):
        with contextlib.closing(sqlite3.connect(self.path)) as db, db:
            db.execute(f'UPDATE {table} SET Settings=?', (json.dumps(settings),))

    def test_unauthenticated_transmission_sends_no_credentials(self):
        # Unzen's real row: username and password are empty strings.
        self._rewrite('DownloadClients', dict(self.transmission, username='', password=''))
        client = RecordingGraphQL()
        connect.connect(client, ['clients'], self.source)
        row = next(r for r in client.tables['downloadClientConfigs'] if r['name'] == 'Transmission (torrent)')
        self.assertEqual({c['key'] for c in row['config']}, {'host', 'port', 'use_ssl', 'url_base'})

    def test_existing_authenticated_client_has_credentials_cleared(self):
        client = RecordingGraphQL()
        connect.connect(client, ['clients'], self.source)  # authenticated fixture
        row = next(r for r in client.tables['downloadClientConfigs'] if r['name'] == 'Transmission (torrent)')
        self.assertEqual(set(row['storedSecretKeys']), {'username', 'password'})
        self._rewrite('DownloadClients', dict(self.transmission, username='', password=''))
        connect.connect(client, ['clients'], self.source)
        row = next(r for r in client.tables['downloadClientConfigs'] if r['name'] == 'Transmission (torrent)')
        self.assertEqual(row['storedSecretKeys'], [])
        test = [c for c in client.calls if c[0] == 'mutate' and c[1] == 'testDownloadClientConnection'][-1]
        self.assertEqual({v['key'] for v in test[2]['config'] if v.get('clearSecret')}, {'username', 'password'})

    def test_half_set_credentials_refuse(self):
        self._rewrite('DownloadClients', dict(self.transmission, password=''))
        with self.assertRaises(ValueError):
            connect.connect(RecordingGraphQL(), ['clients'], self.source)

    def test_jellyfin_notification_without_url_base(self):
        # Unzen's real MediaBrowser row has no urlBase key.
        settings = {k: v for k, v in self.jellyfin.items() if k != 'urlBase'}
        self._rewrite('Notifications', settings)
        client = RecordingGraphQL()
        connect.connect(client, ['jellyfin'], self.source)
        [channel] = client.tables['notificationChannels']
        base = next(c['value']['value'] for c in channel['config'] if c['key'] == 'base_url')
        self.assertEqual(base, 'http://jellyfin.test:8096')

    def test_read_back_mismatch_refuses(self):
        with self.assertRaises(ValueError):
            connect.connect(RecordingGraphQL(corrupt=True), ['clients'], self.source)

    def test_missing_source_value_refuses_before_mutations(self):
        self.transmission.pop('password')
        with contextlib.closing(sqlite3.connect(self.path)) as db, db:
            db.execute('UPDATE DownloadClients SET Settings=?', (json.dumps(self.transmission),))
        client = RecordingGraphQL()
        with self.assertRaises(ValueError):
            connect.connect(client, ['indexers', 'clients'], self.source)
        self.assertFalse(any(call[0] == 'mutate' for call in client.calls))

    def test_enabled_acquisition_refuses_before_mutations(self):
        client = RecordingGraphQL(acquisition=True)
        with self.assertRaises(ValueError):
            connect.connect(client, ['indexers'], self.source)
        self.assertFalse(any(call[0] == 'mutate' for call in client.calls))

    def test_duplicate_names_refuse(self):
        client = RecordingGraphQL()
        client.tables['downloadClientConfigs'] = [{'id': str(i), 'name': 'NZBFAST (usenet)'} for i in range(2)]
        with self.assertRaises(ValueError):
            connect.connect(client, ['clients'], self.source)

    def test_private_copy_reads_wal_and_leaves_source_unchanged(self):
        with contextlib.closing(sqlite3.connect(self.path)) as db, db:
            db.execute('PRAGMA journal_mode=WAL')
            db.execute('UPDATE DownloadClients SET Settings=?', (json.dumps(dict(self.transmission, port=9191)),))
            db.commit()
            self.assertEqual(connect.read_sonarr_settings(self.path, 'DownloadClients', 'Transmission')['port'], 9191)
            self.assertEqual(db.execute('PRAGMA journal_mode').fetchone()[0], 'wal')
        self.assertEqual(list(Path(self.directory.name).glob('.media-*')), [])

    def test_path_mapping_is_explicit_and_ambiguous_paths_refuse(self):
        mapping = connect.jellyfin_mappings(self.source.jellyfin()['folders'])
        self.assertEqual(mapping, '/srv/range/media/tv => /media/tv\n/srv/range/media/movies => /media/movies')
        with self.assertRaises(ValueError):
            connect.jellyfin_mappings([{'CollectionType': 'tvshows', 'Locations': ['/a', '/b']},
                                      {'CollectionType': 'movies', 'Locations': ['/c']}])

    def test_cli_failures_have_fixed_errors_and_no_secret_argv(self):
        result = subprocess.run([sys.executable, str(HERE / 'media-scryer-connect.py')], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr.strip(), 'Refused: Scryer connection configuration failed')
        self.assertNotIn(SECRET, result.stdout + result.stderr + str(result.args))


if __name__ == '__main__':
    unittest.main()
