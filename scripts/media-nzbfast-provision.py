#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Copy Server1 credentials to private NZBFAST state. Never open the ready gate."""
import argparse
import grp
import json
import os
from pathlib import Path
import pwd
import sys
import tempfile


def convert(text):
    """NZBGet saved Server1 values, with the module's effective non-secret defaults."""
    settings = dict(line.split("=", 1) for line in text.splitlines()
                    if "=" in line and not line.lstrip().startswith("#"))
    settings = {key.strip(): value.strip() for key, value in settings.items()}
    host = settings.get("Server1.Host", "news.newsdemon.com")
    port = int(settings.get("Server1.Port", "563"))
    encryption = settings.get("Server1.Encryption", "yes").lower()
    connections = int(settings.get("Server1.Connections", "50"))
    username = settings.get("Server1.Username", "")
    password = settings.get("Server1.Password", "")
    if not host or not username or not password or encryption not in ("yes", "no"):
        raise ValueError("invalid server fields")
    if not 1 <= port <= 65535 or not 1 <= connections <= 4294967295:
        raise ValueError("invalid server limits")
    return {"servers": [{"host": host, "port": port, "tls": encryption == "yes",
        "username": username, "password": password, "connections": connections, "enabled": True}]}


def write_config(target, config, uid, gid, force):
    """Publish a fsynced 0600 file; link gives atomic no-overwrite admission."""
    target = Path(target)
    descriptor, temporary = tempfile.mkstemp(prefix=".config-", dir=target.parent)
    try:
        with os.fdopen(descriptor, "w") as stream:
            os.fchmod(stream.fileno(), 0o600)
            os.fchown(stream.fileno(), uid, gid)
            json.dump(config, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        if force:
            os.replace(temporary, target)
        else:
            os.link(temporary, target)
        directory = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="replace existing NZBFAST server config")
    parser.add_argument("--check", action="store_true", help="validate source without writing state")
    parser.add_argument("--source", type=Path, default=Path("/var/lib/nzbget/nzbget.conf"))
    parser.add_argument("--destination", type=Path, default=Path("/var/lib/nzbfast/config.json"))
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise ValueError("root required")
    config = convert(args.source.read_text())
    if not args.check:
        uid = pwd.getpwnam("nzbfast").pw_uid
        gid = grp.getgrnam("media").gr_gid
        write_config(args.destination, config, uid, gid, args.force)
    server = config["servers"][0]
    print(("Checked" if args.check else "Provisioned") + " one enabled server; host/username/password redacted; "
          + f"port={server['port']} tls={server['tls']} connections={server['connections']}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Parser and OS exceptions can contain source contents or credentials.
        print("Refused provisioning: source invalid, destination exists, or private state unavailable", file=sys.stderr)
        sys.exit(1)
