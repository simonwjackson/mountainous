"""Merge RPC credentials into transferred state, never regenerate UI settings."""

import json
import os
import sys
from pathlib import Path


def merge(settings_path):
    password = (
        (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "transmission-rpc-password")
        .read_text()
        .rstrip("\r\n")
    )
    if not password:
        raise ValueError("empty Transmission RPC password")
    with Path(settings_path).open("r+", encoding="utf-8") as settings:
        state = json.load(settings)
        if not isinstance(state, dict):
            raise TypeError("Transmission settings must be an object")
        auth = {
            "rpc-authentication-required": True,
            "rpc-username": "torrents",
            "rpc-password": password,
        }
        # 4.1 can persist snake_case names. Remove aliases so old values cannot
        # shadow these credentials after restart or secret rotation.
        for key in auth:
            state.pop(key.replace("-", "_"), None)
        state.update(auth)
        encoded = json.dumps(state, indent=4) + "\n"
        # The file briefly contains plaintext before Transmission hashes it.
        # Do not inherit a permissive mode from transferred, auth-free state.
        os.fchmod(settings.fileno(), 0o600)
        settings.seek(0)
        settings.write(encoded)
        settings.truncate()
        settings.flush()
        os.fsync(settings.fileno())


if __name__ == "__main__":
    try:
        merge(sys.argv[1])
    except (KeyError, OSError, TypeError, ValueError):
        # A decoder error may include saved settings or credential contents.
        print(
            "Refused startup: cannot merge Transmission RPC credentials",
            file=sys.stderr,
        )
        sys.exit(1)
