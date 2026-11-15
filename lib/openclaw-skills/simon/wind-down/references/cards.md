# Today's cards, tomorrow's app contract

**Product mode**: reuse Canvas classless baseline and `.card`, `.row`, `.muted`.
Tokens: `--text`, `--text-strong`, `--muted`, `--card`, `--border`, `--radius`,
`--font-body`. Transparent page, neutral buttons, no new visual system,
external assets/fonts, network requests, browser storage, auto-submission or
pins. No accent blue/stripe, gradient, custom hero typography or decorative
charts. Held back: mockup battery/hero art and full pane chrome; Canvas owns
this surface today. Future app uses accepted cd76947 deck/REFINE, not a new
redesign. Colour belongs only beside zone words on scale/chip; neutral words
are sufficient if no Canvas zone token exists. Runway and ratings stay neutral.

Eye flow: current step's facts/input → the one question/action → quiet context.
Each visual must encode real information: table = checkable arithmetic;
calendar list = time order; two lists = energy deposits/withdrawals; labelled
series = real paired weekly means. No invented marks for missing data.

## Rating: ONE show_widget, two groups of five buttons

Draw charge and mood together, **five buttons** numbered 1,2,3,4,5 **each**.
Keep an optional note and Continue in that same card. Each number button's
user click sets its own widget-local selection, aria-pressed and visible
Selected state; it must **not** send a half-answer that advances the step.
Continue sends the two explicit selected values in one `sendPrompt`, only
inside its click handler. Disable Continue until both are chosen; Skip stays
available so either may be omitted in chat. No hidden/default rating.

Use this pattern with all ten numbered buttons; no example answers:

```html
<div class="card">
  <h2>Rate</h2>
  <fieldset id="charge"><legend>Charge: 1 depleted, 5 very charged</legend>
    <div class="row">
      <button type="button" aria-pressed="false" onclick="pick('charge',1,this)">1</button>
      <button type="button" aria-pressed="false" onclick="pick('charge',2,this)">2</button>
      <button type="button" aria-pressed="false" onclick="pick('charge',3,this)">3</button>
      <button type="button" aria-pressed="false" onclick="pick('charge',4,this)">4</button>
      <button type="button" aria-pressed="false" onclick="pick('charge',5,this)">5</button>
    </div>
  </fieldset>
  <fieldset id="mood"><legend>Mood: 1 very low, 5 very good</legend>
    <div class="row">
      <button type="button" aria-pressed="false" onclick="pick('mood',1,this)">1</button>
      <button type="button" aria-pressed="false" onclick="pick('mood',2,this)">2</button>
      <button type="button" aria-pressed="false" onclick="pick('mood',3,this)">3</button>
      <button type="button" aria-pressed="false" onclick="pick('mood',4,this)">4</button>
      <button type="button" aria-pressed="false" onclick="pick('mood',5,this)">5</button>
    </div>
  </fieldset>
  <label for="note">Optional note</label><textarea id="note" rows="2"></textarea>
  <button id="continue" type="button" disabled onclick="sendPrompt('Wind-down rate: charge ' + chosen.charge + '/5; mood ' + chosen.mood + '/5; note: ' + document.getElementById('note').value)">Continue</button>
  <button type="button" onclick="sendPrompt('Wind-down: skip rate')">Skip</button>
</div>
<script>
const chosen = {};
function pick(kind, value, button) {
  chosen[kind] = value;
  document.querySelectorAll('#' + kind + ' button').forEach(b => {
    b.setAttribute('aria-pressed', String(b === button));
    b.textContent = b === button ? value + ' Selected' : b.textContent.replace(' Selected', '');
  });
  document.getElementById('continue').disabled = !(chosen.charge && chosen.mood);
}
</script>
```

This single submission carries explicit text for both ratings. Accept a typed
single rating too without inventing the other. Widgets unavailable: say so,
then ask_user one question per rating with authored **1,2,3,4** options and
“type 5 in Other” in the prompt. OpenClaw 2026.11.3 allows 2–4 authored
options, not five. Other is built in; never author it. Validate typed 5, allow
skip/no_answer and optional note in chat. Never use the old “4 or 5” choice.
Scheduled openers cannot render widgets; wait for Simon's interactive turn.

