#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Apply service-owned NZBFAST settings without exposing provider or API credentials."""
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile


def prepare(directory, held):
    directory = Path(directory)
    path = directory / "settings.json"
    settings = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(settings, dict):
        raise ValueError("settings must be an object")
    if held:
        # tasks.rs:89-108 replays a saved schedule AFTER restore_pause.
        # Refuse conflicts without removing the operator's standing rules.
        schedule = settings.get("schedule")
        if schedule is not None:
            if isinstance(schedule, str):
                schedule = json.loads(schedule) if schedule else []
            if not isinstance(schedule, list) or schedule:
                raise ValueError("held startup requires an empty schedule")
        # daemon_shutdown.rs:876-887 resumes an expired saved timer or arms
        # a future auto-resume. Admission must not silently erase that intent.
        if settings.get("pause_until_unix") is not None:
            raise ValueError("held startup refuses a saved auto-resume deadline")
    # bootstrap.rs:673 treats pre-seeded settings as an existing install and
    # skips first_run_apikey. Mint privately before the first service start.
    apikey = settings.get("apikey")
    if apikey is not None and not isinstance(apikey, str):
        raise ValueError("API key must be a string")
    if not (apikey or "").strip():
        keyfile = directory / "apikey"
        if keyfile.exists():
            if not keyfile.read_text().strip():
                raise ValueError("existing API key is empty")
        elif (directory / ".spool").exists():
            raise ValueError("existing state has no API key")
        else:
            settings["apikey"] = secrets.token_hex(32)
    settings.update({"auto_rename": False, "spot_enabled": False, "index_enabled": False,
        "identity_lookup": False, "update_checks": False, "delete_to_trash": False,
        "categories": "Series, Movies", "cat_meta": {"Series": {"dir": "Series"}, "Movies": {"dir": "Movies"}},
        "out_umask": "002"})
    # Held admission already rejected any deadline. Enabled startup removes
    # old pause bookkeeping when explicitly releasing the service hold.
    for key in ("paused", "offline", "pause_until_unix", "paused_by_offline"):
        settings.pop(key, None)
    if held:
        settings.update({"paused": True, "offline": True})
    descriptor, temporary = tempfile.mkstemp(prefix=".settings-", dir=directory)
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(settings, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        prepare(sys.argv[1], {"held": True, "enabled": False}[sys.argv[2]])
    except Exception:
        print("Refused NZBFAST settings preparation: private state invalid", file=sys.stderr)
        sys.exit(1)
