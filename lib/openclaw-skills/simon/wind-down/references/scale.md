# Transparent burnout scale (Logbook arithmetic, no Logbook calls)

Source: Logbook ADR 0016 and `logbook_core::wellbeing::compute`, read as source
only. Fixed weights are initial guesses, not clinical evidence. Review their
fit against Simon's ratings after about four weeks; don't silently tune them.
This skill computes the same rules over the inputs Flakey can actually read.
It is a degraded, explicitly partial model, not the stopped service's output.

## Data and dates

Build consecutive America/Denver local days, including days with missing data.
Use fresh sparky_get_daily_report, sparky_get_30_day_trends,
sparky_get_sleep_science and sparky_get_synced_data as needed. Discover their
schemas and inspect returned dates, sources, units and completeness. Trends
without individual daily readings cannot supply population standard deviation.
Use one resolved daily reading per metric, never count overlapping sync sources
twice. Sleep belongs to the wake day; retain returned body offsets. Convert
sleep to seconds, HRV to ms, resting HR to bpm only from explicit units.
If sources conflict without a clear resolved/preferred record, mark missing.
Do not use a readiness score as HRV. Food and exercise are ledger context,
not replacements for sleep/HRV/RHR. Never fabricate them from a free calendar.

| Signal | Available route | Numerical role |
|---|---|---|
| Felt charge, mood 1–5 | Simon; verified Sparky check-in; legacy daily block | Charge baseline/zone/gap; mood tracked, no fixed pull |
| Sleep, HRV, resting HR | SparkyFitness dated daily readings | Body pulls below; sleep zone rule |
| Activity and food | SparkyFitness reports | Ledger/context only, no new coefficient |
| Late conversation hours | **missing**: no authoritative hourly export | Do not infer from this chat's length or substitute exercise |
| Forgerie projects/activity | **missing**: no connected exporter | Interim projects are not measured activity |
| Slipped picks | Daily blocks, only Simon-confirmed totals | Missing until enough history exists, never zero-filled |
| Work meetings | **missing** as a workload signal | Calendar plans are not measured workload; no original fixed coefficient |
| Skipped nights | Explicit skipped closes in daily notes | Zone rule; short is not skipped |
| Felt minus data gap | Computed below | Track divergence/context, no invented coefficient or threshold |

Unknown/unconnected signals are **null/missing, never zero**. The partial sum
omits their contribution and lists them beside the result. A body metric with
insufficient history has Logbook's neutral arithmetic pull of 0.0, but its
input remains missing or thin, labelled why. Missing late/project routes do
not become measured zero-night/zero-project rows. Never renormalize weights
or use the interim active count as the missing Forgerie count.

## Estimate for day D

1. History = **preceding 28 local days**, `[D−28,D)`, excluding today. Current
   felt charge must never affect its own usual. `usual = mean(prior charges)`
   only with ≥7 prior ratings; otherwise **3.0**, explicitly “default; <7 ratings”.
2. For each body metric use its own prior nonmissing readings. Baseline is their
   mean. Need ≥7. Population SD = `sqrt(sum((x−mean)^2)/n)`, not sample SD.
   For a current reading and SD ≥1e−9, `z=clip((value−mean)/SD,−2,+2)`.
   No current reading, <7 prior readings or SD <1e−9 yields neutral pull with
   explicit “no reading”, “not enough history” or “baseline has no variation”.
3. Raw body pulls: sleep **+0.25*z**; HRV **+0.25*z**; resting HR **−0.15*z**.
4. Original late-night rule, only when connected later: distinct positive-count
   nights at **23:00–02:59**; post-midnight hours belong to the previous night.
   Last 7-night count N versus preceding 28-night count /4 B;
   `pull=max(−0.6,−0.1*max(0,N−B))`.
5. Original projects rule, only with activity: distinct stable named projects
   with positive counts in last 7 calendar days across assistant/Forgerie,
   `pull=max(−0.5,−0.1*max(0,P−steady))`; default steady upper bound **4**.
   Occupied hours count each UTC hour once; repeated DST hours count twice,
   but only one late night. An authoritative bounded successful empty summary
   can mean zero; an absent route cannot.
6. `raw=usual+sum(available raw pulls)`. `estimate=round1(clamp(raw,1,5))`.
   Round halfway away from zero, as Rust `round`, not ties-to-even.
   `shownUsual=round1(usual)`. First identify the largest **raw absolute** pull
   (last in order sleep, HRV, RHR, late, projects wins ties among available rows).
   Round each pull to tenths. In **integer tenths**, compute
   `delta=estimateTenths−usualTenths−sum(pullTenths)` and add delta to that
   largest pull. If |delta|>1 tenth, label “includes the 1 to 5 scale limit”.
   Never adjust the estimate to fit a story. Missing rows stay missing; if
   no available pulls exist, show default/usual only, explicitly thin.
7. `gap=round1(feltCharge−shownEstimate)` if charge exists. Positive means
   Simon feels more charged than the available data estimate, not denial or
   illness. Track daily gap and paired weekly means; don't add a sixth pull.

**Always show working**, after Rate and at Scale, as a table with these exact
columns (units/counts and n/SD may be in the cells):

| input | baseline | deviation | weight | pull |
|---|---|---|---|---|
| Usual: prior charge n | prior 28-day mean or default 3.0 | — | — | shown usual |
| Sleep / HRV / resting HR: actual value + unit or missing | mean, n, SD | clipped z or unavailable | +0.25 / +0.25 / −0.15 | shown pull, with reason |
| Late nights / projects | missing until connected | unavailable | −0.1, capped as above | missing, excluded |

