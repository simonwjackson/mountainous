# Full wind-down skill — 2026-11-15

Simon-only. Replaces v1 in place. The paused Pi assistant, Logbook, Atlas and
Laure's tools are not called or changed. OpenClaw gets no new key, exec tool,
ClawHub package, job or data service.

## Source and storage decisions

The short SKILL entry loads seven references at each boundary. Sources are
assistant wind-down/day-plan/planning-patterns instructions, ADR 0014, life.md,
the original therapy method, accepted web mockups at `cd76947` (read with git
show only), vocabulary.ts, and Logbook ADR 0016 plus its pure wellbeing model
and tests. Fixed coefficients and thresholds are not judgement or newly tuned.
Unavailable activity inputs remain missing, not measured zeros. A default-only
3.0 is not a personal recovery estimate. Mood/gap/food/activity have no invented
numeric coefficient in the original formula.

SparkyFitness **does** support energy 1–5 and mood 1–10. Wind-down writes one
check-in with energy=charge and mood=2×original mood (stored 20/40/60/80/100).
Only date and a safe marker accompany the ratings; private notes/worries stay
local. A read-back verifies original values through this explicit encoding.
The current tools expose date/time/values/notes, **not entry IDs**, so receipts
use that tuple unless an ID is returned. There is no MCP check-in update,
delete or idempotency key; ambiguous writes reconcile, never automatically retry.
The existing nutrition-fitness skill delegates this one write to wind-down.

Daily notes retain 13 November's exact heading/field structure. Optional v2
sections hold picks, ledger, state, computed scale and weekly review. No second
tomorrow store. Private `memory/wind-down/` contains policy, latest-zone,
crashes and the one interim project list. USER.md/MEMORY.md are not destinations.
The 07:00 brief reads the latest projection and authoritative quiet policy;
only a fresh matching zone after 14 elapsed days can lighten the day. The
21:00 opener's declaration and prompt stay unchanged.

## Deployment boundary found by the real test

The first browser turn reproduced `Hardlinked path is not allowed under
sandbox root` for all three attempted references in the optimized Nix store.
Native skills_read can load SKILL.md but cannot load its other files. Do not
turn off workspaceOnly or the hardlink guard. Simon-only Nix oneshot
`openclaw-wind-down-references` installs seven read-only **real copies**, not
symlinks/hardlinks, at workspace `.wind-down-references/`, before the gateway.
The entry names this runtime read path. Nix remains the only editable source.
No service or new references are installed for Laure. Live reads then succeeded;
all seven destination files had link count 1.

A second real-data boundary was a calendar event whose start equalled its end.
The reference now says its duration is unknown, not zero occupancy: known gaps
before it may show, but the affected remainder is unknown, not an “uncertain
free window”. No existing calendar event was edited.

## Original feature map

“Codified” means specified in the installed skill, not necessarily live-tested
on every branch. “Codified-but-degraded” means the interim source/UI differs.

