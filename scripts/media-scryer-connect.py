#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Connect held Scryer to the existing VPN providers and Jellyfin. Root only."""
import importlib.util
from contextlib import closing
import json
import os
from pathlib import Path, PurePosixPath
import re
import sqlite3
import stat
import sys
import tempfile
import urllib.parse
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)

PROWLARR = 'http://10.200.200.2:9696'
SONARR_DB = Path('/var/lib/sonarr/.config/NzbDrone/sonarr.db')
VALUE_FIELDS = ('config{key value{__typename ... on StringConfigValuePayload{value} '
                '... on BoolConfigValuePayload{value} ... on IntConfigValuePayload{value} '
                '... on SecretConfigValuePayload{stored}}} storedSecretKeys')
INDEXER_FIELDS = 'id name providerType baseUrl isEnabled managedParentConfigId hasApiKey ' + VALUE_FIELDS
CLIENT_FIELDS = 'id name clientType isEnabled ' + VALUE_FIELDS
CHANNEL_FIELDS = 'id name channelType isEnabled blockedReason ' + VALUE_FIELDS
SERVER_FIELDS = ('id provider displayName baseUrl enabled loginEnabled linkingEnabled autoAddEnabled apiKeyPresent '
                 'pathMappings{sourcePath destinationPath}')
TRANSMISSION_ENABLED = False
SUB_FIELDS = 'id channelId targetKind targetId eventType scope scopeId isEnabled'
INDEXER_ROUTE = 'indexerId enabled categories priority'
CLIENT_ROUTE = 'clientId enabled category recentQueuePriority olderQueuePriority removeCompleted removeFailed seedingProfileId'
# updateLibrary REPLACES library settings: an omitted field deletes that
# library-scoped override (scryer-application/src/settings/runtime/library.rs:
# 1775-1807). searchLanguages is the one exception (kept when omitted, :1498).
# Every override is therefore read and written back unchanged.
SCALAR_OVERRIDES = ('requiredAudioLanguages', 'metadataLanguage', 'useSeasonFolders', 'qualityProfileId',
                    'requestQualityProfileIds', 'scoringPersona', 'fillerPolicy', 'recapPolicy',
                    'monitorSpecials', 'interSeasonMovies', 'monitorFillerMovies', 'nfoWriteOnImport',
                    'plexmatchWriteOnImport', 'importMode', 'setPermissionsLinux', 'fileChmod',
                    'folderChmod', 'chownGroup')
ROUTE_OVERRIDES = {'indexerRouting': INDEXER_ROUTE, 'downloadClientRouting': CLIENT_ROUTE}
LIBRARY_FIELDS = ('id facet roots{path} settings{'
                  + ' '.join(name + 'Override' for name in SCALAR_OVERRIDES)
                  + ''.join(f' {name}Override{{{fields}}}' for name, fields in ROUTE_OVERRIDES.items()) + '}')


def text(value, empty=False):
    if not isinstance(value, str) or (not empty and not value.strip()) or any(c in value for c in ('\n', '\r', '\0')):
        raise ValueError('missing or invalid source value')
    return value


def source_value(settings, key, kind=str, empty=False):
    if key not in settings:
        raise ValueError('missing source value')
    value = settings[key]
    if kind is str:
        return text(value, empty)
    if type(value) is not kind:
        raise ValueError('invalid source value type')
    return value


def connection_values(settings):
    host = source_value(settings, 'host')
    if not re.fullmatch(r'[A-Za-z0-9_.:\[\]-]+', host):
        raise ValueError('invalid source host')
    port = source_value(settings, 'port', int)
    if not 1 <= port <= 65535:
        raise ValueError('invalid source port')
    ssl = source_value(settings, 'useSsl', bool)
    # Sonarr's MediaBrowser notification has no urlBase field at all.
    base = source_value(settings, 'urlBase', empty=True) if 'urlBase' in settings else ''
    if base and (not base.startswith('/') or any(c in base for c in ('?', '#', '=>'))):
        raise ValueError('invalid source URL base')
    return {'host': host, 'port': str(port), 'use_ssl': ssl, 'url_base': base}


