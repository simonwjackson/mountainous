# Unified Notification System — Setup Runbook

## Overview

Matrix-based notification system with bidirectional dismiss sync.
Service alerts (Sonarr, Radarr, systemd failures) post to a `#notifications:yari`
Matrix room. Desktop popups appear on yuki via mako. Phone notifications via
SchildiChat. Dismissing on any device dismisses on all others.

### Architecture

```
Services (yari)                 Desktop (yuki)                Phone
─────────────────              ─────────────────             ──────────────
Sonarr/Radarr ──┐              matrix-notify-daemon          SchildiChat
systemd failures─┤              │  ↕ D-Bus (mako)            │
                 ▼              │  ↕ read receipts            │  ↕ push notif
  matrix-webhook-relay          │                             │  ↕ read receipts
         │                      │                             │
         ▼                      ▼                             ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Matrix (Synapse) — #notifications:yari                         │
  │  @notify-bot:yari posts    @simonwjackson:yari reads            │
  └─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- yari deployed from its local repository checkout with `sudo nixos-rebuild switch --flake .#yari` (Matrix server, webhook relay, notification room)
- yuki deployed from its local repository checkout with `sudo nixos-rebuild switch --flake .#yuki` (desktop notification daemon)
- Phone on the Tailscale network

## Step 1: Generate the user access token

The desktop daemon on yuki authenticates as `@simonwjackson:yari`.
After deploying yari, obtain a real access token:

```bash
# SSH into yari
ssh -F /dev/null yari

# Login to get an access token
curl -s -X POST http://localhost:8008/_matrix/client/v3/login \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "m.login.password",
    "identifier": {"type": "m.id.user", "user": "simonwjackson"},
    "password": "'$(cat /run/agenix/matrix-admin-pass)'",
    "device_id": "YUKI_NOTIFY_DAEMON"
  }' | jq -r '.access_token'
```

Copy the token, then on the machine with the repo:

```bash
# Use the repository's Nix app without placing the token in shell history.
read -rsp 'Matrix access token: ' MATRIX_TOKEN; echo
printf '%s' "$MATRIX_TOKEN" | nix run .#secrets -- encrypt \
  user/simonwjackson/matrix-access-token --from-stdin --force
unset MATRIX_TOKEN

# On yuki, from its repository checkout:
sudo nixos-rebuild switch --flake .#yuki
```

## Step 2: Verify server-side services (yari)

```bash
ssh -F /dev/null yari

# Check the notification room was created
systemctl status matrix-synapse-ensure-notifications

# Check the webhook relay is running
systemctl status matrix-webhook-relay
curl -s http://localhost:9100/health
# → {"status": "ok"}

# Send a test notification
curl -s -X POST http://localhost:9100/hook \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test","body":"Hello from yari!","url":"https://example.com"}'
# → {"event_id": "$..."}

# Check Sonarr/Radarr notification connections were seeded
systemctl status sonarr-seed-notifications
systemctl status radarr-seed-notifications
```

## Step 3: Verify desktop daemon (yuki)

```bash
# Check the user service is running
systemctl --user status matrix-notify-daemon

# View logs
journalctl --user -u matrix-notify-daemon -f
```

The test notification from step 2 should have produced a mako popup on yuki.
If the daemon isn't running yet, start it:

```bash
systemctl --user start matrix-notify-daemon
```

## Step 4: Set up SchildiChat on phone

1. **Install SchildiChat** from F-Droid or Google Play
2. **Sign in:**
   - Homeserver: `https://matrix.hummingbird-lake.ts.net`
   - Username: `simonwjackson`
   - Password: *(your Matrix admin password)*
3. **Join the notifications room:**
   - Tap ＋ → Join room → `#notifications:yari`
4. **Configure notification settings per room:**

| Room | Notification Setting | Why |
|------|---------------------|-----|
| `#notifications` | **All messages** | Service alerts — you want to see these |
| Signal bridge rooms | **Default** (or Mentions only) | Real conversations — normal priority |
| WhatsApp bridge rooms | **Default** (or Mentions only) | Real conversations — normal priority |

This keeps service alerts and real conversations in separate rooms with
independent notification levels. Your real messages won't get lost in
service alert noise.

## Step 5: Test dismiss sync

1. **Send a test notification** (on yari):
   ```bash
   curl -s -X POST http://localhost:9100/hook \
     -H 'Content-Type: application/json' \
     -d '{"title":"Dismiss Test","body":"Dismiss me on either device"}'
   ```

2. **Desktop → Phone:** Dismiss the mako popup on yuki → open SchildiChat →
   the message should show as read (no unread badge)

3. **Phone → Desktop:** Send another test notification → read it in
   SchildiChat → the mako popup on yuki should auto-dismiss

## Important: Desktop Matrix clients

If you install a Matrix desktop client (Element, SchildiChat Desktop, nheko)
on yuki:

> **Disable its desktop notifications in the client's settings.**
>
> The `matrix-notify-daemon` systemd user service is the single owner of
> the desktop notification path (mako popups). Running a Matrix client with
> desktop notifications enabled will cause **duplicate popups** for every
> message.

The desktop client is fine for reading/replying — just turn off its
notification popups.

## Troubleshooting

### Daemon can't connect to homeserver

```
matrix-notify-daemon: Access token verification failed
```

- Verify Tailscale is connected: `tailscale status`
- Verify the homeserver is reachable: `curl -s https://matrix.hummingbird-lake.ts.net/_matrix/client/versions`
- Verify the access token is valid (not the placeholder):
  `cat /run/agenix/matrix-access-token` — should start with `syt_`, not `PLACEHOLDER`

### No mako popups

- Check the daemon is running: `systemctl --user status matrix-notify-daemon`
- Check mako is running: `systemctl --user status mako`
- Check logs: `journalctl --user -u matrix-notify-daemon -f`
- Verify the daemon joined the room (look for "Joined" in logs)

### Webhook relay returns 502

```bash
# Check bot token exists
ls -la /var/lib/matrix-notifications/bot-token

# Check Synapse is running
systemctl status matrix-synapse

# Check the room exists
curl -s http://localhost:8008/_matrix/client/v3/directory/room/%23notifications%3Ayari
```

### Dismiss sync not working

- Ensure both devices are logged in as `@simonwjackson:yari`
- The desktop daemon uses a device called `YUKI_NOTIFY_DAEMON` (from the login step) —
  each device should have a unique device ID
- Check for read receipt errors in daemon logs:
  `journalctl --user -u matrix-notify-daemon | grep -i receipt`

## Service map

| Service | Host | Type | Purpose |
|---------|------|------|---------|
| `matrix-synapse` | yari | system | Matrix homeserver |
| `matrix-synapse-ensure-notifications` | yari | oneshot | Creates room + bot on boot |
| `matrix-webhook-relay` | yari | long-running | HTTP → Matrix relay (port 9100) |
| `sonarr-seed-notifications` | yari | oneshot | Configures Sonarr webhook |
| `radarr-seed-notifications` | yari | oneshot | Configures Radarr webhook |
| `notify-matrix-failure@` | yari | template | Posts on systemd service failure |
| `matrix-notify-daemon` | yuki | user service | Matrix → mako with dismiss sync |
