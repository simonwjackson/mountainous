# The household assistant on Rakku

`modules/pi-assistant.nix` runs Simon's and Laure's Pi assistants and their
shared Household assistant on Rakku, behind `https://assistant.hummingbird-lake.ts.net`.
This note says how to deploy the application, how the move from Zao works,
and how to roll it back.

## What runs

| Unit | User | State | Loopback ports |
| --- | --- | --- | --- |
| `pi-assistant-simon` | `pi-simon` | `/var/lib/pi-assistant-simon` (0700) | 4317 voice, 4318 web |
| `pi-assistant-laure` | `pi-laure` | `/var/lib/pi-assistant-laure` (0700) | 4327, 4328 |
| `pi-assistant-household` | `pi-household` | `/var/lib/pi-assistant-household` (0700) | 4337, 4338 |
| `assistant-tsgo` | `assistant-tsgo` | `/var/lib/assistant-tsgo` (0700, the tailnet identity) | tailnet 443 |

Every instance is in the `household` group, which owns
`/var/lib/pi-household-notebook` (2770). That directory is the only place two
instances share. `checks.pi-assistant` fails the flake if an instance shares a
user, loses its 0700 state, leaves the persistent volume, or sets
`ASSISTANT_HOST`.

The tailnet node routes by person: the web app's `assistant_person` cookie
for `/rpc`, `/auth`, and `/household/*`, and `?person=` for the watch's
`/api/voice`. A request that names no person of the household gets 400.
The cookie is a choice, not authentication.

Each unit's `ExecStartPre` writes the instance's `seed/` files and
`agent/web-search.json`, and points `agent/cliproxyapi.json` at the local
CLIProxyAPI on 8317 with the `pi-assistant-cliproxyapi-key` secret. The search
keys stay in the unit's credentials; `web-search.json` names them with `!cat`.

## Deploy the application

The units run `/nix/var/nix/profiles/per-user/pi-assistant/application`, and
do not start until it exists. Build it on Zao from the committed tips:

```sh
scripts/pi-assistant-deploy build                     # main of core, web, tsgo
scripts/pi-assistant-deploy install --restart         # copy, set the profile, restart
```

`--core`, `--web`, and `--tsgo` pick other branches.

## Move from Zao

Zao ran one assistant as `simonwjackson` (`~/.local/share/pi-assistant`,
`pi-assistant-foundation.service`) and the tailnet node as a user unit
(`~/.config/assistant-tsgo`). Only one host may own each at a time.

1. Switch Rakku to a generation with the `pi-assistant` layer
   (`scripts/rakku-switch-target`). The units stay stopped: no profile yet.
2. Install the application without starting it: `pi-assistant-deploy install`.
3. On Zao, back up and stop both user units:
   `systemctl --user stop assistant-tsgo pi-assistant-foundation`.
4. Copy Zao's home to `/var/lib/pi-assistant-simon` and the tailnet state to
   `/var/lib/assistant-tsgo`, then `chown -R` to `pi-simon` and
   `assistant-tsgo`. Keep Zao's copies.
5. Start the units on Rakku and check: the app loads for both people,
   `pi-laure` cannot read `/var/lib/pi-assistant-simon`, and the watch
   connects at `/api/voice?person=simon`.

Roll back by stopping the four units on Rakku and starting the two user units
on Zao. Zao's home was not changed, so it resumes where it stopped; anything
said on Rakku in between stays on Rakku.