def _stable_private_copy(path, directory):
    """Copy DB, WAL and journal bytes without opening the live database in SQLite.

    Opening the source, even read-only, can create a live -shm sidecar. Copy the
    files, then refuse unless none changed during the copy.
    """
    source = Path(path)
    names = [source.name, source.name + '-wal', source.name + '-journal']

    def state():
        result = {}
        for name in names:
            try:
                info = (source.parent / name).lstat()
            except FileNotFoundError:
                result[name] = None
                continue
            if not stat.S_ISREG(info.st_mode):
                raise ValueError('invalid source database')
            result[name] = (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)
        return result

    for _ in range(10):
        before = state()
        if before[source.name] is None:
            raise ValueError('invalid source database')
        for name in names:
            target = Path(directory) / name
            if target.exists():
                target.unlink()
            if before[name] is not None:
                fd = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                with open(source.parent / name, 'rb') as reader, os.fdopen(fd, 'wb') as writer:
                    writer.write(reader.read())
        if state() == before:
            return Path(directory) / source.name
    raise ValueError('source database kept changing')


def read_sonarr_settings(path, table, implementation, name=None):
    """Read a private, stability-checked byte copy; SQLite never opens the live files."""
    if table not in ('DownloadClients', 'Notifications'):
        raise ValueError('invalid source database')
    with tempfile.TemporaryDirectory(prefix='.media-sonarr-') as directory:
        private = _stable_private_copy(path, directory)
        uri = 'file:' + urllib.parse.quote(str(private)) + '?mode=ro'
        with closing(sqlite3.connect(uri, uri=True)) as db:
            rows = db.execute('SELECT Name, Settings FROM ' + table + ' WHERE Implementation=?', (implementation,)).fetchall()
        rows = [row for row in rows if name is None or row[0] == name]
        if len(rows) != 1:
            raise ValueError('missing or ambiguous source row')
        value = json.loads(rows[0][1])
        if not isinstance(value, dict):
            raise ValueError('invalid source settings')
        return value


def newznab_categories(rows):
    matches = [row for row in rows if 'nzbgeek' in row['name'].casefold() and row['implementation'] == 'Newznab']
    if len(matches) != 1:
        raise ValueError('missing or ambiguous source indexer')
    fields = [f['value'] for f in matches[0]['fields'] if f['name'] == 'categories']
    if len(fields) != 1 or not isinstance(fields[0], list) or not fields[0]:
        raise ValueError('missing source categories')
    if any(type(v) is not int or v <= 0 for v in fields[0]):
        raise ValueError('invalid source categories')
    return sorted({str(v) for v in fields[0]}, key=int)


def jellyfin_mappings(folders):
    """Use provider-declared collection kinds; refuse ambiguous roots, never guess."""
    mappings = []
    for kind, scope in [('tvshows', 'SERIES'), ('movies', 'MOVIE')]:
        locations = {text(location) for folder in folders if folder.get('CollectionType') == kind
                     for location in folder['Locations']}
        local = common.SCOPES[scope]
        # Exact shared paths need no translation, even if the server has other roots.
        if local in locations:
            remote = local
        elif len(locations) == 1:
            remote = next(iter(locations))
        else:
            raise ValueError('missing or ambiguous media-server root')
        path = PurePosixPath(remote)
        if not path.is_absolute() or '..' in path.parts or '=>' in remote or str(path) != remote:
            raise ValueError('invalid media-server root')
        mappings.append(local + ' => ' + remote)
    return '\n'.join(mappings)


