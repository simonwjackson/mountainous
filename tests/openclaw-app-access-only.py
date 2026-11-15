"""Verify both session-read calls in the actual installed gateway bundle."""

from pathlib import Path
import sys

root = Path(sys.argv[1])
unpatched = len(sys.argv) == 3 and sys.argv[2] == "--unpatched"
source = (root / "dist/mcp-app-CHXbi1_o.mjs").read_text()
for arguments in (
    'options, requireString(params, "sessionKey"), active.view.agentId',
    "options, sessionKey, agentId",
):
    strict = f"retainSessionScopedRead({arguments});"
    patched = f"retainSessionScopedRead({arguments}, {{ allowMetadataChanges: true }});"
    expected, absent = (strict, patched) if unpatched else (patched, strict)
    if source.count(expected) != 1 or absent in source:
        raise SystemExit(
            f"OpenClaw app session-read patch missing or ambiguous: {arguments}"
        )
print("PASS both installed MCP App session-read calls match the expected variant")
