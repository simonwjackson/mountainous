# Packages

This directory is the canonical package root for the repository.

The flake discovers packages from this tree, exposes them under `packages.<system>.*`, and injects them into `pkgs` through the generated package overlay.

## Layout

- Put each package in its own directory under `packages/`
- Add a `default.nix` at the package root
- Keep helper scripts, source files, and assets next to that `default.nix`
- Nested package directories are supported and are exposed with dash-joined attribute names

## Examples

- `packages/scaffold/default.nix` -> `.#scaffold` and `pkgs.scaffold`
- `packages/deploy/default.nix` -> `.#deploy` and `pkgs.deploy`
- `packages/syncthing-keygen/default.nix` -> `.#syncthing-keygen` and `pkgs.syncthing-keygen`
- `packages/steam-prefs/default.nix` -> `pkgs.steam-prefs`

## Notes

- New files must be `git add`ed immediately so the flake can evaluate them
- Prefer package directory names that match the exported attribute name
