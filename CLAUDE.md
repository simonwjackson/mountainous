# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Build system: `nix build .#vm-[system-name]`
- Run VM: `./result/bin/run-nixos-vm`
- Deploy to hardware: `just switch [system-name]`
- Common just commands: `just switch`, `just test`, `just build`, `just up`, `just deploy`
- Scaffold new system: `nix run .#scaffold -- [args]`
- Check history: `just history`
- Search packages: `nix search nixpkgs <regex>` to find packages by name or description

## Code Style Guidelines
- **Project Structure**: Follow modular approach with `/nix/modules/`, `/nix/packages/`, `/nix/profiles/`, `/nix/systems/`
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
- Store common functions in `utils.nix`
- Test in VM with `nix build .#vm-<system>` before deploying
- Use the three-layer approach for home-manager configurations
- Enable modules with `mountainous.<module-name>.enable = true`
- Verify VM with `./result/bin/run-nixos-vm` before hardware deployment
- Documentation for various applications, operating system, etc is located in `./ai_docs`
- use `just [test|build|switch|..]` instead of raw nix commands where possible
- `hyprctl --instance 0 ..` for all hyprctl commands