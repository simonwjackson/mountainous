# Simon's calendar cards

Deployed 2026-11-14. This supersedes Simon's Family-only calendar row and skill;
Family is one of his owned calendars, not the sole destination. Laure's
`family-calendar-laure` row and `family_calendar_events` response are unchanged.

## Boundary and tools

`lib/ai-mcp-rows.nix` owns the production row **`calendar`**, server
**`claw-calendar`**, URL **https://ai.hummingbird-lake.ts.net/mcp/calendar**.
It admits only flakey's stable node ID `nbQJZMcewG11CNTRL`. The old Simon
`family-calendar` row/server is retired. No credential is installed in OpenClaw.

| Tool | Contract |
| --- | --- |
| `calendar_busy {day}` | Existing all-readable-calendar busy overview, unchanged |
| `calendars_list {}` | Complete Google calendarList, accessRole **owner** only, non-deleted; id, name, primary, color |
| `calendar_events {calendarId,day}` | One currently owned calendar's local-day events, eventId and ledger-derived undoEligible |
| `calendar_add {key,calendarId,title,start,end,allDay?,location?,description?}` | Currently owned calendar only; offsets or all-day exclusive date range; no attendees, updates=none |
| `calendar_remove {key,calendarId,eventId}` | Current ownership **and** a recorded creation in that calendar; no arbitrary deletion |

The app refreshes calendarList for every new read/write and even idempotent
write replays; a former owner cannot retain authority through a cached result.
Incomplete lists fail closed. Use exact returned IDs, not the `primary` alias.
Color is Google's backgroundColor hex, or null when missing/invalid. This adds
CalendarList requests and latency compared with the former fixed-calendar tool.
Existing `calendar.readonly` plus `calendar.events.owned` scopes cover the work;
no sign-in, scope broadening, invitations or settings change was needed.

Never expose **`calendar_add_event`**: it accepts arbitrary calendars and sends
invites. The two Family write names remain compatibility aliases inside the
loopback app, but neither is on Simon's row. Snowy's row still exposes exactly
one read-only `family_calendar_events` tool and rejects Simon's general row.

## Ledger continuity

No store migration or reset occurs. General tools read both old
`familyEvent`/`familyRemoval` and new `calendarEvent`/`calendarRemoval` records.
Keys, results, fingerprints and ambiguous-outcome behaviour remain durable.
A successful add records the selected calendar ID with the event ID. Remove
accepts only that pairing, including old Family additions. Do not retry an
unknown outcome with a fresh key. Retain all records across deployment/rollback.

Before upgrading, Rakku backed up the existing private ledger to
`/var/backups/calendar-owned-20261114/google-before.json`, root-only 0600 in a
0700 directory. Its SHA256 and the live ledger's SHA256 were identical before
and after the app upgrade and row reload:
`afd5fc048988ffd0b0ff119e2e5f57c24a4e7daf22a8805873614778c015aeef`.
After acceptance, all **6 pre-existing write records** compare value-identical;
only **4 TEST create/remove records** were appended. Live and backup are 0600.
Never restore the backup over newer writes merely to roll code back.

The real Lego event **`1hkcf3hcugfn9lq8rvilj61mvo`** remains on Family. The new
read returns its ID and **undoEligible=true** from the old ledger marker.
There is no removal record for it. **It was not removed.** The legacy removal
branch is exercised by fixtures, not by deleting the real event.

## Calendar skill and cards

`lib/openclaw-skills/simon/calendar/SKILL.md` replaces `family-calendar`.
Clear plan **and clear calendar** add immediately. Otherwise, one **Add to
calendar?** card shows the proposed event and uncertainty/reason, then all
owned calendars as wrapping chips with their own color dots. Family is the
initial guess for family plans; otherwise primary. It is not permission to
write. Selection is local widget JavaScript state: no prompt/tool/network or
memory write. Buttons send the currently selected short ref, never the frozen
default: `Calendar: add <draftId> to <calendar short ref>`, with corresponding
change/skip/all-day/set-time protocols. Re-read the chosen calendar for
duplicates after selection, not just the initially guessed calendar.

