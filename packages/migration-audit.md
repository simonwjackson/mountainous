# Package migration audit

Status: root-level layout migration is complete.

## Canonical source trees

The repository now treats these top-level directories as canonical:

- `packages/`
- `modules/`
- `features/`
- `profiles/`
- `home/`
- `lib/`

The legacy `nix/` layout is no longer the source of truth.

## Current package exposure

`flake.nix` now discovers flake packages from `./packages` and exposes them under `packages.<system>.*`.

Validated with `nix flake show --json --all-systems .`, which currently exposes:

- `devShells`
- `nixosConfigurations`
- `overlays`
- `packages`

Notable package outputs include:

- `deploy`
- `nixie`
- `scaffold`
- `secrets`
- `syncthing-keygen`
- `tsnet-proxy`
- `vpn-ns`

## Current consumers

### Overlay definitions

`overlays/default.nix` now points at root-level package sources:

- `../packages/vpn-ns`
- `../packages/gogcli`
- `../packages/scripts`
- `../packages/airconnect`
- `../packages/steam-cage`
- `../packages/steam-prefs`

### Direct `callPackage` users

`features/hyprland/keybinds.nix` now imports from `../../packages/...`.

### Host-local source builds

`hosts/rakku/default.nix` now builds `tsnet-proxy` from `../../packages/tsnet-proxy`.

## Remaining follow-up

The codebase no longer contains active references to `./nix/...` source paths.

Remaining mentions of the old layout are historical documentation only, primarily in:

- brainstorm notes under `docs/brainstorms/`
- older migration notes

Those can be updated later if desired, but they do not affect evaluation or builds.
