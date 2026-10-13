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
import time

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)

PROFILE_TIERS = {
    'Any': ['4320P', '2160P', '1080P', '720P', '576P', '480P'],
    'SD': ['576P', '480P'], 'HD-720p': ['720P'], 'HD-1080p': ['1080P'],
    'Ultra-HD': ['2160P'], 'HD - 720p/1080p': ['1080P', '720P'],
}


CRITERIA_FIELDS = ('qualityTiers archivalQuality allowUnknownQuality sourceAllowlist sourceBlocklist '
    'videoCodecAllowlist videoCodecBlocklist audioCodecAllowlist audioCodecBlocklist '
    'dolbyVisionAllowed detectedHdrAllowed preferRemux allowBdDisk allowUpgrades cutoffTier '
    'minScoreToGrab cutoffScore scoringOverrides{allowX265Non4K blockDvWithoutFallback '
    'preferCompactEncodes preferLosslessAudio blockUpscaled}')


def source_upgrade_policy(source_profiles):
    policy = {}
    for profiles in source_profiles:
        for profile in profiles:
            name, allowed = profile['name'], profile['upgradeAllowed']
            if not isinstance(allowed, bool) or (name in policy and policy[name] != allowed):
                raise ValueError('source upgrade policy ambiguous')
            policy[name] = allowed
    return policy


def profiles(client, upgrade_policy=None):
    print('Reading quality profile criteria')
    current = client.graphql('query{qualityProfileSettings{profiles{id name criteria{' + CRITERIA_FIELDS + '}} globalProfileId globalScoringPersona}}')['qualityProfileSettings']
    existing = {p['name']: p['id'] for p in current['profiles']}
    upgrade_policy = upgrade_policy or {}
    wanted = []
    for index, (name, tiers) in enumerate(PROFILE_TIERS.items()):
        criteria = {'qualityTiers': tiers, 'archivalQuality': tiers[0],
                    'allowUnknownQuality': name == 'Any', 'sourceAllowlist': [],
                    'sourceBlocklist': [], 'videoCodecAllowlist': [], 'videoCodecBlocklist': [],
                    'audioCodecAllowlist': [], 'audioCodecBlocklist': [],
                    'dolbyVisionAllowed': True, 'detectedHdrAllowed': True, 'preferRemux': False,
                    'allowBdDisk': False, 'allowUpgrades': upgrade_policy.get(name, False), 'scoringOverrides': {},
                    'cutoffTier': tiers[0]}
        wanted.append({'id': existing.get(name, f'mountainous-{index}'), 'name': name,
                       'criteria': criteria})
    # Existing unrelated or built-in profiles must also stay held. Preserve
    # their other criteria and selections; names shared by source apps must agree.
    wanted_ids = {profile['id'] for profile in wanted}
    for profile in current['profiles']:
        if profile['id'] not in wanted_ids:
            profile['criteria']['allowUpgrades'] = upgrade_policy.get(profile['name'], False)
            wanted.append(profile)
    print('Applying quality profile upgrade policy')
    client.mutate('saveQualityProfileSettings', 'SaveQualityProfileSettingsInput',
                  {'profiles': wanted, 'globalProfileId': current['globalProfileId'],
                   'globalScoringPersona': current['globalScoringPersona'],
                   'categorySelections': [], 'categoryPersonaSelections': [],
                   'replaceExisting': False}, 'profiles{id name}')
    criteria_fields = CRITERIA_FIELDS
    actual = client.graphql('query{qualityProfileSettings{profiles{id name criteria{' + criteria_fields
                            + '}}}}')['qualityProfileSettings']['profiles']
    print('Verifying quality profile criteria')
    by_id = {p['id']: p for p in actual}
    for expected in wanted:
        found = by_id[expected['id']]
        if found['name'] != expected['name']:
            raise ValueError('profile verification failed')
        for key in expected['criteria']:
            if key != 'scoringOverrides' and found['criteria'][key] != expected['criteria'][key]:
                print('Profile criterion verification failed: ' + key, file=sys.stderr)
                raise ValueError('profile verification failed')


def set_acquisition(client, enabled):
    selection = ('enabled sameTierMinDelta pollIntervalSeconds walkIntervalSeconds '
                 'longTailBackfillMaxScopesPerCycle longTailReconvergeDays')
    value = client.graphql('query{acquisitionSettings{' + selection + '}}')['acquisitionSettings']
    value['enabled'] = enabled
    client.mutate('updateAcquisitionSettings', 'UpdateAcquisitionSettingsInput', value, 'enabled')
    if client.graphql('query{acquisitionSettings{enabled}}')['acquisitionSettings']['enabled'] is not enabled:
        raise ValueError('acquisition verification failed')


def media_settings_input(scope):
    # An explicit facet value prevents finalize from creating a library override.
    # Empty source chownGroup is filtered by finalize; keep permission writes off.
    return {'scope': scope, 'renameEnabled': False, 'importMode': 'HARDLINK_OR_COPY',
            'libraryPath': common.SCOPES[scope], 'setPermissionsLinux': False,
            'folderChmod': '755', 'chownGroup': '', 'nfoWriteOnImport': False,
            **({'plexmatchWriteOnImport': False} if scope != 'MOVIE' else {})}


