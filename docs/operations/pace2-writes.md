# Pace: reversible writes

Pace's writes slice pins pace-service `ff5744fd3d5a1cb870ffe20767aec5400d30f040`.
The first Nix build found that the package source filter omitted `CONTEXT.md`,
which a writes test embeds. The source filter fix is landed in pace-service;
the test and package checks stay enabled. A second sandbox failure exposed host
zoneinfo dependence. Household dates now use embedded `chrono-tz` rules, parsed
once from `TZ` with a Denver default, and passed explicitly through the server.
The normal suites and sandboxed package tests pass, including no-`TZ` coverage.

Both people have the same tools. The front-door rows and gateway filters share
`lib/ai-mcp-rows.nix`. Both gateways also need each exact projected tool name in
`tools.allow` until OpenClaw fixes MCP App tool ownership. The shared Pace skill
explains writes, attribution, Changes and conversational Undo. The Change card
resource joins the Status card and Overview on both front-door rows.

## Approval choice

Keep Pace's server-scoped `codex.defaultToolsApprovalMode = "auto"`.
The OpenClaw bench proved that a non-admin can write by talking, use the Change
card, Undo by talking or by tap, see the other person's Change, and Undo from the
Overview with refreshed figures. No approval prompt appeared. The installed
approval evaluator permits Pace's `readOnlyHint: false` writes because they also
set `destructiveHint: false` and `openWorldHint: false`. Destructive or open-world
annotations still require approval. Do not set a global approval bypass.

The read-only bench refresh assertion initially searched Recent changes too.
That section correctly retains the old value. The corrected assertion checks
only current Budget figures and passed against the running bench without a new
write.

## Deployment and data safety

Build Rakku on Unzen, copy through Zao, and verify target trust and closure
identity. Build Yari natively. Keep the installed OpenClaw app and its
access-only session-read and fullscreen CSS patches unchanged.

Before switching Rakku, use SQLite's backup API to make a consistent root-only
backup under `/var/lib/pace2/backups/`. Record every original table's row count.
After the switch, prove schema version 2, the new `changes` table, unchanged
original row counts and original-column contents, and SQLite integrity.
Never replace or reimport a versioned database.

Only Pace restarts on Rakku. The front-door table reloads by SIGHUP without a
proxy restart. Only the two gateway services restart on Yari; their containers
stay up. Require both gateways at zero active runs for 90 continuous seconds
before restarting gateways or the front door. Check Home Assistant HTTP and a
Z-Wave handshake after switching Rakku. Never reboot Rakku.

Accept on flakey only in new, non-admin test chats. Compare structured Overview
figures before and after the reversible test by equality, not by printing them.
Check Laure attribution through a non-browser row-path write followed at once
by its Undo. Delete only owned test chats using their gateway session keys,
then remove the disposable pairing after closing the browser.

A rollback is only for a real core failure, not an assertion defect. Restore
Yari before Rakku, restore the recorded database backup while Pace is stopped,
then revert the deployment commit on `cairn` and prove its evaluated systems
match both running hosts. Restoring the backup discards Changes made since it;
never do that as routine cleanup.
