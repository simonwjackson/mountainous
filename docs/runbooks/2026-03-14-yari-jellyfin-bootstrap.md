# Yari Jellyfin bootstrap runbook

Date: 2026-03-14
Host: `yari`
Status: **implemented**

## Decision

Jellyfin on `yari` is now provisioned in two layers:

1. **Service layer** is declarative in Nix:
   - Jellyfin service
   - media-path access
   - Tailscale exposure via `tsnet-proxy`
2. **First-run application state** is also declaratively seeded in Nix through an idempotent systemd one-shot bootstrap service.

This replaces the earlier manual/UI-first bootstrap approach.

## Declarative bootstrap state

`mountainous.jellyfin` on `yari` now declares:

- admin username: `simonwjackson`
- admin password secret: `config.age.secrets.jellyfin-pass.path`
- server name: `yari`
- remote access: disabled
- TV library:
  - name: `TV`
  - path: `/srv/storage/media/tv`
- Movies library:
  - name: `Movies`
  - path: `/srv/storage/media/movies`

## How bootstrap works

The module now installs a one-shot service:

- `jellyfin-seed-bootstrap.service`

It runs after `jellyfin.service` and uses Jellyfin's API to converge first-run state.

At runtime it:

1. waits for Jellyfin to answer on `127.0.0.1:8096`
2. reads the admin password from the dedicated Jellyfin secret via systemd credentials
3. applies startup-wizard configuration through Jellyfin APIs
4. authenticates as the configured admin user
5. ensures the `TV` and `Movies` libraries exist with the desired paths
6. completes the startup wizard if needed
7. validates that the TV library hierarchy is actually queryable
8. if the TV graph is incomplete on a fresh install, queues a targeted refresh for the TV library and waits for the hierarchy to become queryable

## Idempotency and non-destructive behavior

The bootstrap is intentionally non-destructive.

If Jellyfin already has the desired state, the seed service exits cleanly without rewriting unrelated runtime state.

The no-op path requires:

- startup wizard already completed
- configured admin credentials already authenticate
- server name already matches
- remote-access setting already matches
- `TV` library already exists with the desired type/path
- `Movies` library already exists with the desired type/path
- TV hierarchy queries are already healthy (`Shows/{id}/Seasons`, `Shows/{id}/Episodes`, `Shows/NextUp`)

The bootstrap does **not** wipe users, remove libraries, or rebuild unrelated state.

## Secrets

Jellyfin now uses its own dedicated secret instead of reusing the NZBGet/Prowlarr password:

- repo secret: `secrets/system/jellyfin/jellyfin-pass.age`
- host wiring: `age.secrets.jellyfin-pass`

## Operational flow

For a fresh `yari` deployment:

1. deploy the host configuration
2. `jellyfin.service` starts
3. `jellyfin-seed-bootstrap.service` converges first-run Jellyfin state
4. `tsnet-proxy-jellyfin.service` exposes Jellyfin at `watch.*`

No manual browser wizard should be required for the intended default setup.

## Current intended state on `yari`

After deployment, the expected Jellyfin state is:

- `jellyfin.service` active
- `tsnet-proxy-jellyfin.service` active
- startup wizard completed
- admin login works for `simonwjackson`
- server name is `yari`
- remote access disabled
- libraries present:
  - `TV` → `/srv/storage/media/tv`
  - `Movies` → `/srv/storage/media/movies`

## Scope boundary for this pass

This pass includes declarative first-run bootstrap for the initial admin and libraries, but still does **not** include:

- general multi-user lifecycle management in Nix
- VPN namespace routing for Jellyfin
- hardware transcoding setup
- public internet exposure

## Sources consulted

- Jellyfin docs: `general/quick-start.md`
- Jellyfin server source: `Jellyfin.Api/Controllers/StartupController.cs`
- Jellyfin server source: `Jellyfin.Api/Controllers/LibraryStructureController.cs`
- Jellyfin server source: `Jellyfin.Api/Controllers/TvShowsController.cs`
- Jellyfin server source: `MediaBrowser.Model/Configuration/BaseApplicationConfiguration.cs`
