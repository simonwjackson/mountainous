"""Wait on metadata-only audit receipts before interrupting an OpenClaw gateway."""

import argparse
import json
import re
import sqlite3
import time
from pathlib import Path


def active_runs(database: Path) -> tuple[int, int | None]:
    """A started run remains active until its matching terminal receipt commits."""
    with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as connection:
        count, oldest = connection.execute(
            """SELECT count(*), min(s.occurred_at) FROM audit_events s
            WHERE s.action = 'agent.run.started' AND NOT EXISTS (
                SELECT 1 FROM audit_events f
                WHERE f.action = 'agent.run.finished' AND f.run_id = s.run_id
                  AND f.occurred_at >= s.occurred_at
            )"""
        ).fetchone()
    return count, oldest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("containers", nargs="+")
    parser.add_argument(
        "--container-root", type=Path, default=Path("/var/lib/nixos-containers")
    )
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for name in args.containers:
        if not re.fullmatch(r"[a-zA-Z0-9-]+", name):
            parser.error("invalid container name")
    deadline = time.monotonic() + args.timeout
    while True:
        idle = True
        for name in args.containers:
            database = (
                args.container_root / name / "var/lib/openclaw/state/openclaw.sqlite"
            )
            try:
                count, oldest = active_runs(database)
            except (OSError, sqlite3.Error) as error:
                # Missing or unreadable receipts are not proof of idle.
                print(json.dumps({"container": name, "error": str(error)}), flush=True)
                return 2
            print(
                json.dumps(
                    {
                        "container": name,
                        "activeRuns": count,
                        "oldestStartedAtMs": oldest,
                    }
                ),
                flush=True,
            )
            idle = idle and count == 0
        if idle:
            return 0
        if args.check or time.monotonic() >= deadline:
            return 1
        time.sleep(2)


if __name__ == "__main__":
    raise SystemExit(main())
