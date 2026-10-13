#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Archive read-only source history, blocklists and Radarr list exclusions."""
import importlib.util
import json
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def main():
    parser = common.ArgumentParser(description=__doc__)
    parser.add_argument('outdir', type=Path)
    args = parser.parse_args()
    common.root_only()
    args.outdir.mkdir(mode=0o700)
    for name in common.ARR:
        source = common.Arr(name)
        for resource in ('history', 'blocklist'):
            common.protected_write(args.outdir / f'{name}-{resource}.json',
                                   json.dumps(source.pages(resource), indent=2) + '\n')
        common.protected_write(args.outdir / f'{name}-qualityprofile.json',
                               json.dumps(source.get('qualityprofile'), indent=2) + '\n')
        if name == 'radarr':
            common.protected_write(args.outdir / 'radarr-exclusions.json',
                                   json.dumps(source.get('exclusions'), indent=2) + '\n')
    print('Source history, blocklists and exclusions archived; no source writes')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Refused: source archive failed', file=sys.stderr)
        sys.exit(1)
