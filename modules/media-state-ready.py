#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Refuse empty or damaged app state instead of starting a setup wizard."""
from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import sys
import xml.etree.ElementTree as ET

ARR = {
    "sonarr": "/var/lib/sonarr/.config/NzbDrone",
    "radarr": "/var/lib/radarr/.config/Radarr",
    "prowlarr": "/var/lib/prowlarr",
}


def pause_columns(name):
    if name == "prowlarr":
        return {"DownloadClients": ["Enable"], "Indexers": ["Enable"], "Applications": ["SyncLevel"]}
    return {"DownloadClients": ["Enable"], "Indexers": ["EnableRss", "EnableAutomaticSearch", "EnableInteractiveSearch"]}


def validate_arr_pause(name, connection):
    for table, columns in pause_columns(name).items():
        for column in columns:
            if connection.execute('SELECT count(*) FROM "' + table + '" WHERE "' + column + '" IS NULL OR "' + column + '" != 0').fetchone()[0]:
                raise ValueError("application processing is not held")
    if name != "prowlarr":
        rows = connection.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
        if len(rows) != 1 or rows[0][0].lower() != "false":
            raise ValueError("completed-download imports are not held")


def prepare_arr_pause(name, directory, receipt):
    """Hold a stopped target copy. Keep exact old flags for later approved recovery."""
    if name not in ARR:
        raise ValueError("unsupported application")
    directory, receipt = Path(directory), Path(receipt)
    if receipt.resolve().is_relative_to(directory.resolve()):
        raise ValueError("receipt must be outside application state")
    validate_arr(name, directory)
    database = directory / (name + ".db")
    with closing(sqlite3.connect("file:" + str(database) + "?mode=rw", uri=True)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        original = {"format": 1, "application": name, "flags": {}, "completed_download_handling": None}
        for table, columns in pause_columns(name).items():
            selected = ','.join('"' + column + '"' for column in ["Id"] + columns)
            original["flags"][table] = [dict(zip(["Id"] + columns, row))
                for row in db.execute('SELECT ' + selected + ' FROM "' + table + '"')]
        if name != "prowlarr":
            rows = db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
            if len(rows) > 1:
                raise ValueError("duplicate import configuration")
            original["completed_download_handling"] = rows[0][0] if rows else None
        fd = os.open(receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as stream:
            json.dump(original, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        for table, columns in pause_columns(name).items():
            assignments = ','.join('"' + column + '"=0' for column in columns)
            db.execute('UPDATE "' + table + '" SET ' + assignments)
        if name != "prowlarr":
            if rows:
                db.execute("UPDATE Config SET Value='False' WHERE Key='enablecompleteddownloadhandling'")
            else:
                db.execute("INSERT INTO Config (Key,Value) VALUES ('enablecompleteddownloadhandling','False')")
        validate_arr_pause(name, db)


def validate_arr(name, directory, require_pause=False):
    root = ET.parse(directory / "config.xml").getroot()
    if not (root.findtext("ApiKey") or "").strip():
        raise ValueError("missing application identity")
    database = directory / (name + ".db")
    with closing(sqlite3.connect("file:" + str(database) + "?mode=ro", uri=True)) as connection:
        connection.execute("PRAGMA query_only=ON")
        if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
            raise ValueError("database integrity failure")
        for table in ("Users", "VersionInfo"):
            if connection.execute('SELECT count(*) FROM "' + table + '"').fetchone()[0] == 0:
                raise ValueError("missing configured application state")
        if require_pause:
            validate_arr_pause(name, connection)


def main():
    name = sys.argv[1]
    if name in ARR:
        validate_arr(name, Path(ARR[name]), require_pause="--hold" in sys.argv[2:])
    elif name == "transmission":
        settings = json.loads(Path("/var/lib/transmission/.config/transmission-daemon/settings.json").read_text())
        if not settings.get("download-dir", settings.get("download_dir")):
            raise ValueError("missing download directory")
    elif name == "nzbget":
        path = Path("/var/lib/nzbget/nzbget.conf")
        settings = dict(tuple(part.strip() for part in line.split("=", 1))
                        for line in path.read_text().splitlines()
                        if line.strip() and not line.lstrip().startswith("#") and "=" in line)
        if not settings.get("ControlPassword", "").strip():
            raise ValueError("missing downloader credentials")
    else:
        raise ValueError("unknown application")
    print("Existing application state passed startup validation")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Parser errors can include config contents. Never print the exception.
        print("Refused startup: existing application state is missing or invalid", file=sys.stderr)
        sys.exit(1)