Then an explicit equation `shown usual + shown numeric pulls = estimate /5`,
felt charge and gap. Use no fabricated precision beyond tenths for the result;
retain enough baseline/SD precision to check the calculation. Show coverage,
missing signals and the default, even if the table has no body rows with data.
“Not enough data for a personal estimate yet” is the honest default-only state,
not a measured 3.0. A partial estimate may still be shown as provisional.

Arithmetic check (invented numbers, never save as Simon's data): usual 3.0,
sleep z −2 → −0.5, HRV z −2 → −0.5, RHR z +2 → −0.3; missing late/projects;
**3.0−0.5−0.5−0.3=1.7** (partial). Felt 4 gives gap **+2.3**.

## Zones, since and trend

Recompute each historical estimate with **that day's** preceding baseline,
never apply today's baseline to the whole history. Evaluate red before amber;
retain all matched reasons, deduplicated. Missing evidence cannot match a
condition. Do not create recorded zeros for unrated or unknown days.

| Zone | Any condition |
|---|---|
| Red | Estimate ≤2.0 on ≥3 of last 4 **calendar days**; charge ≤2 on ≥3 of last 4 **rated days** (which may be sparse); ≥5 late nights in 7; amber signals on ≥5 consecutive calendar days |
| Amber | On ≥2 of last 3 calendar days either estimate OR charge ≤2.5 (count day once); ≥3 late nights in 7; ≥6 active activity projects in 7 days; ≥5 **slipped picks** in 9 days; 3 consecutive explicitly skipped wind-downs; 7-day mean sleep ≥2700 seconds (45 minutes) below preceding-28-day mean |
| Green | No supported red or amber condition matches; qualify “partial signals” when routes are missing |

Sleep amber needs all 7 recent readings and ≥7 preceding baseline readings.
Amber persistence counts any amber-signal days consecutively, including the
fifth that becomes red; it remains red while those signals persist, not an
alternating fifth-day red. A day without supported amber signals resets the
streak; unknown coverage must remain noted. Since is the first consecutive
day with the current zone; if history is truncated, label it as known since,
not the true onset. Trend is the last **28 local days**, one zone per computed
day with missingness/coverage, not interpolated ratings. Save only computed
history with provenance. Never call a historical unknown a measured green.

Mood and the felt-vs-data gap are reviewed as signals but have **no numeric
weight or independent zone condition** in the original model. Work meetings,
food and exercise also have no fixed coefficient. Don't invent one to appear
complete. A skipped night is a signal, not a failure or a zero charge.

## Crashes

Offer once to mark past crashes roughly: inclusive local **start and end**,
optional private note. Simon's manual mark confirms it. Validate start≤end.
He need not declare a new crash: suggest missed windows from evidence/context,
including him saying he feels burnt out; **he confirms or rejects each one**.
No diagnosis or silent confirmation from the number.

Original suggestion algorithm: maximal consecutive runs ≥3 days with estimate
≤2.0. When all preceding 14 days **and current day** have activity counts
(including explicit zeros), each current count must also be **< one quarter**
of that prior daily mean. Otherwise estimate suffices and note exactly
“no activity data for this window”. Sparky exercise is not that activity
count. Missing exporter history must not hide a possible crash. Label weak
partial estimates and context; never invent a data window from nothing.

Use storage's crash IDs and statuses suggested/confirmed/rejected, source
marked/suggested. Same start/end/note mark is idempotent; same current decision
is idempotent. Later confirm/reject may correct even a manual crash. Do not
suggest any window overlapping **any existing crash**, including rejected
ones; rejecting a window suppresses overlapping future suggestions even if
edges move. Explain that this may hide a distinct overlapping crash.
Read-back each change. Recompute runway after decisions; no automatic retry.

## Runway

Display **“not enough data yet”** until ≥2 confirmed crashes each have three
preceding daily estimates **and** there are 14 current consecutive daily
estimates. Never infer days-to-crash from a zone alone. Each crash level is
the mean of its three preceding estimates. Fit ordinary least squares to the
last 14 estimates with x=0…13, x̄=6.5: slope = sum((x−6.5)*(y−ȳ)) /
sum((x−6.5)^2). If slope≥−1e−9: `no_trend`, “last 14 days flat or rising”.
Otherwise fitted current = ȳ + slope*6.5; crossing(level) =
round1(max(0,(level−current)/slope)). Central days uses the mean crash level;
low/high use earliest/latest individual crash-level crossings. These are
**not confidence intervals**, guarantees or deadlines. basedOn counts only
eligible confirmed crashes. Default/thin body data makes this weak; say so.

## 14-day quiet period

Record firstFullRunAt once after the first **real completed normal close**,
quietUntil = that instant + **14 elapsed days** (not 14 UTC date labels).
Tests never start this clock. Read this policy before every recommendation.
Before quietUntil (or if policy is missing/unreadable), **no lighter plan due
to zone and no daytime warnings**. Scale/reasons are live immediately. Simon's
own requests for less work/rest still apply. After quietUntil, amber/red can
reduce non-essential plans with why once; don't prescribe new initiatives.

No daytime monitor or phone-push route is connected here. Do not claim it is.
If connected later, original cap is one daytime warning per local day on a
worsening zone after quietUntil; no second push on ambiguous delivery. Green
resets warning baseline. Zone changes originally also refreshed Household,
but Flakey must not send anything there (not-connected.md).