# New imports only. Sonarr and Radarr kept renaming off but named every import
# after its release (SceneName), so an obfuscated post never reached the library
# as a hash. Scryer with renaming off keeps the downloaded filename
# (scryer-application/src/import/workflow/paths.rs:518), and hash names stop
# Jellyfin parsing SxxEyy. These mirror the formats configured in Sonarr
# ({Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full})
# and Radarr ({Movie Title} ({Release Year}) {Quality Full}). Existing files are
# never renamed: that needs an explicit rename plan (library/rename.rs:300-530).
RENAME_TEMPLATES = {
    'SERIES': '{title} - S{season:2}E{episode:2}{?episode_title: - {episode_title}} {quality}.{ext}',
    'ANIME': '{title} - S{season_order:2}E{episode:2}{?episode_title: - {episode_title}} {quality}.{ext}',
    'MOVIE': '{title} ({year}) {quality}.{ext}',
}


def apply_rename_templates(client):
    for scope, template in RENAME_TEMPLATES.items():
        client.mutate('updateMediaSettings', 'UpdateMediaSettingsInput',
                      {'scope': scope, 'renameEnabled': True, 'renameTemplate': template}, 'renameEnabled')
        saved = client.graphql('query{mediaSettings(scope:' + scope + '){renameEnabled renameTemplate}}')['mediaSettings']
        if saved != {'renameEnabled': True, 'renameTemplate': template}:
            raise ValueError('rename template verification failed')
    recycle = client.graphql('query{recycleBinSettings{enabled}}')['recycleBinSettings']['enabled']
    if recycle is not False:
        raise ValueError('recycle bin must stay off')


def apply_settings(client):
    for scope, path in common.SCOPES.items():
        print('Applying media settings: ' + scope)
        client.mutate('updateMediaSettings', 'UpdateMediaSettingsInput',
                      media_settings_input(scope), 'renameEnabled importMode libraryPath')
        permissions = client.graphql('query{mediaSettings(scope:' + scope
                                     + '){setPermissionsLinux folderChmod chownGroup}}')['mediaSettings']
        if permissions != {'setPermissionsLinux': False, 'folderChmod': '755', 'chownGroup': None}:
            raise ValueError('permission settings verification failed')
    print('Applying recycle-bin settings')
    client.mutate('updateRecycleBinSettings', 'UpdateRecycleBinSettingsInput',
                  {'enabled': False}, 'enabled')
    print('Applying acquisition settings')
    set_acquisition(client, False)
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
    if actual != {'acquisitionSettings': {'enabled': False},
                  'subtitleSettings': {'enabled': False, 'autoDownloadOnImport': False, 'syncEnabled': False},
                  'pluginAutoUpdateSettings': {'enabled': False}}:
        raise ValueError('settings verification failed')


