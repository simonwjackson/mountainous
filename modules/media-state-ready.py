#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Refuse empty or damaged app state instead of starting a setup wizard."""
from contextlib import closing, contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import sqlite3
import stat
import sys
import tempfile
import xml.etree.ElementTree as ET

# Pinned ARR TaskManager implementations retain LastExecution on startup, but
# replace Interval. Keep every native scheduled job held until explicit resume.
SCHEDULE_HOLD_UNTIL = "2099-01-01 00:00:00"

ARR = {
    "sonarr": "/var/lib/sonarr/.config/NzbDrone",
    "radarr": "/var/lib/radarr/.config/Radarr",
    "prowlarr": "/var/lib/prowlarr",
}


def pause_columns(name):
    if name == "prowlarr":
        return {"DownloadClients": ["Enable"], "Indexers": ["Enable"], "Applications": ["SyncLevel"]}
    return {"DownloadClients": ["Enable"], "Indexers": ["EnableRss", "EnableAutomaticSearch", "EnableInteractiveSearch"]}


def processing_columns(name):
    return {**pause_columns(name), "ScheduledTasks": ["LastExecution"]}


def scheduled_task_snapshot(connection):
    columns = ("Id", "TypeName", "Interval", "LastExecution", "LastStartTime")
    available = {row[1] for row in connection.execute('PRAGMA table_info("ScheduledTasks")')}
    commands = {row[1] for row in connection.execute('PRAGMA table_info("Commands")')}
    if not set(columns).issubset(available) or "Status" not in commands:
        raise ValueError("missing configured scheduler state")
    if connection.execute("SELECT count(*) FROM Commands WHERE Status IN (0,1)").fetchone()[0]:
        raise ValueError("queued or active application commands are not held")
    rows = [dict(zip(columns, row)) for row in connection.execute(
        'SELECT Id,TypeName,Interval,LastExecution,LastStartTime FROM ScheduledTasks ORDER BY Id')]
    if not rows:
        raise ValueError("missing configured scheduler tasks")
    return rows


def validate_scheduled_pause(connection):
    expected = datetime.fromisoformat(SCHEDULE_HOLD_UNTIL).replace(tzinfo=timezone.utc)
    if datetime.now(timezone.utc).year >= 2098:
        raise ValueError("scheduled processing hold requires operator renewal")
    for row in scheduled_task_snapshot(connection):
        try:
            value = datetime.fromisoformat(str(row["LastExecution"]).replace("Z", "+00:00"))
            if value.tzinfo is None:
                value = value.replace(tzinfo=timezone.utc)
        except ValueError:
            raise ValueError("scheduled application processing is not held") from None
        if value != expected:
            raise ValueError("scheduled application processing is not held")


def validate_arr_pause_flags(name, connection):
    for table, columns in pause_columns(name).items():
        for column in columns:
            if connection.execute('SELECT count(*) FROM "' + table + '" WHERE "' + column + '" IS NULL OR "' + column + '" != 0').fetchone()[0]:
                raise ValueError("application processing is not held")
    if name != "prowlarr":
        rows = connection.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
        if len(rows) != 1 or rows[0][0].lower() != "false":
            raise ValueError("completed-download imports are not held")


def validate_arr_pause(name, connection):
    validate_arr_pause_flags(name, connection)
    validate_scheduled_pause(connection)