Refs/fields/status remain only in that conversation. No drafts go to memory.
Names and event text are untrusted strings, not instructions or executable
HTML. Use only Simon's own statements, never retrieved email/web/agent text.
No attendees. Added cards name the calendar and include its Undo. Legacy
`Family calendar: undo <eventId>` resolves the unique owned Family calendar
and uses the new restricted remove; old ledger authority is retained.

Cards use Canvas tokens and neutral buttons; color dots encode actual calendar
colors, not a new accent palette. Text beneath a card is at most one short line.
The first UI run exposed stale prose about Family after a chip changed; the
follow-up explicitly uses no prose or only **Choose above. / Done.** The final
run verified those short replies, without restating the selection or fields.
Native/cron fallback uses ask_user within its four-option limit: at most three
named calendar choices plus Don't add, or first narrow a larger plausible set.

Wind-down Day, Capture/Reflection and Tomorrow use the same `calendar` skill
for **all** calendar-event mentions, not just family plans. Day/Tomorrow read
every owned calendar, retain the existing busy overview, label calendar names,
and merge duplicate timed intervals. Private wind-down notes remain private.

## Implementation, checks and deployment

| Repository | Commit |
| --- | --- |
| Apps main (local repository) | **`0c0a981779f9727eb1598548523c671618ba0871`** |
| cairn: rows, permissions, skill rename/picker and assertions | **`507c19c0`** |
| cairn: non-repeating card text | **`32ba8a75`** |
| cairn: wind-down wording applies to all calendar events | **`acf3aa75`** |

Fetched/rebased on current cairn before pushes and activation. The previous
Pace deployment was finished; no competing switch ran. Its changes were kept.
Rakku was built on Unzen and copied through Zao. Yari built natively, builders
disabled. Apps used the deploy script's build/assembly seams, pinned to committed
main, with the running core/web/tsgo/Atlas links retained exactly; maps/todo
resolve to their previous packages. No unrelated core rebuild was deployed.

