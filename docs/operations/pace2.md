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
