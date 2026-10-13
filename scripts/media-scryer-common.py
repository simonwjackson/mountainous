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

    def require_safe(self):
        settings = self.safe_settings()
        if settings['recycle']['enabled'] or any(settings[s]['renameEnabled'] for s in SCOPES):
            raise ValueError('unsafe import settings')
        return settings


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
