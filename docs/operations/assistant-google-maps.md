# Assistant Google and maps services

Only Simon's personal instance on Rakku has these apps. Laure and Household
do not receive Google credentials or these MCP servers. The application profile
at `/nix/var/nix/profiles/per-user/pi-assistant/application` supplies the apps;
mountainous supplies their units and credentials.

| Service | Loopback port | State | Read-only tools |
|---|---|---|---|
| google | 3171 | `/var/lib/pi-assistant-simon/apps/google` | calendar_busy, family_calendar_events, mail_list, mail_read, mail_proposals |
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
URL. Open that URL, select the same account, and approve Calendar read-only and
Gmail modify consent. The browser cannot reach Rakku's loopback callback. Copy the complete
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

The wizard requests exactly these scopes:

- `openid`
- `email`
- `https://www.googleapis.com/auth/userinfo.email`
- `https://www.googleapis.com/auth/calendar.readonly`
- `https://www.googleapis.com/auth/gmail.modify`

Gmail modify supports read, label, archive and drafts. It also permits sending;
this is not a read-only Gmail grant. No send-only or settings scopes are requested.
The wizard does not use `gog auth add`: gogcli 0.11.0 adds `gmail.settings.basic`
and `gmail.settings.sharing` to Gmail write consent, including forwarding settings.
Instead, the helper uses Desktop OAuth with PKCE, offline access, fresh consent,
and `include_granted_scopes=false`. It checks the callback state, requires the
returned scope set to match exactly, and verifies the account with Google's
userinfo endpoint before importing the refresh token into gog's keyring.
A different or missing scope, or a different account, fails without import.
Temporary state and token-import files are private (0600). The helper consumes
state on exchange and deletes the token-import file even if import fails.
An interrupted sign-in can leave private state; a new sign-in replaces it,
and the helper refuses state older than ten minutes.

Google's [native-app OAuth documentation](https://developers.google.com/identity/protocols/oauth2/native-app)
defines the token response's `scope` as space-delimited, case-sensitive strings.
The helper does not treat aliases as equivalent; a changed response fails closed.
Reauthorizing replaces the account's saved grant, not a union with its old scopes.
It does not revoke other tokens or grants at Google.

Gmail modify is a restricted scope, so Google shows an unverified-app screen;
choose Advanced, then continue. The Gmail API must be enabled in the client
project. The 15-minute Gmail poll is off (`GOOGLE_POLL_DISABLED = "1"` in
`modules/hosts/rakku.nix`) until OpenClaw's mail endpoint exists (assistant core
ADR 0021); `mail_list` and `mail_read` still work.

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
gog binary, checks the actual 0600 config file, and exercises exact OAuth scopes,
PKCE, state, local token/userinfo responses and private token import with a recording
gog command. It never calls Google or starts a real consent flow.

Build Rakku on Unzen, copy its closure as root (or signed), then switch Rakku.
Do not build or reboot Rakku. Check Home Assistant, Z-Wave, ai-gateway, all three
pi-assistant units and the Google app remain active. Roll back a failed switch
with `nixos-rebuild switch --rollback`; retain persisted OAuth and app state.

## Deployment evidence (2026-11-11 UTC)

- Implementation commits: `8fb95b65`, `943960f2`, `90598ac7` on `cairn`.
  Rakku generation **131** runs
  `/nix/store/3k9qmp0li936dzw5lipk66m6rwbyas5r-nixos-system-rakku-26.11.20260923.4975466`.
  Unzen built it. Zao relayed the closure through Rakku's root Nix daemon;
  Rakku did not build or reboot.
- All three focused checks passed. The wizard check passed **9 tests**,
  including real gog Desktop import/scope selection, local JSON/SSE transport,
  assistant RPC framing, and rejection of old/error assistant tool results.
  Nix formatting, Python formatting/static checks, Bash syntax and shellcheck
  passed. The existing Home Assistant lovelace deprecation warning remains.
- Rendered client: `pi-simon:pi-simon`, **0400**. Imported gog client:
  `pi-simon:pi-simon`, **0600**. The installed `claw-google-auth --check` passed
  and confirmed their values match without printing them. Unit text and the
  store-side template contain no plaintext client values. Existing encrypted
  secret entries stayed byte-identical; only two keys and SOPS metadata changed.
- Home Assistant, Z-Wave, ai-gateway, all three assistants, Google and maps are
  active. Only Google restarted, when the credentials were first deployed;
  every other service retained its pre-change start time. Home Assistant HTTP
  returned **200**. Z-Wave's real websocket returned its version greeting
  (driver **15.15.0**).
- Real assistant GetConversation/GetTranscript RPCs passed. Both loopback Google
  and the restricted HTTPS endpoint returned the expected **not_authorised**
  before consent. This proves transport, **not** access to Calendar data.
  Successful real-data comparisons remain deliberately pending Simon's consent.
- The installed interactive PTY path was exercised as `pi-simon` with both
  `TERM=dumb` and `TERM=xterm-256color`. Both runs declined the readiness gate:
  **no OAuth URL was made, no callback was exchanged, no account was saved**.
  Simon still needs only the one-time email selection and browser consent above.
- After the secrets were committed and deployed, `/tmp/client-id` and
  `/tmp/client-secret` on Zao were removed with `shred --remove`; their absence
  was checked again. No plaintext client values were found in committed source.
  Local deployment/check evidence is in `/tmp/google-client-evidence/` on Zao;
  that evidence directory is not required for future sign-in.
