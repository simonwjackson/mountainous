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
2. Open Mindwtr → **Settings → Sync → Self-hosted**.
3. Enter **Self-hosted URL**: `https://tasks.hummingbird-lake.ts.net`.
   Do not append `/v1/data`, `/mcp` or a port. Leave insecure HTTP disabled.
4. Read the Cloud token privately on Rakku. Run this yourself on your terminal:
   `ssh -F /dev/null simonwjackson@rakku sudo cat /run/secrets/mindwtr-cloud-token`.
   Paste it into the app's **Access token** field. Do not paste it into agent chat. The
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

## Deployment and acceptance: 2026-11-16 UTC

Flake `main`: `a5449cb40dd1d95df87d8161f71f3fa3958c0759`, followed by lint-only
`c7b513cd49dd05b378353921674e41d261435eaf` (the consumed pin).
Mountainous deployment source: `dd6129549851d5ccfbf0db11cf6ded7568a8d094`.
Fetched/rebased cairn immediately before both activations. Both helpers refused
concurrent switches and checked the running source system before activating.
Rakku's system was built on Unzen; Yari's ARM system was built on Yari, one
job / two cores. All Mindwtr components were built from source.

| Host | Before | Deployed system |
| --- | --- | --- |
| Rakku | generation 174 | generation **175**, `/nix/store/z647abb03j56a0x9fd93knrwf0703dlc-nixos-system-rakku-26.11.20260923.4975466` |
| Yari | generation 77 | generation **78**, `/nix/store/qv50r1l0if6n16dia2id06d53vws7l9p-nixos-system-yari-26.11.20260923.4975466` |

Yari switched Flakey in place. Its container and tailnet invocation IDs stayed
unchanged. Flakey's gateway was unhealthy for 13.2 seconds during the planned
restart. Snowy's health stayed good throughout. Her host unit, container
configuration, container system, gateway configuration and invocation IDs stayed
unchanged. The rollback preconditions were checked afterwards without activating
a rollback. The local guarded rollback launcher is
`nix-shell /tmp/claw/mindwtr-rollback.sh` (Yari first, then Rakku).

Previous systems, retained in their profiles:

- Rakku 174: `/nix/store/va0ml3vs6wpi4k8rx3q0hylzf1a47hy0-nixos-system-rakku-26.11.20260923.4975466`.
- Yari 77: `/nix/store/p41mjpwn1byqjq2j8c1wc42mq9cdkc2c-nixos-system-yari-26.11.20260923.4975466`.

### Verified

- The three packages build. The static web build ran its TypeScript checker.
  The flake's module evaluation and real cloud/MCP create → available → delete
  smoke check passed. Nix formatting, Statix, Deadnix and Ruff for the smoke
  script passed. No full mountainous flake check was run.
- Focused mountainous checks `mindwtr`, `claw-tools`, `openclaw-people` and
  `openclaw` passed. The last check first exposed its old fixed 79-permission
  expectation; the assertion now includes Mindwtr's 15 permissions from the row
  source of truth (94 total). This assertion-only follow-up changes no runtime
  configuration. Rakku and Yari toplevels evaluated and their systems built.
- From Zao, the web URL returned HTTP 200 and Chromium rendered Mindwtr's
  onboarding and navigation. `/ready` and authenticated `/v1/data` returned
  HTTP 200. Without a token `/v1/data` returned HTTP 401. The new hostname briefly failed TLS while its first certificate
  was provisioned; subsequent curl and browser requests succeeded.
- Created one task `TEST – delete me` through the Cloud REST API, then read it
  back. REST creation expects status inside `props`; the initial request's
  top-level status was ignored and the capture landed in inbox. Patched that
  same task to `next`, without creating another task.
- As Flakey's UID, the real row initialized and exposed exactly the 15 tools.
  `view: "available"` returned the TEST task. An unlisted people tool was
  refused (-32601); a forged caller Authorization header was ignored. Zao and
  Snowy each received HTTP 403 on the row. OpenClaw's live server had no key.
- In a **new Control UI conversation** at Flakey's URL, asked for available
  tasks. Flakey called `mindwtr__mindwtr_list_tasks` with the actual argument
  `view: "available"` and displayed `TEST – delete me`, status `next`.
  The audit contained only discovery/skill reads, dispatch and that read tool.
- Deleted the TEST task through the API. It was absent from the default REST
  task list and the MCP available view. This is upstream soft deletion: its
  sync tombstone remains, as required for client convergence.
- Deleted that exact test conversation, ran offline `openclaw memory forget`
  for its exact session ID and checked all 14 artifact counters were zero.
  The idle gate delayed cleanup for real agent runs. A run started between
  conversation deletion and the second idle check, so forgetting resumed later
  from the saved, exact deleted-session metadata. No running agent was stopped.
  Removed only the temporary Zao pairing; pre-existing pairings stayed present.
- Final host and gateway checks passed, with no failed units on Rakku, Yari or
  either gateway. Rakku Home Assistant returned HTTP 200 and Z-Wave's WebSocket
  returned HTTP 101. Atlas, SparkyFitness, Logbook and the paused Pi assistant
  units retained their state and invocation IDs. No wind-down or coach file
  or workflow configuration changed.

### Limits

Simon's Android setup/sync and a restore from an off-host Mindwtr backup were
not performed. Project/area writes and deferred/blocked view behavior were not
manually exercised. No Z-Wave device was operated. Only x86_64-linux Mindwtr packages
are supported by this flake. Deletion confirmation remains an agent instruction,
not server-enforced approval. Rotating the Cloud token can select a different
upstream token namespace; preserve/migrate the library before rotating it.