def bootstrap(open_gate):
    common.CREDENTIALS.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = common.CREDENTIALS.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('invalid credentials directory')
    common.fsync_directory(common.CREDENTIALS.parent)
    if not common.PASSWORD.exists():
        fd = os.open(common.PASSWORD, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(secrets.token_urlsafe(48) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        common.fsync_directory(common.PASSWORD.parent)
    if not common.protected_read(common.PASSWORD).strip():
        raise ValueError('empty password')
    if open_gate:
        gate = Path('/var/lib/media-migration/ready')
        gate.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = gate.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError('invalid gate directory')
        common.fsync_directory(gate.parent)
        fd = os.open(gate / 'scryer', os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        os.fsync(fd)
        os.close(fd)
        common.fsync_directory(gate)


def password_login(client):
    pending = common.PASSWORD.with_name('scryer-admin-password.pending')
    password = common.protected_read(common.PASSWORD).strip()
    replacement = common.protected_read(pending).strip() if pending.exists() else None
    accepted = []
    for candidate in dict.fromkeys([password] + ([replacement] if replacement is not None else [])):
        try:
            result = client.mutate('login', 'LoginInput', {'username': 'admin', 'password': candidate},
                                   'token passwordChangeRequired')
            accepted.append((candidate, result))
        except Exception:
            continue
    if not accepted:
        raise ValueError('password recovery refused')
    password, login = accepted[-1]
    client.key = login['token']
    if login['passwordChangeRequired']:
        if replacement is None:
            replacement = secrets.token_urlsafe(48)
        # File AND containing directory are durable before the server call,
        # including a pending file created by an older command version.
        common.protected_write(pending, replacement + '\n')
        changed = client.mutate('completeRequiredPasswordChange', 'CompleteRequiredPasswordChangeInput',
                                {'password': replacement}, 'token passwordChangeRequired')
        if not changed['token'] or changed['passwordChangeRequired']:
            raise ValueError('required password change incomplete')
        client.key = changed['token']
        password = replacement
    # Also cleans a pending file left after local publication, or before a
    # mutation that never ran. The successful server login is authoritative.
    if pending.exists():
        common.protected_write(common.PASSWORD, password + '\n')
        common.protected_unlink(pending)
    return client


def authenticate():
    # Recover a pending password even when a saved API key is still valid.
    pending = common.PASSWORD.with_name('scryer-admin-password.pending')
    login_client = password_login(common.Scryer()) if pending.exists() else None
    if common.IDENTITY.exists():
        client = common.Scryer.saved()
        try:
            client.graphql('query{recycleBinSettings{enabled}}')
            return client
        except Exception:
            pass
    client = login_client or password_login(common.Scryer())
    key = client.mutate('createMyApiKey', 'CreateMyApiKeyInput',
                        {'label': 'mountainous', 'expiry': 'NEVER'}, 'apiKey')['apiKey']
    common.protected_write(common.IDENTITY, json.dumps(
        {'username': 'admin', 'password_file': str(common.PASSWORD), 'api_key': key}) + '\n')
    return common.Scryer(key)


def enable_acquisition_and_restart(client):
    set_acquisition(client, True)
    subprocess.run(['systemctl', 'restart', 'scryer.service'], capture_output=True,
                   check=True, timeout=200)
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        try:
            if common.request('http://127.0.0.1:8080/health/ready').get('ready') is True:
                break
        except Exception:
            pass
        time.sleep(1)
    else:
        raise ValueError('Scryer readiness timeout')
    # A saved API key must not substitute for the required post-restart login.
    session = password_login(common.Scryer())
    if session.graphql('query{acquisitionSettings{enabled}}')['acquisitionSettings']['enabled'] is not True:
        raise ValueError('acquisition not enabled after restart')
    invocation = subprocess.run(['systemctl', 'show', 'scryer.service', '-p', 'InvocationID', '--value'],
                                capture_output=True, text=True, check=True).stdout.strip()
    if not invocation:
        raise ValueError('missing service invocation')
    while time.monotonic() < deadline:
        journal = subprocess.run(['journalctl', '-u', 'scryer.service',
                                  '_SYSTEMD_INVOCATION_ID=' + invocation, '--no-pager', '-o', 'cat'],
                                 capture_output=True, text=True, check=True).stdout
        if 'background acquisition poller started' in journal:
            print('Acquisition enabled; fresh service poller verified')
            return
        time.sleep(1)
    raise ValueError('acquisition poller startup not observed')


def main():
    parser = common.ArgumentParser(description=__doc__)
    parser.add_argument('--open-gate', action='store_true')
    parser.add_argument('--plugins', action='store_true')
    parser.add_argument('--upgrades', choices=['off', 'match-source'], default='off')
    parser.add_argument('--source-archive', type=Path)
    parser.add_argument('--acquisition', choices=['off', 'on'], default='off')
    parser.add_argument('--rename', choices=['off', 'templates'], default='off')
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
    enabling = False
    try:
        # Disarm first, even if a requested source policy later proves invalid.
        set_acquisition(client, False)
        policy = None
        if args.upgrades == 'match-source':
            sources = [json.loads(common.protected_read(args.source_archive / (name + '-qualityprofile.json')))
                       if args.source_archive else common.Arr(name).get('qualityprofile') for name in common.ARR]
            policy = source_upgrade_policy(sources)
        elif args.source_archive:
            raise ValueError('archive requires match-source')
        apply_settings(client)
        print('Pre-import settings verified')
        profiles(client, policy)
        if args.upgrades == 'off':
            client.require_held_import()
        print('Quality profiles verified')
        if args.rename == 'templates':
            # After every held check: renaming is a post-cutover setting.
            apply_rename_templates(client)
            print('New-import rename templates verified; existing files are not renamed')
        if args.plugins:
            for plugin in ('transmission', 'jellyfin'):
                source = Path(os.environ['MEDIA_SCRYER_PLUGIN_' + plugin.upper()])
                wasm = subprocess.run(['zstd', '-d', '-c', str(source)], capture_output=True, check=True).stdout
                client.mutate('installUploadedPlugin', 'ManualPluginUploadInput',
                              {'fileName': plugin + '.wasm', 'wasmBase64': base64.b64encode(wasm).decode(),
                               'acknowledgeRisk': True}, 'id name version')
        if not client.graphql('mutation{completeSetup{completed}}')['completeSetup']['completed']:
            raise ValueError('setup incomplete')
        # Enabling is the final mutation, after every other step has passed.
        if args.acquisition == 'on':
            enabling = True
            enable_acquisition_and_restart(client)
    except Exception:
        # A failed verification must not leave a reachable service acquiring.
        # API unavailability is reported as failure; never edit its DB to recover.
        set_acquisition(client, False)
        if enabling:
            subprocess.run(['systemctl', 'restart', 'scryer.service'], capture_output=True,
                           check=True, timeout=200)
        raise
    print('Scryer settings and quality profiles verified; credentials remain protected')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Refused: Scryer provisioning failed', file=sys.stderr)
        sys.exit(1)