| Original feature | Status | Flakey implementation / limit |
|---|---|---|
| 10–15 minute close, usual persona, one question | codified | Current step/card; no new therapist persona |
| 03:00–03:00 Denver day, frozen identity, DST | codified | Local date/offset rules; tomorrow is next civil date |
| 21:00 offer waits, no duplicate completed close | codified-but-degraded | Unchanged text opener; exact daily-note check |
| Native waiting chip priority after send holds | not connected | No Pi open-strip workflow engine |
| Short after midnight, Rate/Capture/Stop | codified | Never refill with Day/Tomorrow |
| Contextual hybrid order, ≤3 middles, green lookBack | codified | progress_card rail; extras only at Simon's request |
| Skip, Add, revisit, restore, resume | codified-but-degraded | Conversation controls and private state, not native step IDs |
| Rate 1–5 charge/mood and optional note | codified | One ten-button widget, explicit combined submission; ask_user fallback |
| ChargeRead usual/pulls/felt/gap | codified-but-degraded | Same arithmetic, partial inputs; default labelled thin |
| Paired weekly felt/data means | codified | Same paired dates, n/coverage, omit incomplete pairs |
| Day planned/done/slipped/trail/waiting loops | codified-but-degraded | Last night's must-dos; Simon supplies completions/times; no Atlas trail |
| Personal preceding-28-day baseline, weights, rounding | codified-but-degraded | Exact rules/tenths reconciliation; daily metric history can be unavailable |
| Body, activity and food evidence | codified-but-degraded | SparkyFitness reads; aggregate-only data cannot supply SD |
| Mood and felt/data gap as signals | codified | Track and discuss; no invented fixed pull/zone threshold |
| Late conversation hours and activity projects | not connected | No authoritative counts; exercise/interim list do not substitute |
| Slipped picks and skipped nights as signals | codified-but-degraded | Explicit records only; absent history is missing, short isn't skipped |
| Future work-meeting signal | not connected | Calendar plans are not measured workload; no original coefficient |
| Red-before-amber rules, persistence, since, 28-day trend | codified-but-degraded | Supported evidence only; no unknown-as-green reassurance |
| Past crash marking, suggestions, confirm/reject | codified | Inclusive dates, overlap suppression, human decisions, private list |
| Runway and uncertainty | codified-but-degraded | Two eligible crashes/14 estimates; otherwise “not enough data yet” |
| 14-day quiet period and later lighter plan | codified | Starts only at first real full close; missing policy is conservative |
| Daytime worsening-zone monitor and phone push | not connected | No new cron/push; future once-daily policy documented |
| Project review, Park/Resume, restart note | codified-but-degraded | One interim active/on_hold list, last touched; no service status claim |
| Ledger deposits/withdrawals and week net | codified-but-degraded | Facts and labelled assessments; no invented numeric net |
| Capture/Reflect free text, sort after speaking | codified | Original words, Ideas/To-dos/Worries, no idea-to-debt conversion |
| Atlas capture filing/private ideas/restructuring/keys | not connected | Private daily bins and labelled filing suggestions only |
| Private journal worries/reflection writes | not connected | Private daily block, honest destination gap |
| Tomorrow note/≤3 must-dos/calendar shape | codified-but-degraded | Daily block feeds morning; no Atlas Today or day line |
| Owned calendar card, picker, duplicate check, Undo | codified | Existing calendar skill unchanged; consent separate from note save |
| Stop, verified saves, failed-write escape | codified | Noted until each destination read-back; close never held open |
| Sunday review/projects/week shape/one intention | codified | Separate optional weekly close and durable once-weekly offer gate |
| Weekly deeper talk outside close | codified | Separate once-weekly gate; no 22:30 fallback job |
| Original therapy methods and crisis boundaries | codified | OFF until full reading and explicit approval; no clinical diagnosis |
| Household privacy-filtered latest summary | not connected | Nothing sent to Laure; future summary boundary documented |
| WellbeingDashboard app drill-in/back | codified-but-degraded | Private conversational sections; no native app activity |
| Future card/UI map | codified | One-to-one original names; Canvas baseline, no invented missing numbers |

## Checks and acceptance

Landed on cairn, fetched/rebased before pushes and activation:

- `1966daf13c164583079c015ba53fcbae3f66236f`: complete skill and focused contracts.
- `284895e9d02157ac7b89aa3db1dab095a8ce2b84`: sandbox-readable references.
- **Tested/deployed source** `d5428c5128f2394048518e159510ba7f36cd6e94`:
  honest check-in receipts, concise prose and unknown calendar durations.

| Yari generation | System suffix | Result |
|---|---|---|
| Before: 67 | `cqgkp8b0k2kdam2br5hpfjiap4jmf4dd` | Baseline |
| 68 | `19haqla5nmxkcsp78q37xqfgqxpxw5hq` | First source; real test exposed store hardlink rejection |
| 69 | `spb7y2qz8z66drb455nwzm77fs1zl9nq` | Real reference reads and full daily/weekly acceptance |
| **70** | **`2gbc8cv14lcivh3vx0pgypx6j3f5gbr8`** | Final corrections; new live arithmetic/calendar/gate smoke |