## Rail and free text

progress_card holds the ordered plan and generic step names, not answers.
Use pending/in_progress/completed statuses the actual tool accepts; mark
skipped labels plainly. A user answer advances; no artificial extra Next.
Offer explicit conversational buttons when useful: `Wind-down: skip <kind>`,
`Wind-down: add <kind>`, `Wind-down: revisit <kind>`, `Wind-down: resume`,
`Wind-down: stop`. Never fabricate native Pi workflow IDs or tools.

Capture/reflect: one labelled textarea and Continue sending explicit
`Wind-down capture: ` / `Wind-down reflect: ` plus its value from the user
click. Keep speech input usable through the normal device keyboard. No fake
microphone recording capability. Plain chat always works. Escape tool/user
strings as HTML text or use textContent; never interpolate them into scripts,
event attributes or URLs. Only safe fixed kind/ID values in executable handlers.

## One-to-one future card map

| Original name | Today's show_widget content / behaviour |
|---|---|
| RateStep | One ten-button card above, optional note, validated explicit submission |
| ChargeRead | Felt/data comparison on labelled 1–5 scale, working table, equation, gap, paired weeks when real |
| DayStep | Planned picks from tomorrow note, Simon-confirmed done/slipped, planned calendar timeline, known waiting loops |
| ReflectStep (lookBack) | One contextual day prompt and speech-friendly text input; green always included |
| ScaleView | Zone word, 28-day zone trend, full arithmetic table, missing signals, runway, confirmed/suggested crashes |
| ProjectsView | Interim active/on_hold list, last touched, at most three explicit Park suggestions, Resume; no invented activity cells |
| LedgerView | Took charge / Restored charge, facts first, labelled assessments, no invented net bars |
| CaptureStep | Single textarea for all thoughts |
| CaptureSorted | Original words and Ideas/To-dos/Worries; destination gaps; saved only on verified note read-back |
| ReflectStep (reflect) | Same input, contextual reflection; deeper topics outside close |
| TomorrowStep | Next-date calendar shape, actual note and up to three Simon-selected must-dos |
| StopStep | Plain close, only confirmed saves; never new work/questions |
| EmptyState | Named missing/failed source and supported next action, not fabricated zero |
| WellbeingDashboard | Outside the workflow only: latest private scale/project/charge sections with explicit Open/back prompts, no rail or required completion |

Weekly uses ChargeRead.weeks, zone trend, ProjectsView and TomorrowStep's
calendar shape, then the intention input. No second source of domain state.
Original vocabulary limits remain: Day picks ≤3; project park suggestions ≤3;
ChargeRead pulls ≤10 and weeks ≤52; projects/crashes ≤100; scale reasons ≤20;
ledger rows ≤30 each; Tomorrow blocks ≤48. Longer collections paginate with
all entries reachable, never silently discard. No unsupported hours just to
satisfy an old required numeric prop; future app needs typed missing states.

## Container and failure rules

No fixed widths/heights. Reflow rows and whole button groups to the actual
container. Reduce spacing before facts/controls; overflow only with labelled
reachable controls, never remove a rating, calendar or Skip/Stop. Text wraps,
including long unbroken names. Tables can use a visibly scrollable region;
primary controls stay outside it. Document/list scrolling is normal. Do not
change the shared Canvas baseline to solve a single card.

Check desktop 1440×900, phone 390×844, narrow-tall and wide-short. Inspect
blank/loading/partial/error/ideal; 0/1/many rows; long names; missing alongside
zero and negative pulls. Empty data must not become a fake chart. If
show_widget is unavailable/fails, use compact facts and ask_user/chat, not
internal Canvas URLs or a false “rendered” claim. Full original pane, waiting
chip priority, folded side rail and dashboard navigation are codified but
not native OpenClaw workflow capabilities today (not-connected.md).
