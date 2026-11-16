# Mindwtr on Rakku

## Placement

Mindwtr v1.3.8 (`cdd2161995beaca286e7e2a4686ba28e3574f8e6`) is built
from source by `~/code/sandbox/mindwtr-nix`, consumed over Zao SSH like
Ossicle and YouTube. Cloud, web and MCP use native systemd/nginx services.
No OCI image or container runtime is involved.

| Component | Endpoint / state |
| --- | --- |
| Web and Android Cloud URL | `https://tasks.hummingbird-lake.ts.net` |
| Web/nginx | `127.0.0.1:4592` |
| Cloud REST and sync | `127.0.0.1:8787`, `/v1/` proxied through the web origin |
| MCP HTTP | `127.0.0.1:8723/mcp`, write-enabled |
| Flakey MCP server | `mindwtr`, `https://ai.hummingbird-lake.ts.net/mcp/mindwtr` |
| State | `/var/lib/mindwtr`, UID/GID 951, mode 0700 |
| Persistence | `/tundra/permafrost/var/lib/mindwtr` bind-mounted to state |
| Cloud credential | sops `mindwtr-cloud-token`, `/run/secrets/mindwtr-cloud-token` |
| MCP credential | separate sops `mindwtr-mcp-token`, `/run/secrets/mindwtr-mcp-token` |

The MCP row admits only Flakey's stable node ID. The AI proxy holds the incoming
MCP credential. The helper holds the Cloud credential. Neither token enters
OpenClaw configuration. Snowy has no server, tools or tasks skill. The Simon-only
`tasks` skill captures his words into inbox, uses the **available** GTD view for
next actions, tells him before creating projects and confirms deletes. Wind-down
and coach are unchanged.

The cloud and MCP services have read-only system/home, private tmp/devices,
no capabilities, no new privileges and bounded memory (384M high / 768M max).
Only cloud can write the state directory. Its unit requires the persistence
mount. The web/API are tailnet-only; no public listener or firewall opening is
added. A Cloud token grants the entire library. MCP delete confirmation is an
agent instruction, not server-side approval enforcement.

## Tools

The row exposes exactly the 15 names in `lib/openclaw-mindwtr-tools.nix`:

- Tasks: `mindwtr_list_tasks`, `mindwtr_get_task`, `mindwtr_add_task`,
  `mindwtr_update_task`, `mindwtr_complete_task`, **`mindwtr_delete_task` (deletes)**.
- Projects: `mindwtr_list_projects`, `mindwtr_get_project`, `mindwtr_add_project`,
  `mindwtr_update_project`, **`mindwtr_delete_project` (deletes)**.
- Areas: `mindwtr_list_areas`, `mindwtr_add_area`, `mindwtr_update_area`,
  **`mindwtr_delete_area` (deletes)**.

Inbox uses `mindwtr_add_task` / `mindwtr_list_tasks` with `status: "inbox"`;
there is no separate inbox tool. `mindwtr_list_tasks` supports `view: "available"`,
`"deferred"` and `"blocked"` (sequential projects). Sections and people tools are
not forwarded. The helper advertises some tools unsupported by Cloud mode,
such as task restore and people writes; those are not forwarded either.

## Android setup (Simon)

1. Install **Mindwtr** from Google Play or F-Droid. Keep Tailscale connected to
   `hummingbird-lake.ts.net` on the phone.
2. Open Mindwtr → **Settings → Sync → Self-Hosted**.
3. Enter **Self-Hosted URL**: `https://tasks.hummingbird-lake.ts.net`.
   Do not append `/v1/data`, `/mcp` or a port. Leave insecure HTTP disabled.
4. Read the Cloud token privately on Rakku. Run this yourself on your terminal:
   `ssh -F /dev/null simonwjackson@rakku sudo cat /run/secrets/mindwtr-cloud-token`.
   Paste it into the app's token field. Do not paste it into agent chat. The
   MCP token is different and must not be used here.
5. Save the sync settings, then use **Sync now**. Capture a task and check that
   the same task appears in the web app. Enter the same Cloud URL and token
   in the web app's Self-Hosted sync setup.

The phone sync itself must be checked on Simon's device. Tailnet reachability
and authenticated API checks do not prove mobile setup.

## Backup and rollback

State follows Rakku's existing persistence-volume convention. Back up the
whole `/tundra/permafrost/var/lib/mindwtr` directory, including attachments and
token-namespace directories. The server uses atomic snapshot writes, but stop
only `mindwtr-cloud` for a consistent file-level backup, or use the existing
Btrfs persistence-volume snapshot procedure. Do not stop Home Assistant or
Z-Wave for a Mindwtr backup. Persistence alone is not an off-host backup.

For rollback, first idle-gate Yari with `openclaw-wait-idle --check openclaw
claw-simon` and use the reviewed in-place switch helper to the previous system.
Do not restart either container or Snowy. Then switch Rakku to its previous
system with `nix-env --profile /nix/var/nix/profiles/system --set PREVIOUS` and
`PREVIOUS/bin/switch-to-configuration switch`. Check no other switch is running
immediately before either activation. Keep the data directory and sops tokens;
rollback removes service wiring, not captured tasks. Do not downgrade the Cloud
schema once real data exists without reviewing upstream compatibility.

Deploy and acceptance records follow below after activation.
