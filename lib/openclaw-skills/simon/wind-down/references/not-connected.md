# Connection map and honest degradation

Do not call the stopped Logbook, the paused Pi assistant, retired/offline Atlas or Laure's
tools. Do not install ClawHub skills, add exec or place keys in OpenClaw.
Connection/config changes go through Nix and their own tested boundaries.

| Original feature | Flakey now: exact honest note | What would connect it later |
|---|---|---|
| Atlas plans/picks and done trail | “Atlas is retired and offline; planned picks come from last night's note, and done/slipped from what you tell me.” | Retired and offline; no Atlas connection is planned |
| Atlas ideas/actions/private flags/project filing | “Captured privately here, not filed in Atlas.” | Retired and offline; no Atlas connection is planned |
| Atlas tomorrow note/Today | “Tomorrow's note stays in this private daily note; there is no Today view.” | Retired and offline; no Atlas connection is planned |
| Project status/parking | “This changes only the interim project list, not Atlas or Forgerie.” | Atlas is retired and offline; Forgerie never owned parked state in the final original |
| Private Logbook journal | “Worries stay in this private workspace; the private journal is not connected.” | An approved owner-only journal tool with typed schema, confirmed receipts and no shared destination |
| Laure's Household view | “Household is not connected; nothing is sent to Laure.” | A separately approved privacy-filtered summary channel; zone, zone-only trend, plain runway/reasons, what would help and tomorrow shape only; never ratings, body readings or raw journal |
| Forgerie counts/work-personal activity | “Project hours and late-night counts are unavailable, not zero.” | Authenticated exporter of per-project/per-hour positive/explicit-zero counts; known IDs and work/personal classification, not open Forgerie API to other hosts |
| Phone pushes / worsening-zone monitor | “No daytime monitoring or phone push is connected.” | Nix-managed timer/notification seam; after quietUntil, worsening zone only, one per day with ambiguous-send dedup; fixed privacy-safe body, no health readings |
| Logbook estimate/history/runway | “This is the same arithmetic over partial SparkyFitness inputs, not Logbook's live output.” | Deterministic tested computation tool using typed daily data, missing states and stored crash decisions; no need to restart Logbook |
| Native waiting workflow/pane/rail | “The 21:00 opener waits for your reply; this is a conversation workflow, not a persistent Pi activity chip.” | App workflow state/delivery engine, exact step IDs, Next/Skip/Add/revisit/resume, side rail/folded toolbar, send-hold chip priority and recovery |
| Sunday 22:30 deeper-talk fallback | “The weekly offer is tracked here; no 22:30 fallback job is installed.” | One durable once-per-week gate shared with a Nix-configured fallback, after close only |
| WellbeingDashboard | “I can show these private sections here, not open the original app.” | App activity with Open/back section navigation, same domain source, no workflow rail |

## Features that are connected

- 21:00 opener and 07:00 brief remain their existing isolated scheduled jobs.
- Owned-calendar skill/card, complete owned-calendar picker, duplicate check,
  read-back and Undo stay in charge of calendar mutations.
- SparkyFitness report/sleep/sync reads supply dated body, food and exercise
  evidence. Its explicit energy/mood check-in is the sole wind-down write
  exception; storage documents scale encoding, receipts and failure handling.
- Private fs/memory stores daily blocks, interim projects/crashes/policy and
  latest-zone projection. Coach is live at its four daily boundaries and Sunday
  patterns/crash-plan review. show_widget/ask_user/progress_card provide today's
  step UI; no therapy approval switch remains.

The cost: this is still agent-run arithmetic and conversational workflow, not
a deterministic service or native workflow/card state machine. Partial inputs
can miss a worsening zone; no estimate is a diagnosis or assurance. Future
cards must expose typed missing/failed/partial states rather than inventing
numbers to satisfy the original required numeric props.