class LocalSources:
    def __init__(self, sonarr_db=SONARR_DB, prowlarr_config=Path('/var/lib/prowlarr/config.xml'),
                 nzbfast_settings=Path('/var/lib/nzbfast/settings.json'), arr_factory=common.Arr, request=common.request):
        self.sonarr_db, self.prowlarr_config, self.nzbfast_settings = sonarr_db, prowlarr_config, nzbfast_settings
        self.arr_factory, self.request = arr_factory, request

    def indexers(self):
        key = text(ET.parse(self.prowlarr_config).getroot().findtext('ApiKey'))
        categories = {scope: newznab_categories(self.arr_factory(app).get('indexer'))
                      for scope, app in [('SERIES', 'sonarr'), ('MOVIE', 'radarr')]}
        return {'key': key, 'categories': categories}

    def clients(self):
        key = text(json.loads(self.nzbfast_settings.read_text())['apikey'])
        return {'key': key, 'transmission': read_sonarr_settings(self.sonarr_db, 'DownloadClients', 'Transmission')}

    def jellyfin(self):
        settings = read_sonarr_settings(self.sonarr_db, 'Notifications', 'MediaBrowser', 'Jellyfin Library Update')
        connection = connection_values(settings)
        base = ('https://' if connection['use_ssl'] else 'http://') + connection['host'] + ':' + connection['port'] + connection['url_base'].rstrip('/')
        key = source_value(settings, 'apiKey')
        folders = self.request(base + '/Library/VirtualFolders', headers={'X-Emby-Token': key})
        return {'settings': settings, 'folders': folders}


def is_secret_key(key):
    """Upstream's masking rule (scryer-interface-media/src/mappers/configuration.rs:997-1006)."""
    key = key.strip().lower()
    return (any(word in key for word in ('password', 'secret', 'token', 'api_key'))
            or key in ('username', 'user_name', 'apikey'))


def provider_values(values, secrets=()):
    result = []
    for key, value in values.items():
        slot = 'secretValue' if key in secrets or is_secret_key(key) else ('boolValue' if type(value) is bool else 'stringValue')
        result.append({'key': key, slot: value})
    return result


def rows(client, table, fields):
    return client.graphql('query{' + table + '{' + fields + '}}')[table]


def named(values, name):
    matches = [row for row in values if row['name'] == name]
    if len(matches) > 1:
        raise ValueError('ambiguous connection name')
    return matches[0] if matches else None


def verify_config(row, inputs):
    actual = {field['key']: field['value'] for field in row['config']}
    for field in inputs:
        key = field['key']
        if field.get('clearSecret'):
            if key in row['storedSecretKeys'] or actual.get(key, {}).get('stored') is True:
                raise ValueError('secret absence verification failed')
        elif 'secretValue' in field:
            if key not in row['storedSecretKeys'] or actual.get(key, {}).get('stored') is not True:
                raise ValueError('secret presence verification failed')
        else:
            expected = field.get('boolValue', field.get('stringValue'))
            if actual.get(key, {}).get('value') != expected:
                raise ValueError('provider value verification failed')


def upsert(client, table, fields, stem, value, type_key):
    old = named(rows(client, table, fields), value['name'])
    if old and old[type_key] != value[type_key]:
        raise ValueError('connection provider mismatch')
    update = dict(value, id=old['id']) if old else value
    if old and stem == 'NotificationChannel':
        update.pop('channelType')  # The update input preserves the provider type.
    verb = 'update' if old else 'create'
    client.mutate(verb + stem, verb.title() + stem + 'Input', update, 'id')
    saved = named(rows(client, table, fields), value['name'])
    if not saved or any(saved.get(k) != v for k, v in value.items() if k != 'config'):
        raise ValueError('connection read-back verification failed')
    verify_config(saved, value['config'])
    return saved['id']


def libraries(client):
    result = rows(client, 'libraries', LIBRARY_FIELDS)
    if len(result) != 3 or {r['facet'] for r in result} != set(common.SCOPES):
        raise ValueError('missing or ambiguous libraries')
    if any(r['roots'] != [{'path': common.SCOPES[r['facet']]}] for r in result):
        raise ValueError('unexpected library roots')
    return result


