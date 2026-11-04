# Assistant Google and maps services

Prepared on `s28/apps`, based on `origin/cairn`. No deployment or Google
sign-in was run. The application profile must contain `google` and `maps`
from assistant/apps before the new units can start.

Only Simon's personal instance on Rakku has these apps. Laure and Household
do not receive Google credentials or these MCP servers.

| Service | Loopback port | Data | Read-only tools |
|---|---|---|---|
| todo-board | 3170 | `/var/lib/pi-assistant-simon/apps/todo-board` | list_todos, board_state |
| google | 3171 | `/var/lib/pi-assistant-simon/apps/google` | calendar_busy, mail_list, mail_read, mail_proposals |
| maps | 3172 | none | travel_time |

Google runs as `pi-simon`. Its HOME is its app folder and its file keyring
therefore persists with that folder. `GOG_BIN` points at the locked official
0.11.0 package. `TZ=America/Denver` follows `pi-assistant.homePlace`, also used
by the board's 03:00 boundary. Maps uses the existing tailnet Valhalla name,
`https://valhalla.hummingbird-lake.ts.net`, whose placement is Unzen.

The keyring password `pi-assistant-google-keyring-password` is set in
`secrets/hosts/rakku.yaml` (a random value made for this; rotate with `./scripts/secrets`). Nothing here
signs in to Google. The service reads `gog-keyring-password` from its systemd
credential directory. The value does not enter a Nix derivation or unit env.
The app passes it to the gog subprocess's environment, as gog 0.11.0 requires.
A separate authorized Google sign-in remains outside fixture development.
The sign-in commands verified against 0.11.0 are in assistant/apps/google/README.md.

The app asks Jev through the existing front door, using its dedicated assistant
key, and falls back to the configured mechanical model through the same grant.
The grant now allows `chat_completions` for that fallback. The monthly cap does
not apply to Jev: `providers.typesafe.prepaid=true` already excludes that route
from monthly cap reservations. `monthly_cap_usd` remains a mandatory gateway
schema field and guards future non-prepaid providers. Do not replace it with a
large pretend cap or remove it and break gateway parsing. A focused assertion
now protects the uncapped prepaid Jev behavior. Only Jev's provider balance
(the free allowance and top-ups) limits these decisions.

Focused checks:

```sh
nix eval .#nixosConfigurations.rakku.config.system.build.toplevel.drvPath
nix build .#checks.x86_64-linux.pi-assistant .#checks.x86_64-linux.pi-assistant-resources .#gogcli
```

Rakku is evaluation-only for host builds (`no-builds`); the package/check
builds run on the development machine. Do not deploy as part of this change.
Rollback uses the previous application profile and previous host generation.
