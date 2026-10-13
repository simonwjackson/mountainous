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
        self.tables = {name: [] for name in ('indexers', 'downloadClientConfigs', 'notificationChannels', 'notificationSubscriptions')}
        self.tables['libraries'] = [{'id': scope, 'facet': scope, 'roots': [{'path': root}], 'settings': {}}
                                    for scope, root in connect.common.SCOPES.items()]

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
            row = next(row for row in self.tables['libraries'] if row['id'] == value['libraryId'])
            for key, data in value['settings'].items():
                row['settings'][key + 'Override'] = copy.deepcopy(data)
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
            data['config'] = [{'key': v['key'], 'value': {'stored': True} if 'secretValue' in v else
                               {'value': next(v[key] for key in ('stringValue', 'boolValue', 'intValue') if key in v)}}
                              for v in value['config']]
            data['storedSecretKeys'] = [v['key'] for v in value['config'] if 'secretValue' in v]
        if table == 'notificationChannels':
            data['blockedReason'] = None
        if table == 'indexers':
            data['baseUrl'] = connect.PROWLARR
        return copy.deepcopy(data)

    def assert_saved_test(self, value):
        assert value['id'] and value['config'] == []


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
