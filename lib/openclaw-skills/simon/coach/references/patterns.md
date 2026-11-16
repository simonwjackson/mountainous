# Private patterns note and minimal gates

Only Simon's private workspace. Read exact paths, distinguish absent from
unavailable. No transcripts, raw quotes from distress, diagnostic labels or
copies in USER.md/MEMORY.md. No external services, shared sessions or Laure.
These workspace files are private notes, not a guarantee that the model
provider never processes the conversation.

## coach/state.json

Single authority for coaching offers, not wind-down quiet policy or projects.
Create only after confirmed absence. Version 1 shape:
`{version:1,offers:{"YYYY-MM-DD":{status:"offered",at:"ISO"}},referrals:[]}`.
Dates are America/Denver **civil dates**, not frozen 03:00 wind-down days.
Before an unsolicited offer read, edit/write, then read-back today's entry;
only offer if no entry existed and the new entry verified. After an answer,
update status accepted/declined with read-back. Any entry suppresses another
automatic offer that day, across sessions/restarts/triggers. Read failure or
ambiguous write means no automatic offer. No hidden scheduler.
Referrals contain only `{id,trigger,startedAt,suggestedAt,resolvedAt?}` for
hopelessness/disappear, sustained-red or repeat-crashes occurrences. Check the
continuing occurrence before suggesting again; no raw speech. Resolve when
known to end; don't invent recovery or use a forever “once” flag. Preserve
unrelated fields. Existing wind-down `policy.json` still owns quiet/weekly
gates; ignore any legacy therapy approval flag, which cannot disable coach.

## coach/patterns.md

Short dated bullets with stable line IDs, provenance (Simon reported / observed
with date), and only useful drains, restorers, early crash signs, experiments
and decisions. Don't infer a trait from one tired night. Ask before treating
a guess as a pattern. Never retain a conversation transcript or harsh labels.
No separate ratings, project status list, daily plan or crash history.

Experiments: `{id,choice,start,end,decisionRule,result,status}` in readable
bullets. Start/end are agreed dates or instants. Decision rule says how to
keep/change/drop it; result is pending until actually reported. At end ask
briefly if needed, never fabricate a result or quietly extend the experiment.

Sunday's existing weekly look-back reads this note and shows **what changed
that Monday–Sunday**: additions, corrections, decisions, experiment outcomes,
with dates/IDs and uncertainty. Offer Keep / Correct / Delete, one line or
small related group at a time, using the wind-down cards/options style and
chat fallback. Simon may correct/delete any line any time. Apply the exact
edit, read-back and confirm only that edit. Don't copy deleted content into
a changelog or daily note; a deletion marker may contain just date/ID.
Deletion changes this note only. Never say “no copy anywhere”, or imply a
correction erased earlier chat messages, provider logs or backups. Confirm the
exact note edit, not global erasure; transcript/memory retention is separate.
If no file or no changes, say so, no invented weekly pattern.

## Writes and tests

Read immediately before edit; preserve unrelated content and IDs. Say “noted”
until read-back matches. Ambiguity reconciles, never blind retry; failure lets
him stop. No real files from TEST: use `coach/TEST-patterns.md`,
`coach/TEST-crash-plan.md`, `coach/TEST-state.json`, never real coach state,
wind-down policy/quiet clocks, real project changes, daily ratings or check-ins.
Show TEST clearly on cards. Record created paths for operator cleanup; do not
ask the agent to invent a deletion tool it doesn't have. TEST content never
counts as an offer, referral, pattern, crash or baseline in real use.
