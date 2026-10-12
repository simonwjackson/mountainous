# mountainous

Only rules that the code cannot show are here. Read the tree and the code for everything else.

- Nix flakes see only files that git tracks. Run `git add` on each new file before you evaluate or build.
- `nix run .#install` wipes every disk of the target host and installs from scratch. Run it only for a new install that the operator approved. Change a running host with `nixos-rebuild`.
- Take external sources as flake inputs, with `flake = false` for non-flakes, so `nix flake update` moves them. Do not use `fetchurl` or `fetchFromGitHub`.
- To wrap an upstream NixOS module, declare only the new options under `mountainous.*`. Set the upstream options directly in `config`, with `lib.mkDefault` for values a host can override.
- Connect to fleet machines with `ssh -F /dev/null`.
- Run every `hyprctl` command as `hyprctl --instance 0`.
- Before you finish, run `nix flake check`. Add or update a check when behaviour changes.
