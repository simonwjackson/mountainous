# Assistant Google and maps services

Only Simon's personal instance on Rakku has these apps. Laure and Household
do not receive Google credentials or these MCP servers. The application profile
at `/nix/var/nix/profiles/per-user/pi-assistant/application` supplies the apps;
mountainous supplies their units and credentials.

| Service | Loopback port | State | Read-only tools |
|---|---|---|---|
| google | 3171 | `/var/lib/pi-assistant-simon/apps/google` | calendar_busy, mail_list, mail_read, mail_proposals |
| maps | 3172 | none | travel_time |

Google runs as `pi-simon`. HOME is its app folder. The file keyring and gog
configuration persist under `.config/gogcli` there. `GOG_BIN` pins official
0.11.0. `TZ=America/Denver` follows `pi-assistant.homePlace`. Maps uses the
existing Valhalla service, `https://valhalla.hummingbird-lake.ts.net`, on Unzen.
The retired todo-board's state remains as a backup; Atlas replaced that app.

## Desktop client and keyring

`secrets/hosts/rakku.yaml` contains `google-oauth-client-id` and
`google-oauth-client-secret`, encrypted for Rakku and Simon's master key. These
are the Desktop client created on 2026-11-10. Change them with `sops set` and
the converted master identity, as `scripts/secrets` does. Keep the existing
encrypted entries unchanged. Do not put plaintext client values in commands,
logs, source, the Nix store, or systemd environment settings.

sops-nix renders the Desktop `installed` JSON to
`/run/secrets/rendered/google-oauth-client`, owned by `pi-simon:pi-simon`, mode
0400. The Google unit loads it as `gog-oauth-client`. Before every start, the
unit runs `gog auth credentials set "$CREDENTIALS_DIRECTORY/gog-oauth-client"`.
The real 0.11.0 importer converts that Desktop JSON to gog's normalized
`/var/lib/pi-assistant-simon/apps/google/.config/gogcli/credentials.json`,
owned by `pi-simon:pi-simon`, mode 0600. This is the file gog actually reads.
Rotation restarts the Google app and refreshes that imported file.

The separate `pi-assistant-google-keyring-password` secret is loaded as
`gog-keyring-password`. The app and sign-in wizard pass it only to gog's process
environment. A client and a keyring password do **not** authorize an account.
No secret values enter a Nix derivation or unit text. Claw receives neither
client credentials nor tokens; its filtered MCP endpoint forwards only
`calendar_busy`.

## Sign in or sign in again

Run this one command from your computer:

```sh
ssh -F /dev/null -t simonwjackson@rakku sudo claw-google-auth
```

The flake installs this command on Rakku. Its Nix-shebang sources live in
`scripts/claw-google-auth/`; the installed wrapper uses pinned Python/Bash and
runtime dependencies, so Rakku does not build or fetch a wizard at sign-in.
The old `/var/tmp/claw-google-auth/start` is obsolete. Do not use it.

On the first run, enter the intended Google account's email once. The wizard
then asks whether you are ready **before** making the short-lived authorization
URL. Open that URL, select the same account, and approve Calendar read-only
consent. The browser cannot reach Rakku's loopback callback. Copy the complete
callback URL from the address bar into the wizard's hidden prompt. Do not put
it in chat, logs, or shell history.

There is no client ID, client secret, Cloud project, or API setup prompt.
The Google project must already have Calendar API enabled and allow this
account (including its test-user list if it is in Testing). If Google denies
consent, fix that project prerequisite. The wizard does not publish the app.
External apps in Testing can have seven-day refresh-token expiry.

After successful consent, the wizard writes only `GOG_ACCOUNT=<email>` to
`/var/lib/pi-assistant-simon/apps/google/.config/gogcli/.calendar-signin.env`
(mode 0600, `pi-simon:pi-simon`). The Google service reads that same optional
EnvironmentFile at every start. Later sign-ins reuse the email without asking.
To change accounts, run `sudo -u pi-simon nano` on that file on Rakku, change
only `GOG_ACCOUNT`, then run `sudo claw-google-auth`. Do not add a systemd
override or a second account selection in Nix.

The wizard requests `calendar.readonly` and gog's required identity scopes
(`email`, `openid`, `userinfo.email`). It requests no Gmail or Calendar write
scope. Existing Gmail polling remains unauthorized; it does not prevent
Calendar reads. Reauthorizing an existing account replaces its saved grant;
this command does not preserve a previous Gmail/write grant.

The launcher restarts only `assistant-app-simon-google`, waits for its listener,
and compares real busy blocks for today (America/Denver) from the loopback
Google app and `https://claw-calendar.hummingbird-lake.ts.net/mcp`. It then asks
Simon's normal assistant to call `mcp_google_calendar_busy`, checks its new
successful **tool result in the transcript**, and compares that result too.
A model answer alone does not count as verification. Output contains only busy
start/end times, never titles, locations, attendees or IDs. An empty day is
reported as empty, not populated with invented events.

If transport or assistant verification fails after consent, keep the saved
token. Repeat only the checks without another consent:

```sh
ssh -F /dev/null simonwjackson@rakku sudo claw-google-auth --verify
```

The assistant must be idle for its check. The verification prompt and real tool
result become part of Simon's existing private assistant conversation. A bounded
assistant result can be truncated on an unusually full calendar; verification
then fails rather than claiming a match. `sudo claw-google-auth --check` checks
placement, version, rendered/imported credentials, owner/mode and service state
without starting OAuth or requesting Google data.

## Classifier and checks

The app asks Jev through the existing front door and falls back to the configured
mechanical model through the same grant. The grant permits `chat_completions`.
`providers.typesafe.prepaid=true` excludes Jev from monthly cap reservations;
only its provider balance limits those decisions. `monthly_cap_usd` remains a
mandatory schema field and protects future non-prepaid routes.

Focused checks (never run `nix flake check`):

```sh
nix build .#checks.x86_64-linux.claw-google-auth --no-link --max-jobs 1 --cores 1
nix build .#checks.x86_64-linux.pi-assistant-resources .#checks.x86_64-linux.pi-assistant --no-link --max-jobs 1 --cores 1
nix eval --raw .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
```

The wizard check exercises real local JSON/SSE HTTP endpoints and assistant
transcript validation. It also imports fixture Desktop JSON with the pinned
gog binary, checks the actual 0600 config file, and checks the real dry-run
scope builder. It never starts OAuth or calls Google.

Build Rakku on Unzen, copy its closure as root (or signed), then switch Rakku.
Do not build or reboot Rakku. Check Home Assistant, Z-Wave, ai-gateway, all three
pi-assistant units and the Google app remain active. Roll back a failed switch
with `nixos-rebuild switch --rollback`; retain persisted OAuth and app state.