def library_routes(client, library, key, entries):
    if key not in ROUTE_OVERRIDES:
        raise ValueError('invalid routing key')
    # Read fresh: an earlier step may have written other overrides.
    current = next(row for row in libraries(client) if row['id'] == library['id'])['settings']
    settings = {name: current[name + 'Override'] for name in SCALAR_OVERRIDES + tuple(ROUTE_OVERRIDES)
                if current.get(name + 'Override') is not None}
    settings[key] = entries
    client.mutate('updateLibrary', 'UpdateLibraryInput', {'libraryId': library['id'], 'settings': settings}, 'id')
    saved = next(row for row in libraries(client) if row['id'] == library['id'])
    for name in SCALAR_OVERRIDES + tuple(ROUTE_OVERRIDES):
        if name != key and saved['settings'].get(name + 'Override') != current.get(name + 'Override'):
            raise ValueError('library override changed unexpectedly')
    route = saved['settings'][key + 'Override']
    if not isinstance(route, list) or len(route) != len(entries):
        raise ValueError('library routing verification failed')
    indexed = {r['indexerId' if key == 'indexerRouting' else 'clientId']: r for r in route}
    for entry in entries:
        actual = indexed.get(entry['indexerId' if key == 'indexerRouting' else 'clientId'], {})
        if any(actual.get(k) != v for k, v in entry.items()):
            raise ValueError('library routing verification failed')


def require_off(client):
    if client.graphql('query{acquisitionSettings{enabled}}')['acquisitionSettings']['enabled'] is not False:
        raise ValueError('acquisition must remain off')


