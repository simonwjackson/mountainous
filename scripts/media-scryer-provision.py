#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Bootstrap protected credentials, then apply and verify held import settings."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import secrets
import stat
import subprocess
import sys

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)

PROFILE_TIERS = {
    'Any': ['4320P', '2160P', '1080P', '720P', '576P', '480P'],
    'SD': ['576P', '480P'], 'HD-720p': ['720P'], 'HD-1080p': ['1080P'],
    'Ultra-HD': ['2160P'], 'HD - 720p/1080p': ['1080P', '720P'],
}


def profiles(client):
    current = client.graphql('query{qualityProfileSettings{profiles{id name} globalProfileId globalScoringPersona}}')['qualityProfileSettings']
    existing = {p['name']: p['id'] for p in current['profiles']}
    wanted = []
    for index, (name, tiers) in enumerate(PROFILE_TIERS.items()):
        criteria = {'qualityTiers': tiers, 'archivalQuality': tiers[0],
                    'allowUnknownQuality': name == 'Any', 'sourceAllowlist': [],
                    'sourceBlocklist': [], 'videoCodecAllowlist': [], 'videoCodecBlocklist': [],
                    'audioCodecAllowlist': [], 'audioCodecBlocklist': [],
                    'dolbyVisionAllowed': True, 'detectedHdrAllowed': True, 'preferRemux': False,
                    'allowBdDisk': False, 'allowUpgrades': True, 'scoringOverrides': {},
                    'cutoffTier': tiers[0]}
        wanted.append({'id': existing.get(name, f'mountainous-{index}'), 'name': name,
                       'criteria': criteria})
    client.mutate('saveQualityProfileSettings', 'SaveQualityProfileSettingsInput',
                  {'profiles': wanted, 'globalProfileId': current['globalProfileId'],
                   'globalScoringPersona': current['globalScoringPersona'],
                   'categorySelections': [], 'categoryPersonaSelections': [],
                   'replaceExisting': False}, 'profiles{id name}')
    criteria_fields = ('qualityTiers archivalQuality allowUnknownQuality sourceAllowlist sourceBlocklist '
                       'videoCodecAllowlist videoCodecBlocklist audioCodecAllowlist audioCodecBlocklist '
                       'dolbyVisionAllowed detectedHdrAllowed preferRemux allowBdDisk allowUpgrades cutoffTier')
    actual = client.graphql('query{qualityProfileSettings{profiles{id name criteria{' + criteria_fields
                            + '}}}}')['qualityProfileSettings']['profiles']
    by_id = {p['id']: p for p in actual}
    for expected in wanted:
        found = by_id[expected['id']]
        if found['name'] != expected['name'] or any(
                found['criteria'][key] != expected['criteria'][key]
                for key in expected['criteria'] if key != 'scoringOverrides'):
            raise ValueError('profile verification failed')


def apply_settings(client, acquisition):
    for scope, path in common.SCOPES.items():
        print('Applying media settings: ' + scope)
        client.mutate('updateMediaSettings', 'UpdateMediaSettingsInput',
                      {'scope': scope, 'renameEnabled': False, 'importMode': 'HARDLINK_OR_COPY',
                       'libraryPath': path}, 'renameEnabled importMode libraryPath')
    print('Applying recycle-bin settings')
    client.mutate('updateRecycleBinSettings', 'UpdateRecycleBinSettingsInput',
                  {'enabled': False}, 'enabled')
    print('Applying acquisition settings')
    selection = ('enabled sameTierMinDelta pollIntervalSeconds walkIntervalSeconds '
                 'longTailBackfillMaxScopesPerCycle longTailReconvergeDays')
    value = client.graphql('query{acquisitionSettings{' + selection + '}}')['acquisitionSettings']
    value['enabled'] = acquisition
    client.mutate('updateAcquisitionSettings', 'UpdateAcquisitionSettingsInput', value, 'enabled')
    print('Applying subtitle settings')
    selection = ('enabled languages{code hearingImpaired forced} autoDownloadOnImport '
                 'minimumScoreSeries minimumScoreMovie searchIntervalHours includeAiTranslated '
                 'includeMachineTranslated syncEnabled syncThresholdSeries syncThresholdMovie '
                 'syncMaxOffsetSeconds')
    value = client.graphql('query{subtitleSettings{' + selection + '}}')['subtitleSettings']
    value.update(enabled=False, autoDownloadOnImport=False, syncEnabled=False)
    client.mutate('updateSubtitleSettings', 'UpdateSubtitleSettingsInput', value, 'enabled')
    print('Applying plugin auto-update settings')
    client.mutate('updatePluginAutoUpdateSettings', 'UpdatePluginAutoUpdateSettingsInput',
                  {'enabled': False}, 'enabled')
    actual = client.require_safe()
    for scope, path in common.SCOPES.items():
        if actual[scope] != {'renameEnabled': False, 'importMode': 'HARDLINK_OR_COPY', 'libraryPath': path}:
            raise ValueError('media settings verification failed')
    actual = client.graphql('query{acquisitionSettings{enabled} subtitleSettings{enabled autoDownloadOnImport syncEnabled} pluginAutoUpdateSettings{enabled}}')
    if actual != {'acquisitionSettings': {'enabled': acquisition},
                  'subtitleSettings': {'enabled': False, 'autoDownloadOnImport': False, 'syncEnabled': False},
                  'pluginAutoUpdateSettings': {'enabled': False}}:
        raise ValueError('settings verification failed')


