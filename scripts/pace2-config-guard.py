#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Allow only the Pace server and shared skill to change a gateway config."""
import json
import sys
from pathlib import Path


def check(before, after, row, rollback=False):
    if rollback:
        before, after = after, before
    before = json.loads(Path(before).read_bytes())
    after = json.loads(Path(after).read_bytes())
    assert "pace" not in before["mcp"]["servers"], "Pace already existed"
    assert after["mcp"]["servers"].pop("pace") == {
        "transport": "streamable-http",
        "url": f"https://ai.hummingbird-lake.ts.net/mcp/{row}",
        "toolFilter": {"include": ["pace_status"]},
    }, "unexpected Pace server contract"
    old_dirs = before["skills"]["load"]["extraDirs"]
    new_dirs = after["skills"]["load"]["extraDirs"]
    assert len(old_dirs) == len(new_dirs) == 2
    assert old_dirs[1:] == new_dirs[1:], "personal skills changed"

    def files(directory):
        return {str(p.relative_to(directory)): p.read_bytes()
                for p in Path(directory).rglob("*") if p.is_file()}

    old_files, new_files = files(old_dirs[0]), files(new_dirs[0])
    pace = new_files.pop("pace/SKILL.md")
    assert b"mcp:pace:pace__pace_status" in pace
    assert b"Never invent or recompute figures" in pace
    assert old_files == new_files, "shared skills changed outside Pace"
    after["skills"]["load"]["extraDirs"] = old_dirs
    assert before == after, "gateway config changed outside Pace and the shared skill"


if __name__ == "__main__":
    check(*sys.argv[1:4], rollback="--rollback" in sys.argv[4:])
    print("Pace-only gateway config guard passed")
