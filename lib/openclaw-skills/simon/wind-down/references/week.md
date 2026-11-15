# Sunday end-of-week close

After normal Sunday Stop, separately offer: “Would a short weekly look-back
help?” Keep it optional, outside Stop. A decline ends it. Don't force a long
review after midnight: defer short-mode Sunday until Simon asks. A requested
weekly look-back on another day is valid; label its actual date range.

Read policy.weeklyOffers keyed by the local **Monday date**. Persist the offer
status (offered/accepted/declined/completed) with read-back, never repeat it
because a session/restart forgot. An unavailable gate means don't repeat an
automatic offer. This is not the deeper-talk gate below. Resume accepted but
unfinished weekly work at the actual next step, not with a new offer.

Read every exact daily `memory/YYYY-MM-DD.md` Monday through Sunday, including
13 November's legacy block. Separate missing files, missing ratings, failed
reads and explicit skips. Never fill missing days with zero, interpolate, or
claim seven days if only two were recorded. Exclude TEST blocks/files.
Read SparkyFitness check-in receipts and daily estimates when available;
legacy Charge/Mood 1–5 remain usable as legacy felt data. No mass migration.

## Weekly steps: one at a time

1. **ChargeRead weeks.** Draw labelled 1–5 felt and data series, mood separately
   when useful. **ChargeRead.weeks** is one `{week,felt,data}` pair per week,
   up to 52. For a checkable gap, use dates having **both** felt charge and a
   computed estimate: arithmetic means on those same paired dates; show n
   and included/missing dates. Omit an incomplete pair, never invent a data
   mean. Show unpaired felt/mood means separately with their own coverage.
   Weekly gap = felt mean − data mean. A default-only estimate is labelled
   default, not measured recovery. Review whether the gap grew without
   blaming Simon or changing fixed weights to fit. Ask one contextual question
   about the week's pattern, not a questionnaire. If no ratings, say so.
2. **Zone trend.** Show the recorded/computed daily zone words and supported
   reasons, plus 28-day context if available. Distinguish deteriorating,
   improving or unchanged observed zones from unknown days; no invented
   continuous history. Runway says “not enough data yet” until eligible crashes
   exist. Offer missed-crash confirmation only when evidence supports it.
3. **Project review.** Read the interim list, show active/on_hold and explicit
   lastTouched. Ask what to carry, park or resume. Suggest parking at most
   three with short reasons, never auto-park. Apply agreement to the same
   stable IDs and read-back. Save a restart note when supplied. Atlas/Forgerie
   remain disconnected; no invented commit hours, late nights or activity.
   Repeated skips/bounces only support a planning preference with dated
   evidence and explicit feedback; a single skip is not a preference. Never
   silently drop/park an action. Keep this private, not USER.md/MEMORY.md.
4. **Next week's calendar shape.** Read calendar_busy plus calendars_list and
   each owned calendar_events for **next Monday through Sunday**, actual
   America/Denver offsets. Show dates, named busy blocks, all-day obligations,
   and known open stretches; mark failed/partial dates unknown. Use day's
   interval/gap rules. Do not create seven day plans or infer work locations,
   meetings attended, journeys or consent to fill gaps. Existing calendar
   skill still owns any proposed event, picker, verified Added and Undo.
5. **One intention.** Ask for one intention for the coming week, in Simon's
   words. If his reflection already contains one, don't ask again. This is
   not seven obligations, a project assignment or a new morning plan.

Save the actual reflection, week dates/coverage/means, project decisions,
calendar shape and the **one intention** under Sunday's existing
`### Weekly look-back` inside the single Wind-down block. Preserve all daily
answers and other notes. Read-back before “saved”; any failure never holds
this close open. Do not share it. Mark weekly gate completed only after
verified storage, or closed-unconfirmed if storage failed; no automatic retries.

## Deeper talk, once a week, after the close

After the weekly close (or declined weekly offer), separately offer a deeper
talk **at most once that week**, tracked as `deepOfferedAt` in the same Monday
policy entry, with verified read-back before an automatic repeat could occur.
Belief and religion stay here, never in daily steps. If an offer already
happened after another night's close, don't offer again Sunday. No 22:30
fallback cron exists here; don't pretend it does. A clear topic on another
night can earn this same once-a-week offer after Stop, not a second gate.

Therapy remains **OFF** until Simon has read and explicitly approved the
therapy reference and the policy switch is verified. Do **not load or use**
therapy.md merely because he accepts a talk. With therapy off, offer an
ordinary deeper conversation, no therapeutic method or automatic activation.
If enabled, read therapy.md and apply it as Flakey, not a separate persona.
A decline ends the offer immediately; no nagging or automatic new work.
