# Private storage and receipts

All paths are relative to **Flakey main's configured private workspace**, not
this skill's read-only installation and not a host path guessed from memory.
Use fs read/edit/write or exact memory_get. No exec, Logbook, Atlas or journal
tool. Read the exact path; a search miss is not proof of absence. Confirm
missing versus unavailable. Keep ratings/worries out of USER.md and MEMORY.md.

| Path | Authority and contents |
|---|---|
| `memory/YYYY-MM-DD.md` | One `## Wind-down` block for the frozen wind-down day: private answers, picks, captures, tomorrow note, weekly close and service receipts |
| `memory/wind-down/policy.json` | version 2; firstFullRunAt, quietUntil; weekly offer gates, optional last daytime warning date if a future monitor is connected |
| `memory/wind-down/latest-zone.json` | Disposable latest projection read by **07:00 brief**, not a second rating store |
| `memory/wind-down/crashes.json` | version 1; crashes array `{id,start,end,status,source,note?}`; inclusive dates, confirmed decisions, stable IDs |
| `memory/wind-down/projects.json` | version 1; interim projects array `{id,name,status,kind?,lastTouched?,restartNote?}`; status active/on_hold; explicit last-touched date or null, not inferred hours |

Never create a separate tomorrow file or second capture inbox. Tomorrow lives
in tonight's dated block, headed with the next civil date. The morning reads
that same source. Interim projects replace only the missing Atlas status/list,
not Forgerie's activity or running state. Mark the list “interim, Atlas retired and offline”. Use stable locally unique IDs (safe letters/digits/dash), preserve
IDs on park/resume and names on unrelated edits. Don't change pinned user
fields without his request. Migration later must reconcile, not duplicate it.
Crashes and policy are independent of the zone projection. No file starts
with invented empty history; create an empty list only after absence is known.

## Daily block: backward compatible with 13 November

Keep the original heading and all original fields/subheadings below. Optional
v2 sections append; legacy readers still find Charge, Mood and Tomorrow.
Do not bulk-rewrite old notes, rename headings or reinterpret legacy mood.
A legacy complete/short/stopped status remains valid. Never replace unrelated
content above or below the block. Locate its end at the next level-2 heading
or EOF, not at the next level-3 subheading.

Template only; placeholders are not data:

```markdown
## Wind-down
- Wind-down day: YYYY-MM-DD (America/Denver, 03:00 to 03:00)
- Status: complete / short / stopped / skipped / in_progress
- Charge: <1–5 or not provided>
- Mood: <1–5 or not provided>
- Rating note: <own words or not provided>
### Day
<actual answer or skipped/not asked>
### Look-back / Reflection
<actual answers or skipped/not asked>
### Capture
#### Ideas
<own words or not provided>
#### To-dos
<own words or not provided>
#### Worries
<own words or not provided>
### Tomorrow — YYYY-MM-DD
- Note: <actual note or not provided/not asked>
- Must-dos: <up to three supplied picks or not provided/not asked>
### Picks
- Planned: <count or pending>
- Done: <count or pending>
- Slipped: <count or pending>
<each actual pick and Simon's explicit done/slipped/planned status; known times only>
### Projects
<verified changes to interim list, or none; never a second project list>
### Ledger
<Took charge / Restored charge, facts versus labelled assessment>
### Scale
<working table, equation, partial coverage, gap, zone reasons, runway>
### State
- Schema: 2
- Mode: normal / short
- Steps: <ordered kinds, done/skipped/pending/current; private result per step>
- Closed at: <actual ISO instant or not closed>
- Check-in: <verified date/time/marker/values, ID only if exposed; or not confirmed>
### Weekly look-back
<Sunday only: actual reflection, paired means/coverage, project decisions, next-week calendar shape, one intention; explicit missing data>
```

Omit v2 answer sections not asked, except state/receipts needed for resume.
Never save pending calendar drafts. Keep structured scale data as an optional
JSON fence in Scale with `day,usual,estimate,gap,zone,reasons,coverage,pulls`
and each pull's raw input, baseline n/mean/SD, weight, shown pull and note.
This is a dated computation snapshot, not an authoritative body store. Read
fresh Sparky data when recomputing; retain provenance and calculation version.

## SparkyFitness owns the explicit ratings

**Yes, check-ins can hold energy and mood.** The deployed
`sparky_manage_checkin` schema has `log_mood`, `energy_value` integer **1–5**
and `mood_value` integer **1–10** (stored upstream as **10–100**). These are
not the same mood scale. Use a stated, reversible encoding:
**energy_value = charge; mood_value = 2 × wind-down mood**. Thus the five mood
buttons map 1,2,3,4,5 → 2,4,6,8,10; stored mood scores 20,40,60,80,100.
This is an encoding, not a judgement or a mood inferred from prose. Daily
memory keeps the original 1–5 values and the verified check-in receipt (ID if exposed).
Do not let nutrition-fitness log these a second time.