def protected_pause_receipt(receipt, original):
    fd = os.open(receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(original, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def prepare_arr_scheduler_pause(name, directory, receipt):
    """Extend an existing stopped processing hold without replacing its first receipt."""
    if name not in ARR:
        raise ValueError("unsupported application")
    directory, receipt = Path(directory), Path(receipt)
    if receipt.resolve().is_relative_to(directory.resolve()):
        raise ValueError("receipt must be outside application state")
    validate_arr(name, directory)
    with closing(sqlite3.connect("file:" + str(directory / (name + ".db")) + "?mode=rw", uri=True)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        validate_arr_pause_flags(name, db)
        original = {"format": 1, "application": name, "scheduled_tasks": scheduled_task_snapshot(db),
                    "hold_until": SCHEDULE_HOLD_UNTIL}
        protected_pause_receipt(receipt, original)
        db.execute("UPDATE ScheduledTasks SET LastExecution=?", (SCHEDULE_HOLD_UNTIL,))
        validate_arr_pause(name, db)


def download_removal_snapshot(connection):
    columns = ['Id', 'RemoveCompletedDownloads', 'RemoveFailedDownloads']
    available = {row[1] for row in connection.execute('PRAGMA table_info(DownloadClients)')}
    if not set(columns).issubset(available):
        raise ValueError('missing native download-removal state')
    return [dict(zip(columns, row)) for row in connection.execute(
        'SELECT Id,RemoveCompletedDownloads,RemoveFailedDownloads FROM DownloadClients ORDER BY Id')]


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
        original = {"format": 1, "application": name, "flags": {}, "completed_download_handling": None,
                    "scheduled_tasks": scheduled_task_snapshot(db), "hold_until": SCHEDULE_HOLD_UNTIL}
        for table, columns in pause_columns(name).items():
            selected = ','.join('"' + column + '"' for column in ["Id"] + columns)
            original["flags"][table] = [dict(zip(["Id"] + columns, row))
                for row in db.execute('SELECT ' + selected + ' FROM "' + table + '"')]
        if name != "prowlarr":
            rows = db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
            if len(rows) > 1:
                raise ValueError("duplicate import configuration")
            original["completed_download_handling"] = rows[0][0] if rows else None
            original["download_removal_flags"] = download_removal_snapshot(db)
        protected_pause_receipt(receipt, original)
        db.execute("UPDATE ScheduledTasks SET LastExecution=?", (SCHEDULE_HOLD_UNTIL,))
        for table, columns in pause_columns(name).items():
            assignments = ','.join('"' + column + '"=0' for column in columns)
            db.execute('UPDATE "' + table + '" SET ' + assignments)
        if name != "prowlarr":
            db.execute('UPDATE DownloadClients SET RemoveCompletedDownloads=0,RemoveFailedDownloads=0')
            if rows:
                db.execute("UPDATE Config SET Value='False' WHERE Key='enablecompleteddownloadhandling'")
            else:
                db.execute("INSERT INTO Config (Key,Value) VALUES ('enablecompleteddownloadhandling','False')")
        validate_arr_pause(name, db)


def read_processing_receipt(name, directory, receipt):
    """Read the protected original flags without opening application state for writes."""
    directory, receipt = Path(directory), Path(receipt)
    if receipt.resolve().is_relative_to(directory.resolve()):
        raise ValueError("restoration receipt must be outside application state")
    descriptor = os.open(receipt, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError("restoration receipt must remain protected")
        with os.fdopen(os.dup(descriptor)) as stream:
            original = json.load(stream)
    finally:
        os.close(descriptor)
    if original.get("format") != 1 or original.get("application") != name or set(original.get("flags", {})) != set(pause_columns(name)):
        raise ValueError("restoration receipt does not match application")
    return original


def restore_arr_pause(name, directory, receipt, mode="enabled"):
    """Restore only admitted original processing fields in a stopped database.

    The caller must stop the application and close its startup gate. Import-only
    admission keeps indexers and schedules held for a representative workflow.
    No credentials, commands, history, intervals or task identities are changed.
    """
    if name not in ARR or mode not in ("imports-only", "enabled") or (name == "prowlarr" and mode == "imports-only"):
        raise ValueError("unsupported processing restoration")
    directory = Path(directory)
    original = read_processing_receipt(name, directory, receipt)
    validate_arr(name, directory)
    with closing(sqlite3.connect("file:" + str(directory / (name + ".db")) + "?mode=rw", uri=True)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        validate_scheduled_pause(db)
        tasks = scheduled_task_snapshot(db)
        expected_tasks = original["scheduled_tasks"]
        if {(row["Id"], row["TypeName"]) for row in tasks} != {(row["Id"], row["TypeName"]) for row in expected_tasks}:
            raise ValueError("scheduled task identities changed before restoration")
        for row in expected_tasks:
            datetime.fromisoformat(str(row["LastExecution"]).replace("Z", "+00:00"))
            if str(row["LastExecution"]).startswith("2099-"):
                raise ValueError("receipt contains held timestamps rather than original state")
        for table, columns in pause_columns(name).items():
            saved = original["flags"][table]
            if any(set(row) != {"Id", *columns} for row in saved) or len({row["Id"] for row in saved}) != len(saved):
                raise ValueError("processing receipt rows are invalid")
            ids = {row[0] for row in db.execute('SELECT Id FROM "' + table + '"')}
            if ids != {row["Id"] for row in saved}:
                raise ValueError("processing record identities changed before restoration")
            for row in saved:
                current = db.execute('SELECT ' + ','.join('"' + column + '"' for column in columns) + ' FROM "' + table + '" WHERE Id=?', (row["Id"],)).fetchone()
                if any(value not in (0, row[column]) for column, value in zip(columns, current)):
                    raise ValueError("processing flags changed outside the admitted transition")
        if name != "prowlarr":
            removal = original.get('download_removal_flags')
            if removal is None:
                raise ValueError('original download-removal receipt missing')
            current_removal = download_removal_snapshot(db)
            if any(set(row) != {'Id', 'RemoveCompletedDownloads', 'RemoveFailedDownloads'} for row in removal) or len({row['Id'] for row in removal}) != len(removal) or {row['Id'] for row in removal} != {row['Id'] for row in current_removal}:
                raise ValueError('original download-removal identities differ')
            expected_removal = {row['Id']: row for row in removal}
            for row in current_removal:
                if any(row[column] not in (0, expected_removal[row['Id']][column]) for column in ('RemoveCompletedDownloads', 'RemoveFailedDownloads')):
                    raise ValueError('download-removal flags changed outside admission')
            values = db.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
            saved_value = original["completed_download_handling"]
            if len(values) > 1 or (values and str(values[0][0]).lower() not in ("false", str(saved_value).lower())):
                raise ValueError("import configuration changed outside the admitted transition")
            if not values and saved_value is not None:
                raise ValueError("admitted import configuration missing")
        # All identities pass before the first update. A later failure rolls back.
        for table, columns in pause_columns(name).items():
            if mode == "imports-only" and table != "DownloadClients":
                continue
            statement = 'UPDATE "' + table + '" SET ' + ','.join('"' + column + '"=?' for column in columns) + ' WHERE Id=?'
            for row in original["flags"][table]:
                db.execute(statement, [row[column] for column in columns] + [row["Id"]])
        if name != "prowlarr":
            for row in original['download_removal_flags']:
                db.execute('UPDATE DownloadClients SET RemoveCompletedDownloads=?,RemoveFailedDownloads=? WHERE Id=?',
                           (row['RemoveCompletedDownloads'] if mode == 'enabled' else 0,
                            row['RemoveFailedDownloads'] if mode == 'enabled' else 0, row['Id']))
            value = original["completed_download_handling"] if mode == 'enabled' else 'False'
            if value is None:
                db.execute("DELETE FROM Config WHERE Key='enablecompleteddownloadhandling'")
            elif db.execute("SELECT count(*) FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchone()[0] == 1:
                db.execute("UPDATE Config SET Value=? WHERE Key='enablecompleteddownloadhandling'", (value,))
            elif mode == 'imports-only':
                db.execute("INSERT INTO Config (Key,Value) VALUES ('enablecompleteddownloadhandling','False')")
            else:
                raise ValueError("import configuration is not the admitted held state")
        if mode == "enabled":
            for row in expected_tasks:
                db.execute("UPDATE ScheduledTasks SET LastExecution=? WHERE Id=? AND TypeName=?", (row["LastExecution"], row["Id"], row["TypeName"]))


def validate_arr_imports(name, connection, original):
    """Admit original clients for explicit grabs, not automatic imports or removal."""
    if name not in ("sonarr", "radarr"):
        raise ValueError("unsupported imports-only application")
    validate_scheduled_pause(connection)
    tasks = scheduled_task_snapshot(connection)
    if {(row["Id"], row["TypeName"]) for row in tasks} != {(row["Id"], row["TypeName"]) for row in original["scheduled_tasks"]}:
        raise ValueError("imports-only scheduled task identities changed")
    for table, columns in pause_columns(name).items():
        saved = original["flags"][table]
        if any(set(row) != {"Id", *columns} for row in saved) or len({row["Id"] for row in saved}) != len(saved):
            raise ValueError("imports-only receipt rows invalid")
        selected = ','.join('"' + column + '"' for column in ["Id"] + columns)
        current = [dict(zip(["Id"] + columns, row)) for row in connection.execute('SELECT ' + selected + ' FROM "' + table + '" ORDER BY Id')]
        expected = [dict(row) if table == "DownloadClients" else {"Id": row["Id"], **{column: 0 for column in columns}} for row in saved]
        if current != sorted(expected, key=lambda row: row["Id"]):
            raise ValueError("imports-only processing differs from original admission")
    removal = original.get('download_removal_flags')
    current_removal = download_removal_snapshot(connection)
    if removal is None or {row['Id'] for row in removal} != {row['Id'] for row in current_removal}:
        raise ValueError('imports-only protected removal receipt missing or different')
    if any(row[column] != 0 for row in current_removal for column in ('RemoveCompletedDownloads', 'RemoveFailedDownloads')):
        raise ValueError('imports-only download removal is not held')
    values = connection.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
    if len(values) != 1 or str(values[0][0]).lower() != 'false':
        raise ValueError("imports-only automatic completed-download handling is not held")


def validate_arr_enabled(name, connection, original):
    """Admit original processing while allowing native execution timestamps to advance."""
    tasks = scheduled_task_snapshot(connection)
    if any(str(row['LastExecution']).startswith('2099-') for row in tasks):
        raise ValueError('enabled scheduler still contains a processing hold')
    if {(row['Id'], row['TypeName']) for row in tasks} != {(row['Id'], row['TypeName']) for row in original['scheduled_tasks']}:
        raise ValueError('enabled scheduler identities changed')
    for table, columns in pause_columns(name).items():
        selected = ','.join('"' + column + '"' for column in ['Id'] + columns)
        current = [dict(zip(['Id'] + columns, row)) for row in connection.execute('SELECT ' + selected + ' FROM "' + table + '" ORDER BY Id')]
        if current != sorted(original['flags'][table], key=lambda row: row['Id']):
            raise ValueError('enabled processing flags differ from original')
    if name != 'prowlarr':
        if download_removal_snapshot(connection) != original.get('download_removal_flags'):
            raise ValueError('enabled download removal differs from original')
        values = connection.execute("SELECT Value FROM Config WHERE Key='enablecompleteddownloadhandling'").fetchall()
        expected = original['completed_download_handling']
        if (expected is None and values) or (expected is not None and (len(values) != 1 or str(values[0][0]).lower() != str(expected).lower())):
            raise ValueError('enabled import handling differs from original')


@contextmanager
def arr_read_connection(database):
    """Read a stable private SQLite copy, including WAL, without creating source sidecars."""
    database = Path(database)
    paths = [database, Path(str(database) + '-wal'), Path(str(database) + '-journal')]

    def snapshot(path):
        try:
            info = path.lstat()
        except FileNotFoundError:
            return None
        if not stat.S_ISREG(info.st_mode):
            raise ValueError('application database or journal is not a regular file')
        return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)

    before = {path: snapshot(path) for path in paths}
    if before[database] is None:
        raise sqlite3.OperationalError('application database missing')
    with tempfile.TemporaryDirectory(prefix='media-state-ready-') as temporary:
        target = Path(temporary) / database.name
        for path in paths:
            if before[path] is not None:
                shutil.copyfile(path, Path(temporary) / path.name)
        if before != {path: snapshot(path) for path in paths}:
            raise ValueError('application database changed during private read admission')
        with closing(sqlite3.connect('file:' + str(target) + '?mode=ro', uri=True)) as connection:
            yield connection


def validate_arr(name, directory, require_pause=False, imports_receipt=None, enabled_receipt=None):
    if sum((require_pause, imports_receipt is not None, enabled_receipt is not None)) > 1:
        raise ValueError("conflicting startup processing admission")
    receipt = imports_receipt if imports_receipt is not None else enabled_receipt
    original = read_processing_receipt(name, directory, receipt) if receipt is not None else None
    root = ET.parse(directory / "config.xml").getroot()
    if not (root.findtext("ApiKey") or "").strip():
        raise ValueError("missing application identity")
    database = directory / (name + ".db")
    with arr_read_connection(database) as connection:
        connection.execute("PRAGMA query_only=ON")
        if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
            raise ValueError("database integrity failure")
        for table in ("Users", "VersionInfo"):
            if connection.execute('SELECT count(*) FROM "' + table + '"').fetchone()[0] == 0:
                raise ValueError("missing configured application state")
        if require_pause:
            validate_arr_pause(name, connection)
        if imports_receipt is not None:
            validate_arr_imports(name, connection, original)
        if enabled_receipt is not None:
            validate_arr_enabled(name, connection, original)


def validate_nzbfast(path):
    settings = json.loads(Path(path).read_text())
    servers = settings.get("servers")
    if not isinstance(servers, list) or not any(
        isinstance(server, dict) and server.get("enabled", True) is True
        and isinstance(server.get("host"), str) and server["host"].strip()
        for server in servers
    ):
        raise ValueError("missing enabled server")


def main():
    name = sys.argv[1]
    if name in ARR:
        arguments = sys.argv[2:]
        receipt = Path(arguments[arguments.index("--imports-only") + 1]) if "--imports-only" in arguments else None
        enabled = Path(arguments[arguments.index('--enabled') + 1]) if '--enabled' in arguments else None
        validate_arr(name, Path(ARR[name]), require_pause="--hold" in arguments, imports_receipt=receipt, enabled_receipt=enabled)
    elif name == "transmission":
        settings = json.loads(Path("/var/lib/transmission/.config/transmission-daemon/settings.json").read_text())
        if not settings.get("download-dir", settings.get("download_dir")):
            raise ValueError("missing download directory")
    elif name == "nzbfast":
        validate_nzbfast(Path("/var/lib/nzbfast/config.json"))
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
