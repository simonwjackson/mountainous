# Pace 2 first slice

Simon approved this deploy on 2026-11-13, including Laure's key and row in the
same switch. Pace 1's quarantined profile and gates are unchanged.

- Placement: Rakku, dedicated `pace2` user/unit/state (`/var/lib/pace2`, persisted).
  Loopback `127.0.0.1:3195`, Denver time, six-hourly SimpleFIN sync.
- Input `pace-service` pins the local Zao repository's landed `main` commit.
- `/mcp/pace` admits only flakey; `/mcp/pace-laure` only snowy. Each has its own
  server-held bearer credential and exposes only `pace_status` and
  `ui://pace/status`. Both gateways use server name `pace`: server names are
  unique per gateway, not across rows. Neither gateway holds a Pace key.
- Both have equal rights. This slice contains no write tools.
- The systemd sandbox matches the other Rakku apps. Pace has general outbound
  HTTPS; it has no destination allowlist. No host-wide firewall rule is added.

## Preparation and deployment

Follow `ai-mcp-production.md`: never run the aggregate flake check. Build the
focused `pace2`, `ai-mcp-proxy`, `tailnet-names`, `ai-gateway`,
`ai-gateway-staging`, `openclaw`, `openclaw-people`, `openclaw-in-place`,
`claw-tools`, `claw-ebay`, `claw-scryer`, `claw-websearch` checks sequentially,
and the Go formatting/test/vet/race checks. Evaluate Rakku and Yari. On Yari
build `openclaw-config` and `openclaw-in-place-config` natively.

Generate both keys on Zao (32 random bytes each) and pipe JSON directly to
`sops set --value-stdin`, using the converted master identity in memory. Pipe
`~/finance/simplefin.json`'s `accessUrl` likewise. Never print values.

Rebase onto latest origin/cairn before building. Pin all builds to the full
commit SHA. Rakku never builds: copy its derivation to Unzen, build there,
and relay the closure through Zao with `--no-check-sigs`. Yari builds natively.
Record both previous system paths and generation numbers before activation.

On Zao import `~/finance` into a fresh private temporary state directory; the
import is read-only on finance. Copy only the closed database into Rakku's
persistent `/var/lib/pace2/pace.sqlite` before its first start. A tmpfiles rule
sets its owner to pace2 before services start. Remove the Zao temporary copy.
Do not overwrite an existing Pace 2 database or copy an open WAL database.

Copy the local Nix-shebang deployment scripts to each host; use
`ssh -F /dev/null`. `pace2-rakku-switch.py` retains the production preflight,
protected-unit checks and nonce-bound ready/go handshake. The orchestrator
checks both gateways' unfinished-run metadata again immediately before `go`.
Both credentials arrive in ONE switch: production ai restarts exactly once.
Check Home Assistant HTTP 200 and the Z-Wave handshake afterwards. Never reboot
Rakku. Check no other switch is running on either target.

`pace2-yari-switch.py` retains Laure's guards, but calls
`pace2-config-guard.py`: the only permitted JSON changes are exactly the new
`pace` server entry (person-specific row URL and exact toolFilter) and the shared
skill directory. Every old shared skill and all personal skills must be
byte-identical. Both containers must switch in place; only the gateway unit may
change, and each gateway must restart once. Both must be idle before activation.
The guard also applies in reverse during rollback. It never reads conversations.

## Acceptance and rollback

First Rakku sync must finish; report outcome and warning codes only. From each
gateway initialize/list exactly `pace_status`, read the card resource, and
check the other person's row returns 403. Zao must get 403 on both. In a new
throwaway Simon session, make a real agent call and verify the tool reply's
text and `ui://pace/status` metadata without printing financial content; delete
only this test session. Never start a Laure conversation or impersonate her.
Inspect Pace's log for `person=laure` only.

On ANY failed acceptance check, switch BOTH hosts back to their recorded
previous system paths (Yari first, then Rakku), under `pace2-launch.sh` /
`systemd-run --wait --collect`. Do not use the historical 404 fix-forward
exception. Do not use `nixos-rebuild switch --rollback`: a failed attempt can
make “previous” point at the wrong generation. Keep data and encrypted secrets.
The Rakku rollback also uses the ready/idle/go gate. Record the exact pinned
commands and resulting health in the deploy report.

## Deployment record — 2026-11-14 UTC

Pace source: `886fe83d65b9a7e9e7a30c6d627e9becacf4cb07`, landed on its local
Zao `main`. Rust: 52 tests; SDK: 10 checks across Simon and Laure; fmt/clippy
passed. Both generated keys are distinct 64-character random hex values.
No plaintext key or SimpleFIN URL exists in tracked files or the branch diff.
The initial private import was copied before first service start; Zao's temporary
state was deleted. Database ownership/mode and loopback binding passed live.

The original one-restart target was **not met**. The first acceptance script
expected `outcome=complete`, but tracing writes `outcome="complete"`. Its parser
exception caused the prescribed rollback of both hosts. The supervisor authorized
one more forward credential restart, reusing exactly the tested Rakku build.
The parser now passes on the filtered real log and four permanent regression
tests in `checks.pace2`. No new bank sync was requested for this correction.

