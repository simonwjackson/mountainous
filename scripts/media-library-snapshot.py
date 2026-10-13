#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Record all library entries without following symlinks; compare preservation."""
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys

spec = importlib.util.spec_from_file_location('common', Path(__file__).with_name('media-scryer-common.py'))
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)


def snapshot(roots):
    entries = {}

    def walk(path, relative):
        info = path.lstat()
        kind = ('dir' if stat.S_ISDIR(info.st_mode) else 'file' if stat.S_ISREG(info.st_mode)
                else 'symlink' if stat.S_ISLNK(info.st_mode) else 'other')
        entries[relative] = {'type': kind, 'size': info.st_size, 'mtime_ns': info.st_mtime_ns,
                             'inode': info.st_ino, 'mode': stat.S_IMODE(info.st_mode),
                             'uid': info.st_uid, 'gid': info.st_gid}
        if kind == 'symlink':
            entries[relative]['target'] = os.readlink(path)
        if kind == 'dir':
            for child in sorted(path.iterdir()):
                walk(child, relative + '/' + child.name)
    for name, root in roots.items():
        walk(Path(root), name)
    return {'format': 1, 'entries': entries}


def compare(before, after):
    if before['format'] != 1 or after['format'] != 1:
        raise ValueError('unsupported snapshot')
    a, b = before['entries'], after['entries']
    failures, warnings = [], []
    new = sorted(set(b) - set(a))
    empty_removed = []
    for name in sorted(set(a) - set(b)):
        if a[name]['type'] == 'dir' and not any(p.startswith(name + '/') for p in a):
            empty_removed.append(name)
            warnings.append('removed empty directory: ' + name)
        else:
            failures.append('missing: ' + name)
    for name in sorted(set(a) & set(b)):
        old, current = dict(a[name]), dict(b[name])
        # An allowed new entry or removed empty directory changes its parent's
        # directory size/mtime. All other metadata, including inode, is strict.
        if old['type'] == current['type'] == 'dir' and any(
                str(Path(p).parent) == name for p in new + empty_removed):
            for key in ('size', 'mtime_ns'):
                old.pop(key)
                current.pop(key)
        if old != current:
            failures.append('changed: ' + name)
    for name, entry in b.items():
        parts = Path(name).parts
        if '.scryer-recycle' in parts and (
                parts[-1] != '.scryer-recycle' or entry['type'] != 'dir'):
            failures.append('recycle bin has content: ' + name)
    return {'failures': failures, 'warnings': warnings, 'new': new}


def main():
    parser = common.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    create = commands.add_parser('create')
    create.add_argument('out', type=Path)
    check = commands.add_parser('compare')
    check.add_argument('a', type=Path)
    check.add_argument('b', type=Path)
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise ValueError('root required')
    if args.action == 'create':
        payload = snapshot({name: '/srv/range/media/' + name for name in ('tv', 'movies')})
        descriptor = os.open(args.out, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(payload, stream, sort_keys=True)
            stream.write('\n')
        print('Library snapshot created')
        return 0
    result = compare(json.loads(args.a.read_text()), json.loads(args.b.read_text()))
    for category in ('new', 'warnings', 'failures'):
        for detail in result[category]:
            print(category.upper() + ' ' + detail)
    return int(bool(result['failures']))


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        print('Refused: snapshot operation failed', file=sys.stderr)
        sys.exit(1)
