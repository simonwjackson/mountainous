---
name: wind-down
description: Simon's private end-of-day and Sunday end-of-week close. Use for wind down, start wind-down, resume/skip/add/revisit a wind-down step, weekly look-back, burnout scale, charge comparison or project park/resume. After midnight use Rate, Capture, Stop only.
---

# Wind-down

Flakey closes the day in 10–15 minutes, as the usual persona, not a survey,
new therapist or dashboard. Simon may skip, add, revisit, resume or stop.
One step and one open question at a time. Never invent an answer.
Keep prose outside the current card to two short sentences, except the required
scale arithmetic table. No tool narration, file inventory or repeated card
facts. A failure may name its exact destination in one short status line.

## Select the mode

Use **America/Denver**, with the date's actual MST/MDT offset. The day is
**03:00–03:00**. Between 00:00 inclusive and 03:00 exclusive, use yesterday's
civil date and **short mode: Rate, Capture, Stop**. A start after midnight
also shortens an earlier waiting plan. Freeze the day once started. Preserve
an unfinished close's day and answers when resuming; never replace it at 03:00.
Tomorrow means the next civil date after that frozen day.

Read the exact `memory/YYYY-MM-DD.md` before starting. A missing file is not
a failed read. A completed `## Wind-down` block means no second close unless
Simon asks to revise it. Resume an unfinished close; replace its block on
save, never duplicate it. The 21:00 cron opener stays text-only and waits for
his reply. Ignoring it is not a dismissal. No fabricated automatic skip.

Normal spine: **Rate → ChargeRead → Day → contextual middle → Stop**.
Choose at most three middle steps from lookBack, scale, projects, ledger,
capture, reflect, tomorrow. On a green night always choose lookBack.
On Sunday, offer the weekly close separately after Stop. Short mode never
adds Day, Tomorrow or a weekly questionnaire; defer the weekly offer until a
later request. The weekly and deeper-talk offers are separate, optional gates.

## Read the references at their boundary

**Runtime read path:** Nix installs real, non-hardlinked copies of these
versioned references at **`.wind-down-references/<name>.md` in your workspace**.
Use `read` on that relative path, not the Nix-store link below: OpenClaw rejects
optimized store hardlinks. These files are read-only deployment assets, not
private notes or a second editable source. If absent, name the install failure;
do not improvise missing instructions or ask Simon to repair the files.

- Start and each daily step: [references/day.md](references/day.md).
- First drawing and widget actions: [references/cards.md](references/cards.md).
- Before any write, resume or read-back: [references/storage.md](references/storage.md).
- After Rate and for scale, crashes or runway: [references/scale.md](references/scale.md).
- Sunday after Stop or a requested weekly review: [references/week.md](references/week.md).
- Missing service or dashboard request: [references/not-connected.md](references/not-connected.md).
- Coach is **live**. Read [references/therapy.md](references/therapy.md), now a
  compatibility pointer to coach, at amber/red Scale, Projects choosing what
  to park, Capture worries (one ACT unhooking move), and Tomorrow (cut to three).
  Sunday also reviews patterns-note changes and drafts a crash plan if absent.
  All other steps stay unchanged. No approval switch; safety always applies.

## Privacy and truth

Private workspace only. Never put ratings, worries, reflections or journal-like
text in **USER.md** or **MEMORY.md**, progress summaries, logs, shared sessions,
Laure's tools, Household, another agent or external links. SparkyFitness owns
only the explicit charge/mood check-in described in storage; never send it
worries or the whole close. Calendar uses the existing Simon-only calendar
skill and its own explicit event permission, never private reflection text.
Food, training, sleep and body evidence come from SparkyFitness reads, not
memory guesses. Do not call Logbook, Atlas or paused Pi tools. No exec exists.
Use memory/fs, ask_user, show_widget, progress_card and registered MCP tools.

Before verified read-back say **noted**, not **saved**. A failed write never
holds the close open. Name the failed destination and let Simon stop. An
ambiguous write is not permission to repeat it. This is a skill, not a hidden
workflow engine: no promise of persistent chips, pushes or automatic monitoring.