| Host | Generation sequence | Final system |
| --- | --- | --- |
| Rakku | 163 → 164 (Pace) → 165 (rollback) → 166 (same Pace build) | `/nix/store/zy7x2f3kq24fy7b29fd7d4712fm9dplb-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | 56 → 57 (Pace) → 58 (rollback) → 59 (another session's Family plans) → 60 (Pace rebased onto that change) | `/nix/store/d63gws8c0qpziylcmh2fhilghcq05lq8-nixos-system-yari-26.11.20260923.4975466` |

Production ai restarted **three times total**, each forward switch loading both
Pace credentials together. Stop-to-ready times from its journal were **21.6 s,
21.4 s, 21.4 s** (the middle one was rollback). Staging ai did not restart.
Every Rakku switch preserved Home Assistant, Z-Wave and the model backend;
final Home Assistant HTTP 200, Z-Wave driver 15.15.0/server 3.4.0, `/v1` healthy.
No host or container was rebooted.

Yari's rollback returned status 4 because the existing brief/wind-down/mail/eBay
reconcile oneshots called the gateway before it was ready. The same startup race
occurred on forward. All four retried successfully without a code/config fix or
manual restart; the gateways stayed at NRestarts=0. The final acceptance checks
all four active/success and no failed units on the hosts or inside the containers.

Another session deployed `fec704f3` while our idle gate held Yari. The gate refused
our stale source system. We rebased onto `origin/cairn` (`fec704f3`, including
`b63642d8`), preserving both changes, then rebuilt **only Yari**, natively.
Focused checks `pace2`, `openclaw`, `openclaw-people`, `openclaw-in-place`,
`ai-mcp-proxy` and both native ARM config checks passed. Earlier checks also
covered tailnet-names, ai-gateway/staging, claw-tools/eBay/Scryer/websearch,
and Go's 49 tests, vet, formatting and race checks. No aggregate flake check ran.

The live-generation-59 comparison proved exactly the two host container unit
changes, only each guest's gateway unit changes, and exactly the `pace` server
and shared skill in each JSON config. Both container conf files otherwise
matched. Reversing only our four Pace commits produced the exact `fec704f3`
source tree, whose Rakku output equals the recorded original Rakku system.
Our rebased Rakku output equals running 166. Rakku was **not** redeployed after
that rebase. Thus the other session's Rakku needs were not reverted.

Before the final Yari-only switch, both gateways stayed idle for 93 s, checked
at 30 s intervals and again by the switch guard immediately before activation.
Earlier busy receipts were main/dashboard runs, sub-agents and automatic
requester-settle resumptions, not cron sessions. Only audit metadata was read.
Both containers kept their identities; each gateway restarted once onto the
rebased config. The Laure config guard remained strict outside Pace.

All final acceptance checks **passed**:

- First Rakku sync: **complete**, warnings **none**. No financial figures reported.
- From flakey and snowy: initialize, exactly `pace_status`, successful status and
  `ui://pace/status` read; unlisted tools refused; forged caller auth ignored.
- Cross-person rows and Zao: HTTP **403**. Pace admission identifies **laure**.
- A real flakey agent call succeeded and returned text plus the card resource in
  the gateway's history projection. Only this disposable verification session
  was inspected, then deleted. No Laure conversation or login was used.
- Both deployed OpenClaw CLI probes: Pace has one tool, no diagnostics; all
  existing servers still present. Home Assistant/Z-Wave and failed-unit checks pass.

Evidence/scripts on Zao: `/tmp/pace2-*`; final acceptance log:
`/tmp/pace2-rebased-idle-switch-accept.log`. No financial contents are printed.

### Pinned rollback for this final deployment

Keep the other session's Family plans on Yari: rollback there to generation 59,
not our original generation 56. The local helper's saved previous paths now pin:

- Yari: `/nix/store/qd9w4q53a2ankyvb6cb0md79wwpy9kf2-nixos-system-yari-26.11.20260923.4975466`
- Rakku: `/nix/store/kisiwq6lw147f80kl7bb5k88j5bq4zn9-nixos-system-rakku-26.11.20260923.4975466`

On Zao, with both gateways idle:

```sh
/tmp/pace2-deploy.sh /tmp/pace2-deploy-source rollback
```

The helper switches Yari first, then uses the nonce/idle gate for Rakku, under
systemd-run on each. Removing the Pace credentials restarts production ai again.
It retains Pace's data and encrypted secrets. If `/tmp` is gone, copy the tracked
`pace2-*` deployment scripts to the hosts and use these exact pinned store paths,
never an ambiguous `nixos-rebuild switch --rollback`.

## Skill and Goal order follow-ups — 2026-11-14 UTC

