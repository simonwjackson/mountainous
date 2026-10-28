"""Request compositor frames before desktop launch; never edit a locked browser.

Chromium owns Preferences while running. Local locks defer migration only
while their PID belongs to Chromium; stale locks stay for Chromium to clean up.
Foreign or unreadable locks defer migration. A login service runs before the
shell can launch apps. This is not a live preference writer or profile manager.
"""

import json
import os
import socket
import stat
import sys
import tempfile
from pathlib import Path


def locked(root: Path) -> bool:
    # Chromium uses a dangling <hostname>-<pid> symlink, not a target file.
    try:
        target = os.readlink(root / "SingletonLock")
    except FileNotFoundError:
        return False
    except OSError:
        return True  # Unknown format or unreadable lock: do not risk a writer.
    host, separator, pid = target.rpartition("-")
    if (
        not separator
        or host != socket.gethostname()
        or not pid.isascii()
        or not pid.isdecimal()
        or int(pid) <= 0
    ):
        return True
    try:
        comm = Path(f"/proc/{int(pid)}/comm").read_bytes()
    except FileNotFoundError:
        return False
    except OSError:
        return True  # An uninspectable owner is not proof of a stale lock.
    # A recycled PID belonging to another program must not block every login.
    return b"chromium" in comm.lower()


def apply(root: Path) -> None:
    if root.is_symlink() or not root.is_dir():
        return
    if locked(root):
        print(f"chromium-frame: defer locked user-data root {root}")
        return
    for profile in sorted(root.iterdir()):
        prefs = profile / "Preferences"
        if profile.is_symlink() or not profile.is_dir() or not prefs.is_file():
            continue
        if prefs.is_symlink():
            raise ValueError(f"refuse symlink {prefs}")
        original = prefs.read_bytes()
        data = json.loads(original)
        if not isinstance(data, dict) or not isinstance(data.get("browser", {}), dict):
            raise TypeError(f"invalid browser preferences in {prefs}")
        if data.get("browser", {}).get("custom_chrome_frame") is False:
            continue
        data.setdefault("browser", {})["custom_chrome_frame"] = False
        mode = stat.S_IMODE(prefs.stat().st_mode)
        fd, name = tempfile.mkstemp(prefix=".mountainous-frame-", dir=profile)
        try:
            with os.fdopen(fd, "w") as output:
                os.fchmod(output.fileno(), mode)
                json.dump(data, output, ensure_ascii=False)
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            if locked(root):
                print(f"chromium-frame: defer newly locked user-data root {root}")
                return
            backup = profile / "Preferences.before-mountainous-frame"
            try:
                # Atomically keep the original inode once. The rename below
                # gives Preferences a new inode; the backup cannot be partial.
                os.link(prefs, backup)
            except FileExistsError:
                pass
            if locked(root):
                print(f"chromium-frame: defer newly locked user-data root {root}")
                return
            os.replace(name, prefs)
            print(f"chromium-frame: set browser.custom_chrome_frame=false in {prefs}")
        finally:
            Path(name).unlink(missing_ok=True)


def main() -> int:
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    roots = [config / "chromium", home / ".local/share/mountainous/browser"]
    failed = False
    for root in roots:
        try:
            apply(root)
        except (OSError, ValueError, TypeError) as error:
            print(f"chromium-frame: {root}: {error}", file=sys.stderr)
            failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
