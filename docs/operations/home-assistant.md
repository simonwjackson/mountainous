# Home Assistant on Rakku

Home Assistant runs on Rakku as the official container image. Z-Wave JS runs
natively next to it. `modules/home-automation.nix` holds the setup.

## What needs a rebuild and what does not

| Change | How |
|---|---|
| Automations, scripts, scenes, dashboards, helpers, areas | UI, REST/WebSocket API or MCP. No rebuild. |
| Add or remove an integration, a custom component, HACS | UI or API. The image has every integration; custom ones install at runtime. No rebuild. |
| `configuration.yaml` and the other YAML files | Edit `/var/lib/hass/*.yaml` on Rakku, then reload or restart HA. No rebuild. |
| Home Assistant version | Change `image` (tag and index digest) in `modules/home-automation.nix`, then deploy. |
| Z-Wave JS server version | Move the `zwave-js-server-src` input and `npmDepsHash`, then deploy. |
| Serial devices, ports, persistence | `modules/home-automation.nix`, then deploy. |

## Connect an agent

1. Make a long-lived access token for that agent: Profile → Security →
   Long-lived access tokens, one token per agent, named after it. Revoke it
   there.
2. Base URL: `https://habitat.hummingbird-lake.ts.net` (tailnet), or
   `http://rakku:8123` on the LAN.
3. Pick the interface:
   - REST: `/api/states`, `/api/services/<domain>/<service>`,
     `/api/config/config_entries/entry`, `/api/template`. Full admin access
     for an admin user's token.
   - WebSocket: `/api/websocket`, for registries, dashboards, config flows.
   - MCP: `/api/mcp` (streamable HTTP, `Authorization: Bearer <token>`). It
     exposes the Assist API: only entities exposed to Assist, and only Assist
     actions. Use REST or WebSocket for configuration.

## History and recovery

- `hass-config-commit.timer` commits `/var/lib/hass` every 15 minutes to a
  local git repository on Rakku. `.gitignore` there is written by Nix and
  leaves out databases, logs, caches and the auth store. The repository holds
  integration credentials: never push it anywhere.
  See changes: `sudo git -C /var/lib/hass log --stat`.
- Revert a bad change: `sudo git -C /var/lib/hass checkout <commit> -- <path>`,
  then `sudo systemctl restart home-assistant`.
- Full snapshots before risky work go to `/tundra/permafrost/backups/`.
  `hass-pre-container-20261121T205303Z.tar.zst` is the state before the move
  to the container (HA 2025.12.3).

## Zigbee

The coordinator is the HubZ (HUSBZB-1) stick, `...-if01-port0`. Its old
firmware changes the PAN ID every few days. When ZHA then refuses to start
with "Network settings do not match most recent backup", check that only the
PAN ID and NWK update ID differ, and run the ZHA repair with
`use_new_settings`. Never `restore_old_settings`: devices have already moved
to the new PAN ID. The lasting fix is a modern coordinator, migrated from the
ZHA backup.
