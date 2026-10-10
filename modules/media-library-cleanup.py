#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Prune only empty descendants. Preserve staging's media and library roots."""
import errno
import os
from pathlib import Path
import stat
import sys


ROOTS = ('movies', 'tv')


def prune_empty_titles(root):
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    removed = 0

    def descendants(parent):
        nonlocal removed
        for name in os.listdir(parent):
            info = os.stat(name, dir_fd=parent, follow_symlinks=False)
            if not stat.S_ISDIR(info.st_mode):
                continue
            child = os.open(name, flags, dir_fd=parent)
            try:
                if os.fstat(child).st_dev != os.fstat(parent).st_dev:
                    raise ValueError('nested mount is outside cleanup scope')
                descendants(child)
                # Do not delete an entry replaced while the original was open.
                current = os.stat(name, dir_fd=parent, follow_symlinks=False)
                if (current.st_dev, current.st_ino) != (info.st_dev, info.st_ino):
                    raise ValueError('directory changed during cleanup')
                try:
                    os.rmdir(name, dir_fd=parent)
                    removed += 1
                except OSError as error:
                    if error.errno not in (errno.ENOTEMPTY, errno.EEXIST):
                        raise
            finally:
                os.close(child)

    descriptor = os.open(Path(root), flags)
    libraries = []
    try:
        # Admit both physical roots before deleting any title directory.
        for name in ROOTS:
            libraries.append(os.open(name, flags, dir_fd=descriptor))
        for library in libraries:
            descendants(library)
    finally:
        for library in libraries:
            os.close(library)
        os.close(descriptor)
    return removed


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('one physical media root is required')
        print('Empty title directories removed: ' + str(prune_empty_titles(sys.argv[1])))
    except Exception:
        print('Refused cleanup: media roots or directory scope are invalid', file=sys.stderr)
        sys.exit(1)