def bootstrap(open_gate):
    common.CREDENTIALS.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = common.CREDENTIALS.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('invalid credentials directory')
    if not common.PASSWORD.exists():
        fd = os.open(common.PASSWORD, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(secrets.token_urlsafe(48) + '\n')
    if not common.protected_read(common.PASSWORD).strip():
        raise ValueError('empty password')
    if open_gate:
        gate = Path('/var/lib/media-migration/ready')
        gate.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = gate.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError('invalid gate directory')
        fd = os.open(gate / 'scryer', os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        os.close(fd)


def authenticate():
    if common.IDENTITY.exists():
        client = common.Scryer.saved()
        try:
            client.require_safe()
            return client
        except Exception:
            # A valid key with unsafe settings must still be reused.
            try:
                client.graphql('query{recycleBinSettings{enabled}}')
                return client
            except Exception:
                pass
    client = common.Scryer()
    pending = common.PASSWORD.with_name('scryer-admin-password.pending')
    try:
        login = client.mutate('login', 'LoginInput',
            {'username': 'admin', 'password': common.protected_read(common.PASSWORD).strip()},
            'token passwordChangeRequired')
    except Exception:
        # Recover a completed server change interrupted before local publication.
        replacement = common.protected_read(pending).strip()
        login = client.mutate('login', 'LoginInput',
            {'username': 'admin', 'password': replacement}, 'token passwordChangeRequired')
        common.protected_write(common.PASSWORD, replacement + '\n')
        pending.unlink()
    client.key = login['token']
    if login['passwordChangeRequired']:
        if not pending.exists():
            common.protected_write(pending, secrets.token_urlsafe(48) + '\n')
        replacement = common.protected_read(pending).strip()
        result = client.mutate('completeRequiredPasswordChange', 'CompleteRequiredPasswordChangeInput',
                              {'password': replacement}, 'token passwordChangeRequired')
        if not result['token'] or result['passwordChangeRequired']:
            raise ValueError('required password change incomplete')
        client.key = result['token']
        common.protected_write(common.PASSWORD, replacement + '\n')
        pending.unlink()
    key = client.mutate('createMyApiKey', 'CreateMyApiKeyInput',
                        {'label': 'mountainous', 'expiry': 'NEVER'}, 'apiKey')['apiKey']
    common.protected_write(common.IDENTITY, json.dumps(
        {'username': 'admin', 'password_file': str(common.PASSWORD), 'api_key': key}) + '\n')
    return common.Scryer(key)


def main():
    parser = common.ArgumentParser(description=__doc__)
    parser.add_argument('--open-gate', action='store_true')
    parser.add_argument('--plugins', action='store_true')
    parser.add_argument('--acquisition', choices=['off', 'on'], default='off')
    args = parser.parse_args()
    common.root_only()
    bootstrap(args.open_gate)
    try:
        ready = common.request('http://127.0.0.1:8080/health/ready')
        if ready.get('ready') is not True:
            raise ValueError('not ready')
    except Exception:
        print('Credentials prepared; start Scryer, then run provision again')
        return
    client = authenticate()
    print('Protected API identity prepared')
    apply_settings(client, args.acquisition == 'on')
    print('Pre-import settings verified')
    profiles(client)
    print('Quality profiles verified')
    if args.plugins:
        for plugin in ('transmission', 'jellyfin'):
            source = Path(os.environ['MEDIA_SCRYER_PLUGIN_' + plugin.upper()])
            wasm = subprocess.run(['zstd', '-d', '-c', str(source)], capture_output=True, check=True).stdout
            client.mutate('installUploadedPlugin', 'ManualPluginUploadInput',
                          {'fileName': plugin + '.wasm', 'wasmBase64': base64.b64encode(wasm).decode(),
                           'acknowledgeRisk': True}, 'id name version')
    if not client.graphql('mutation{completeSetup{completed}}')['completeSetup']['completed']:
        raise ValueError('setup incomplete')
    print('Scryer settings and six quality profiles verified; credentials remain protected')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Refused: Scryer provisioning failed', file=sys.stderr)
        sys.exit(1)
