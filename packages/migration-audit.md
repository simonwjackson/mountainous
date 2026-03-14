# Package migration audit

Step 2 audit of package consumers, grouped by migration type.

## 1. Overlay definitions (`overlays/default.nix`)

These are the canonical package exposure points that currently bridge `pkgs/` and `nix/packages/` into `pkgs.*` attributes:

- `overlays/default.nix:3` → `vpn-ns = final.callPackage ../pkgs/vpn-ns {}`
- `overlays/default.nix:4` → `gogcli = final.callPackage ../pkgs/gogcli.nix {}`
- `overlays/default.nix:5` → `lifted-scripts = final.callPackage ../pkgs/scripts {}`
- `overlays/default.nix:6` → `airconnect = final.callPackage ../pkgs/airconnect {}`
- `overlays/default.nix:7` → `steam-cage = final.callPackage ../nix/packages/steam-cage {}`
- `overlays/default.nix:8` → `steam-prefs = final.callPackage ../nix/packages/steam-prefs {}`

### Downstream consumers of those overlay attrs

These files do not reference legacy paths directly, but they depend on the overlay definitions above and will break if overlay names or exposure change during migration:

- `hosts/fuji/default.nix:58-60` uses `gogcli` and `pkgs.lifted-scripts`
- `hosts/fuji/default.nix:367-368` uses `pkgs.vpn-ns`
- `hosts/yari/default.nix:98-99` uses `pkgs.vpn-ns`
- `hosts/rakku/default.nix:189` uses `pkgs.airconnect`
- `features/gaming/nixos.nix:38` uses `pkgs.steam-cage`
- `features/gaming/steam-prefs.nix:88,126` uses `pkgs.steam-prefs`
- `modules/kroger/default.nix:64-69,86` uses `pkgs.lifted-scripts.*`
- `modules/omi/default.nix:48` uses `pkgs.lifted-scripts.*`
- `pkgs/scripts/default.nix:122,133,144,155,166,177` self-references `pkgs.lifted-scripts.kroger-lib`

## 2. Direct `callPackage` users (`features/hyprland/keybinds.nix`)

These files hardcode source paths and need straightforward path-only rewrites when the sources move:

- `features/hyprland/keybinds.nix:10` → `../../nix/packages/brightness-sync`
- `features/hyprland/keybinds.nix:11` → `../../nix/packages/dictation`
- `features/hyprland/keybinds.nix:12` → `../../nix/packages/scale-adjust`
- `features/hyprland/keybinds.nix:13` → `../../nix/packages/split-toggle`
- `features/hyprland/keybinds.nix:14` → `../../nix/packages/workspace-cycler`

Migration type: direct source path rewrites from `../../nix/packages/...` to `../../packages/...`.

## 3. Host-local source builds (`hosts/rakku/default.nix`)

This host bypasses overlays and builds directly from a source tree in `pkgs/`:

- `hosts/rakku/default.nix:8` → `src = ../../pkgs/tsnet-proxy`
- `hosts/rakku/default.nix:9` → `modules = ../../pkgs/tsnet-proxy/gomod2nix.toml`

Migration type: direct path rewrites from `../../pkgs/tsnet-proxy` to `../../packages/tsnet-proxy`.

## 4. `nix run .#...` entrypoints that rely on package outputs

User-facing commands currently assume flake package or app outputs exist:

- `justfile:34,76` → `nix run .#nixie ...`
- `justfile:161` → `nix run .#deploy -- ...`
- `justfile:194` → `nix run .#scaffold -- ...`
- `justfile:204` → `nix run .#secrets -- encrypt`
- `justfile:215` → `nix run .#syncthing-keygen -- ...`
- `AGENTS.md:4` → `nix run .#scaffold -- [args]`
- `AGENTS.md:32` → `nix run .#deploy`

Related special case:

- `justfile:209` → `nix run .#agenix-rekey.x86_64-linux.rekey -- -a`
- `scripts/reencrypt-secrets.sh:80` → `nix run .#agenix-rekey -- rekey -a`

### Current flake status

`nix flake show --json --all-systems .` currently exposes only:

- `devShells`
- `nixosConfigurations`

It does **not** currently expose `packages` or `apps` outputs for `nixie`, `deploy`, `scaffold`, `secrets`, or `syncthing-keygen`.

Migration implication: step 5 must reconcile flake package exposure so these entrypoints resolve from the canonical `packages/` tree.

## Summary by migration bucket

- **Overlay source rewrites**: `overlays/default.nix`
- **Indirect overlay consumers to keep stable**: gaming features, `fuji`, `yari`, `rakku`, `kroger`, `omi`, and `pkgs/scripts/default.nix`
- **Direct `callPackage` rewrites**: `features/hyprland/keybinds.nix`
- **Host-local source build rewrites**: `hosts/rakku/default.nix`
- **Flake package/app exposure audit**: `justfile`, `AGENTS.md`, `scripts/reencrypt-secrets.sh`, and `flake.nix`/`nix flake show`
