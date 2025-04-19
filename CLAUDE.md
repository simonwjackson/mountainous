# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Build system: `nix build .#vm-[system-name]`
- Run VM: `./result/bin/run-nixos-vm`
- Deploy to hardware: `sudo nixos-rebuild switch --flake .#[system-name]`
- Common just commands: `just switch`, `just test`, `just build`, `just up`, `just deploy`

## Code Style Guidelines
- **Project Structure**: Follow modular approach with `/nix/modules/`, `/nix/packages/`, `/nix/profiles/`, `/nix/systems/`
- **Function Parameters**: Use destructuring pattern, e.g., `{ config, pkgs, lib, ... }: { ... }`
- **Module Options**: Define with `mkEnableOption` and `mkOption`, in `mountainous` namespace
- **Naming Conventions**: 
  - Use camelCase for variables and functions
  - Modules named based on functionality (e.g., `hyprland`, `impermanence`)
  - Package name should match directory name
- **Error Handling**: Use `lib.mkIf` for conditional configuration, with sensible defaults

## Development Workflow
- Store common functions in `utils.nix`
- Test in VM with `nix build .#vm-<system>` before deploying
- Use the three-layer approach for home-manager configurations
- Enable modules with `mountainous.<module-name>.enable = true`