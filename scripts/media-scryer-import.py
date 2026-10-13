#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Warm up, preview and finalize a catalog import. Never execute client import."""
import importlib.util
from pathlib import Path
import sys
import time


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name('media-scryer-' + name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


common = load('common')
parity = load('parity')


def poll(client, session, deadline):
    while time.monotonic() < deadline:
        progress = client.graphql('query($id:ID!){externalImportWarmupStatus(sessionId:$id){status}}',
                                  {'id': session})['externalImportWarmupStatus']
        if progress['status'] == 'COMPLETED':
            return
        if progress['status'] not in ('QUEUED', 'RUNNING'):
            raise ValueError('warmup failed')
        time.sleep(2)
    raise ValueError('warmup timeout')


def scan_imported_libraries(client, mappings, monitor_session, deadline):
    # finalize prepares snapshots, not a catalog. Follow the upstream wizard's
    # hinted scan step; never poll the reserved monitor snapshot key as a job.
    sessions = []
    for library in sorted({mapping['libraryId'] for mapping in mappings}):
        scan = client.mutate('scanLibrary', 'ScanLibraryInput',
                             {'libraryId': library, 'importWarmupSessionId': monitor_session},
                             'sessionId status')
        sessions.append(scan['sessionId'])
    for session in sessions:
        while time.monotonic() < deadline:
            progress = client.graphql('query($id:ID!){libraryScanSession(sessionId:$id){status}}',
                                      {'id': session})['libraryScanSession']
            if progress and progress['status'] == 'COMPLETED':
                break
            if not progress or progress['status'] not in ('DISCOVERING', 'RUNNING'):
                raise ValueError('library scan incomplete')
            time.sleep(2)
        else:
            raise ValueError('library scan timeout')


def add_missing_source_titles(client, source):
    """Metadata only: addTitle, never addTitleAndQueueDownload or source hints."""
    client.require_held_import()
    target = {t['key']: t for t in parity.target_catalog(client)}
    libraries = client.graphql('query{libraries{id facet roots{id path}}}')['libraries']
    profiles = client.graphql('query{qualityProfileSettings{profiles{id name}}}')['qualityProfileSettings']['profiles']
    profile_ids = {}
    for profile in profiles:
        profile_ids.setdefault(profile['name'], []).append(profile['id'])
    added = 0
    for original in source:
        if original['key'] in target:
            continue
        provider, identity = original['key'].split(':', 1)
        facet = 'MOVIE' if provider == 'tmdb' else 'SERIES'
        if provider not in ('tmdb', 'tvdb') or int(identity) <= 0 or original['root'] != common.SCOPES[facet]:
            raise ValueError('unsupported source identity or root')
        roots = [(library['id'], root['id']) for library in libraries if library['facet'] == facet
                 for root in library['roots'] if root['path'] == original['root']]
        ids = profile_ids.get(original['quality_profile'], [])
        if len(roots) != 1 or len(ids) != 1:
            raise ValueError('source library or profile missing or ambiguous')
        library, root = roots[0]
        result = client.mutate('addTitle', 'AddTitleInput',
            {'name': original['name'], 'facet': facet, 'libraryId': library,
             'monitored': original['monitored'], 'tags': [], 'year': original.get('year'),
             'externalIds': [{'source': provider, 'value': identity}],
             'options': {'rootFolderId': root, 'qualityProfileId': ids[0]}},
            'title{id monitored rootFolderId externalIds{source value}} downloadJobId reusedQueuedDownload')
        title = result['title']
        if (result['downloadJobId'] is not None or result['reusedQueuedDownload']
                or title['monitored'] != original['monitored'] or title['rootFolderId'] != root
                or not any(i['source'] == provider and i['value'] == identity for i in title['externalIds'])):
            raise ValueError('metadata-only title add verification failed')
        target[original['key']] = title
        added += 1
    client.require_held_import()
    return added


def await_source_metadata(client, source, deadline):
    # Monitoring snapshots only update existing seasons/episodes. Wait for the
    # addTitle hydration worker before the scan consumes those snapshots.
    while time.monotonic() < deadline:
        target = {t['key']: t for t in parity.target_catalog(client)}
        if all(t['key'] in target and set(t['seasons']).issubset(target[t['key']]['seasons'])
               and set(t['episodes']).issubset(target[t['key']]['episodes']) for t in source):
            return
        client.require_held_import()
        time.sleep(2)
    raise ValueError('source metadata coverage incomplete')


def quality_overrides(client):
    profiles = client.graphql('query{qualityProfileSettings{profiles{id name}}}')['qualityProfileSettings']['profiles']
    by_name = {}
    for profile in profiles:
        if profile['name'] in by_name:
            raise ValueError('ambiguous quality profile')
        by_name[profile['name']] = profile['id']
    target = {t['key']: t for t in parity.target_catalog(client)}
    for source in parity.source_catalog():
        found = target.get(source['key'])
        if found is None:
            raise ValueError('source title missing after import')
        name = source['quality_profile']
        if found['quality_profile'] != name:
            if name not in by_name:
                raise ValueError('source profile has no target mapping')
            client.mutate('updateTitle', 'UpdateTitleInput',
                          {'titleId': found['id'], 'options': {'qualityProfileId': by_name[name]}}, 'id')
    counts, mismatches = parity.compare(parity.source_catalog(), parity.target_catalog(client))
    if any('quality_profile' in mismatch for mismatch in mismatches):
        raise ValueError('quality override verification failed')
    print('Per-title quality profile names verified')


def main():
    parser = common.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout', type=int, default=3600)
    args = parser.parse_args()
    if not 1 <= args.timeout <= 86400:
        raise ValueError('invalid timeout')
    common.root_only()
    client = common.Scryer.saved()
    client.require_held_import()
    sessions = []
    for name in common.ARR:
        connection = common.Arr(name).connection()
        input_value = {'kind': name.upper(), 'connection': connection}
        valid = client.mutate('validateExternalImportConnection', 'ValidateExternalImportConnectionInput',
                              input_value, 'connected')
        if not valid['connected']:
            raise ValueError('source unavailable')
        warmup = client.mutate('startExternalImportArrSourceWarmup', 'StartExternalImportArrSourceWarmupInput',
                               input_value, 'sessionId status')
        sessions.append(warmup['sessionId'])
    deadline = time.monotonic() + args.timeout
    for session in sessions:
        poll(client, session, deadline)
    preview = client.mutate('previewExternalImport', 'PreviewExternalImportInput',
        {'sourceWarmupSessionIds': sessions},
        'arrSources{sessionId sourceKey kind connected status} rootFolders{sourceWarmupSessionId sourceKey kind arrRootPath}')
    if len(preview['arrSources']) != 2 or any(not s['connected'] or s['status'] != 'COMPLETED'
                                             for s in preview['arrSources']):
        raise ValueError('preview incomplete')
    libraries = client.graphql('query{libraries{id facet isDefault roots{path}}}')['libraries']
    mappings = []
    for root in preview['rootFolders']:
        facet = 'SERIES' if root['kind'] == 'SONARR' else 'MOVIE'
        path = common.SCOPES[facet]
        if root['arrRootPath'] != path:
            raise ValueError('unexpected source root')
        matches = [library for library in libraries if library['facet'] == facet
                   and any(r['path'] == path for r in library['roots'])]
        if len(matches) != 1:
            raise ValueError('library root missing or ambiguous')
        mappings.append({'sourceWarmupSessionId': root['sourceWarmupSessionId'],
                         'sourceKey': root['sourceKey'], 'kind': root['kind'],
                         'arrRootPath': path, 'scryerRootPath': path, 'facet': facet,
                         'libraryId': matches[0]['id']})
    if {m['facet'] for m in mappings} != {'SERIES', 'MOVIE'}:
        raise ValueError('preview roots incomplete')
    before = client.require_held_import()
    finalized = client.mutate('finalizeExternalImport', 'FinalizeExternalImportInput',
                              {'sourceWarmupSessionIds': sessions, 'mappings': mappings},
                              'finalizeSessionId monitorWarmupSessionId')
    poll(client, finalized['finalizeSessionId'], deadline)
    after = client.require_held_import()
    if before != after:
        raise ValueError('import changed protected settings')
    source = parity.source_catalog()
    print('Metadata-only titles added=' + str(add_missing_source_titles(client, source)))
    await_source_metadata(client, source, deadline)
    client.require_held_import()
    scan_imported_libraries(client, mappings, finalized['monitorWarmupSessionId'], deadline)
    if client.require_held_import() != before:
        raise ValueError('scan changed protected settings')
    for tmdb, title, year in [(863, 'Toy Story 2', 1999),
                              (502356, 'The Super Mario Bros. Movie', 2023)]:
        client.mutate('addListExclusion', 'AddListExclusionInput',
                      {'kind': 'MOVIE', 'externalIds': [{'source': 'tmdb', 'value': str(tmdb)}],
                       'displayTitle': title, 'year': year, 'scope': 'ALL_LISTS'}, 'id')
    quality_overrides(client)
    if client.require_held_import() != before:
        raise ValueError('protected settings changed')
    print('Catalog finalization completed; run media-scryer-parity before cutover')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Refused: Scryer import failed; inspect held state before retry', file=sys.stderr)
        sys.exit(1)
