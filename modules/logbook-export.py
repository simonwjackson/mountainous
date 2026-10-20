#!/usr/bin/env python3
"""Publish one complete SQLite export without exposing simon's home to Logbook."""

import os
import pwd
import sqlite3
import stat
import sys
from pathlib import Path


def publish(source: Path | str, destination: Path | str, uid: int, gid: int) -> None:
    source, destination = Path(source), Path(destination)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    # The destination directory is root-owned and not writable by Logbook.
    temporary.unlink(missing_ok=True)
    try:
        with os.fdopen(os.open(source, os.O_RDONLY | os.O_NOFOLLOW), "rb") as src:
            before = os.fstat(src.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_size == 0:
                raise ValueError("export must be a non-empty regular SQLite file")
            with os.fdopen(
                os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb"
            ) as dst:
                while chunk := src.read(1024 * 1024):
                    dst.write(chunk)
                dst.flush()
                os.fchown(dst.fileno(), uid, gid)
                os.fchmod(dst.fileno(), 0o600)
                os.fsync(dst.fileno())
            after = os.fstat(src.fileno())
            current = source.stat(follow_symlinks=False)

            def signature(s: os.stat_result) -> tuple[int, int, int, int, int]:
                return (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)

            if signature(before) != signature(after) or signature(before) != signature(
                current
            ):
                raise ValueError(
                    "export changed during copy; retry after export completes"
                )
        connection = sqlite3.connect(
            temporary.resolve().as_uri() + "?mode=ro&immutable=1", uri=True
        )
        try:
            if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                raise ValueError("export SQLite integrity check failed")
        finally:
            connection.close()
        os.replace(temporary, destination)
        directory = os.open(destination.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    account = pwd.getpwnam("logbook")
    try:
        publish(sys.argv[1], sys.argv[2], account.pw_uid, account.pw_gid)
    except (OSError, ValueError, sqlite3.Error):
        # Do not log export contents or health records.
        raise SystemExit(
            "Gadgetbridge export unavailable, incomplete, or changed; retrying"
        )
