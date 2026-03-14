# Mountainous

- Evolve a system: `just switch [system-name]`
- Scaffold new system: `nix run .#scaffold -- [args]`
- Search packages: `nix search nixpkgs <regex>` to find packages by name or description

## Code Style Guidelines
- **Project Structure**: Follow modular approach with `/modules/`, `/features/`, `/packages/`, `/hosts/`, `/home/`, and shared helpers in `/nix/lib/`
- **Function Parameters**: Use destructuring pattern, e.g., `{ config, pkgs, lib, ... }: { ... }`
- **Imports**: Place related imports together, use direct imports like `inherit (lib) mkEnableOption mkIf;`
- **Module Options**: Define with `mkEnableOption` and `mkOption`, in `mountainous` namespace
- **Naming Conventions**:
  - Use camelCase for variables and functions
  - Modules named based on functionality (e.g., `hyprland`, `impermanence`)
  - Package name should match directory name
- **Error Handling**: Use `lib.mkIf` for conditional configuration, with sensible defaults

## Development Workflow
- **CRITICAL**: Always `git add` new files immediately - Nix flakes only see git-tracked files
- **External Dependencies**: Prefer flake inputs with `flake = false` over `fetchurl`/`fetchFromGitHub` for updatability via `nix flake update`
- Store common helper functions in `nix/lib` or dedicated modules
- Test in VM with `nix build .#vm-<system>` before deploying
- Use the three-layer approach for home-manager configurations
- Enable modules with `mountainous.<module-name>.enable = true`
- Verify VM with `./result/bin/run-nixos-vm` before hardware deployment
- Documentation for various applications, operating system, etc is located in `./ai_docs`
- use `just [test|build|switch|..]` instead of raw nix commands where possible
- `hyprctl --instance 0 ..` for all hyprctl commands

## Deploy Commands

- `nix run .#deploy` - **DESTRUCTIVE** - For fresh system installs only. Will wipe the target system.
- For updating existing systems, use: `nixos-rebuild switch --flake .#<hostname> --target-host user@ip`

## Development Guidelines

- Run tests before completing any task, adding or updating tests as needed
- use ssh -F /dev/null when connecting

## Extending Upstream NixOS Modules

When wrapping an upstream module (e.g., `services.sunshine`) with custom options:

1. **Add custom options** to your module, then **forward to upstream** in `config`:
   ```nix
   options.mountainous.foo = {
     myOption = mkOption { ... };  # Your custom option
   };
   config = mkIf cfg.enable {
     services.foo = {               # Forward to upstream
       enable = true;
       setting = cfg.myOption;
     };
   };
   ```

2. **Don't redeclare upstream options** - set them directly via `services.*` in `config`

3. **Use `mkDefault`** for values that systems might override
