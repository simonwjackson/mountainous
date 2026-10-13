"""Protected local API boundaries shared by the media migration commands."""
import argparse
import json
import os
from pathlib import Path
import stat
import tempfile
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

CREDENTIALS = Path('/var/lib/media-migration/credentials')
PASSWORD = CREDENTIALS / 'scryer-admin-password'
IDENTITY = CREDENTIALS / 'scryer.json'
SCOPES = {'MOVIE': '/srv/range/media/movies', 'SERIES': '/srv/range/media/tv',
          'ANIME': '/srv/range/media/tv/anime'}
ARR = {'sonarr': (8989, Path('/var/lib/sonarr/.config/NzbDrone/config.xml')),
       'radarr': (7878, Path('/var/lib/radarr/.config/Radarr/config.xml'))}


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse's default error echoes untrusted input. CLI errors must not.
        raise ValueError('invalid arguments')


def root_only():
    if os.geteuid() != 0:
        raise ValueError('root required')


def protected_read(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('unprotected credential')
        with os.fdopen(os.dup(fd)) as stream:
            return stream.read()
    finally:
        os.close(fd)


def fsync_directory(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def protected_unlink(path):
    Path(path).unlink()
    fsync_directory(Path(path).parent)


def protected_write(path, value):
    path = Path(path)
    if path.exists() or path.is_symlink():
        protected_read(path)
    fd, temporary = tempfile.mkstemp(prefix='.media-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        fsync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def request(url, data=None, headers=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=headers or {},
                                 method='GET' if data is None else 'POST')
    # Never send a key to a redirect destination or use operator proxy variables.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(req, timeout=60) as response:
        return json.load(response)


class Scryer:
    def __init__(self, key=None):
        self.key = key

    def graphql(self, query, variables=None):
        headers = {'Content-Type': 'application/json'}
        if self.key:
            headers['Authorization'] = 'Bearer ' + self.key
        payload = request('http://127.0.0.1:8080/graphql',
                          {'query': query, 'variables': variables or {}}, headers)
        if payload.get('errors') or not isinstance(payload.get('data'), dict):
            raise ValueError('Scryer API refused operation')
        return payload['data']

    def mutate(self, field, input_type, value, selection):
        query = ('mutation($input:' + input_type + '!){' + field
                 + '(input:$input){' + selection + '}}')
        return self.graphql(query, {'input': value})[field]

    @classmethod
    def saved(cls):
        identity = json.loads(protected_read(IDENTITY))
        if identity['password_file'] != str(PASSWORD) or identity['username'] != 'admin':
            raise ValueError('invalid identity')
        return cls(identity['api_key'])

    def safe_settings(self):
        result = {}
        for scope in SCOPES:
            result[scope] = self.graphql('query{mediaSettings(scope:' + scope
                + '){renameEnabled importMode libraryPath}}')['mediaSettings']
        result['recycle'] = self.graphql('query{recycleBinSettings{enabled}}')['recycleBinSettings']
        result.update(self.graphql('query{acquisitionSettings{enabled} subtitleSettings{enabled autoDownloadOnImport syncEnabled} pluginAutoUpdateSettings{enabled}}'))
        return result

    def held_settings(self):
        settings = self.safe_settings()
        for scope in SCOPES:
            settings[scope].update(self.graphql('query{mediaSettings(scope:' + scope
                + '){rootFolders{path} setPermissionsLinux nfoWriteOnImport plexmatchWriteOnImport}}')['mediaSettings'])
        settings.update(self.graphql('query{qualityProfileSettings{profiles{id name criteria{allowUpgrades}}} '
            'libraries{id facet roots{path} settings{importMode importModeOverride setPermissionsLinux '
            'setPermissionsLinuxOverride fileChmodOverride folderChmodOverride chownGroupOverride '
            'nfoWriteOnImport nfoWriteOnImportOverride plexmatchWriteOnImport plexmatchWriteOnImportOverride '
            'qualityProfileId qualityProfileIdOverride requestQualityProfileIds}}}'))
        return settings

    def require_held_import(self):
        settings = self.held_settings()
        validate_held_import(settings)
        return settings

    def require_safe(self):
        settings = self.safe_settings()
        if settings['recycle']['enabled'] or any(settings[s]['renameEnabled'] for s in SCOPES):
            raise ValueError('unsafe import settings')
        return settings


def validate_held_import(settings):
    """Fail closed on effective scope/library settings and every stored profile."""
    if (settings['recycle']['enabled'] is not False
            or settings['acquisitionSettings']['enabled'] is not False
            or settings['pluginAutoUpdateSettings']['enabled'] is not False
            or any(settings['subtitleSettings'][field] is not False
                   for field in ('enabled', 'autoDownloadOnImport', 'syncEnabled'))):
        raise ValueError('unheld import workers')
    for scope, path in SCOPES.items():
        media = settings[scope]
        if (media['renameEnabled'] is not False or media['importMode'] != 'HARDLINK_OR_COPY'
                or media['libraryPath'] != path or media['rootFolders'] != [{'path': path}]
                or media['setPermissionsLinux'] is not False or media['nfoWriteOnImport'] is not False
                or media['plexmatchWriteOnImport'] not in (None, False)):
            raise ValueError('unheld media settings')
    profiles = settings['qualityProfileSettings']['profiles']
    profile_ids = {p['id'] for p in profiles}
    if not profiles or any(p['criteria']['allowUpgrades'] is not False for p in profiles):
        raise ValueError('upgrades are not held')
    libraries = settings['libraries']
    if {library['facet'] for library in libraries} != set(SCOPES):
        raise ValueError('missing library scope')
    for library in libraries:
        value = library['settings']
        if (library['roots'] != [{'path': SCOPES[library['facet']]}]
                or value['importMode'] != 'HARDLINK_OR_COPY'
                or value['importModeOverride'] not in (None, 'HARDLINK_OR_COPY')
                or any(value[field] not in (None, False) for field in (
                    'setPermissionsLinux', 'setPermissionsLinuxOverride', 'nfoWriteOnImport',
                    'nfoWriteOnImportOverride', 'plexmatchWriteOnImport', 'plexmatchWriteOnImportOverride'))
                or any(value[field] is not None for field in ('fileChmodOverride', 'folderChmodOverride', 'chownGroupOverride'))
                or value['qualityProfileId'] not in profile_ids
                or (value['qualityProfileIdOverride'] is not None and value['qualityProfileIdOverride'] not in profile_ids)
                or not set(value['requestQualityProfileIds']).issubset(profile_ids)):
            raise ValueError('unheld library override')


class Arr:
    def __init__(self, name):
        self.name = name
        port, config = ARR[name]
        self.base = f'http://127.0.0.1:{port}/api/v3/'
        self.key = (ET.parse(config).getroot().findtext('ApiKey') or '').strip()
        if not self.key:
            raise ValueError('missing source key')

    def get(self, resource, **params):
        return request(self.base + resource + ('?' + urllib.parse.urlencode(params) if params else ''),
                       headers={'X-Api-Key': self.key})

    def pages(self, resource):
        rows, page = [], 1
        while True:
            payload = self.get(resource, page=page, pageSize=1000, sortKey='id', sortDirection='ascending')
            records = payload['records']
            rows.extend(records)
            if len(rows) >= payload['totalRecords']:
                return rows
            if not records:
                raise ValueError('incomplete source pagination')
            page += 1

    def connection(self):
        port = ARR[self.name][0]
        return {'baseUrl': f'http://127.0.0.1:{port}', 'apiKey': self.key}