Discover the live schema first; if it no longer has these fields, say why and
keep the original ratings only in the daily block. Never silently reinterpret
1–5 as 1–10. Skip an omitted rating field; never substitute a default.
Only when a rating was actually supplied:
1. Read `sparky_manage_checkin {action:"list_checkin_diary",entry_date:<day>}`.
   Look for the exact marker/receipt before writing, including on resume.
2. Write **one** `log_mood` with entry_date = frozen day, energy_value and/or
   mood_value as above, `notes:"wind-down:<day>; mood5=<original or missing>"`.
   Use no private rating note, worries or reflection in upstream notes.
3. Read list_checkin_diary for the same date; verify date, energy and mood including the service's stored scaling, plus
   the unique marker and returned local time. Keep an ID **only if returned**:
   current log_mood/list_checkin_diary text exposes time/values/notes but no ID.
   Do not invent one or claim ID-based reconciliation is available. The
   timestamp + exact marker + values form the receipt when no ID is exposed.
   The operator can resolve that receipt to an ID through SparkyFitness's
   authenticated existing app/API for TEST cleanup. Keep that receipt
   in State. Only then call the check-in saved. It is separate from the note.

Every log_mood appends a NEW check-in; it has **no idempotency key**, update or
delete action in the current allowlist. On timeout/ambiguous result read and
reconcile, **never automatically repeat**. Multiple same-marker results mean
ambiguous; don't choose silently. On a revised rating keep the prior receipt,
write a clearly labelled revision only on Simon's explicit revision request;
use a revision suffix in the marker, read-back and use latest verified revision
for that wind-down day. Ignore unrelated daytime check-ins in this model;
never average them in as extra nights. Daily note ratings are receipt snapshots
of these check-ins, not competing independently editable upstream truth.
If check-in fails, record original ratings with `not confirmed in SparkyFitness`;
this failure never blocks closing. Never send the optional private note there.

## Policy, latest zone and ordering

Initialize policy only after confirmed absence. On first real completed normal
close set `{version:2,firstFullRunAt:<actual ISO>,quietUntil:<ISO +14 elapsed days>,
weeklyOffers:{}}`. Preserve existing fields on each edit.
Do not reset quietUntil at deployment, restart, revision, short mode or tests.
A missing/unreadable policy is conservative: no zone-driven lighter plan/warning.
Coach is live independently of this policy. Ignore legacy `therapy` fields;
never require approval or set a new therapy switch. Coach owns only its private
`coach/crash-plan.md`, `coach/patterns.md` and minimal `coach/state.json`; see
its references. Do not copy their contents into daily notes or USER.md/MEMORY.md.

At each full close or explicit scale refresh, after confirmed daily storage,
write/read-back latest-zone.json:
`{version:1,day,computedAt,zone,since,reasons,estimate,coverage,missingSignals,
quietUntil,sourceDay:"memory/<day>.md"}`. zone is green/amber/red or null when
uncomputable; estimate may be null. coverage says partial/thin/available, with
metric sample counts. reasons are safe plain reasons, not private journal text.
quietUntil is a copy from policy, never its authority. No fake fresh timestamps
on old data. Revisions recompute this projection from authoritative inputs.
The 07:00 brief accepts only last wind-down day's fresh matching source and
policy, checks quietUntil, and treats missing/stale/invalid data as unavailable.
No warning scheduler is installed; this file is not monitoring.

## Write/read-back contract

Read current file immediately before editing; preserve unrelated notes/fields.
For a confirmed new file use write; existing notes use exact edit. A resumed
or revised close replaces its single block, never appends a second. After each
write **read-back** with read or memory_get and compare date, values, IDs,
answers and unrelated content against the input. A write-tool success alone
is not a verified save. Say **noted** until that destination's read-back passes.
StopStep.saved names only verified saves, not Atlas/journal destinations.

If a read/write/read-back fails, name the exact path or SparkyFitness check-in,
say “not confirmed saved”, and **let Simon stop**. Do not reopen the close or
automatically retry an ambiguous write. A repeated save first reads/reconciles.
If a projection fails, the daily note still stands; flag the stale projection.
No save may hold the workflow open.

## TEST isolation

Only explicit TEST runs may use invented answers. Prefix every created test
file/answer/receipt with TEST; never use other conversations as real evidence.
Tests must not start the real quiet clock or mark real historical skips.
Never merge TEST records into model baselines or Sunday means. Record all
created paths and Sparky check-in IDs for complete cleanup. Flakey has no
check-in delete action: do not invent one; the operator removes precisely
those TEST IDs through SparkyFitness's authenticated existing deletion path
and verifies absence. A test-only temporary policy/zone/projects/crash file
must be removed or its exact prior content restored before the real run.