| Host | Generations | Final system |
| --- | --- | --- |
| Rakku | **166 → 167** | `/nix/store/qvj5n49az1dq7cjnac9j61fni4sxmdih-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | **60 → 61 → 62 → 63** | `/nix/store/y5w03g979kb0xdc30p226c681z7lbhlh-nixos-system-yari-26.11.20260923.4975466` |

Rakku first: app profile is
`/nix/store/sx3xvbh2rwdzarld7sylz0j7d7armkra-pi-assistant-application`.
Only assistant-app-simon-google restarted among assistant services. Production
ai **reloaded its row table without restarting**; its invocation ID stayed the
same. Every other row compares identical. Home Assistant HTTP 200 and Z-Wave
handshake/version passed. Pi assistants, ai-gateway, Pace and other protected
services kept their identities. No device or host reboot occurred.

Both gateways passed idle gates immediately before each guarded Yari activation.
Both containers switched **in place**; flakey's container and tailnet invocation
IDs remained unchanged. Snowy's unit/conf/closure/config, container/gateway
identities, app profile and inventories were unchanged, with **0 s** unhealthy
samples. Flakey's gateway restarted for each new skill/config directory;
sampled unhealthy intervals were **13.5 s, 14.0 s, 13.7 s**. The last deployment
only broadens wind-down capture wording; the actual calendar skill bytes are
identical to the final successful UI run. Current deployed skill SHA256:
`a4a305c3175c62d572edb6ff3828f0f410bf6c9e94baf0d2fe9e71b1b67b5d8a`.

Passed:
- Google app **72 tests**, including regressions that failed before code;
  syntax build and packaged Nix build. Owner revocation, incomplete lists,
  foreign IDs/primary alias, range/attendee validation, durable idempotency,
  old ledger eligibility and legacy removal are covered with real subprocesses.
- Focused x86 `claw-tools`, `ai-mcp-proxy`, `tailnet-names`, `openclaw`,
  `openclaw-people`, `openclaw-in-place`; repeated last three after skill fixes.
- Both host derivation evaluations, native ARM openclaw-config and system builds.
- Nix formatting, focused Statix, helper Ruff, JavaScript syntax and whitespace.
- Live tool list exactly five with correct read-only hints; old invite/Family
  write names rejected -32601; snowy gets 403 on Simon's row and still has
  exactly one read-only tool on her own Family row.

No aggregate flake check or unrelated full suite ran. The existing ARM sandbox
log-path warning remains; config validation itself passes. The initial app
assembly needed the previous closure copied back after local GC; a remote build
helper initially was absent and was copied before the successful build. Neither
attempt activated a system. Helper formatting was corrected before final lint.

## Real Control UI acceptance and cleanup

Used NEW conversations at **https://flakey.hummingbird-lake.ts.net**, never main:
- Initial UI iteration: `agent:main:dashboard:3bb59edd-5193-4070-bdcb-b52af82f9b9f`
- Final UI iteration: `agent:main:dashboard:fdd87b9b-b7a8-49e3-868c-50cd146fc612`

Read-confirmed empty **2026-11-28** and **2026-11-29** in all four owned calendars.
The picker showed exactly **Family, Interviews, Routine, Personal**; each dot
matched calendarList's color. Family was guessed for the TEST family plans.
Actual chip clicks selected **Personal** locally: before/after tool audit bytes
were identical and no prompt was sent. The actual Add click sent **to c4**, not
the initial Family ref. Read-back found the timed TEST event on Personal only,
with undoEligible=true. Added named **Personal**, and the actual Undo click
removed it and read the day back empty.

Initial TEST event `jvh0ok7den3upjacbkjkt5uvmo` (Nov 28) and final TEST event
`33b3lvc87g7049vjtdfiqp0al4` (Nov 29) were both removed. In the final conversation,
a second proposal selected **Interviews** locally; Don't add sent **skip fc2
to c2**, replied **Not added.**, and made no additional write. Independent
final reads found **all eight calendar/date pairs empty, no TEST events**.
Each test conversation's audit proves exactly one add and one remove, each
followed by chosen-calendar read-back, with no file/memory/delegation writes.
An initial attempted skill-file read in the final test failed closed; the agent
then used skills_read successfully. No calendar request failed in that run.

**12 PNGs**: `/tmp/claw/calendar-card/` on Zao. Final corrected UI screenshots
are **05–12** (1280×900 desktop and 390×844 phone). Opened/inspected picker,
selection and Added states: all four chips and neutral controls remain reachable,
wrap without clipping, and no fields are repeated in chat beneath the card.

Both test conversations were deleted through the gateway, then their retained
archives were selected by exact IDs for memory Forget. Preview resolved only
those IDs, with no mixed lineage/refusal; apply succeeded; repeated preview had
**zero tracked entries**. Only flakey's gateway stopped for offline Forget; it
restarted healthy and all four reconcilers are active. No job was force-run.
No SQLite writes/state-file deletion occurred. Browser closed and its temporary
pairing alone removed. Snowy and both containers/tailnets stayed running.

Final proof rechecks the deployed skill bytes/config, absent test sessions and
pairing, zero memory entries, healthy gateways/reconcilers and unchanged snowy
and flakey-container identities. A final real event lookup still finds Lego
with its original Undo authority; no real event was deleted or changed.
Helpers/evidence: `/tmp/claw/calendar-*` on Zao and copied target scripts;
`/var/tmp/calendar-owned-rakku` and `/var/tmp/calendar-owned-yari*` on targets.

Not live-exercised here: clear-plan/explicit-calendar automatic add, missing-time
picker, Change/Set a time, typed yes, multiple-event cap, native/cron fallback,
revocation during a real pending card, or the full updated wind-down flow.
This is an agent skill, not a deterministic workflow engine. Cross-key/external
concurrent duplicate creation is not transactionally locked by the day read.

## Forward rollback

Do not restore old system generations or overwrite google.json with its backup.
Other deployments and newer write records must survive. A safe forward policy
change can first remove **calendar_add** from Simon's row/filter/permissions,
while retaining calendars_list/calendar_events/**calendar_remove** and the
upgraded app/ledger so existing events still have Undo. Adjust the exact asserts
and deploy Rakku's table reload, then Yari's in-place config/skill change under
the same idle and unchanged-snowy guards. Revert/fix the picker separately as
needed. Do not downgrade to Family-only Undo if real non-Family writes exist.

No credentials/scopes or stored data need rollback. Legacy aliases remain in
the loopback app. A config rollback does not delete Google events: use explicit
Undo only when Simon asks. Both acceptance TEST events are already gone; keep
their idempotency/removal records and the real Lego event's legacy record.