Full final path:
`/nix/store/2gbc8cv14lcivh3vx0pgypx6j3f5gbr8-nixos-system-yari-26.11.20260923.4975466`.
Built natively on Yari, builders off, pinned source and clean tree. Each switch
ran under `systemd-run`, with both gateways idle and checked again immediately
before activation, exact unchanged-Snowy guards and automatic fallback.
No competing switch was present; none was interrupted. No container or tailnet
restart. Final activation: flakey sampled unhealthy **13.6 s**, Snowy **0 s**;
Snowy's container, gateway, config/profile and session/device/job inventory
unchanged. Across all three switches the sampled flakey intervals were 14.1,
14.4 and 13.6 s. Rakku had no deployment/service restart; only its authenticated
SparkyFitness API removed the precisely identified TEST row at cleanup.

Checks passed:
- Focused x86 `openclaw` (includes wind-down, calendar and morning-brief
  contracts), `openclaw-people`, `openclaw-in-place`.
- Yari toplevel evaluation/build; native aarch64 `openclaw-config` and
  `openclaw-in-place-config` (including config validation).
- nixfmt checks, changed-test Statix, whitespace; helper Ruff and ShellCheck
  (`-s bash` for Nix shebangs). Whole touched container module has **5 existing
  Statix warnings**, exactly the same 5 as baseline `0e69c40c`, no new warning.
- New reference-path contracts failed before files existed, then passed.
  The browser reproduced the separate hardlink bug before the Nix fix.

No full suite, aggregate flake check or cron job was force-run. Initial build
attempts copied derivations but hit a non-executable scp destination; the final
helper invokes it through bash. This did not activate a system.

### Real Control UI acceptance

Used **https://flakey.hummingbird-lake.ts.net**, in a NEW TEST conversation,
never sent TEST input to main:
`agent:main:dashboard:3628aeff-7cd4-4b38-922c-58251e59d535`, session
`f1bf5ac7-466d-4aeb-baab-1064d9e84db8`. Its browser alone was paired, then removed.

- One rating widget held five charge and five mood buttons. Actual button
  clicks selected 4 and 3, optional note was TEST, Continue sent explicit
  `TEST Wind-down rate: charge 4/5; mood 3/5; ...`.
- Exactly one TEST check-in was created; write/read-back showed energy 4/5 and
  mood 6/10 (stored 60), with safe TEST marker and no private note.
- ChargeRead and Scale showed input/baseline/deviation/weight/pull tables and
  default-only 3.0 with missing history, no invented zone/trend/runway.
- Projects seeded two TEST entries, then verified park/resume using stable IDs
  and a restart note. No fabricated hours or claim of changing Atlas/Forgerie.
- Ledger showed reported took/restored charge without numeric costs. Capture
  used one text box and sorted fake ideas/to-dos/worries; the idea stayed an
  idea, and no calendar event was created.
- Tomorrow used all four owned-calendar reads, two fake must-dos and the next
  civil date. The zero-duration real event exposed the free-window issue;
  corrected weekly output and final-source smoke marked its remainder unknown.
- Stop wrote/read-back `memory/TEST-2026-11-15.md`, retaining the daily schema.
  Real `memory/2026-11-15.md` was not created. Sunday review read all seven exact
  real dates, excluded TEST, retained 13 November's legacy ratings, omitted
  nonexistent paired means, reviewed zone/projects/calendar and saved one TEST
  intention with read-back. Deeper talk declined; therapy stayed off.
- On final source, an invented n=8 body example produced **3.0−0.5−0.5−0.3=1.7**,
  felt 4, **gap +2.3**, with missing activity/project routes. No Sparky write.
  A TEST policy was saved/read twice: completed weekly gate, declined deeper
  gate, null firstFullRunAt/quietUntil and therapy false; repeated offers suppressed.

