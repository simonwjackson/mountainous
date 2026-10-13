#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Read-only catalog preservation gate, keyed by TVDb and TMDb identifiers."""
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def compare(source, target):
    mismatches = []
    counts = {'series': 0, 'movies': 0, 'seasons': 0, 'episodes': 0, 'files': 0}
    indexed = {}
    for title in target:
        key = title['key']
        if key in indexed:
            mismatches.append('duplicate target identity: ' + key)
        indexed[key] = title
    for original in source:
        key = original['key']
        counts['movies' if key.startswith('tmdb:') else 'series'] += 1
        counts['seasons'] += len(original['seasons'])
        counts['episodes'] += len(original['episodes'])
        counts['files'] += len(original['paths'])
        found = indexed.get(key)
        if found is None:
            mismatches.append('missing title: ' + key)
            continue
        for field in ('monitored', 'quality_profile'):
            if original[field] != found[field]:
                mismatches.append(f'{key}: {field} differs')
        for field in ('seasons', 'episodes'):
            for identifier, monitored in original[field].items():
                if found[field].get(identifier) != monitored:
                    mismatches.append(f'{key}: {field} {identifier} differs or missing')
        for path in original['paths']:
            if path not in found['paths']:
                mismatches.append(f'{key}: unregistered path {path}')
    return counts, mismatches


def source_catalog():
    catalog = []
    for name in common.ARR:
        api = common.Arr(name)
        profiles = {p['id']: p['name'] for p in api.get('qualityprofile')}
        for title in api.get('series' if name == 'sonarr' else 'movie'):
            series = name == 'sonarr'
            key = ('tvdb:' + str(title['tvdbId']) if series else 'tmdb:' + str(title['tmdbId']))
            seasons = {str(s['seasonNumber']): s['monitored'] for s in title.get('seasons', [])}
            episodes, paths = {}, []
            if series:
                episodes = {f"{e['seasonNumber']}:{e['episodeNumber']}": e['monitored']
                            for e in api.get('episode', seriesId=title['id'])}
                paths = [f['path'] for f in api.get('episodefile', seriesId=title['id'])]
            elif title.get('hasFile'):
                paths = [f['path'] for f in api.get('moviefile', movieId=title['id'])]
            catalog.append({'key': key, 'name': title['title'],
                            'root': title['rootFolderPath'], 'year': title.get('year'),
                            'monitored': title['monitored'], 'seasons': seasons,
                            'episodes': episodes, 'paths': paths,
                            'quality_profile': profiles[title['qualityProfileId']]})
    return catalog


def target_catalog(client):
    catalog, offset = [], 0
    while True:
        page = client.graphql('query($offset:Int!){titles(limit:300,offset:$offset){hasMore items{'
            'id facet monitored externalIds{source value} qualityTier mediaFiles{filePath} '
            'collections{collectionType collectionIndex monitored episodes{seasonNumber episodeNumber monitored}}'
            '}}}', {'offset': offset})['titles']
        for title in page['items']:
            provider = 'tmdb' if title['facet'] == 'MOVIE' else 'tvdb'
            identifiers = [i['value'] for i in title['externalIds'] if i['source'].lower() == provider]
            if len(identifiers) != 1:
                # No matchable external ID cannot satisfy a source identity.
                continue
            seasons, episodes = {}, {}
            for collection in title['collections']:
                # Scryer stores season 0 as SPECIALS, not SEASON
                # (crates/scryer-domain/src/lib.rs:1690-1696).
                if collection['collectionType'] in ('SEASON', 'SPECIALS'):
                    seasons[str(int(collection['collectionIndex']))] = collection['monitored']
                for episode in collection['episodes']:
                    if episode['seasonNumber'] is not None and episode['episodeNumber'] is not None:
                        key = f"{int(episode['seasonNumber'])}:{int(episode['episodeNumber'])}"
                        if key in episodes:
                            raise ValueError('duplicate target episode')
                        episodes[key] = episode['monitored']
            catalog.append({'key': provider + ':' + str(int(identifiers[0])), 'id': title['id'],
                            'monitored': title['monitored'], 'quality_profile': title['qualityTier'],
                            'seasons': seasons, 'episodes': episodes,
                            'paths': [f['filePath'] for f in title['mediaFiles']]})
        if not page['hasMore']:
            return catalog
        if not page['items']:
            raise ValueError('incomplete catalog pagination')
        offset += len(page['items'])


def main():
    if len(sys.argv) != 1:
        raise ValueError('invalid arguments')
    common.root_only()
    counts, mismatches = compare(source_catalog(), target_catalog(common.Scryer.saved()))
    print(' '.join(f'{key}={value}' for key, value in counts.items()))
    print(f'mismatches={len(mismatches)}')
    for message in mismatches[:20]:
        print(message)
    return int(bool(mismatches))


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        print('Refused: Scryer parity read failed', file=sys.stderr)
        sys.exit(1)