Simon approved these as **two separate deploys**, Yari first and Rakku second.
For these follow-ups only, a real acceptance failure rolls back **only the
host just deployed**. A checker defect stops the procedure for classification;
it is not a reason to roll back either host. The earlier two-host rollback
instructions above belong to the initial credential/row rollout, not this update.

| Change | Landed source | Host | Generations |
| --- | --- | --- | --- |
| Short Pace replies, no repeated card, explicit read-only limits | mountainous `e673d821` | Yari | 63 → 64 |
| Stable due-month Goal order for Goal cash and Recent pace | pace-service `535a46537c2af4dd448627091c2841ef0d23df7f`, mountainous input `211bcea5` | Rakku | 167 → 168 |

Yari's running generation 63 equalled the parent commit's evaluated output.
The source diff was only `lib/openclaw-skills/shared/pace/SKILL.md`. The built
comparison allowed only the two host container units and their system paths,
only each guest's gateway unit, and only the shared Pace skill in the configs'
skill directories. The Pace server contracts, personal skills and every other
shared skill were byte-identical. Both gateways stayed idle for at least 90 s;
the guards checked metadata again immediately before activation. No conversation
content was read, and no Laure conversation was started.

Yari built natively, including both aarch64 config checks. Both containers kept
their identities; each gateway restarted once with NRestarts=0. Exact deployed
skill hashes and both health endpoints passed. Laure retained 9 sessions,
4 paired devices and 2 jobs. Activation returned 4 on a container reload, as in
the initial rollout; final health, target systems and failed-unit checks passed.
No manual restart or rollback was needed.

Rakku's baseline equalled the evaluated pre-bump source. Unzen built the new
system; Zao relayed it with `--no-check-sigs`. The input bump did not change
Yari's output. The strict preflight compared every unit file and the complete
system closures: only Pace's package, `pace2.service`, its wants link and the
necessarily derived system-units/etc/toplevel paths changed. The normalized
Pace unit differed only in its ExecStart package path. Production ai's unit
and credentials did not change. No build ran on Rakku.

The first preflight stopped before activation because a copied health helper
lacked execute permission. The supervisor approved fixing its mode and restarting
the complete preflight. The complete preflight and a fresh 90-second idle gate
then passed. Rakku's activation returned 0; 65 other running services kept their
InvocationIDs, including `tsnet-proxy-ai`, Home Assistant and Z-Wave. All secret
contents matched their before hashes. Activation also started four previously
non-running, already-declared assistant services; none of their units changed.
Home Assistant returned HTTP 200 on :8123; Z-Wave's WebSocket version handshake
passed (driver 15.15.0, server 3.4.0). No failed host units remained.

From flakey's real `/mcp/pace` row, `pace_status` and `resources/read` succeeded
with `ui://pace/status` and `text/html;profile=mcp-app`. Only verdicts and counts
were printed:

| Goal order | Verdict | Goals late | Budgets over |
| --- | --- | ---: | ---: |
| Before | Two savings goals are running late, and six budgets are heading over. | 2 | 6 |
| After | Savings goals are on track, but six budgets are heading over. | 0 | 6 |

Checks: 53 Rust tests (including the real-data golden references), 10 SDK
checks, 5 view tests, clippy with warnings denied and rustfmt passed. The new
invented-goal test failed under file order and passed with stable due-month
sorting. The partial-sync test still failed when its cutoff filter was removed;
the filter was restored before the final full suite. The worked fixture
calculation is in pace-service `crates/pace/tests/reference/README.md`.
All 30 reference-host renders passed overflow/tap-target/error audits; 18 PNGs
changed. Focused mountainous checks passed: pace2, ai-mcp-proxy, openclaw,
openclaw-people, openclaw-in-place, and both native aarch64 config checks.

### Follow-up rollback (host only)

| Host | Pinned previous system |
| --- | --- |
| Yari, generation 63 | `/nix/store/y5w03g979kb0xdc30p226c681z7lbhlh-nixos-system-yari-26.11.20260923.4975466` |
| Rakku, generation 167 | `/nix/store/qvj5n49az1dq7cjnac9j61fni4sxmdih-nixos-system-rakku-26.11.20260923.4975466` |

On Zao, the host-only helper waits for 90 s of metadata-proven idle on both
gateways, then invokes the strict reverse guard and a pinned switch under
systemd-run. Both reverse preflights passed; neither rollback was executed.
It refuses if another deploy changed the running source system. Keep all state
and secrets. Do not use a relative `nixos-rebuild --rollback`.

```sh
/tmp/pace-followup/rollback.sh yari
/tmp/pace-followup/rollback.sh rakku
```

Evidence and local Nix-shebang automation: `/tmp/pace-followup/` on Zao;
remote copies: `/tmp/pace-followup/` on Yari and Rakku. Final systems are Yari
`/nix/store/0vycq2lfzfvp9z99hkh2z8xf2qvrg2ns-nixos-system-yari-26.11.20260923.4975466`
and Rakku
`/nix/store/9709w007kxf4hixyhbhhl70rfv2cyxa6-nixos-system-rakku-26.11.20260923.4975466`.