**19 inspected PNGs** in `/tmp/claw/winddown-full/`: desktop 1440×900 and phone
390×844. Rate, Projects, Ledger, Capture, Tomorrow and weekly coverage are
readable/reflowed. Native Markdown arithmetic tables show full columns on
desktop; phone uses the existing reachable Expand table control. These local
screenshots include real calendar names/locations and legacy rating context;
do not publish them. No new visual system or shared Canvas layout changed.

### Complete cleanup and final proof

Verified **2026-11-15 16:59Z**, more than ten hours before the 03:00Z deadline:

- Removed exactly `memory/TEST-2026-11-15.md`, TEST interim `projects.json` and
  TEST `policy.json`. No zone/crash files were created. No TEST file/state
  remains in the private workspace. Quiet-period state is absent for tonight.
- Deleted only Sparky check-in **`a7373ac8-8b30-4db5-9506-05bac6dd18b7`**, matched
  by TEST marker, date/time and 4/60 values through the authenticated existing
  API. DELETE 204; date read-back omitted it; ID GET 404. Independent live MCP
  list_checkin_diary also confirmed no TEST entry. No new key was made.
- Browser closed, exact TEST session deleted, then `openclaw memory forget
  --agent main --session f1bf5ac7-466d-4aeb-baab-1064d9e84db8` applied offline
  after preview. No mixed lineage/refusals; repeated preview **0 entries**.
  Retained archives are durably forgotten, not manually edited or deleted.
- Only flakey stopped/restarted for offline Forget. Gateways healthy, all four
  reconcilers active; Snowy unchanged. Temporary pairing removed.
- Today's `memory/2026-11-15.md` is **absent: no Wind-down block**. USER.md and
  13 November's original file are byte-identical; MEMORY.md remains absent.
- Job **`d963c743-e6fe-47b4-8a67-94df999a735a`** unchanged in ID, enabled state,
  agent, full payload, delivery and schedule: **21:00 America/Denver**. Next run
  **2026-11-16 04:00Z** (MST). This is correctly later than the requested 03:00Z
  readiness cutoff. The 07:00 job contains the latest-zone/quiet policy reads.
- All seven installed reference copies match final Nix source, link count 1.

Evidence/scripts: `/tmp/claw/winddown-full-*` locally and on Yari; switch
snapshots `/var/tmp/winddown-full-yari/`; TEST storage evidence outside the
workspace `/var/tmp/winddown-full-workspace/`. The scripts contain no keys.

### Limits still unverified

This remains an agent-run skill, not deterministic workflow/arithmetic code.
Real daily body inputs were too thin; synthetic arithmetic and honest missing
states were checked, not every clamp/rounding/zone-persistence/crash/runway
branch. No crash was marked, therapy enabled, phone/Household/Atlas connected,
or real quiet clock started. Post-quiet amber/red morning behaviour, short
mode, every skip/add/revisit/resume/failure branch and widget-less ask_user were
not live-exercised in this acceptance. Calendar writes/Undo were not retested
or changed; all **calendar calls in this run were reads**. Persistent weekly
and deeper gates were checked with a removed TEST policy. A fresh automatic
21:00 run and tomorrow's 07:00 run are necessarily still future events.

## Forward rollback

Do not restore a historical Yari generation: it could undo another session's
changes. On current cairn, make an inverse commit of the wind-down feature,
reference materialization and acceptance corrections (`git revert --no-commit
d5428c51 284895e9 1966daf1`),
resolving later overlaps explicitly. Fetch/rebase, run the same focused checks,
build the pinned current Yari output, then use the idle-gated **in-place**
procedure with unchanged-Snowy, no-container-restart and automatic fallback
guards. Rakku, Google and SparkyFitness need no deployment change. Preserve
real daily notes/check-ins/projects/crashes/policy and all pairing/tailnet state;
the daily schema remains backward compatible. A skill rollback is not a data
rollback and must not delete real check-ins or calendar events.
