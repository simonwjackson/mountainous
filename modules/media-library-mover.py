#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Publish verified aged imports through the mapped library view without replacing files.

The destination view controls stored ownership. This command never changes an
existing destination's owner, mode or timestamp. It releases only the physical
local import entry after successful publication and content admission.
"""
import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import time
import urllib.parse
import urllib.request
import uuid

DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
FILE = os.O_RDONLY | os.O_NOFOLLOW


def regular_file(path, directory):
    # Pin the object without opening a FIFO or asking FUSE for nonblocking I/O.
    # The private proc descriptor then opens only that admitted regular inode.
    descriptor = os.open(path, os.O_PATH | os.O_NOFOLLOW, dir_fd=directory)
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise ValueError('non-regular file refused')
        return os.open('/proc/self/fd/' + str(descriptor), os.O_RDONLY)
    finally:
        os.close(descriptor)


def fingerprint(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def digest(descriptor):
    os.lseek(descriptor, 0, os.SEEK_SET)
    result = hashlib.sha256()
    while block := os.read(descriptor, 8 * 1024 * 1024):
        result.update(block)
    return result.digest()


def busy(info):
    # Real open descriptors, including this command's caller. No optional lsof.
    for process in Path('/proc').iterdir():
        if not process.name.isdecimal():
            continue
        try:
            descriptors = list((process / 'fd').iterdir())
        except (FileNotFoundError, PermissionError):
            continue
        for descriptor in descriptors:
            try:
                other = descriptor.stat()
            except (FileNotFoundError, PermissionError):
                continue
            if stat.S_ISREG(other.st_mode) and (other.st_dev, other.st_ino) == (info.st_dev, info.st_ino):
                return True
    return False


def candidates(root, cutoff):
    result = []

    def walk(directory, relative, device):
        for name in os.listdir(directory):
            if name.startswith('.'):
                continue
            info = os.stat(name, dir_fd=directory, follow_symlinks=False)
            if info.st_dev != device or stat.S_ISLNK(info.st_mode):
                raise ValueError('source escape or nested mount refused')
            if stat.S_ISDIR(info.st_mode):
                child = os.open(name, DIRECTORY, dir_fd=directory)
                try:
                    walk(child, relative + [name], device)
                finally:
                    os.close(child)
            elif stat.S_ISREG(info.st_mode):
                if info.st_mtime <= cutoff:
                    result.append((info.st_mtime_ns, relative + [name]))
            else:
                raise ValueError('unsupported source object')

    walk(root, [], os.fstat(root).st_dev)
    return sorted(result)


def parent(root, parts, create=False):
    current = os.dup(root)
    try:
        for name in parts:
            if name in ('', '.', '..') or '/' in name:
                raise ValueError('invalid relative path')
            if create:
                try:
                    os.mkdir(name, mode=0o2775, dir_fd=current)
                    os.fsync(current)
                except FileExistsError:
                    pass
            next_directory = os.open(name, DIRECTORY, dir_fd=current)
            os.close(current)
            current = next_directory
        return current
    except Exception:
        os.close(current)
        raise


def mark_refresh_pending(path):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('refresh admission receipt is not protected')
        os.write(descriptor, b'pending\n')
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    directory = os.open(Path(path).parent, DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def move_file(source_root, destination_root, parts, pending_refresh=None):
    source_parent = parent(source_root, parts[:-1])
    destination_parent = None
    source = destination = None
    temporary = None
    try:
        name = parts[-1]
        before = os.stat(name, dir_fd=source_parent, follow_symlinks=False)
        if not stat.S_ISREG(before.st_mode):
            raise ValueError('source is not a regular file')
        if busy(before):
            return None
        source = regular_file(name, source_parent)
        if fingerprint(os.fstat(source)) != fingerprint(before):
            raise ValueError('source changed before copy')
        destination_parent = parent(destination_root, parts[:-1], create=True)
        wanted = digest(source)
        try:
            destination = regular_file(name, destination_parent)
        except FileNotFoundError:
            temporary = '.media-handoff-' + uuid.uuid4().hex
            destination = os.open(temporary, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                  0o600, dir_fd=destination_parent)
            os.lseek(source, 0, os.SEEK_SET)
            while block := os.read(source, 8 * 1024 * 1024):
                view = memoryview(block)
                while view:
                    written = os.write(destination, view)
                    if written <= 0:
                        raise OSError('destination copy made no progress')
                    view = view[written:]
            os.fchmod(destination, stat.S_IMODE(before.st_mode))
            for attribute in os.listxattr(source):
                if not attribute.startswith('user.'):
                    raise ValueError('unmapped source metadata requires admission')
                os.setxattr(destination, attribute, os.getxattr(source, attribute))
            os.utime(destination, ns=(before.st_atime_ns, before.st_mtime_ns))
            os.fsync(destination)
            if os.fstat(destination).st_size != before.st_size or digest(destination) != wanted:
                raise ValueError('destination content admission failed')
            # An atomic no-replace publication, including a competing creator.
            os.link(temporary, name, src_dir_fd=destination_parent,
                    dst_dir_fd=destination_parent, follow_symlinks=False)
            os.unlink(temporary, dir_fd=destination_parent)
            temporary = None
        if not stat.S_ISREG(os.fstat(destination).st_mode) or digest(destination) != wanted:
            raise ValueError('destination collision: original files retained')
        if fingerprint(os.fstat(source)) != fingerprint(before) or digest(source) != wanted:
            raise ValueError('source changed during handoff')
        current = os.stat(name, dir_fd=source_parent, follow_symlinks=False)
        if fingerprint(current) != fingerprint(before):
            raise ValueError('source entry changed during handoff')
        os.close(source)
        source = None
        if busy(before):
            return None
        published = os.stat(name, dir_fd=destination_parent, follow_symlinks=False)
        if fingerprint(published) != fingerprint(os.fstat(destination)):
            raise ValueError('published destination entry changed')
        os.fsync(destination_parent)
        if pending_refresh is not None:
            mark_refresh_pending(pending_refresh)
        os.unlink(name, dir_fd=source_parent)
        os.fsync(source_parent)
        return before.st_size
    finally:
        for descriptor in [source, destination, source_parent, destination_parent]:
            if descriptor is not None:
                os.close(descriptor)
        # Retain incomplete temporary data on failure for protected recovery.


def handoff(source, destination, *, min_age_seconds=300, mode='nightly', min_free_percent=10, pending_refresh=None):
    if mode not in ('nightly', 'low-space') or min_age_seconds < 0 or not 0 <= min_free_percent <= 100:
        raise ValueError('invalid handoff policy')
    source, destination = Path(source), Path(destination)
    if source.resolve() == destination.resolve() or source.resolve().is_relative_to(destination.resolve()) or destination.resolve().is_relative_to(source.resolve()):
        raise ValueError('source and destination overlap')
    source_fd = os.open(source, DIRECTORY)
    destination_fd = os.open(destination, DIRECTORY)
    libraries = []
    moved_files = moved_bytes = 0
    try:
        # Admit both physical roots before releasing any local import.
        for part in ('movies', 'tv'):
            libraries.append((part, os.open(part, DIRECTORY, dir_fd=source_fd),
                              os.open(part, DIRECTORY, dir_fd=destination_fd)))
        def enough_space():
            space = os.fstatvfs(source_fd)
            return space.f_bavail * 100 > space.f_blocks * min_free_percent
        if mode == 'low-space' and enough_space():
            return {'moved_files': 0, 'moved_bytes': 0}
        for _, local, stored in libraries:
            for _, parts in candidates(local, time.time() - min_age_seconds):
                size = move_file(local, stored, parts, pending_refresh)
                if size is not None:
                    moved_files += 1
                    moved_bytes += size
                if mode == 'low-space' and enough_space():
                    break
        cleanup_path = Path(__file__).with_name('media-library-cleanup.py')
        spec = importlib.util.spec_from_file_location('cleanup', cleanup_path)
        cleanup = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cleanup)
        cleanup.prune_empty_titles(source)
        return {'moved_files': moved_files, 'moved_bytes': moved_bytes}
    finally:
        for _, local, stored in libraries:
            os.close(local)
            os.close(stored)
        os.close(source_fd)
        os.close(destination_fd)


def refresh_library(config):
    descriptor = os.open(config, FILE)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('refresh connection is not protected')
        with os.fdopen(os.dup(descriptor)) as stream:
            connection = json.load(stream)
    finally:
        os.close(descriptor)
    address = urllib.parse.urlsplit(connection['url'])
    if address.scheme not in ('http', 'https') or address.username or address.password or address.query or address.fragment or not connection.get('api_key'):
        raise ValueError('invalid retained library connection')
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, request, file, code, message, headers, new_url):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    request = urllib.request.Request(connection['url'].rstrip('/') + '/Library/Refresh', data=b'',
                                     headers={'X-Emby-Token': connection['api_key']}, method='POST')
    with opener.open(request, timeout=30) as response:
        if response.status not in (200, 204):
            raise ValueError('library refresh failed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--min-age-seconds', type=int, default=300)
    parser.add_argument('--mode', choices=['nightly', 'low-space'], default='nightly')
    parser.add_argument('--min-free-percent', type=int, default=10)
    parser.add_argument('--refresh-config', type=Path)
    parser.add_argument('--refresh-pending', type=Path, default=Path('/var/lib/media-migration/library-handoff/refresh-pending'))
    args = parser.parse_args()
    try:
        with open('/run/media-library-mover/lock', 'a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print(json.dumps({'already_running': True, 'moved_files': 0, 'moved_bytes': 0}))
                raise SystemExit(0)
            result = handoff(args.source, args.destination, min_age_seconds=args.min_age_seconds,
                             mode=args.mode, min_free_percent=args.min_free_percent,
                             pending_refresh=args.refresh_pending if args.refresh_config else None)
            if args.refresh_config and args.refresh_pending.exists():
                refresh_library(args.refresh_config)
                args.refresh_pending.unlink()
                directory = os.open(args.refresh_pending.parent, DIRECTORY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)
                result['library_refresh_accepted'] = True
            print(json.dumps(result))
    except Exception as error:
        print(json.dumps({'handoff_stopped': True, 'error_type': type(error).__name__, 'errno': getattr(error, 'errno', None), 'failure_site': [{'function': frame.name, 'line': frame.lineno} for frame in __import__('traceback').extract_tb(error.__traceback__)]}), file=__import__('sys').stderr)
        print('Library handoff stopped. Published files and remaining local imports are retained.', file=__import__('sys').stderr)
        raise SystemExit(1)