def connect(client, steps, source):
    require_off(client)
    # Validate every requested source before changing any target configuration.
    plans = {}
    for step in steps:
        data = getattr(source, step)()
        if step == 'indexers':
            text(data['key'])
            for scope in ('SERIES', 'MOVIE'):
                if not data['categories'][scope] or any(not re.fullmatch(r'[1-9][0-9]*', v) for v in data['categories'][scope]):
                    raise ValueError('missing source categories')
        elif step == 'clients':
            values = connection_values(data['transmission'])
            # Unzen's Transmission is reached over the tailnet without auth, so
            # both may be empty. Send only credentials that exist.
            username = source_value(data['transmission'], 'username', empty=True)
            password = source_value(data['transmission'], 'password', empty=True)
            if bool(username) != bool(password):
                raise ValueError('incomplete source credentials')
            # A masked password must never replace the database's real value.
            if password and set(password) == {'*'}:
                raise ValueError('masked source password')
            if username:
                values.update(username=username, password=password)
            data['config'] = values
            text(data['key'])
        elif step == 'jellyfin':
            values = connection_values(data['settings'])
            base = ('https://' if values['use_ssl'] else 'http://') + values['host'] + ':' + values['port'] + values['url_base'].rstrip('/')
            data['config'] = {'base_url': base, 'api_key': source_value(data['settings'], 'apiKey'),
                              'path_mappings': jellyfin_mappings(data['folders'])}
        else:
            raise ValueError('invalid connection step')
        plans[step] = data
    libs = libraries(client)
    if 'indexers' in plans:
        data = plans['indexers']
        parent = upsert(client, 'indexers', INDEXER_FIELDS, 'IndexerConfig',
                        {'name': 'Prowlarr', 'providerType': 'prowlarr', 'isEnabled': True,
                         'config': provider_values({'base_url': PROWLARR, 'api_key': data['key']}, ('api_key',))}, 'providerType')
        synced = client.graphql('mutation($id:ID!){syncIndexerConfig(id:$id){parentConfigId}}', {'id': parent})['syncIndexerConfig']
        if synced['parentConfigId'] != parent:
            raise ValueError('indexer sync verification failed')
        children = [row for row in rows(client, 'indexers', INDEXER_FIELDS) if row['id'] != parent]
        if not children or any(row['managedParentConfigId'] != parent or not row['hasApiKey']
                               or not re.fullmatch(re.escape(PROWLARR) + r'/[1-9][0-9]*', row['baseUrl']) for row in children):
            raise ValueError('indexers must target the VPN-owned proxy')
        for library in libs:
            if library['facet'] in ('SERIES', 'MOVIE'):
                entries = [{'indexerId': row['id'], 'enabled': row['isEnabled'], 'priority': 0,
                            'categories': data['categories'][library['facet']]} for row in children]
                library_routes(client, library, 'indexerRouting', entries)
        print('Prowlarr sync and library-scoped TV/movie categories verified; acquisition remains off')
    if 'clients' in plans:
        data = plans['clients']
        usenet_config = provider_values({'host': '10.200.200.2', 'port': '6790', 'use_ssl': False,
                                         'api_key': data['key']})
        torrent_config = provider_values(data['config'])
        if 'username' not in data['config']:
            # Upstream keeps omitted secrets on update and in stored-ID tests
            # (scryer-interface/src/mutation/config.rs:153-158,724-730), so an
            # unauthenticated source must clear them explicitly.
            torrent_config += [{'key': 'username', 'clearSecret': True},
                               {'key': 'password', 'clearSecret': True}]
        usenet = upsert(client, 'downloadClientConfigs', CLIENT_FIELDS, 'DownloadClientConfig',
                        {'name': 'NZBFAST (usenet)', 'clientType': 'sabnzbd', 'isEnabled': True,
                         'config': usenet_config}, 'clientType')
        # Kept configured but DISABLED: the transmission 2.0.2 plugin types
        # session-get's rpc-version as a string, but Transmission 4.x sends an
        # integer (19 on Unzen), so every call fails (scryer-plugins issue #100,
        # open). No torrent indexer exists, so nothing reaches it today.
        torrent = upsert(client, 'downloadClientConfigs', CLIENT_FIELDS, 'DownloadClientConfig',
                         {'name': 'Transmission (torrent)', 'clientType': 'transmission',
                          'isEnabled': TRANSMISSION_ENABLED, 'config': torrent_config}, 'clientType')
        # A stored-ID test merges only omitted secrets, not the saved host/port/URL
        # (scryer-interface/src/mutation/config.rs:165-181), so send the full
        # configuration through GraphQL variables.
        tests = [(usenet, 'sabnzbd', usenet_config)]
        if TRANSMISSION_ENABLED:
            tests.append((torrent, 'transmission', torrent_config))
        for identity, kind, config in tests:
            result = client.mutate('testDownloadClientConnection', 'TestDownloadClientConnectionInput',
                                   {'id': identity, 'clientType': kind, 'config': config}, 'status')
            if result['status'] != 'ok':
                raise ValueError('download-client connection test failed')
        for library in libs:
            movie = library['facet'] == 'MOVIE'
            entries = [{'clientId': identity, 'enabled': enabled, 'category': category,
                        'removeCompleted': True, 'removeFailed': True}
                       for identity, enabled, category in [
                           (usenet, True, 'Movies' if movie else 'Series'),
                           (torrent, TRANSMISSION_ENABLED, 'movies-radarr' if movie else 'tv-sonarr')]]
            library_routes(client, library, 'downloadClientRouting', entries)
        ordered = [usenet, torrent] + [row['id'] for row in rows(client, 'downloadClientConfigs', CLIENT_FIELDS)
                                      if row['id'] not in (usenet, torrent)]
        client.mutate('reorderDownloadClientConfigs', 'ReorderDownloadClientConfigsInput', {'ids': ordered}, 'ids')
        if [row['id'] for row in rows(client, 'downloadClientConfigs', CLIENT_FIELDS)] != ordered:
            raise ValueError('client order verification failed')
        print('NZBFAST connection test, categories, removal policy and order verified')
        if not TRANSMISSION_ENABLED:
            print('Transmission configured but disabled: plugin 2.0.2 cannot read Transmission 4.x (scryer-plugins#100)')
    if 'jellyfin' in plans:
        # Jellyfin is a media-server connection, not a plugin channel: upstream
        # refuses media-server providers as channels
        # (scryer-application/src/notifications/notifications.rs:222).
        config = plans['jellyfin']['config']
        mappings = [{'sourcePath': local, 'destinationPath': remote}
                    for local, remote in (line.split(' => ') for line in config['path_mappings'].splitlines())]
        value = {'provider': 'JELLYFIN', 'displayName': 'Jellyfin Library Update', 'baseUrl': config['base_url'],
                 'enabled': True, 'loginEnabled': False, 'linkingEnabled': False, 'autoAddEnabled': False,
                 'apiKey': config['api_key'], 'pathMappings': mappings}
        existing = [row for row in rows(client, 'mediaServerConnections', SERVER_FIELDS)
                    if row['displayName'] == value['displayName']]
        if len(existing) > 1:
            raise ValueError('ambiguous media-server connection')
        if existing:
            if existing[0]['provider'] != 'JELLYFIN':
                raise ValueError('connection provider mismatch')
            client.mutate('updateMediaServerConnection', 'UpdateMediaServerConnectionInput',
                          dict(value, id=existing[0]['id']), 'id')
        else:
            client.mutate('createMediaServerConnection', 'CreateMediaServerConnectionInput', value, 'id')
        [saved] = [row for row in rows(client, 'mediaServerConnections', SERVER_FIELDS)
                   if row['displayName'] == value['displayName']]
        if (saved['provider'] != 'JELLYFIN' or saved['baseUrl'].rstrip('/') != value['baseUrl'].rstrip('/')
                or saved['enabled'] is not True or saved['loginEnabled'] or saved['linkingEnabled']
                or saved['autoAddEnabled'] or saved['apiKeyPresent'] is not True
                or sorted((m['sourcePath'], m['destinationPath']) for m in saved['pathMappings'])
                != sorted((m['sourcePath'], m['destinationPath']) for m in mappings)):
            raise ValueError('media-server connection read-back verification failed')
        server = saved['id']
        result = client.mutate('testMediaServerConnection', 'TestMediaServerConnectionInput', {'id': server}, 'status')
        if result['status'] != 'ok':
            raise ValueError('media-server connection test failed')
        target = 'media_server_connection'
        for event in ('import_complete', 'upgrade', 'rename'):
            def matching():
                return [row for row in rows(client, 'notificationSubscriptions', SUB_FIELDS)
                        if row['targetKind'] == target and row['targetId'] == server
                        and row['eventType'] == event and row['scope'] == 'global' and row['scopeId'] is None]
            existing = matching()
            if len(existing) > 1:
                raise ValueError('ambiguous notification subscription')
            sub = {'eventType': event, 'scope': 'global', 'isEnabled': True}
            if existing:
                sub['id'] = existing[0]['id']
                client.mutate('updateNotificationSubscription', 'UpdateNotificationSubscriptionInput', sub, 'id')
            else:
                sub.update(targetKind=target, targetId=server)
                client.mutate('createNotificationSubscription', 'CreateNotificationSubscriptionInput', sub, 'id')
            verified = matching()
            if len(verified) != 1 or verified[0]['isEnabled'] is not True:
                raise ValueError('notification subscription verification failed')
        print('Jellyfin mapping verified: SERIES/ANIME use the TV prefix; MOVIE uses the movie prefix')
        print('Jellyfin import/download completion, upgrade and rename subscriptions and test verified')
    require_off(client)


def main(argv=None):
    parser = common.ArgumentParser(description=__doc__)
    for step in ('indexers', 'clients', 'jellyfin'):
        parser.add_argument('--' + step, action='store_true')
    args = parser.parse_args(argv)
    common.root_only()
    steps = [step for step in ('indexers', 'clients', 'jellyfin') if getattr(args, step)]
    if not steps:
        raise ValueError('missing connection step')
    connect(common.Scryer.saved(), steps, LocalSources())


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Refused: Scryer connection configuration failed', file=sys.stderr)
        sys.exit(1)
